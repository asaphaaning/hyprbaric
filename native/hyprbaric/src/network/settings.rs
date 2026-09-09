//! System network settings launchers.

use std::process::Command;

use tracing::instrument;

use super::Error;

/// Opens the first known network settings application.
#[instrument(err)]
pub(super) fn open() -> Result<(), Error> {
    for candidate in [
        Candidate::new("nm-connection-editor", &[]),
        Candidate::new("gnome-control-center", &["wifi"]),
        Candidate::new("systemsettings", &["kcm_networkmanagement"]),
    ] {
        if candidate.spawn() {
            return Ok(());
        }
    }

    Err(Error::SettingsUnavailable)
}

/// A network settings application candidate.
struct Candidate<'a> {
    program: &'a str,
    args: &'a [&'a str],
}

impl<'a> Candidate<'a> {
    /// Creates one settings application candidate.
    const fn new(program: &'a str, args: &'a [&'a str]) -> Self {
        Self { program, args }
    }

    /// Attempts to launch this settings application as a session-owned process.
    fn spawn(self) -> bool {
        let words: Vec<&str> = std::iter::once(self.program)
            .chain(self.args.iter().copied())
            .collect();
        let Ok(shell) = shlex::try_join(words) else {
            return false;
        };
        let mut command = Command::new(self.program);
        command.args(self.args);
        crate::hyprland::start_user(&shell, &mut command).is_ok()
    }
}
