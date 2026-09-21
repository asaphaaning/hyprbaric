//! RINF projections for system occupancy.

use crate::signals;

use super::{Cpu, Disk, Memory, Snapshot, Usage};

impl From<&Snapshot> for signals::SystemStatus {
    fn from(snapshot: &Snapshot) -> Self {
        match snapshot {
            Snapshot::Ready {
                cpu,
                memory,
                disk,
                uptime,
                temperature,
                processes,
            } => Self::from_ready(cpu, memory, disk, uptime, *temperature, *processes),
            Snapshot::Unavailable { message } => Self {
                cpu_percent: None,
                cpu_history: Vec::new(),
                memory_used_bytes: 0,
                memory_total_bytes: 0,
                memory_history: Vec::new(),
                disk_used_bytes: None,
                disk_total_bytes: None,
                uptime_seconds: 0,
                temperature_celsius: None,
                process_count: 0,
                message: Some(message.clone()),
            },
        }
    }
}

impl signals::SystemStatus {
    fn from_ready(
        cpu: &Cpu,
        memory: &Memory,
        disk: &Disk,
        uptime: &std::time::Duration,
        temperature: Option<super::Celsius>,
        processes: u32,
    ) -> Self {
        let (disk_used_bytes, disk_total_bytes) = match disk {
            Disk::Present { used, total } => (Some(used.as_u64()), Some(total.as_u64())),
            Disk::Unavailable => (None, None),
        };

        Self {
            cpu_percent: match cpu.usage {
                Usage::Measuring => None,
                Usage::Sample(percent) => Some(percent.as_u8()),
            },
            cpu_history: cpu.history.iter().map(|percent| percent.as_u8()).collect(),
            memory_used_bytes: memory.used.as_u64(),
            memory_total_bytes: memory.total.as_u64(),
            memory_history: memory
                .history
                .iter()
                .map(|percent| percent.as_u8())
                .collect(),
            disk_used_bytes,
            disk_total_bytes,
            uptime_seconds: uptime.as_secs(),
            temperature_celsius: temperature.map(super::Celsius::as_f64),
            process_count: processes,
            message: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use crate::{
        signals,
        system::{Bytes, Cpu, Disk, Memory, Percent, Snapshot, Trace},
    };

    #[test]
    fn ready_snapshot_projects_optional_cpu_and_disk() {
        let snapshot = Snapshot::Ready {
            cpu: Cpu::measuring().record(Percent::new(12)),
            memory: Memory {
                used: Bytes::new(11_200_000_000),
                total: Bytes::new(32_000_000_000),
                history: Trace::empty().push(Percent::new(35)),
            },
            disk: Disk::Present {
                used: Bytes::new(56),
                total: Bytes::new(100),
            },
            uptime: Duration::from_secs(2 * 3600 + 14 * 60),
            temperature: crate::system::Celsius::from_millidegrees(58_000),
            processes: 238,
        };

        let status = signals::SystemStatus::from(&snapshot);
        assert_eq!(status.cpu_percent, Some(12));
        assert_eq!(status.cpu_history, vec![12]);
        assert_eq!(status.memory_used_bytes, 11_200_000_000);
        assert_eq!(status.disk_used_bytes, Some(56));
        assert_eq!(status.uptime_seconds, 8040);
        assert_eq!(status.process_count, 238);
        assert_eq!(status.message, None);
    }

    #[test]
    fn unavailable_snapshot_projects_a_message() {
        let status = signals::SystemStatus::from(&Snapshot::unavailable("meminfo is missing"));
        assert_eq!(status.cpu_percent, None);
        assert_eq!(status.memory_total_bytes, 0);
        assert_eq!(status.message.as_deref(), Some("meminfo is missing"));
    }
}
