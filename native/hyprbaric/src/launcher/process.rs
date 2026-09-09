//! Process spawning and desktop-entry Exec expansion.

use std::{
    env,
    ffi::OsString,
    path::{Path, PathBuf},
    process::Command,
};

use tracing::instrument;

use super::{Error, domain::Entry};

pub(super) fn start_entry(entry: &Entry) -> Result<(), Error> {
    if command_exists("gtk-launch") {
        let launch = Launch::gtk_launch(entry.id.as_str());
        if start(&launch, entry).is_ok() {
            return Ok(());
        }
    }

    let launch = Launch::from_exec(entry)?;
    start(&launch, entry)
}

#[instrument(skip_all, fields(entry_id = %entry.id, command = tracing::field::Empty), err)]
fn start(launch: &Launch, entry: &Entry) -> Result<(), Error> {
    let command = launch.shell().map_err(|_| Error::InvalidExec {
        id: entry.id.clone(),
        exec: entry.exec.clone(),
    })?;
    tracing::Span::current().record("command", command.as_str());
    let mut fallback = launch.command();
    crate::hyprland::start_user(&command, &mut fallback)
        .map_err(|source| Error::Spawn { command, source })
}

struct Launch {
    program: String,
    arguments: Vec<String>,
    working_dir: Option<PathBuf>,
}

impl Launch {
    fn gtk_launch(id: &str) -> Self {
        Self {
            program: "gtk-launch".to_string(),
            arguments: vec![id.to_string()],
            working_dir: None,
        }
    }

    fn from_exec(entry: &Entry) -> Result<Self, Error> {
        let argv = expand_exec(entry)?;
        let (program, arguments) = argv.split_first().ok_or_else(|| Error::InvalidExec {
            id: entry.id.clone(),
            exec: entry.exec.clone(),
        })?;

        if entry.terminal {
            let terminal = terminal_command()?;
            let mut wrapped = terminal.arguments;
            wrapped.push(program.clone());
            wrapped.extend(arguments.iter().cloned());
            return Ok(Self {
                program: terminal.program,
                arguments: wrapped,
                working_dir: entry.working_dir.clone(),
            });
        }

        Ok(Self {
            program: program.clone(),
            arguments: arguments.to_vec(),
            working_dir: entry.working_dir.clone(),
        })
    }

    fn shell(&self) -> Result<String, shlex::QuoteError> {
        let mut words = vec![self.program.as_str()];
        words.extend(self.arguments.iter().map(String::as_str));
        let command = shlex::try_join(words)?;
        match &self.working_dir {
            Some(directory) => {
                let directory = directory.to_string_lossy();
                let directory = shlex::try_quote(&directory)?;
                Ok(format!("cd {directory} && {command}"))
            }
            None => Ok(command),
        }
    }

    fn command(&self) -> Command {
        let mut command = Command::new(&self.program);
        command.args(&self.arguments);
        if let Some(directory) = &self.working_dir {
            command.current_dir(directory);
        }
        command
    }
}

fn expand_exec(entry: &Entry) -> Result<Vec<String>, Error> {
    let tokens = shlex::split(&entry.exec).ok_or_else(|| Error::InvalidExec {
        id: entry.id.clone(),
        exec: entry.exec.clone(),
    })?;
    let mut expanded = Vec::new();

    for token in tokens {
        let token = expand_token(&token, entry)?;
        if token.is_empty() {
            continue;
        }
        expanded.push(token);
    }

    if expanded.is_empty() {
        return Err(Error::InvalidExec {
            id: entry.id.clone(),
            exec: entry.exec.clone(),
        });
    }

    Ok(expanded)
}

fn expand_token(token: &str, entry: &Entry) -> Result<String, Error> {
    let mut output = String::new();
    let mut chars = token.chars().peekable();

    while let Some(character) = chars.next() {
        if character != '%' {
            output.push(character);
            continue;
        }

        let Some(code) = chars.next() else {
            output.push('%');
            break;
        };

        match code {
            '%' => output.push('%'),
            'c' => output.push_str(&entry.name),
            'k' => output.push_str(&entry.desktop_path.to_string_lossy()),
            'i' => {}
            'f' | 'F' | 'u' | 'U' | 'd' | 'D' | 'n' | 'N' | 'v' | 'm' => {}
            other => {
                return Err(Error::UnsupportedExecPlaceholder {
                    id: entry.id.clone(),
                    placeholder: other,
                });
            }
        }
    }

    Ok(output)
}

fn terminal_command() -> Result<TerminalCommand, Error> {
    if let Some(command) =
        env::var_os("TERMINAL").and_then(|value| parse_terminal_command(value).ok())
    {
        return Ok(command);
    }

    for (program, arguments) in [
        ("x-terminal-emulator", &["-e"][..]),
        ("kitty", &["-e"][..]),
        ("alacritty", &["-e"][..]),
        ("foot", &["-e"][..]),
        ("wezterm", &["start", "--"][..]),
        ("gnome-terminal", &["--"][..]),
        ("konsole", &["-e"][..]),
    ] {
        if command_exists(program) {
            return Ok(TerminalCommand {
                program: program.to_string(),
                arguments: arguments
                    .iter()
                    .map(|argument| argument.to_string())
                    .collect(),
            });
        }
    }

    Err(Error::MissingTerminalEmulator)
}

fn parse_terminal_command(value: OsString) -> Result<TerminalCommand, Error> {
    let command = value.to_string_lossy().into_owned();
    let mut parts = shlex::split(&command).ok_or_else(|| Error::InvalidTerminalCommand {
        command: command.clone(),
    })?;
    let program = parts
        .first()
        .cloned()
        .ok_or_else(|| Error::InvalidTerminalCommand { command })?;
    if !command_exists(&program) {
        return Err(Error::MissingConfiguredTerminal { command: program });
    }
    let _ = parts.remove(0);

    Ok(TerminalCommand {
        program,
        arguments: parts,
    })
}

struct TerminalCommand {
    program: String,
    arguments: Vec<String>,
}

pub(super) fn command_exists(command: &str) -> bool {
    let candidate = command_name(command);
    let candidate_path = Path::new(&candidate);
    if candidate_path.components().count() > 1 {
        return candidate_path.exists();
    }

    env::var_os("PATH").is_some_and(|path| {
        env::split_paths(&path).any(|directory| directory.join(&candidate).exists())
    })
}

pub(super) fn command_name(command: &str) -> String {
    shlex::split(command)
        .and_then(|parts| parts.first().cloned())
        .unwrap_or_else(|| command.to_string())
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use super::{Launch, command_name, expand_token};
    use crate::launcher::domain::{Entry, SearchFields, normalize};

    fn entry(id: &str, name: &str, exec: &str) -> Entry {
        Entry {
            id: super::super::domain::Id::new(id).expect("test entry ID should be non-empty"),
            name: name.to_string(),
            subtitle: Some("Browser".to_string()),
            icon_name: Some("firefox".to_string()),
            icon_path: Some(PathBuf::from(
                "/usr/share/icons/hicolor/scalable/apps/firefox.svg",
            )),
            icon_resolved: true,
            terminal: false,
            desktop_path: Path::new("/usr/share/applications").join(id),
            exec: exec.to_string(),
            working_dir: None,
            normalized: SearchFields {
                name: normalize(name),
                exec: normalize(exec),
                subtitle: normalize("Browser"),
                keywords: vec![normalize("web")],
            },
        }
    }

    #[test]
    fn expand_token_replaces_supported_placeholders() {
        let entry = entry("firefox.desktop", "Firefox", "firefox %u");
        assert_eq!(
            expand_token("%c", &entry).expect("placeholder should expand"),
            "Firefox"
        );
        assert_eq!(
            expand_token("%k", &entry).expect("placeholder should expand"),
            "/usr/share/applications/firefox.desktop"
        );
    }

    #[test]
    fn command_name_uses_first_exec_token() {
        assert_eq!(command_name("firefox --new-window"), "firefox");
        assert_eq!(command_name("\"code\" --reuse-window"), "code");
    }

    #[test]
    fn gtk_launch_shell_quotes_the_desktop_id() {
        let launch = Launch::gtk_launch("Firefox Web Browser.desktop");
        assert_eq!(
            launch.shell().expect("desktop id should quote"),
            "gtk-launch 'Firefox Web Browser.desktop'"
        );
    }

    #[test]
    fn exec_shell_keeps_simple_argv_unquoted() {
        let entry = entry("firefox.desktop", "Firefox", "firefox --new-window");
        let launch = Launch::from_exec(&entry).expect("exec should expand");
        assert_eq!(
            launch.shell().expect("shell should join"),
            "firefox --new-window"
        );
    }

    #[test]
    fn exec_shell_quotes_arguments_and_working_directory() {
        let mut entry = entry(
            "code.desktop",
            "Code",
            r#"code --reuse-window "My Project""#,
        );
        entry.working_dir = Some(PathBuf::from("/tmp/My Docs"));
        let launch = Launch::from_exec(&entry).expect("exec should expand");
        assert_eq!(
            launch.shell().expect("shell should quote"),
            "cd '/tmp/My Docs' && code --reuse-window 'My Project'"
        );
    }

    #[test]
    fn exec_shell_wraps_terminal_entries() {
        let launch = Launch {
            program: "kitty".to_string(),
            arguments: vec!["-e".to_string(), "htop".to_string()],
            working_dir: None,
        };
        assert_eq!(
            launch.shell().expect("terminal shell should join"),
            "kitty -e htop"
        );
    }
}
