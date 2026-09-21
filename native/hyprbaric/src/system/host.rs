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
    path::Path,
    time::Duration,
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

/// Reads a CPU package temperature when a known sensor is present.
#[instrument(name = "system::host::temperature")]
pub(super) fn temperature() -> Option<Celsius> {
    read_hwmon_temperature()
        .inspect_err(|error| {
            tracing::debug!(%error, "hwmon CPU temperature is unavailable");
        })
        .ok()
        .flatten()
        .or_else(read_thermal_zone_temperature)
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

fn read_hwmon_temperature() -> Result<Option<Celsius>, Error> {
    let mut best: Option<(u8, Celsius)> = None;
    let hwmon = match fs::read_dir("/sys/class/hwmon") {
        Ok(entries) => entries,
        Err(error) if error.kind() == ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(Error::Temperature(error)),
    };

    for entry in hwmon {
        let entry = entry.map_err(Error::Temperature)?;
        let path = entry.path();
        let name = fs::read_to_string(path.join("name")).unwrap_or_default();
        let rank = sensor_rank(name.trim());
        let Some(celsius) = read_temp_input(&path) else {
            continue;
        };
        match best {
            Some((current, _)) if rank <= current => {}
            _ => best = Some((rank, celsius)),
        }
    }

    Ok(best.map(|(_, celsius)| celsius))
}

fn read_thermal_zone_temperature() -> Option<Celsius> {
    let zones = fs::read_dir("/sys/class/thermal").ok()?;
    for entry in zones.flatten() {
        let path = entry.path();
        let name = path.file_name()?.to_string_lossy();
        if !name.starts_with("thermal_zone") {
            continue;
        }
        let kind = fs::read_to_string(path.join("type")).ok()?;
        if !matches!(kind.trim(), "x86_pkg_temp" | "cpu-thermal" | "soc_thermal") {
            continue;
        }
        let raw = fs::read_to_string(path.join("temp")).ok()?;
        let millidegrees = raw.trim().parse::<i64>().ok()?;
        if let Some(celsius) = Celsius::from_millidegrees(millidegrees) {
            return Some(celsius);
        }
    }
    None
}

fn read_temp_input(hwmon: &Path) -> Option<Celsius> {
    let mut preferred = None;
    let mut fallback = None;
    let entries = fs::read_dir(hwmon).ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("temp") || !name.ends_with("_input") {
            continue;
        }
        let raw = fs::read_to_string(entry.path()).ok()?;
        let millidegrees = raw.trim().parse::<i64>().ok()?;
        let Some(celsius) = Celsius::from_millidegrees(millidegrees) else {
            continue;
        };
        let label = name.replace("_input", "_label");
        let label = fs::read_to_string(hwmon.join(label)).unwrap_or_default();
        if label_is_package(label.trim()) || name == "temp1_input" {
            preferred = Some(celsius);
        } else {
            fallback = Some(celsius);
        }
    }
    preferred.or(fallback)
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
    use std::time::Duration;

    use super::{Tick, parse_meminfo, parse_uptime};
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
}
