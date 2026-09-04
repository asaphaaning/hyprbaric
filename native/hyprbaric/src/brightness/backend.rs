//! Brightness system backends.
//!
//! [`Controller`] presents a small typed surface to the actor while this module
//! owns the Linux backlight and `ddcutil` process boundaries.

use std::time::Duration;

use ::brightness::{self as brightness_crate, Brightness as CrateBrightness};
use futures_util::TryStreamExt;
use tokio::{process::Command as ProcessCommand, time::timeout};
use tracing::instrument;

use super::{
    Configuration, DDC_BRIGHTNESS_VCP, Error,
    domain::{Device, DeviceId, DeviceKind, Percent},
    registry::{deduplicate_devices, sorted_devices},
};

/// Read/write coordinator for available brightness backends.
#[derive(Clone)]
pub(super) struct Controller {
    backends: Vec<Backend>,
}

#[derive(Clone, Copy)]
enum Backend {
    Backlight(Backlight),
    DdcCi(DdcUtil),
}

#[derive(Clone, Copy)]
struct Backlight;

#[derive(Clone, Copy)]
struct DdcUtil {
    command_timeout: Duration,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct DdcDisplay {
    index: u32,
    bus: String,
    label: String,
    fingerprint: String,
}

impl Controller {
    /// Creates a backend controller from brightness [`Configuration`].
    pub(super) fn new(config: &Configuration) -> Self {
        Self {
            backends: vec![
                Backend::Backlight(Backlight),
                Backend::DdcCi(DdcUtil {
                    command_timeout: config.ddc_command_timeout(),
                }),
            ],
        }
    }

    /// Discovers Linux backlight devices.
    #[instrument(skip(self), err)]
    pub(super) async fn discover_backlight(&self) -> Result<Vec<Device>, Error> {
        let mut first_error = None;
        let mut devices = Vec::new();

        for backend in &self.backends {
            if backend.kind() != DeviceKind::Backlight {
                continue;
            }
            match backend.list_devices().await {
                Ok(next) => devices.extend(next),
                Err(error) => {
                    first_error.get_or_insert(error);
                }
            }
        }

        finish_discovery(sorted_devices(devices), first_error)
    }

    /// Discovers DDC/CI displays.
    #[instrument(skip(self), err)]
    pub(super) async fn discover_ddc(&self) -> Result<Vec<Device>, Error> {
        let mut first_error = None;
        let mut devices = Vec::new();

        for backend in &self.backends {
            if backend.kind() != DeviceKind::DdcCi {
                continue;
            }
            match backend.list_devices().await {
                Ok(next) => devices.extend(next),
                Err(error) => {
                    first_error.get_or_insert(error);
                }
            }
        }

        finish_discovery(deduplicate_devices(devices), first_error)
    }

    /// Reads a known brightness [`Device`].
    #[instrument(skip(self), err)]
    pub(super) async fn read_device(&self, device: &Device) -> Result<Device, Error> {
        let backend = self.backend(device.kind)?;
        backend.read_device(device).await
    }

    /// Writes brightness for a known [`Device`].
    #[instrument(skip(self), err)]
    pub(super) async fn set_brightness(
        &self,
        device: &Device,
        value: Percent,
    ) -> Result<(), Error> {
        let backend = self.backend(device.kind)?;
        backend.set_brightness(&device.id, value).await
    }

    fn backend(&self, kind: DeviceKind) -> Result<Backend, Error> {
        self.backends
            .iter()
            .copied()
            .find(|backend| backend.kind() == kind)
            .ok_or(Error::Unsupported {
                backend: kind.backend_name(),
            })
    }
}

impl Backend {
    const fn kind(self) -> DeviceKind {
        match self {
            Self::Backlight(backend) => backend.kind(),
            Self::DdcCi(backend) => backend.kind(),
        }
    }

    async fn list_devices(self) -> Result<Vec<Device>, Error> {
        match self {
            Self::Backlight(backend) => backend.list_devices().await,
            Self::DdcCi(backend) => backend.list_devices().await,
        }
    }

    async fn read_device(self, device: &Device) -> Result<Device, Error> {
        match self {
            Self::Backlight(backend) => backend.read_device(device).await,
            Self::DdcCi(backend) => backend.read_device(device).await,
        }
    }

    async fn set_brightness(self, device_id: &DeviceId, percent: Percent) -> Result<(), Error> {
        match self {
            Self::Backlight(backend) => backend.set_brightness(device_id, percent).await,
            Self::DdcCi(backend) => backend.set_brightness(device_id, percent).await,
        }
    }
}

impl Backlight {
    const fn kind(self) -> DeviceKind {
        DeviceKind::Backlight
    }

    #[instrument(skip(self), err)]
    async fn list_devices(self) -> Result<Vec<Device>, Error> {
        let mut stream = brightness_crate::brightness_devices();
        let mut devices = Vec::new();

        while let Some(device) = stream
            .try_next()
            .await
            .map_err(Error::from_brightness_crate)?
        {
            let name = device
                .device_name()
                .await
                .map_err(Error::from_brightness_crate)?;
            let label = device
                .friendly_device_name()
                .await
                .unwrap_or_else(|_| name.clone());
            let value = device.get().await.map_err(Error::from_brightness_crate)?;

            devices.push(Device {
                id: DeviceId::backlight(&name),
                label,
                kind: DeviceKind::Backlight,
                value: percent_from_u32(value),
            });
        }

        Ok(sorted_devices(devices))
    }

    #[instrument(skip(self), err)]
    async fn read_device(self, device: &Device) -> Result<Device, Error> {
        let wanted = device
            .id
            .backlight_name()
            .ok_or_else(|| Error::DeviceUnavailable {
                device: device.id.to_string(),
            })?;
        let mut stream = brightness_crate::brightness_devices();

        while let Some(next) = stream
            .try_next()
            .await
            .map_err(Error::from_brightness_crate)?
        {
            let name = next
                .device_name()
                .await
                .map_err(Error::from_brightness_crate)?;
            if name != wanted {
                continue;
            }
            let label = next
                .friendly_device_name()
                .await
                .unwrap_or_else(|_| name.clone());
            let value = next.get().await.map_err(Error::from_brightness_crate)?;
            return Ok(Device {
                id: DeviceId::backlight(&name),
                label,
                kind: DeviceKind::Backlight,
                value: percent_from_u32(value),
            });
        }

        Err(Error::DeviceUnavailable {
            device: wanted.to_owned(),
        })
    }

    #[instrument(skip(self), err)]
    async fn set_brightness(self, device_id: &DeviceId, percent: Percent) -> Result<(), Error> {
        let wanted = device_id
            .backlight_name()
            .ok_or_else(|| Error::DeviceUnavailable {
                device: device_id.to_string(),
            })?;
        let mut stream = brightness_crate::brightness_devices();

        while let Some(mut device) = stream
            .try_next()
            .await
            .map_err(Error::from_brightness_crate)?
        {
            let name = device
                .device_name()
                .await
                .map_err(Error::from_brightness_crate)?;
            if name == wanted {
                return device
                    .set(percent.as_backend_value())
                    .await
                    .map_err(Error::from_brightness_crate);
            }
        }

        Err(Error::DeviceUnavailable {
            device: wanted.to_owned(),
        })
    }
}

impl DdcUtil {
    const fn kind(self) -> DeviceKind {
        DeviceKind::DdcCi
    }

    #[instrument(skip(self), err)]
    async fn list_devices(self) -> Result<Vec<Device>, Error> {
        let output = run_ddcutil(&["detect", "--brief"], self.command_timeout).await?;
        let mut devices = Vec::new();

        for display in parse_ddc_displays(&output) {
            let Ok(value) = self.get_bus_brightness(&display.bus).await else {
                continue;
            };
            devices.push(Device {
                id: DeviceId::ddc(&display.bus, &display.fingerprint),
                label: display.label,
                kind: DeviceKind::DdcCi,
                value,
            });
        }

        Ok(sorted_devices(devices))
    }

    #[instrument(skip(self), err)]
    async fn read_device(self, device: &Device) -> Result<Device, Error> {
        let bus = device
            .id
            .ddc_bus()
            .ok_or_else(|| Error::DeviceUnavailable {
                device: device.id.to_string(),
            })?;
        let value = self.get_bus_brightness(bus).await?;
        Ok(Device {
            value,
            ..device.clone()
        })
    }

    #[instrument(skip(self), err)]
    async fn set_brightness(self, device_id: &DeviceId, percent: Percent) -> Result<(), Error> {
        let bus = device_id
            .ddc_bus()
            .ok_or_else(|| Error::DeviceUnavailable {
                device: device_id.to_string(),
            })?;
        let value = percent.as_backend_value().to_string();
        run_ddcutil(
            &["-b", bus, "setvcp", DDC_BRIGHTNESS_VCP, &value],
            self.command_timeout,
        )
        .await
        .map(|_| ())
    }

    #[instrument(skip(self), err)]
    async fn get_bus_brightness(self, bus: &str) -> Result<Percent, Error> {
        let output = run_ddcutil(
            &["-b", bus, "getvcp", DDC_BRIGHTNESS_VCP, "--brief"],
            self.command_timeout,
        )
        .await?;
        parse_ddc_brightness(&output).ok_or_else(|| Error::BackendFailed {
            backend: DeviceKind::DdcCi.backend_name(),
            message: format!("ddcutil did not report brightness for bus {bus}"),
        })
    }
}

#[instrument(err)]
async fn run_ddcutil(args: &[&str], command_timeout: Duration) -> Result<String, Error> {
    let mut command = ProcessCommand::new("ddcutil");
    command.args(args).kill_on_drop(true);

    let output = timeout(command_timeout, command.output())
        .await
        .map_err(|_| Error::CommandTimedOut {
            program: "ddcutil",
            timeout: command_timeout,
        })?
        .map_err(|source| Error::Command {
            program: "ddcutil",
            source,
        })?;

    if !output.status.success() {
        return Err(Error::CommandFailed {
            program: "ddcutil",
            status: output.status,
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_owned(),
        });
    }

    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn parse_ddc_displays(output: &str) -> Vec<DdcDisplay> {
    let mut displays = Vec::new();
    let mut current = None;

    for line in output.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("Display ") {
            if let Some(display) = current.take() {
                push_ddc_display(&mut displays, display);
            }
            let Some(index) = rest
                .split_whitespace()
                .next()
                .and_then(|value| value.parse::<u32>().ok())
            else {
                continue;
            };
            current = Some(DdcDisplay {
                index,
                bus: String::new(),
                label: format!("Display {index}"),
                fingerprint: format!("display-{index}"),
            });
            continue;
        }

        let Some(display) = current.as_mut() else {
            continue;
        };

        if let Some(bus) = parse_i2c_bus(trimmed) {
            display.bus = bus;
            display.fingerprint.push('|');
            display.fingerprint.push_str(&display.bus);
            continue;
        }

        if let Some(connector) = trimmed.strip_prefix("DRM connector:") {
            let connector = connector.trim();
            if !connector.is_empty() {
                display.label = connector.to_owned();
                display.fingerprint.push('|');
                display.fingerprint.push_str(connector);
            }
            continue;
        }

        for prefix in ["Mfg id:", "Model:", "Monitor:", "Serial number:"] {
            if let Some(value) = trimmed.strip_prefix(prefix) {
                let value = value.trim();
                if value.is_empty() {
                    continue;
                }
                if prefix == "Model:" || prefix == "Monitor:" {
                    display.label = value.to_owned();
                }
                display.fingerprint.push('|');
                display.fingerprint.push_str(value);
            }
        }
    }

    if let Some(display) = current {
        push_ddc_display(&mut displays, display);
    }

    displays
}

fn parse_i2c_bus(line: &str) -> Option<String> {
    line.strip_prefix("I2C bus:")
        .and_then(|value| value.trim().rsplit_once('-').map(|(_, bus)| bus.trim()))
        .filter(|bus| !bus.is_empty() && bus.chars().all(|character| character.is_ascii_digit()))
        .map(ToOwned::to_owned)
}

fn push_ddc_display(displays: &mut Vec<DdcDisplay>, display: DdcDisplay) {
    if !display.bus.is_empty() {
        displays.push(display);
    }
}

fn parse_ddc_brightness(output: &str) -> Option<Percent> {
    let marker = "current value =";
    if let Some(start) = output.find(marker).map(|index| index + marker.len()) {
        let digits = output[start..]
            .chars()
            .skip_while(|value| !value.is_ascii_digit())
            .take_while(|value| value.is_ascii_digit())
            .collect::<String>();
        return digits.parse::<u8>().ok().map(Percent::new);
    }

    output
        .split_whitespace()
        .nth(3)
        .and_then(|value| value.parse::<u8>().ok())
        .map(Percent::new)
}

fn percent_from_u32(value: u32) -> Percent {
    Percent::new(value.min(100) as u8)
}

/// Finishes a backend scan while preserving the distinction between absence and
/// failure.
///
/// An empty device list is a normal result: desktop systems commonly have no
/// `/sys/class/backlight` entry, and external displays are optional. A failed
/// scan only remains an [`Error`] when it yielded no usable device.
fn finish_discovery(
    devices: Vec<Device>,
    first_error: Option<Error>,
) -> Result<Vec<Device>, Error> {
    if devices.is_empty()
        && let Some(error) = first_error
    {
        return Err(error);
    }

    Ok(devices)
}

impl Error {
    fn from_brightness_crate(source: brightness_crate::Error) -> Self {
        let message = source.to_string();
        if message.to_ascii_lowercase().contains("permission") {
            return Self::PermissionDenied {
                backend: DeviceKind::Backlight.backend_name(),
                message,
            };
        }
        Self::BackendFailed {
            backend: DeviceKind::Backlight.backend_name(),
            message,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_ddcutil_displays_with_stable_identifiers() {
        let output = r#"
Display 1
   I2C bus:  /dev/i2c-6
   DRM connector:           card1-DP-1
   EDID synopsis:
      Mfg id:               DEL
      Model:                DELL U2720Q
      Serial number:        ABC123

Display 2
   I2C bus:  /dev/i2c-7
   DRM connector:           card1-HDMI-A-1
"#;

        let displays = parse_ddc_displays(output);

        assert_eq!(
            displays,
            vec![
                DdcDisplay {
                    index: 1,
                    bus: "6".to_owned(),
                    label: "DELL U2720Q".to_owned(),
                    fingerprint: "display-1|6|card1-DP-1|DEL|DELL U2720Q|ABC123".to_owned(),
                },
                DdcDisplay {
                    index: 2,
                    bus: "7".to_owned(),
                    label: "card1-HDMI-A-1".to_owned(),
                    fingerprint: "display-2|7|card1-HDMI-A-1".to_owned(),
                },
            ],
        );
    }

    #[test]
    fn parses_ddcutil_brightness_value() {
        let output = "VCP code 0x10 (Brightness): current value =    42, max value =   100";

        assert_eq!(parse_ddc_brightness(output), Some(Percent::new(42)));
    }

    #[test]
    fn parses_ddcutil_brief_brightness_value() {
        let output = "VCP 10 C 37 100";

        assert_eq!(parse_ddc_brightness(output), Some(Percent::new(37)));
    }

    #[test]
    fn clamps_percent_values() {
        assert_eq!(percent_from_u32(123), Percent::new(100));
        assert_eq!(Percent::new(200), Percent::new(100));
    }

    #[test]
    fn ddc_device_id_preserves_i2c_bus() {
        let display = DdcDisplay {
            index: 3,
            bus: "12".to_owned(),
            label: "Display".to_owned(),
            fingerprint: "Display Three".to_owned(),
        };
        let id = DeviceId::ddc(&display.bus, &display.fingerprint);

        assert_eq!(id.ddc_bus(), Some("12"));
    }

    #[test]
    fn absent_devices_are_a_successful_discovery() {
        let devices =
            finish_discovery(Vec::new(), None).expect("absence is a normal discovery result");

        assert!(devices.is_empty());
    }

    #[test]
    fn failed_empty_discovery_preserves_the_backend_error() {
        let result = finish_discovery(
            Vec::new(),
            Some(Error::Unsupported {
                backend: "backlight",
            }),
        );

        assert!(matches!(result, Err(Error::Unsupported { .. })));
    }
}
