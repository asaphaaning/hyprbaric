//! Async `hyprctl` process boundary.

use std::process::Stdio;

use tokio::process::Command;
use tracing::instrument;

use super::{
    BindEntry, BindSnapshot, Plan, RemovePlan, Shortcut, Spec, plan_reconciliation, plan_removal,
};
use crate::shortcuts::Error;

impl BindSnapshot {
    /// Reads the current Hyprland binding snapshot.
    pub(in crate::shortcuts) async fn read() -> Result<Self, Error> {
        Ok(Self {
            bindings: read_bindings().await?,
        })
    }
}

/// Reconciles one configured [`Spec`] using an already-read binding snapshot.
#[instrument(skip_all, fields(shortcut_id = %spec.shortcut()), err)]
pub(in crate::shortcuts) async fn reconcile_from(
    spec: &Spec,
    snapshot: &BindSnapshot,
) -> Result<(), Error> {
    match plan_reconciliation(spec, &snapshot.bindings)? {
        Plan::Noop => Ok(()),
        Plan::Reinstall {
            unbind_values,
            bind,
        } => {
            for value in unbind_values {
                unbind(value.as_str()).await?;
            }

            install(&bind).await
        }
    }
}

/// Removes every Hyprbaric-owned `global` bind for a shortcut.
#[instrument(skip_all, fields(shortcut_id = %shortcut), err)]
pub(in crate::shortcuts) async fn remove(shortcut: Shortcut) -> Result<(), Error> {
    let snapshot = BindSnapshot::read().await?;
    remove_from(shortcut, &snapshot).await
}

/// Removes one app-owned shortcut bind using an already-read binding snapshot.
#[instrument(skip_all, fields(shortcut_id = %shortcut), err)]
async fn remove_from(shortcut: Shortcut, snapshot: &BindSnapshot) -> Result<(), Error> {
    match plan_removal(shortcut, &snapshot.bindings)? {
        RemovePlan::Noop => Ok(()),
        RemovePlan::Remove { unbind_values } => {
            for value in unbind_values {
                unbind(value.as_str()).await?;
            }

            Ok(())
        }
    }
}

/// Installs a bind through Lua first, then falls back for legacy `.conf` users.
async fn install(bind: &super::Bind) -> Result<(), Error> {
    let lua = bind.lua_expression()?;
    if run(["eval", lua.as_str()]).await.is_ok() {
        return Ok(());
    }

    run(["keyword", bind.keyword, bind.value.as_str()]).await
}

/// Removes a bind through Lua first, then falls back for legacy `.conf` users.
async fn unbind(value: &str) -> Result<(), Error> {
    let lua = super::Bind::lua_unbind_expression(value);
    if run(["eval", lua.as_str()]).await.is_ok() {
        return Ok(());
    }

    run(["keyword", "unbind", value]).await
}

async fn read_bindings() -> Result<Vec<BindEntry>, Error> {
    let command = "hyprctl binds -j";
    let output = Command::new("hyprctl")
        .args(["binds", "-j"])
        .output()
        .await
        .map_err(|source| Error::CommandIo {
            command: command.to_owned(),
            source,
        })?;

    if !output.status.success() {
        return Err(Error::CommandStatus {
            command: command.to_owned(),
            status: output.status,
        });
    }

    serde_json::from_slice::<Vec<BindEntry>>(&output.stdout).map_err(Error::ParseHyprBindings)
}

async fn run<const N: usize>(args: [&str; N]) -> Result<(), Error> {
    let command = format!("hyprctl {}", args.join(" "));
    let status = Command::new("hyprctl")
        .args(args)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .map_err(|source| Error::CommandIo {
            command: command.clone(),
            source,
        })?;

    if status.success() {
        Ok(())
    } else {
        Err(Error::CommandStatus { command, status })
    }
}
