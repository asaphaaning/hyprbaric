//! User-facing process launch through Hyprland.
//!
//! Desktop apps and system settings belong to the session, not to Hyprbaric.
//! Asking the compositor to `exec` them puts the child in Hyprland's process
//! tree and cgroup, so closing or restarting the bar does not take Firefox
//! with it. Transient tools (screenshot, color picker, recorder) spawn on
//! their own and may still die with the bar on purpose.

use std::{
    io,
    os::unix::process::CommandExt,
    process::{Command, Stdio},
};

use hyprland::dispatch::{Dispatch, DispatchType};
use tracing::instrument;

use super::Error;

/// Asks Hyprland to start a shell command so the process belongs to the compositor.
#[instrument(err)]
fn exec(command: &str) -> Result<(), Error> {
    Dispatch::call(DispatchType::Exec(command)).map_err(Error::Dispatch)
}

/// Starts a user-facing program that should outlive Hyprbaric.
///
/// Prefer compositor ownership. If Hyprland is unreachable, spawn a detached
/// child of this process instead so a terminal SIGINT still does not follow.
#[instrument(skip(fallback), fields(command = %command), err)]
pub(crate) fn start_user(command: &str, fallback: &mut Command) -> io::Result<()> {
    match exec(command) {
        Ok(()) => Ok(()),
        Err(error) => {
            tracing::debug!(
                %error,
                command,
                "Hyprland exec unavailable; spawning a detached child"
            );
            detach(fallback);
            fallback.spawn().map(|_| ())
        }
    }
}

fn detach(command: &mut Command) {
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    // SAFETY: `pre_exec` runs in the child after fork and before exec. `setsid`
    // is async-signal-safe and starts a new session so SIGHUP/SIGINT aimed at
    // Hyprbaric's terminal or process group cannot tear this child down. It
    // does not escape a systemd cgroup; compositor `exec` is the path that does.
    unsafe {
        command.pre_exec(|| {
            if setsid() == -1 {
                Err(io::Error::last_os_error())
            } else {
                Ok(())
            }
        });
    }
}

unsafe extern "C" {
    fn setsid() -> i32;
}
