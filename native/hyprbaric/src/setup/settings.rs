//! Setup-guide persistence.

use toml_edit::{DocumentMut, Item, Table, value};
use tracing::instrument;

use crate::config;

use super::{Configuration, Error};

const TABLE: &str = "setup";

/// Persists an acknowledged setup journey.
#[instrument(
    name = "hyprbaric::setup::settings::complete",
    skip(configuration),
    err
)]
pub(super) fn complete(configuration: &Configuration) -> Result<Configuration, Error> {
    let completed = configuration.completed();

    config::try_edit(|document| write(document, &completed))?;

    Ok(completed)
}

fn write(document: &mut DocumentMut, configuration: &Configuration) -> Result<(), Error> {
    if !document.as_table().contains_key(TABLE) {
        document[TABLE] = Item::Table(Table::new());
    }

    let table = document[TABLE].as_table_mut().ok_or(Error::InvalidTable)?;

    // Only the fact this write exists to record. Stamping `startup` back in
    // would freeze a default the user never chose into their own file.
    if table.contains_key("startup") {
        table["startup"] = value(configuration.startup().as_str());
    }
    table["completed"] = value(configuration.completion().is_complete());

    Ok(())
}

#[cfg(test)]
mod tests {
    use toml_edit::DocumentMut;

    use super::write;
    use crate::setup::{Configuration, Error, Status};

    #[test]
    fn completion_preserves_never_policy() {
        let configuration =
            toml::from_str::<Configuration>("startup = \"never\"\ncompleted = false\n")
                .expect("setup fixture should parse")
                .completed();
        let mut document = "[setup]\nstartup = \"never\"\n"
            .parse::<DocumentMut>()
            .expect("setup fixture should parse");

        write(&mut document, &configuration).expect("setup config should be writable");

        assert!(document.to_string().contains("startup = \"never\""));
        assert!(document.to_string().contains("completed = true"));
        assert_eq!(configuration.status(), Status::Disabled);
    }

    #[test]
    fn completion_does_not_stamp_in_an_unset_startup_policy() {
        let configuration = Configuration::default().completed();
        let mut document = DocumentMut::new();

        write(&mut document, &configuration).expect("setup config should be writable");

        // The user never chose a policy, so completing must not freeze the
        // current default into their file.
        assert!(!document.to_string().contains("startup"));
        assert!(document.to_string().contains("completed = true"));
    }

    #[test]
    fn completion_rejects_a_non_table_setup_value() {
        let configuration = Configuration::default().completed();
        let mut document = "setup = \"already-complete\""
            .parse::<DocumentMut>()
            .expect("setup fixture should parse");

        let error = write(&mut document, &configuration)
            .expect_err("a scalar setup value cannot be completed");

        assert!(matches!(error, Error::InvalidTable));
        assert_eq!(document.to_string(), "setup = \"already-complete\"\n");
    }
}
