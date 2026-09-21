use rinf::RustSignal;
use serde::Serialize;

/// Live system occupancy published to Flutter.
#[derive(Serialize, RustSignal)]
pub struct SystemStatus {
    /// Processor occupancy when two `/proc/stat` ticks have been seen.
    pub cpu_percent: Option<u8>,
    /// Oldest-first CPU occupancy samples.
    pub cpu_history: Vec<u8>,
    /// Bytes considered in use.
    pub memory_used_bytes: u64,
    /// Installed or reported capacity.
    pub memory_total_bytes: u64,
    /// Oldest-first memory occupancy samples.
    pub memory_history: Vec<u8>,
    /// Root filesystem bytes in use, when known.
    pub disk_used_bytes: Option<u64>,
    /// Root filesystem capacity, when known.
    pub disk_total_bytes: Option<u64>,
    /// Seconds since boot.
    pub uptime_seconds: u64,
    /// Package or SoC temperature in degrees Celsius.
    pub temperature_celsius: Option<f64>,
    /// Count of processes visible in `/proc`.
    pub process_count: u32,
    /// User-facing failure detail when occupancy could not be assembled.
    pub message: Option<String>,
}
