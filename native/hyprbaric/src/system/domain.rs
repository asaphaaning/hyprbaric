//! System occupancy published to the bar.
//!
//! The runtime keeps `/proc`, hwmon, and `statvfs` bytes at the host boundary.
//! This module owns Hyprbaric's small occupancy vocabulary: [`Percent`],
//! [`Bytes`], [`Usage`], [`Trace`], [`Cpu`], [`Memory`], [`Disk`], and
//! [`Snapshot`].
//!
//! ```text
//! Snapshot
//! ├── cpu      Usage + rolling Trace
//! ├── memory   Bytes used/total + Trace
//! ├── disk     Present { used, total } | Unavailable
//! ├── uptime
//! ├── temperature
//! └── processes
//! ```

use std::{collections::VecDeque, time::Duration};

/// A clamped occupancy percentage.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Percent(u8);

/// A byte count owned by a memory or disk reading.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Bytes(u64);

/// Whole degrees Celsius.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Celsius(i16);

/// CPU occupancy derived from adjacent `/proc/stat` samples.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Usage {
    /// Waiting for a second counter sample.
    Measuring,
    /// Usage derived from two adjacent ticks.
    Sample(Percent),
}

/// A rolling window of occupancy samples, oldest first.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Trace {
    samples: VecDeque<Percent>,
}

/// CPU occupancy and its recent history.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Cpu {
    /// Current usage, or [`Usage::Measuring`] before two ticks exist.
    pub usage: Usage,
    /// Recent occupancy samples, oldest first.
    pub history: Trace,
}

/// Memory occupancy and its recent history.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Memory {
    /// Bytes considered in use.
    pub used: Bytes,
    /// Installed or reported capacity.
    pub total: Bytes,
    /// Recent occupancy samples, oldest first.
    pub history: Trace,
}

/// Root filesystem occupancy.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Disk {
    /// Capacity for the root mount is known.
    Present {
        /// Bytes considered in use.
        used: Bytes,
        /// Total addressable bytes.
        total: Bytes,
    },
    /// The root mount could not be measured.
    Unavailable,
}

/// UI-facing system occupancy snapshot.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Snapshot {
    /// Host counters were readable.
    Ready {
        /// Processor occupancy.
        cpu: Cpu,
        /// Memory occupancy.
        memory: Memory,
        /// Root filesystem occupancy.
        disk: Disk,
        /// Time since boot.
        uptime: Duration,
        /// Package or SoC temperature when a sensor exists.
        temperature: Option<Celsius>,
        /// Count of processes visible in `/proc`.
        processes: u32,
    },
    /// Host counters could not be assembled into a snapshot.
    Unavailable {
        /// User-facing failure detail.
        message: String,
    },
}

impl Percent {
    /// Number of samples kept in a [`Trace`].
    pub const TRACE: usize = 16;

    /// Creates a percentage clamped to `0..=100`.
    pub fn new(value: u8) -> Self {
        Self(value.min(100))
    }

    /// Occupancy of `used` within `total`, rounded to the nearest percent.
    pub fn from_ratio(used: u64, total: u64) -> Self {
        if total == 0 {
            return Self(0);
        }

        let rounded = (u128::from(used) * 100 + u128::from(total) / 2) / u128::from(total);
        Self::new(rounded.min(100) as u8)
    }

    /// Returns this percentage as an integer.
    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl Bytes {
    /// Creates a byte count.
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    /// Interprets a `/proc` kilobyte field as bytes.
    pub const fn from_kib(value: u64) -> Self {
        Self(value.saturating_mul(1024))
    }

    /// Returns the raw byte count.
    pub const fn as_u64(self) -> u64 {
        self.0
    }
}

impl Celsius {
    /// Converts a millidegree hwmon reading into whole degrees.
    pub fn from_millidegrees(value: i64) -> Option<Self> {
        if value.abs() < 1_000 {
            return None;
        }

        Some(Self((value / 1_000) as i16))
    }

    /// Returns whole degrees as a floating value for the transport boundary.
    pub const fn as_f64(self) -> f64 {
        self.0 as f64
    }
}

impl Usage {
    /// Returns the sampled percent when one exists.
    pub const fn percent(self) -> Option<Percent> {
        match self {
            Self::Measuring => None,
            Self::Sample(percent) => Some(percent),
        }
    }
}

impl Trace {
    /// Maximum number of retained samples.
    pub const CAPACITY: usize = Percent::TRACE;

    /// An empty history.
    pub fn empty() -> Self {
        Self {
            samples: VecDeque::new(),
        }
    }

    /// Appends a sample, dropping the oldest once the window is full.
    #[must_use]
    pub fn push(mut self, sample: Percent) -> Self {
        if self.samples.len() == Self::CAPACITY {
            self.samples.pop_front();
        }
        self.samples.push_back(sample);
        self
    }

    /// Oldest-first samples.
    pub fn iter(&self) -> impl Iterator<Item = Percent> + '_ {
        self.samples.iter().copied()
    }
}

impl Cpu {
    /// Measuring occupancy with an empty history.
    pub fn measuring() -> Self {
        Self {
            usage: Usage::Measuring,
            history: Trace::empty(),
        }
    }

    /// Records a newly sampled occupancy into usage and history.
    #[must_use]
    pub fn record(self, percent: Percent) -> Self {
        Self {
            usage: Usage::Sample(percent),
            history: self.history.push(percent),
        }
    }
}

impl Memory {
    /// Occupancy of used bytes within total bytes.
    pub fn percent(&self) -> Percent {
        Percent::from_ratio(self.used.as_u64(), self.total.as_u64())
    }

    /// Records the current occupancy into history.
    #[must_use]
    pub fn recorded(self) -> Self {
        let percent = self.percent();
        let Self {
            used,
            total,
            history,
        } = self;
        Self {
            used,
            total,
            history: history.push(percent),
        }
    }
}

impl Snapshot {
    /// Creates a fully unavailable snapshot.
    pub fn unavailable(message: impl Into<String>) -> Self {
        Self::Unavailable {
            message: message.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{Bytes, Celsius, Cpu, Memory, Percent, Trace, Usage};

    #[test]
    fn percent_from_ratio_rounds_and_clamps() {
        assert_eq!(Percent::from_ratio(0, 0).as_u8(), 0);
        assert_eq!(Percent::from_ratio(1, 3).as_u8(), 33);
        assert_eq!(Percent::from_ratio(2, 3).as_u8(), 67);
        assert_eq!(Percent::from_ratio(11, 10).as_u8(), 100);
    }

    #[test]
    fn bytes_from_kib_shift_by_ten() {
        assert_eq!(Bytes::from_kib(1).as_u64(), 1024);
    }

    #[test]
    fn millidegrees_become_whole_celsius() {
        assert_eq!(
            Celsius::from_millidegrees(58_000).map(Celsius::as_f64),
            Some(58.0)
        );
        assert_eq!(Celsius::from_millidegrees(500), None);
        assert_eq!(
            Celsius::from_millidegrees(-12_000).map(Celsius::as_f64),
            Some(-12.0)
        );
    }

    #[test]
    fn trace_drops_the_oldest_sample_at_capacity() {
        let mut trace = Trace::empty();
        for index in 0..=Trace::CAPACITY {
            trace = trace.push(Percent::new(index as u8));
        }

        let samples: Vec<u8> = trace.iter().map(Percent::as_u8).collect();
        assert_eq!(samples.len(), Trace::CAPACITY);
        assert_eq!(samples.first().copied(), Some(1));
        assert_eq!(samples.last().copied(), Some(Trace::CAPACITY as u8));
    }

    #[test]
    fn cpu_record_promotes_measuring_into_a_sample() {
        let cpu = Cpu::measuring().record(Percent::new(12));
        assert_eq!(cpu.usage, Usage::Sample(Percent::new(12)));
        assert_eq!(cpu.history.iter().count(), 1);
    }

    #[test]
    fn memory_percent_follows_used_over_total() {
        let memory = Memory {
            used: Bytes::new(12),
            total: Bytes::new(32),
            history: Trace::empty(),
        };
        assert_eq!(memory.percent().as_u8(), 38);
    }
}
