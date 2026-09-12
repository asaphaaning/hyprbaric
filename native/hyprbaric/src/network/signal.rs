//! RINF projections for network state.
//!
//! The network runtime owns [`super::Snapshot`], [`super::Command`], and
//! [`super::Report`]. This module is the narrow transport boundary that turns
//! those domain values into generated RINF signal pieces.

use crate::signals;

use super::domain::{Entry, Interface, InterfaceKind, Traffic, Transfer};
use super::{Command, EntryState, Report, Snapshot};

impl From<&Snapshot> for signals::NetworkStatus {
    fn from(snapshot: &Snapshot) -> Self {
        Self {
            wifi_enabled: snapshot.wifi_enabled,
            device_present: snapshot.device_present,
            scanning: snapshot.scanning,
            active_ssid: snapshot.active_ssid.clone(),
            traffic: (&snapshot.traffic).into(),
            networks: snapshot.networks.iter().map(Into::into).collect(),
            interfaces: snapshot.interfaces.iter().map(Into::into).collect(),
            message: snapshot.message.clone(),
        }
    }
}

impl From<&Report> for signals::NetworkCommandResult {
    fn from(report: &Report) -> Self {
        match report {
            Report::Started(command) => Self::Started {
                command: command.into(),
            },
            Report::Failed { command, message } => Self::Failed {
                command: command.into(),
                message: message.clone(),
            },
        }
    }
}

impl From<&Command> for signals::NetworkCommand {
    fn from(command: &Command) -> Self {
        match command {
            Command::Scan => Self::Scan,
            Command::SetWifiEnabled { enabled } => Self::SetWifiEnabled { enabled: *enabled },
            Command::Connect { ssid } => Self::Connect { ssid: ssid.clone() },
            Command::Disconnect { interface } => Self::Disconnect {
                interface: interface.clone(),
            },
            Command::SetAutoConnect { interface, enabled } => Self::SetAutoConnect {
                interface: interface.clone(),
                enabled: *enabled,
            },
            Command::OpenSettings => Self::OpenSettings,
        }
    }
}

impl From<&Entry> for signals::NetworkEntry {
    fn from(entry: &Entry) -> Self {
        Self {
            ssid: entry.ssid.clone(),
            bssid: entry.bssid.clone(),
            strength: entry.strength,
            secure: entry.secure,
            state: entry.state.into(),
        }
    }
}

impl From<EntryState> for signals::NetworkEntryState {
    fn from(state: EntryState) -> Self {
        match state {
            EntryState::Available => Self::Available,
            EntryState::Active => Self::Active,
            EntryState::Connecting => Self::Connecting,
        }
    }
}

impl From<&Traffic> for signals::NetworkTraffic {
    fn from(traffic: &Traffic) -> Self {
        Self {
            upload: (&traffic.upload).into(),
            download: (&traffic.download).into(),
            ping_ms: traffic.ping_ms,
        }
    }
}

impl From<&Transfer> for signals::NetworkTransfer {
    fn from(transfer: &Transfer) -> Self {
        Self {
            bytes_per_second: transfer.bytes_per_second,
            total_bytes: transfer.total_bytes,
        }
    }
}

impl From<&Interface> for signals::NetworkInterface {
    fn from(interface: &Interface) -> Self {
        Self {
            kind: match interface.kind {
                InterfaceKind::Wifi => signals::NetworkInterfaceKind::Wifi,
                InterfaceKind::Ethernet => signals::NetworkInterfaceKind::Ethernet,
                InterfaceKind::Tunnel => signals::NetworkInterfaceKind::Tunnel,
                InterfaceKind::Other => signals::NetworkInterfaceKind::Other,
            },
            speed_mbps: interface.speed_mbps,
            frequency_mhz: interface.frequency_mhz,
            auto_connect: interface.auto_connect,
            name: interface.name.clone(),
            address: interface.address.clone(),
            active: interface.active,
        }
    }
}
