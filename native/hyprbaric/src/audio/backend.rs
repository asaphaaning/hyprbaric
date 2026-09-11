//! Audio system boundary.
//!
//! [`Devices`] owns `wpctl` calls and parsing so the runtime can stay focused on
//! publishing typed [`Snapshot`] and [`super::Report`]
//! values.

use std::time::Duration;

use serde::Deserialize;
use tokio::{process::Command as ProcessCommand, time::timeout};
use tracing::instrument;

use super::{
    Error,
    domain::{Endpoint, EndpointKind, Output, OutputId, Outputs, Percent, Snapshot},
};

/// PipeWire default endpoint reader and writer.
#[derive(Clone, Copy, Debug, Default)]
pub(super) struct Devices;

impl Devices {
    /// Reads the current audio snapshot.
    #[instrument(skip(self), err)]
    pub(super) async fn read_snapshot(self) -> Result<Snapshot, Error> {
        let output = self.read_endpoint(EndpointKind::Output).await.ok();
        let input = self.read_endpoint(EndpointKind::Input).await.ok();
        if output.is_none() && input.is_none() {
            return Err(Error::Unavailable);
        }

        let outputs = match self.read_outputs().await {
            Ok(devices) => output_choices(
                devices,
                output.as_ref().and_then(|device| device.id.as_deref()),
            ),
            Err(error) => Outputs::Unavailable {
                message: error.to_string(),
            },
        };

        Ok(Snapshot::Available {
            output,
            input,
            outputs,
        })
    }

    #[instrument(name = "audio::read_outputs", skip(self), err)]
    async fn read_outputs(self) -> Result<Vec<LiveOutput>, Error> {
        parse_outputs(&run("pw-dump", &["--no-colors"]).await?)
    }

    /// Resolves a stable name afresh so stale numeric ids cannot select another device.
    #[instrument(name = "audio::devices::select_output", skip(self), err)]
    pub(super) async fn select_output(self, id: &OutputId) -> Result<(), Error> {
        let devices = self.read_outputs().await?;
        let node = resolve_output(&devices, id)?;
        run("wpctl", &["set-default", &node.to_string()])
            .await
            .map(|_| ())
    }

    /// Reads one default endpoint.
    #[instrument(skip(self), err)]
    async fn read_endpoint(self, kind: EndpointKind) -> Result<Endpoint, Error> {
        let inspect = run("wpctl", &["inspect", kind.selector()]).await?;
        let volume = run("wpctl", &["get-volume", kind.selector()]).await?;
        let (volume, muted) = parse_volume(&volume)?;

        Ok(Endpoint {
            kind,
            id: parse_id(&inspect),
            name: parse_name(&inspect).unwrap_or_else(|| kind.fallback_name().to_string()),
            volume,
            muted,
        })
    }

    /// Sets the volume for one endpoint class.
    #[instrument(skip(self), err)]
    pub(super) async fn set_volume(self, kind: EndpointKind, volume: Percent) -> Result<(), Error> {
        let value = format!("{}%", volume.as_u8());
        run("wpctl", &["set-volume", kind.selector(), &value])
            .await
            .map(|_| ())
    }

    /// Sets mute state for one endpoint class.
    #[instrument(skip(self), err)]
    pub(super) async fn set_muted(self, kind: EndpointKind, muted: bool) -> Result<(), Error> {
        let value = if muted { "1" } else { "0" };
        run("wpctl", &["set-mute", kind.selector(), value])
            .await
            .map(|_| ())
    }
}

#[instrument(skip(args), err)]
async fn run(program: &str, args: &[&str]) -> Result<String, Error> {
    let output = timeout(
        Duration::from_secs(5),
        ProcessCommand::new(program)
            .args(args)
            .kill_on_drop(true)
            .output(),
    )
    .await
    .map_err(|_elapsed| Error::Timeout {
        program: program.to_owned(),
    })?
    .map_err(|source| Error::Spawn {
        program: program.to_string(),
        source,
    })?;
    if !output.status.success() {
        return Err(Error::CommandFailed {
            program: program.to_string(),
            status: output.status.to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    String::from_utf8(output.stdout).map_err(Error::Utf8)
}

/// Transient PipeWire address paired with stable output identity.
struct LiveOutput {
    node: u32,
    output: Output,
}

/// Only PipeWire nodes carry the properties needed for output discovery.
#[derive(Deserialize)]
#[serde(tag = "type")]
enum Object {
    #[serde(rename = "PipeWire:Interface:Node")]
    Node { id: u32, info: Option<NodeInfo> },
    #[serde(other)]
    Other,
}

/// PipeWire node metadata at the JSON boundary.
#[derive(Deserialize)]
struct NodeInfo {
    props: Properties,
}

/// The small subset of node properties used for output discovery.
#[derive(Deserialize)]
struct Properties {
    #[serde(rename = "media.class")]
    media_class: Option<String>,
    #[serde(rename = "node.name")]
    name: Option<String>,
    #[serde(rename = "node.description")]
    description: Option<String>,
    #[serde(rename = "node.nick")]
    nick: Option<String>,
}

fn parse_outputs(json: &str) -> Result<Vec<LiveOutput>, Error> {
    let mut outputs: Vec<_> = serde_json::from_str::<Vec<Object>>(json)?
        .into_iter()
        .filter_map(|object| {
            let Object::Node {
                id,
                info: Some(NodeInfo { props }),
            } = object
            else {
                return None;
            };
            if props.media_class.as_deref() != Some("Audio/Sink") {
                return None;
            }

            let name = props.name.filter(|name| !name.is_empty())?;
            let label = props
                .description
                .filter(|label| !label.is_empty())
                .or(props.nick.filter(|label| !label.is_empty()))
                .unwrap_or_else(|| name.clone());
            Some(LiveOutput {
                node: id,
                output: Output {
                    id: OutputId(name),
                    name: label,
                },
            })
        })
        .collect();
    outputs.sort_by(|left, right| {
        left.output
            .name
            .cmp(&right.output.name)
            .then_with(|| left.output.id.0.cmp(&right.output.id.0))
    });
    Ok(outputs)
}

fn output_choices(devices: Vec<LiveOutput>, default: Option<&str>) -> Outputs {
    let default = default.and_then(|id| id.parse::<u32>().ok());
    Outputs::Available {
        selected: devices
            .iter()
            .find(|device| Some(device.node) == default)
            .map(|device| device.output.id.clone()),
        devices: devices.into_iter().map(|device| device.output).collect(),
    }
}

fn resolve_output(devices: &[LiveOutput], id: &OutputId) -> Result<u32, Error> {
    devices
        .iter()
        .find(|device| &device.output.id == id)
        .map(|device| device.node)
        .ok_or(Error::OutputMissing)
}

fn parse_id(inspect: &str) -> Option<String> {
    inspect
        .lines()
        .next()
        .and_then(|line| line.trim().strip_prefix("id "))
        .and_then(|tail| tail.split(',').next())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn parse_name(inspect: &str) -> Option<String> {
    for key in ["node.description", "node.nick", "node.name"] {
        if let Some(value) = parse_property(inspect, key) {
            return Some(value);
        }
    }
    None
}

fn parse_property(inspect: &str, key: &str) -> Option<String> {
    inspect.lines().find_map(|line| {
        let normalized = line.trim_start().trim_start_matches("* ").trim_start();
        let (left, right) = normalized.split_once(" = ")?;
        if left == key {
            Some(unquote(right.trim()))
        } else {
            None
        }
    })
}

fn unquote(value: &str) -> String {
    value
        .strip_prefix('"')
        .and_then(|inner| inner.strip_suffix('"'))
        .unwrap_or(value)
        .to_string()
}

fn parse_volume(output: &str) -> Result<(Percent, bool), Error> {
    let value = output
        .trim()
        .strip_prefix("Volume:")
        .ok_or_else(|| Error::ParseVolume {
            output: output.trim().to_string(),
        })?
        .split_whitespace()
        .next()
        .ok_or_else(|| Error::ParseVolume {
            output: output.trim().to_string(),
        })?;
    let fraction = value.parse::<f32>().map_err(|_| Error::ParseVolume {
        output: output.trim().to_string(),
    })?;
    Ok((Percent::from_fraction(fraction), output.contains("MUTED")))
}

#[cfg(test)]
mod tests {
    use super::{
        Devices, Error, OutputId, Outputs, Percent, Snapshot, output_choices, parse_id, parse_name,
        parse_outputs, parse_volume, resolve_output,
    };

    const DEVICES: &str = r#"[
        {"id": 1, "type": "PipeWire:Interface:Client"},
        {"id": 7, "type": "PipeWire:Interface:Node", "info": null},
        {"id": 8, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Source", "node.name": "mic"}}},
        {"id": 9, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Sink"}}},
        {"id": 21, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Sink", "node.name": "usb", "node.description": "Speakers"}}},
        {"id": 12, "type": "PipeWire:Interface:Node", "info": {"props": {"media.class": "Audio/Sink", "node.name": "analog", "node.nick": "Speakers"}}}
    ]"#;

    #[test]
    fn discovers_only_named_sinks_and_preserves_duplicate_labels() {
        let devices = parse_outputs(DEVICES).expect("valid PipeWire fixture");
        assert_eq!(devices.len(), 2);
        assert_eq!(devices[0].output.id, OutputId("analog".into()));
        assert_eq!(devices[1].output.id, OutputId("usb".into()));
        let choices = output_choices(devices, Some("21"));
        assert!(
            matches!(choices, Outputs::Available { selected: Some(OutputId(name)), .. } if name == "usb")
        );
    }

    #[test]
    fn resolves_names_against_live_ids_and_rejects_missing_outputs() {
        let devices = parse_outputs(DEVICES).expect("valid PipeWire fixture");
        assert_eq!(
            resolve_output(&devices, &OutputId("usb".into())).expect("USB output exists"),
            21
        );
        let changed =
            parse_outputs(&DEVICES.replace("\"id\": 21", "\"id\": 83")).expect("updated fixture");
        assert_eq!(
            resolve_output(&changed, &OutputId("usb".into())).expect("USB output exists"),
            83
        );
        assert!(matches!(
            resolve_output(&devices, &OutputId("disconnected".into())),
            Err(Error::OutputMissing)
        ));
    }

    #[test]
    fn empty_and_invalid_discovery_are_distinct() {
        assert!(parse_outputs("[]").expect("empty list is valid").is_empty());
        assert!(matches!(
            parse_outputs("not json"),
            Err(Error::ParseDevices(_))
        ));
    }

    /// Requires the developer's live PipeWire session; keeps its current output.
    #[tokio::test]
    #[ignore = "requires a live PipeWire session"]
    async fn live_default_output_round_trip() -> Result<(), Error> {
        let devices = Devices;
        let Snapshot::Available {
            outputs: Outputs::Available {
                selected: Some(id), ..
            },
            ..
        } = devices.read_snapshot().await?
        else {
            return Err(Error::Unavailable);
        };
        devices.select_output(&id).await?;
        let Snapshot::Available {
            outputs: Outputs::Available { selected, .. },
            ..
        } = devices.read_snapshot().await?
        else {
            return Err(Error::Unavailable);
        };
        assert_eq!(selected.as_ref(), Some(&id));
        Ok(())
    }

    #[test]
    fn parses_wpctl_volume() {
        let (volume, muted) = parse_volume("Volume: 0.85\n").unwrap();
        assert_eq!(volume, Percent::new(85));
        assert!(!muted);
    }

    #[test]
    fn parses_muted_wpctl_volume() {
        let (volume, muted) = parse_volume("Volume: 0.42 [MUTED]\n").unwrap();
        assert_eq!(volume, Percent::new(42));
        assert!(muted);
    }

    #[test]
    fn parses_default_endpoint_metadata() {
        let inspect = r#"id 117, type PipeWire:Interface:Node
  * node.description = "EVO4 Analog Surround 4.0"
  * node.name = "alsa_output.usb-Audient_EVO4-00.analog-surround-40"
"#;
        assert_eq!(parse_id(inspect).as_deref(), Some("117"));
        assert_eq!(
            parse_name(inspect).as_deref(),
            Some("EVO4 Analog Surround 4.0")
        );
    }
}
