//! Linux occupancy sources: `/proc`, hwmon, and the root `statvfs`.
//!
//! Parsers accept the raw text of a proc file so tests can fix the boundary
//! without a live host. File reads and `statvfs` stay here and never leak into
//! the domain module.

use std::{
    ffi::CString,
    fs,
    io::{self, ErrorKind},
    os::unix::ffi::OsStrExt,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};

use tracing::instrument;

use super::{
    Bytes, Celsius, Disk, Error, Memory,
    domain::{Trace, Usage},
};

/// Cumulative idle and total jiffies from the aggregate `cpu` line.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) struct Tick {
    idle: u64,
    total: u64,
}

/// Reads the aggregate CPU tick from `/proc/stat`.
#[instrument(name = "system::host::cpu_tick", err)]
pub(super) fn cpu_tick() -> Result<Tick, Error> {
    let contents = fs::read_to_string("/proc/stat").map_err(Error::CpuStat)?;
    Tick::parse(&contents)
}

/// Reads memory occupancy from `/proc/meminfo`.
#[instrument(name = "system::host::memory", err)]
pub(super) fn memory(history: Trace) -> Result<Memory, Error> {
    let contents = fs::read_to_string("/proc/meminfo").map_err(Error::Memory)?;
    parse_meminfo(&contents, history)
}

/// Reads time since boot from `/proc/uptime`.
#[instrument(name = "system::host::uptime", err)]
pub(super) fn uptime() -> Result<Duration, Error> {
    let contents = fs::read_to_string("/proc/uptime").map_err(Error::Uptime)?;
    parse_uptime(&contents)
}

/// Counts numeric `/proc` entries as running processes.
#[instrument(name = "system::host::processes", err)]
pub(super) fn processes() -> Result<u32, Error> {
    let entries = fs::read_dir("/proc").map_err(Error::Processes)?;
    let mut count = 0_u32;
    for entry in entries {
        let entry = entry.map_err(Error::Processes)?;
        if is_process_dir(&entry.file_name()) {
            count = count.saturating_add(1);
        }
    }
    Ok(count)
}

/// Reads the root filesystem occupancy.
#[instrument(name = "system::host::disk")]
pub(super) fn disk() -> Disk {
    match root_volume() {
        Ok(disk) => disk,
        Err(error) => {
            tracing::debug!(%error, "Root filesystem occupancy is unavailable");
            Disk::Unavailable
        }
    }
}

/// A cached CPU temperature source, periodically checked for better sensors.
///
/// Only the selected input is read between probes. A failed input triggers
/// immediate discovery, while an absent sensor is retried after thirty seconds.
pub(super) struct Thermometer {
    /// Cached source and discovery age.
    selection: Selection,
    /// Hwmon discovery root.
    hwmon: PathBuf,
    /// Thermal-zone fallback root.
    thermal: PathBuf,
}

/// The last discovery result and the time it was checked.
enum Selection {
    /// No discovery has run yet.
    Unprobed,
    /// No readable CPU sensor was found at the last check.
    Missing { checked: Instant },
    /// A sensor was found and is read directly between checks.
    Ready { sensor: Sensor, checked: Instant },
}

/// One readable temperature input at the Linux host boundary.
struct Sensor {
    /// Sysfs input whose contents are millidegrees Celsius.
    input: PathBuf,
}

/// A discoverable input, ranked before any temperature value is read.
struct Candidate {
    /// Input path to test if higher-ranked inputs fail.
    sensor: Sensor,
    /// CPU-focused chip names outrank ACPI and unrelated devices.
    chip_rank: u8,
    /// Package labels outrank generic channels within one chip.
    channel_rank: u8,
}

const SENSOR_RECHECK: Duration = Duration::from_secs(30);

impl Default for Thermometer {
    fn default() -> Self {
        Self::with_roots("/sys/class/hwmon", "/sys/class/thermal")
    }
}

impl Thermometer {
    fn with_roots(hwmon: impl Into<PathBuf>, thermal: impl Into<PathBuf>) -> Self {
        Self {
            selection: Selection::Unprobed,
            hwmon: hwmon.into(),
            thermal: thermal.into(),
        }
    }

    /// Reads the selected CPU sensor, reprobing if it fails or becomes stale.
    #[instrument(name = "system::host::temperature", skip(self))]
    pub(super) fn sample(&mut self) -> Option<Celsius> {
        self.sample_at(Instant::now())
    }

    fn sample_at(&mut self, now: Instant) -> Option<Celsius> {
        match &self.selection {
            Selection::Ready { sensor, checked }
                if now.saturating_duration_since(*checked) < SENSOR_RECHECK =>
            {
                if let Some(value) = sensor.read() {
                    return Some(value);
                }
            }
            Selection::Missing { checked }
                if now.saturating_duration_since(*checked) < SENSOR_RECHECK =>
            {
                return None;
            }
            Selection::Unprobed | Selection::Ready { .. } | Selection::Missing { .. } => {}
        }

        self.probe(now)
    }

    #[instrument(name = "system::host::temperature_probe", skip(self, now))]
    fn probe(&mut self, now: Instant) -> Option<Celsius> {
        let mut candidates = self.hwmon_candidates();
        candidates.extend(self.thermal_candidates());
        candidates.sort_by(|left, right| {
            (right.chip_rank, right.channel_rank)
                .cmp(&(left.chip_rank, left.channel_rank))
                .then_with(|| left.sensor.input.cmp(&right.sensor.input))
        });

        for candidate in candidates {
            if let Some(value) = candidate.sensor.read() {
                tracing::debug!(path = %candidate.sensor.input.display(), "Selected CPU temperature sensor");
                self.selection = Selection::Ready {
                    sensor: candidate.sensor,
                    checked: now,
                };
                return Some(value);
            }
        }

        self.selection = Selection::Missing { checked: now };
        None
    }

    fn hwmon_candidates(&self) -> Vec<Candidate> {
        let entries = match fs::read_dir(&self.hwmon) {
            Ok(entries) => entries,
            Err(error) if error.kind() == ErrorKind::NotFound => return Vec::new(),
            Err(error) => {
                tracing::debug!(error = %Error::Temperature(error), "Could not discover hwmon temperature sensors");
                return Vec::new();
            }
        };

        let mut candidates = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            let name = fs::read_to_string(path.join("name")).unwrap_or_default();
            let chip_rank = sensor_rank(name.trim());
            candidates.extend(temp_candidates(&path, chip_rank));
        }
        candidates
    }

    fn thermal_candidates(&self) -> Vec<Candidate> {
        let Ok(zones) = fs::read_dir(&self.thermal) else {
            return Vec::new();
        };
        let mut candidates = Vec::new();
        for entry in zones.flatten() {
            let path = entry.path();
            if !entry
                .file_name()
                .to_string_lossy()
                .starts_with("thermal_zone")
            {
                continue;
            }
            let Ok(kind) = fs::read_to_string(path.join("type")) else {
                continue;
            };
            if matches!(kind.trim(), "x86_pkg_temp" | "cpu-thermal" | "soc_thermal") {
                candidates.push(Candidate {
                    sensor: Sensor {
                        input: path.join("temp"),
                    },
                    chip_rank: 0,
                    channel_rank: 0,
                });
            }
        }
        candidates
    }
}

impl Sensor {
    fn read(&self) -> Option<Celsius> {
        let raw = fs::read_to_string(&self.input).ok()?;
        let millidegrees = raw.trim().parse::<i64>().ok()?;
        Celsius::from_millidegrees(millidegrees)
    }
}

fn temp_candidates(hwmon: &Path, chip_rank: u8) -> Vec<Candidate> {
    let Ok(entries) = fs::read_dir(hwmon) else {
        return Vec::new();
    };
    let mut candidates = Vec::new();
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("temp") || !name.ends_with("_input") {
            continue;
        }
        let label = name.replace("_input", "_label");
        let label = fs::read_to_string(hwmon.join(label)).unwrap_or_default();
        let channel_rank = if label_is_package(label.trim()) {
            2
        } else if name == "temp1_input" {
            1
        } else {
            0
        };
        candidates.push(Candidate {
            sensor: Sensor {
                input: entry.path(),
            },
            chip_rank,
            channel_rank,
        });
    }
    candidates
}

impl Tick {
    /// Parses the aggregate `cpu` line of `/proc/stat`.
    pub(super) fn parse(stat: &str) -> Result<Self, Error> {
        let line = stat
            .lines()
            .find(|line| line.starts_with("cpu "))
            .ok_or(Error::CpuStatMissing)?;
        let mut fields = line.split_whitespace();
        if fields.next() != Some("cpu") {
            return Err(Error::CpuStatMissing);
        }

        let mut values = [0_u64; 8];
        let mut count = 0_usize;
        for field in fields.by_ref() {
            if count >= values.len() {
                break;
            }
            values[count] = field.parse().map_err(|_parse| Error::CpuStatMissing)?;
            count += 1;
        }
        if count < 4 {
            return Err(Error::CpuStatMissing);
        }

        let idle = values[3].saturating_add(values[4]);
        let total = values.iter().copied().sum();
        Ok(Self { idle, total })
    }

    /// Occupancy between this earlier tick and a later one.
    pub(super) fn usage_until(self, later: Self) -> Usage {
        let idle = later.idle.saturating_sub(self.idle);
        let total = later.total.saturating_sub(self.total);
        if total == 0 {
            return Usage::Measuring;
        }

        let busy = total.saturating_sub(idle);
        Usage::Sample(super::Percent::from_ratio(busy, total))
    }
}

pub(super) fn parse_meminfo(contents: &str, history: Trace) -> Result<Memory, Error> {
    let total = kib_field(contents, "MemTotal").ok_or(Error::MemoryMissing)?;
    let used = match kib_field(contents, "MemAvailable") {
        Some(available) => total.saturating_sub(available),
        None => {
            let free = kib_field(contents, "MemFree").unwrap_or(0);
            let buffers = kib_field(contents, "Buffers").unwrap_or(0);
            let cached = kib_field(contents, "Cached").unwrap_or(0);
            total.saturating_sub(free.saturating_add(buffers).saturating_add(cached))
        }
    };

    Ok(Memory {
        used: Bytes::from_kib(used),
        total: Bytes::from_kib(total),
        history,
    }
    .recorded())
}

pub(super) fn parse_uptime(contents: &str) -> Result<Duration, Error> {
    let field = contents
        .split_whitespace()
        .next()
        .ok_or(Error::UptimeMissing)?;
    let whole = field.split('.').next().ok_or(Error::UptimeMissing)?;
    let seconds = whole
        .parse::<u64>()
        .map_err(|_parse| Error::UptimeMissing)?;
    Ok(Duration::from_secs(seconds))
}

fn kib_field(contents: &str, name: &str) -> Option<u64> {
    contents.lines().find_map(|line| {
        let (key, rest) = line.split_once(':')?;
        if key != name {
            return None;
        }
        rest.split_whitespace().next()?.parse().ok()
    })
}

fn is_process_dir(name: &std::ffi::OsStr) -> bool {
    let bytes = name.as_bytes();
    !bytes.is_empty() && bytes.iter().all(u8::is_ascii_digit)
}

fn root_volume() -> Result<Disk, Error> {
    let path = CString::new("/").map_err(|_nul| Error::DiskPath)?;
    let mut stats = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    // SAFETY: `path` is a valid C string and `stats` is the output of `statvfs`.
    let result = unsafe { libc::statvfs(path.as_ptr(), stats.as_mut_ptr()) };
    if result != 0 {
        return Err(Error::Disk(io::Error::last_os_error()));
    }
    // SAFETY: `statvfs` initialized the struct on a zero return.
    let stats = unsafe { stats.assume_init() };

    let fragment = stats.f_frsize;
    let total = fragment.saturating_mul(stats.f_blocks);
    let available = fragment.saturating_mul(stats.f_bavail);
    if total == 0 {
        return Err(Error::Disk(io::Error::new(
            ErrorKind::InvalidData,
            "root filesystem reported no blocks",
        )));
    }

    Ok(Disk::Present {
        used: Bytes::new(total.saturating_sub(available)),
        total: Bytes::new(total),
    })
}

fn label_is_package(label: &str) -> bool {
    let lowered = label.to_ascii_lowercase();
    lowered.contains("tctl") || lowered.contains("package") || lowered.contains("cpu")
}

fn sensor_rank(name: &str) -> u8 {
    match name {
        "k10temp" | "coretemp" | "zenpower" | "cpu_thermal" => 3,
        "acpitz" => 2,
        _ => 1,
    }
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicU64, Ordering},
        time::{Duration, Instant},
    };

    use super::{Thermometer, Tick, parse_meminfo, parse_uptime};
    use crate::system::domain::{Trace, Usage};

    #[test]
    fn cpu_tick_uses_idle_plus_iowait_against_the_aggregate_line() {
        let earlier =
            Tick::parse("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 100 0 100 800 0 0 0 0 0 0\n")
                .expect("aggregate cpu line should parse");
        let later =
            Tick::parse("cpu  120 0 100 880 0 0 0 0 0 0\n").expect("later tick should parse");

        assert_eq!(
            earlier.usage_until(later),
            Usage::Sample(crate::system::Percent::new(20))
        );
    }

    #[test]
    fn cpu_tick_without_progress_stays_measuring() {
        let tick = Tick::parse("cpu  10 0 10 80 0 0 0 0\n").expect("tick should parse");
        assert_eq!(tick.usage_until(tick), Usage::Measuring);
    }

    #[test]
    fn meminfo_prefers_available_over_free_plus_cache() {
        let memory = parse_meminfo(
            "MemTotal:       32768000 kB\nMemFree:         1000000 kB\nMemAvailable:   20971520 kB\nBuffers:          100 kB\nCached:           200 kB\n",
            Trace::empty(),
        )
        .expect("meminfo should parse");

        assert_eq!(memory.total.as_u64(), 32_768_000 * 1024);
        assert_eq!(memory.used.as_u64(), (32_768_000 - 20_971_520) * 1024);
        assert_eq!(memory.history.iter().count(), 1);
    }

    #[test]
    fn uptime_reads_the_whole_seconds_field() {
        assert_eq!(
            parse_uptime("8024.12 12345.67\n").expect("uptime should parse"),
            Duration::from_secs(8024)
        );
    }

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(0);

    struct Fixture {
        root: PathBuf,
    }

    impl Fixture {
        fn new() -> Self {
            let root = std::env::temp_dir().join(format!(
                "hyprbaric-temperature-{}-{}",
                std::process::id(),
                NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir_all(&root).expect("fixture root");
            Self { root }
        }

        fn write(&self, path: &str, contents: &str) {
            let file = self.root.join(path);
            fs::create_dir_all(file.parent().expect("fixture parent")).expect("fixture directory");
            fs::write(file, contents).expect("fixture file");
        }

        fn thermometer(&self) -> Thermometer {
            Thermometer::with_roots(self.root.join("hwmon"), self.root.join("thermal"))
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.root).expect("remove fixture");
        }
    }

    #[test]
    fn selected_cpu_sensor_is_reused_until_periodic_discovery() {
        let fixture = Fixture::new();
        fixture.write("hwmon/nvme/name", "nvme\n");
        fixture.write("hwmon/nvme/temp1_input", "30000\n");
        fixture.write("hwmon/cpu/name", "k10temp\n");
        fixture.write("hwmon/cpu/temp1_input", "55000\n");
        fixture.write("hwmon/cpu/temp2_label", "Tctl\n");
        fixture.write("hwmon/cpu/temp2_input", "61000\n");

        let now = Instant::now();
        let mut thermometer = fixture.thermometer();
        assert_eq!(
            thermometer.sample_at(now).map(|value| value.as_f64()),
            Some(61.0)
        );

        fixture.write("hwmon/cpu/temp2_input", "62000\n");
        fixture.write("hwmon/cpu/temp1_label", "CPU Package\n");
        assert_eq!(
            thermometer
                .sample_at(now + Duration::from_secs(1))
                .map(|value| value.as_f64()),
            Some(62.0)
        );
        assert_eq!(
            thermometer
                .sample_at(now + Duration::from_secs(31))
                .map(|value| value.as_f64()),
            Some(55.0)
        );
    }

    #[test]
    fn unreadable_selected_sensor_reprobes_immediately() {
        let fixture = Fixture::new();
        fixture.write("hwmon/cpu/name", "k10temp\n");
        fixture.write("hwmon/cpu/temp1_input", "55000\n");
        let now = Instant::now();
        let mut thermometer = fixture.thermometer();
        assert_eq!(
            thermometer.sample_at(now).map(|value| value.as_f64()),
            Some(55.0)
        );

        fs::remove_file(fixture.root.join("hwmon/cpu/temp1_input"))
            .expect("remove selected sensor");
        fixture.write("hwmon/cpu/temp2_label", "Tctl\n");
        fixture.write("hwmon/cpu/temp2_input", "60000\n");
        assert_eq!(
            thermometer
                .sample_at(now + Duration::from_secs(1))
                .map(|value| value.as_f64()),
            Some(60.0)
        );
    }

    #[test]
    fn missing_sensor_is_retried_after_discovery_interval() {
        let fixture = Fixture::new();
        let now = Instant::now();
        let mut thermometer = fixture.thermometer();
        assert_eq!(thermometer.sample_at(now), None);

        fixture.write("thermal/thermal_zone0/type", "cpu-thermal\n");
        fixture.write("thermal/thermal_zone0/temp", "42000\n");
        assert_eq!(thermometer.sample_at(now + Duration::from_secs(1)), None);
        assert_eq!(
            thermometer
                .sample_at(now + Duration::from_secs(31))
                .map(|value| value.as_f64()),
            Some(42.0)
        );
    }

    #[test]
    fn invalid_high_priority_input_falls_back_to_a_valid_sensor() {
        let fixture = Fixture::new();
        fixture.write("hwmon/cpu/name", "k10temp\n");
        fixture.write("hwmon/cpu/temp1_input", "not a temperature\n");
        fixture.write("hwmon/acpi/name", "acpitz\n");
        fixture.write("hwmon/acpi/temp1_input", "44000\n");

        let mut thermometer = fixture.thermometer();
        assert_eq!(
            thermometer
                .sample_at(Instant::now())
                .map(|value| value.as_f64()),
            Some(44.0)
        );
    }
}
