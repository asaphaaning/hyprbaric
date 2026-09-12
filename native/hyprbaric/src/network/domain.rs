//! Network state published to the bar.
//!
//! These types keep UI-facing network state independent of NetworkManager and
//! `/proc` details. Boundary modules construct [`Snapshot`] values from system
//! data; the runtime only needs to publish them.

/// A UI-facing network snapshot.
///
/// [`Snapshot`] intentionally remains a projection for the bar. It carries the
/// traffic, Wi-Fi list, interface rows, and unavailable copy Flutter renders in
/// one update; NetworkManager-specific availability stays at the boundary that
/// constructs it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Whether Wi-Fi is enabled in NetworkManager.
    pub wifi_enabled: bool,
    /// Whether NetworkManager reports a wireless device.
    pub device_present: bool,
    /// Whether the current snapshot was read around a requested scan.
    pub scanning: bool,
    /// The SSID NetworkManager reports as active.
    pub active_ssid: Option<String>,
    /// Current traffic counters and rates.
    pub traffic: Traffic,
    /// Visible Wi-Fi entries after duplicate SSIDs are merged.
    pub networks: Vec<Entry>,
    /// Network interfaces visible to NetworkManager.
    pub interfaces: Vec<Interface>,
    /// A user-facing unavailable or failure detail.
    pub message: Option<String>,
}

/// One visible Wi-Fi entry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    /// The human-facing network name.
    pub ssid: String,
    /// The selected access point address when one is known.
    pub bssid: Option<String>,
    /// Signal strength in NetworkManager's percent-like scale.
    pub strength: u8,
    /// Whether the access point requires a secret.
    pub secure: bool,
    /// The connection state NetworkManager reports for this visible entry.
    pub state: EntryState,
}

/// The display state of one visible Wi-Fi entry.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum EntryState {
    /// The entry is visible but has no active connection transition.
    #[default]
    Available,
    /// The entry represents the active SSID.
    Active,
    /// NetworkManager is connecting the active SSID.
    Connecting,
}

/// Transfer rate and reachability data.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Traffic {
    /// Bytes sent by non-loopback interfaces.
    pub upload: Transfer,
    /// Bytes received by non-loopback interfaces.
    pub download: Transfer,
    /// Best-effort reachability latency.
    pub ping_ms: Option<u16>,
}

/// A directional traffic counter.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Transfer {
    /// Current byte rate derived from adjacent samples.
    pub bytes_per_second: u64,
    /// Total bytes observed in the current system counter sample.
    pub total_bytes: u64,
}

/// One NetworkManager interface row.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Interface {
    /// NetworkManager's device family, parsed at the boundary.
    pub kind: InterfaceKind,
    /// Link speed reported by the driver, in megabits per second.
    pub speed_mbps: Option<u32>,
    /// Active radio frequency in MHz, when available.
    pub frequency_mhz: Option<u32>,
    /// Whether this Wi-Fi interface may automatically connect.
    pub auto_connect: Option<bool>,
    /// The system interface name.
    pub name: String,
    /// The preferred IP address without CIDR suffix.
    pub address: Option<String>,
    /// Whether NetworkManager reports the interface as activated.
    pub active: bool,
}

/// Device families used for connection views, independent of interface names.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InterfaceKind {
    /// An IEEE 802.11 radio.
    Wifi,
    /// A wired Ethernet adapter.
    Ethernet,
    /// A TUN/TAP, IP tunnel, or WireGuard interface.
    Tunnel,
    /// Another device family, including loopback and bridges.
    Other,
}

impl Snapshot {
    /// Creates a network snapshot for an unavailable system boundary.
    pub(super) fn unavailable(message: impl Into<String>) -> Self {
        Self {
            wifi_enabled: false,
            device_present: false,
            scanning: false,
            active_ssid: None,
            traffic: Traffic::empty(),
            networks: Vec::new(),
            interfaces: Vec::new(),
            message: Some(message.into()),
        }
    }
}

impl Entry {
    /// Merges duplicate SSIDs and sorts the visible list for display.
    ///
    /// NetworkManager can expose multiple access points for the same network.
    /// The bar keeps one candidate per SSID, preferring active and stronger
    /// candidates while preserving security and connecting state across the
    /// merged entries.
    pub(super) fn visible(entries: Vec<Self>) -> Vec<Self> {
        let mut entries = Self::merge_ssids(entries);
        entries.sort_by(|left, right| {
            right
                .state
                .is_active()
                .cmp(&left.state.is_active())
                .then_with(|| right.strength.cmp(&left.strength))
                .then_with(|| left.ssid.to_lowercase().cmp(&right.ssid.to_lowercase()))
        });
        entries
    }

    /// Reduces NetworkManager access points to one entry per SSID.
    fn merge_ssids(entries: Vec<Self>) -> Vec<Self> {
        let mut networks: Vec<Self> = Vec::new();

        for entry in entries {
            if let Some(existing) = networks
                .iter_mut()
                .find(|network| network.ssid == entry.ssid)
            {
                let secure = existing.secure || entry.secure;
                let state = existing.state.merge(entry.state);
                let replace = entry.state.is_active() && !existing.state.is_active()
                    || (entry.state.is_active() == existing.state.is_active()
                        && entry.strength > existing.strength);

                if replace {
                    *existing = Self {
                        secure,
                        state,
                        ..entry
                    };
                } else {
                    existing.secure = secure;
                    existing.state = state;
                }
            } else {
                networks.push(entry);
            }
        }

        networks
    }
}

impl EntryState {
    /// Rebuilds one visible-entry state from NetworkManager transition flags.
    pub(super) const fn from_connection(active: bool, connecting: bool) -> Self {
        if active && connecting {
            Self::Connecting
        } else if active {
            Self::Active
        } else {
            Self::Available
        }
    }

    /// Returns whether this state represents the active SSID.
    pub const fn is_active(self) -> bool {
        matches!(self, Self::Active | Self::Connecting)
    }

    /// Preserves the strongest connection transition across merged access points.
    fn merge(self, other: Self) -> Self {
        match (self, other) {
            (Self::Connecting, _) | (_, Self::Connecting) => Self::Connecting,
            (Self::Active, _) | (_, Self::Active) => Self::Active,
            (Self::Available, Self::Available) => Self::Available,
        }
    }
}

impl Traffic {
    /// Creates an empty traffic view for unavailable network state.
    pub(super) fn empty() -> Self {
        Self {
            upload: Transfer::empty(),
            download: Transfer::empty(),
            ping_ms: None,
        }
    }
}

impl Transfer {
    /// Creates an empty directional counter.
    const fn empty() -> Self {
        Self {
            bytes_per_second: 0,
            total_bytes: 0,
        }
    }
}

/// Credentials for a manually named personal network.
#[derive(Clone, PartialEq, Eq)]
pub enum Security {
    /// Unencrypted network, with no secret.
    Open,
    /// WPA/WPA2 Personal passphrase (or a 64-digit hexadecimal PSK).
    Personal(String),
}

impl std::fmt::Debug for Security {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Open => formatter.write_str("Open"),
            Self::Personal(_) => formatter.write_str("Personal([redacted])"),
        }
    }
}

/// A manually named connection profile, ready for boundary validation.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Join {
    /// Exact network name; whitespace is significant.
    pub ssid: String,
    /// Whether the access point suppresses its SSID broadcast.
    pub hidden: bool,
    /// Security and its corresponding credential.
    pub security: Security,
    /// Whether NetworkManager may reconnect this profile automatically.
    pub auto_connect: bool,
}

impl Join {
    /// Checks SSID and personal-key limits before creating a system profile.
    pub(super) fn validate(&self) -> Result<(), super::Error> {
        if self.ssid.is_empty() || self.ssid.len() > 32 {
            return Err(super::Error::InvalidNetworkName);
        }
        if let Security::Personal(password) = &self.security {
            let passphrase = (8..=63).contains(&password.len()) && password.is_ascii();
            let raw_key =
                password.len() == 64 && password.bytes().all(|byte| byte.is_ascii_hexdigit());
            if !passphrase && !raw_key {
                return Err(super::Error::InvalidPersonalKey);
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{Entry, EntryState, Join, Security, Snapshot};

    #[test]
    fn manual_network_names_are_validated_as_utf8_bytes() {
        let request = Join {
            ssid: "é".repeat(16),
            hidden: true,
            security: Security::Open,
            auto_connect: true,
        };
        assert!(request.validate().is_ok());
        assert!(
            Join {
                ssid: "é".repeat(17),
                ..request
            }
            .validate()
            .is_err()
        );
    }

    #[test]
    fn personal_keys_preserve_spaces_and_do_not_appear_in_debug_output() {
        let security = Security::Personal(" secret ".into());
        assert!(!format!("{security:?}").contains("secret"));
        let request = Join {
            ssid: "Private".into(),
            hidden: true,
            security,
            auto_connect: false,
        };
        assert!(request.validate().is_ok());
        assert!(
            Join {
                security: Security::Personal("short".into()),
                ..request.clone()
            }
            .validate()
            .is_err()
        );
        assert!(
            Join {
                security: Security::Personal("a".repeat(64)),
                ..request.clone()
            }
            .validate()
            .is_ok()
        );
        assert!(
            Join {
                security: Security::Personal("z".repeat(64)),
                ..request
            }
            .validate()
            .is_err()
        );
    }

    #[test]
    fn unavailable_snapshot_has_no_networks() {
        let snapshot = Snapshot::unavailable("NetworkManager failed");

        assert!(!snapshot.wifi_enabled);
        assert!(!snapshot.device_present);
        assert!(snapshot.networks.is_empty());
        assert!(snapshot.interfaces.is_empty());
        assert_eq!(snapshot.traffic.upload.bytes_per_second, 0);
        assert_eq!(snapshot.traffic.download.bytes_per_second, 0);
        assert_eq!(snapshot.message.as_deref(), Some("NetworkManager failed"));
    }

    #[test]
    fn network_entries_can_mark_active_connection() {
        let entry = Entry {
            ssid: "Fiber_5G".to_string(),
            bssid: Some("aa:bb:cc:dd:ee:ff".to_string()),
            strength: 88,
            secure: true,
            state: EntryState::Active,
        };

        assert!(entry.state.is_active());
        assert_ne!(entry.state, EntryState::Connecting);
        assert!(entry.secure);
        assert_eq!(entry.strength, 88);
    }

    #[test]
    fn visible_entries_collapse_duplicate_ssids_to_the_best_candidate() {
        let networks = Entry::visible(vec![
            Entry {
                ssid: "Haan".to_string(),
                bssid: Some("aa:aa:aa:aa:aa:aa".to_string()),
                strength: 44,
                secure: true,
                state: EntryState::Available,
            },
            Entry {
                ssid: "Haan".to_string(),
                bssid: Some("bb:bb:bb:bb:bb:bb".to_string()),
                strength: 82,
                secure: true,
                state: EntryState::Available,
            },
            Entry {
                ssid: "Cafe".to_string(),
                bssid: None,
                strength: 70,
                secure: false,
                state: EntryState::Active,
            },
        ]);

        assert_eq!(networks.len(), 2);
        assert_eq!(networks[0].ssid, "Cafe");
        assert_eq!(networks[1].ssid, "Haan");
        assert_eq!(networks[1].bssid.as_deref(), Some("bb:bb:bb:bb:bb:bb"));
        assert_eq!(networks[1].strength, 82);
    }
}
