//! System boundaries for screenshot capture.

use std::{
    env, io,
    path::{Path, PathBuf},
    process::{Output, Stdio},
};

use jiff::Zoned;
use serde::Deserialize;
use tokio::{
    io::AsyncWriteExt,
    process::Command as Process,
    time::{self, Duration},
};
use tracing::instrument;

use super::{Area, Clipboard, Command, Failure, Mode, Saved};

/// Screenshot process/filesystem backend.
#[derive(Clone, Copy, Debug)]
pub(super) struct Backend;

#[derive(Clone, Debug, PartialEq, Eq)]
struct Capture {
    target: Target,
    path: PathBuf,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Target {
    Area(Area),
    Desktop,
}

#[derive(Debug, Deserialize)]
struct HyprWindow {
    at: Option<[i32; 2]>,
    size: Option<[u32; 2]>,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq)]
struct Monitor {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    scale: f64,
    disabled: bool,
}

impl Backend {
    /// Runs one screenshot command against system tools.
    #[instrument(skip(self))]
    pub(super) async fn capture(self, command: Command) -> Result<Saved, Failure> {
        let path = capture(command.mode()).await?;
        let clipboard = copy_png(&path).await?;
        Ok(Saved::new(path, clipboard))
    }
}

impl Capture {
    #[instrument]
    async fn new(mode: Mode) -> Result<Self, Failure> {
        let path = screenshots_dir().await?.join(filename());
        let target = match mode {
            Mode::Region => Target::Area(select_region().await?),
            Mode::Window => Target::Area(active_window().await?),
            Mode::FullScreen => Target::Desktop,
        };
        Ok(Self { target, path })
    }

    #[instrument(skip(self))]
    async fn run(&self) -> Result<PathBuf, Failure> {
        match self.target {
            Target::Area(area) => grim_area(area, &self.path).await?,
            Target::Desktop => grim_desktop(&self.path).await?,
        }
        Ok(self.path.clone())
    }
}

#[instrument]
async fn capture(mode: Mode) -> Result<PathBuf, Failure> {
    if mode == Mode::Region {
        let path = screenshots_dir().await?.join(filename());
        match grimblast_region(&path).await {
            Ok(()) => return Ok(path),
            Err(Failure::MissingTool { tool }) if tool == "grimblast" => {}
            Err(failure) => return Err(failure),
        }
    }

    let capture = Capture::new(mode).await?;
    capture.run().await
}

#[instrument(skip(path))]
async fn grimblast_region(path: &Path) -> Result<(), Failure> {
    let output = Process::new("grimblast")
        .env(
            "SLURP_ARGS",
            "-d -b #08121a99 -c #38bdf8ff -s #38bdf833 -B #0b1118ee -w 2",
        )
        .arg("-f")
        .arg("save")
        .arg("area")
        .arg(path)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(|error| process_spawn_failure("grimblast", error))?;

    if output.status.success() {
        Ok(())
    } else if selection_cancelled(&output) {
        Err(Failure::Cancelled)
    } else {
        Err(process_failure("grimblast", &output))
    }
}

/// Cancellation is an expected picker outcome, even when grimblast explains it.
fn selection_cancelled(output: &Output) -> bool {
    if !output.stdout.is_empty() {
        return false;
    }
    let message = String::from_utf8_lossy(&output.stderr);
    matches!(
        message.trim(),
        "" | "selection cancelled" | "Selection cancelled"
    )
}

#[instrument]
async fn select_region() -> Result<Area, Failure> {
    time::sleep(SELECTION_SETTLE).await;
    let rects = selectable_rects().await?;
    let output = slurp(&rects).await?;
    if !output.status.success() {
        if output.stdout.is_empty() {
            return Err(Failure::Cancelled);
        }
        return Err(process_failure("slurp", &output));
    }

    let geometry = String::from_utf8(output.stdout).map_err(|error| Failure::Utf8 {
        message: error.to_string(),
    })?;
    if geometry.trim().is_empty() {
        return Err(Failure::Cancelled);
    }
    Area::from_slurp(&geometry)
}

const SELECTION_SETTLE: Duration = Duration::from_millis(180);

#[instrument]
async fn selectable_rects() -> Result<String, Failure> {
    let output = output("hyprctl", &["-j", "monitors"]).await?;
    if !output.status.success() {
        return Err(process_failure("hyprctl", &output));
    }

    let monitors =
        serde_json::from_slice::<Vec<Monitor>>(&output.stdout).map_err(|error| Failure::Json {
            message: error.to_string(),
        })?;
    let rects = monitor_rects(&monitors);
    if rects.is_empty() {
        Err(Failure::Process {
            tool: "hyprctl",
            detail: "no enabled monitors were reported".to_owned(),
        })
    } else {
        Ok(rects)
    }
}

fn monitor_rects(monitors: &[Monitor]) -> String {
    monitors
        .iter()
        .filter_map(Monitor::slurp_rect)
        .collect::<Vec<_>>()
        .join("\n")
}

async fn slurp(rects: &str) -> Result<Output, Failure> {
    let mut child = Process::new("slurp");
    child
        .args([
            "-d",
            "-b",
            "#08121a99",
            "-c",
            "#38bdf8ff",
            "-s",
            "#38bdf833",
            "-B",
            "#0b1118ee",
            "-w",
            "2",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);

    let mut child = child
        .spawn()
        .map_err(|error| process_spawn_failure("slurp", error))?;
    let Some(mut stdin) = child.stdin.take() else {
        return Err(Failure::Io {
            message: "`slurp` did not expose stdin".to_owned(),
        });
    };
    stdin
        .write_all(rects.as_bytes())
        .await
        .map_err(|error| process_io_failure("slurp", error))?;
    stdin
        .write_all(b"\n")
        .await
        .map_err(|error| process_io_failure("slurp", error))?;
    drop(stdin);

    child
        .wait_with_output()
        .await
        .map_err(|error| process_io_failure("slurp", error))
}

#[instrument]
async fn active_window() -> Result<Area, Failure> {
    let output = output("hyprctl", &["-j", "activewindow"]).await?;
    if !output.status.success() {
        return Err(process_failure("hyprctl", &output));
    }
    let window =
        serde_json::from_slice::<HyprWindow>(&output.stdout).map_err(|error| Failure::Json {
            message: error.to_string(),
        })?;
    let at = window.at.ok_or(Failure::NoActiveWindow)?;
    let size = window.size.ok_or(Failure::NoActiveWindow)?;
    Area::from_window_parts(at, size)
}

#[instrument(skip(path))]
async fn grim_area(area: Area, path: &Path) -> Result<(), Failure> {
    let geometry = area.grim_geometry();
    status("grim", &["-g", geometry.as_str()], Some(path)).await
}

#[instrument(skip(path))]
async fn grim_desktop(path: &Path) -> Result<(), Failure> {
    status("grim", &[], Some(path)).await
}

#[instrument]
async fn screenshots_dir() -> Result<PathBuf, Failure> {
    let pictures = match output("xdg-user-dir", &["PICTURES"]).await {
        Ok(output) if output.status.success() => {
            let text = String::from_utf8(output.stdout).map_err(|error| Failure::Utf8 {
                message: error.to_string(),
            })?;
            let trimmed = text.trim();
            if trimmed.is_empty() {
                fallback_pictures_dir()
            } else {
                PathBuf::from(trimmed)
            }
        }
        _ => fallback_pictures_dir(),
    };
    let dir = pictures.join("Screenshots");
    tokio::fs::create_dir_all(&dir)
        .await
        .map_err(|error| Failure::Io {
            message: format!(
                "failed to create screenshot directory `{}`: {error}",
                dir.display()
            ),
        })?;
    Ok(dir)
}

fn fallback_pictures_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join("Pictures")
}

fn filename() -> String {
    let now = Zoned::now();
    format!(
        "Screenshot_{:04}-{:02}-{:02}-{:02}-{:02}-{:02}.png",
        now.year(),
        now.month(),
        now.day(),
        now.hour(),
        now.minute(),
        now.second()
    )
}

#[instrument(skip(path))]
async fn copy_png(path: &Path) -> Result<Clipboard, Failure> {
    let bytes = tokio::fs::read(path).await.map_err(|error| Failure::Io {
        message: format!("failed to read screenshot `{}`: {error}", path.display()),
    })?;
    let mut child = match Process::new("wl-copy")
        .arg("--type")
        .arg("image/png")
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(child) => child,
        Err(error) => return Ok(Clipboard::failed(process_spawn_failure("wl-copy", error))),
    };

    let Some(mut stdin) = child.stdin.take() else {
        return Ok(Clipboard::failed("`wl-copy` did not expose stdin"));
    };
    if let Err(error) = stdin.write_all(&bytes).await {
        return Ok(Clipboard::failed(format!("`wl-copy` IO failed: {error}")));
    }
    drop(stdin);

    match time::timeout(Duration::from_millis(750), child.wait()).await {
        Ok(Ok(status)) if status.success() => Ok(Clipboard::Copied),
        Ok(Ok(status)) => Ok(Clipboard::failed(format!("`wl-copy` failed: {status}"))),
        Ok(Err(error)) => Ok(Clipboard::failed(format!("`wl-copy` IO failed: {error}"))),
        Err(_) => Ok(Clipboard::Copied),
    }
}

async fn output(program: &'static str, args: &[&str]) -> Result<Output, Failure> {
    Process::new(program)
        .args(args)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(|error| process_spawn_failure(program, error))
}

impl Monitor {
    fn slurp_rect(&self) -> Option<String> {
        if self.disabled || self.width == 0 || self.height == 0 {
            return None;
        }

        let scale = if self.scale.is_finite() && self.scale > 0.0 {
            self.scale
        } else {
            1.0
        };
        let width = scaled_extent(self.width, scale);
        let height = scaled_extent(self.height, scale);
        Some(format!("{},{} {}x{}", self.x, self.y, width, height))
    }
}

fn scaled_extent(value: u32, scale: f64) -> u32 {
    ((f64::from(value) / scale).round() as u32).max(1)
}

async fn status(program: &'static str, args: &[&str], path: Option<&Path>) -> Result<(), Failure> {
    let mut command = Process::new(program);
    command.args(args);
    if let Some(path) = path {
        command.arg(path);
    }
    let output = command
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(|error| process_spawn_failure(program, error))?;
    if output.status.success() {
        Ok(())
    } else {
        Err(process_failure(program, &output))
    }
}

fn process_spawn_failure(tool: &'static str, error: io::Error) -> Failure {
    if error.kind() == io::ErrorKind::NotFound {
        Failure::MissingTool { tool }
    } else {
        process_io_failure(tool, error)
    }
}

fn process_io_failure(tool: &'static str, error: io::Error) -> Failure {
    Failure::Io {
        message: format!("`{tool}` IO failed: {error}"),
    }
}

fn process_failure(tool: &'static str, output: &Output) -> Failure {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    let detail = if !stderr.is_empty() {
        stderr
    } else if !stdout.is_empty() {
        stdout
    } else {
        output.status.to_string()
    };
    Failure::Process { tool, detail }
}

#[cfg(test)]
mod tests {
    use super::{Monitor, monitor_rects};

    #[test]
    fn cancellation_diagnostics_do_not_hide_real_tool_errors() {
        use std::{
            os::unix::process::ExitStatusExt,
            process::{ExitStatus, Output},
        };
        for (message, cancelled) in [
            ("", true),
            ("selection cancelled\n", true),
            ("Selection cancelled", true),
            ("failed to connect to Wayland", false),
        ] {
            let output = Output {
                status: ExitStatus::from_raw(256),
                stdout: Vec::new(),
                stderr: message.as_bytes().to_vec(),
            };
            assert_eq!(super::selection_cancelled(&output), cancelled, "{message}");
        }
    }

    #[test]
    fn monitor_rects_use_logical_geometry() {
        let rects = monitor_rects(&[Monitor {
            x: 0,
            y: 0,
            width: 3840,
            height: 2160,
            scale: 1.2,
            disabled: false,
        }]);

        assert_eq!(rects, "0,0 3200x1800");
    }

    #[test]
    fn monitor_rects_skip_disabled_outputs() {
        let rects = monitor_rects(&[
            Monitor {
                x: 0,
                y: 0,
                width: 1920,
                height: 1080,
                scale: 1.0,
                disabled: true,
            },
            Monitor {
                x: 1920,
                y: 0,
                width: 2560,
                height: 1440,
                scale: 1.0,
                disabled: false,
            },
        ]);

        assert_eq!(rects, "1920,0 2560x1440");
    }
}
