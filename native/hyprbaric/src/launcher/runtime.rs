//! Runtime composition for the app launcher.

use std::{collections::HashMap, path::PathBuf, sync::Arc, time::Duration};

use freedesktop_desktop_entry::get_languages_from_env;
use notify::{
    Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher,
    event::{AccessKind, AccessMode, MetadataKind, ModifyKind},
};
use tokio::{
    sync::{RwLock, broadcast, watch},
    task,
    time::{Instant, sleep},
};
use tracing::instrument;

use super::{
    Error,
    desktop::{self, DesktopDirectory, WatchTarget},
    domain::{Cache, Id, Phase, Results, State},
    process, usage,
};

pub type Handle = Arc<Launcher>;

const WATCH_DEBOUNCE: Duration = Duration::from_millis(160);

#[derive(Clone)]
pub struct Launcher {
    state: Arc<RwLock<State>>,
    events: broadcast::Sender<Results>,
    desktop_dirs: Arc<[DesktopDirectory]>,
    watch_targets: Arc<[WatchTarget]>,
    locales: Arc<[String]>,
    usage_path: PathBuf,
}

impl Launcher {
    #[instrument]
    pub async fn bootstrap() -> (Handle, Results) {
        let desktop_dirs = desktop::application_directories();
        let watch_targets = desktop::watch_targets(&desktop_dirs);
        let locales = get_languages_from_env();
        let usage_path = usage::usage_path();
        let usage = match usage::read_usage_file(usage_path.clone()).await {
            Ok(usage) => usage,
            Err(error) => {
                tracing::warn!("Failed to load launcher usage file: {error}");
                HashMap::new()
            }
        };

        let (events, _) = broadcast::channel(32);
        let launcher = Arc::new(Self {
            state: Arc::new(RwLock::new(State {
                phase: Phase::Loading,
                query: String::new(),
                cache: Cache {
                    entries: Vec::new(),
                    usage,
                    icons: None,
                },
            })),
            events,
            desktop_dirs: Arc::from(desktop_dirs),
            watch_targets: Arc::from(watch_targets),
            locales: Arc::from(locales),
            usage_path,
        });

        let initial = Results {
            phase: Phase::Loading,
            query: String::new(),
            entries: Vec::new(),
        };
        launcher.spawn_rebuild();
        launcher.spawn_watcher();
        (launcher, initial)
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Results> {
        self.events.subscribe()
    }

    #[instrument(skip(self), fields(query = %query))]
    pub async fn update_query(&self, query: String) -> Results {
        let results = {
            let mut state = self.state.write().await;
            state.query = query;
            state.results()
        };
        let _ = self.events.send(results.clone());
        self.spawn_icon_refresh();
        results
    }

    #[instrument(skip(self), err)]
    pub async fn rebuild(&self) -> Result<Results, Error> {
        let desktop_dirs = self.desktop_dirs.to_vec();
        let locales = self.locales.to_vec();
        let entries = task::spawn_blocking(move || desktop::build_index(desktop_dirs, locales))
            .await
            .map_err(Error::Join)?;

        let results = {
            let mut state = self.state.write().await;
            state.phase = Phase::Ready;
            state.cache.entries = entries;
            state.cache.icons = None;
            state.results()
        };

        let _ = self.events.send(results.clone());
        self.spawn_icon_refresh();
        Ok(results)
    }

    #[instrument(skip(self), fields(entry_id = %entry_id), err)]
    pub async fn launch(&self, entry_id: Id) -> Result<(), Error> {
        let entry = {
            let state = self.state.read().await;
            state
                .cache
                .entry(&entry_id)
                .cloned()
                .ok_or_else(|| Error::UnknownEntry {
                    id: entry_id.clone(),
                })?
        };

        process::start_entry(&entry)?;

        let (results, usage) = {
            let mut state = self.state.write().await;
            state.cache.record_launch(&entry_id);
            (state.results(), state.cache.usage.clone())
        };
        let _ = self.events.send(results);

        if let Err(error) = usage::write_usage_file(self.usage_path.clone(), usage).await {
            tracing::warn!("Failed to persist launcher usage file: {error}");
        }

        Ok(())
    }

    fn spawn_watcher(self: &Arc<Self>) {
        if self.watch_targets.is_empty() {
            return;
        }

        let launcher = Arc::clone(self);
        tokio::spawn(async move {
            let (tx, mut rx) = watch::channel(());
            let watcher = match create_watcher(tx, &launcher.watch_targets) {
                Ok(watcher) => watcher,
                Err(error) => {
                    tracing::warn!("Failed to start app-launcher watcher: {error}");
                    return;
                }
            };

            while rx.changed().await.is_ok() {
                let deadline = Instant::now() + WATCH_DEBOUNCE;
                let timer = sleep_until(deadline);
                tokio::pin!(timer);

                loop {
                    tokio::select! {
                        _ = &mut timer => break,
                        changed = rx.changed() => {
                            if changed.is_err() {
                                return;
                            }
                            timer.as_mut().reset(Instant::now() + WATCH_DEBOUNCE);
                        }
                    }
                }

                if let Err(error) = launcher.rebuild().await {
                    tracing::warn!("Failed to rebuild app-launcher index: {error}");
                }
            }

            drop(watcher);
        });
    }

    fn spawn_rebuild(self: &Arc<Self>) {
        let launcher = Arc::clone(self);
        tokio::spawn(async move {
            if let Err(error) = launcher.rebuild().await {
                launcher.fail(error.to_string()).await;
            }
        });
    }

    fn spawn_icon_refresh(&self) {
        let state = Arc::clone(&self.state);
        let events = self.events.clone();
        tokio::spawn(async move {
            let results = {
                let mut state = state.write().await;
                let query = state.query.clone();
                if !state.cache.resolve_visible_icons(&query) {
                    return;
                }
                state.results()
            };

            let _ = events.send(results);
        });
    }

    async fn fail(&self, message: String) -> Results {
        let results = {
            let mut state = self.state.write().await;
            state.phase = Phase::Failed { message };
            state.results()
        };
        let _ = self.events.send(results.clone());
        results
    }
}

fn create_watcher(
    tx: watch::Sender<()>,
    targets: &[WatchTarget],
) -> Result<RecommendedWatcher, Error> {
    let mut watcher = RecommendedWatcher::new(
        move |event| match event {
            Ok(event) if event_changes_index(&event) => {
                tx.send_replace(());
            }
            Err(error) => {
                tracing::warn!("App-launcher watcher error: {error}");
                tx.send_replace(());
            }
            _ => {}
        },
        Config::default(),
    )
    .map_err(Error::Watch)?;

    for target in targets {
        watcher
            .watch(
                &target.path,
                if target.recursive {
                    RecursiveMode::Recursive
                } else {
                    RecursiveMode::NonRecursive
                },
            )
            .map_err(Error::Watch)?;
    }

    Ok(watcher)
}

fn event_changes_index(event: &Event) -> bool {
    if event.need_rescan() {
        return true;
    }

    match event.kind {
        EventKind::Access(AccessKind::Close(AccessMode::Write)) => true,
        EventKind::Access(_)
        | EventKind::Modify(ModifyKind::Metadata(MetadataKind::AccessTime)) => false,
        EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) | EventKind::Any => true,
        EventKind::Other => false,
    }
}

fn sleep_until(deadline: Instant) -> tokio::time::Sleep {
    sleep(deadline.saturating_duration_since(Instant::now()))
}

#[cfg(test)]
mod tests {
    use std::{
        fs::{self, OpenOptions},
        io::{self, Write},
        path::PathBuf,
        time::{Duration, SystemTime, UNIX_EPOCH},
    };

    use notify::{
        Event, EventKind,
        event::{
            AccessKind, AccessMode, CreateKind, DataChange, Flag, MetadataKind, ModifyKind,
            RemoveKind,
        },
    };
    use tokio::{sync::watch, time::timeout};

    use super::{WATCH_DEBOUNCE, WatchTarget, create_watcher, event_changes_index};

    #[test]
    fn reads_do_not_invalidate_the_desktop_index() {
        for kind in [
            EventKind::Access(AccessKind::Open(AccessMode::Any)),
            EventKind::Access(AccessKind::Open(AccessMode::Read)),
            EventKind::Access(AccessKind::Read),
            EventKind::Access(AccessKind::Close(AccessMode::Read)),
            EventKind::Modify(ModifyKind::Metadata(MetadataKind::AccessTime)),
        ] {
            assert!(!event_changes_index(&Event::new(kind)), "{kind:?}");
        }
    }

    #[test]
    fn writes_and_lost_events_invalidate_the_desktop_index() {
        for kind in [
            EventKind::Create(CreateKind::File),
            EventKind::Create(CreateKind::Folder),
            EventKind::Modify(ModifyKind::Data(DataChange::Any)),
            EventKind::Access(AccessKind::Close(AccessMode::Write)),
            EventKind::Remove(RemoveKind::File),
            EventKind::Any,
        ] {
            assert!(event_changes_index(&Event::new(kind)), "{kind:?}");
        }

        assert!(event_changes_index(
            &Event::new(EventKind::Other).set_flag(Flag::Rescan)
        ));
    }

    #[cfg(target_os = "linux")]
    #[tokio::test]
    async fn opening_desktop_files_does_not_trigger_a_rebuild()
    -> Result<(), Box<dyn std::error::Error>> {
        let directory = TemporaryDirectory::new()?;
        let target = WatchTarget {
            path: directory.0.clone(),
            recursive: true,
        };
        let (tx, mut changes) = watch::channel(());
        let watcher = create_watcher(tx, &[target])?;
        let desktop_file = directory.0.join("hyprbaric-watch-test.desktop");

        fs::write(
            &desktop_file,
            b"[Desktop Entry]\nType=Application\nName=Watch Test\n",
        )?;
        timeout(Duration::from_secs(2), changes.changed()).await??;
        drain_changes(&mut changes).await;

        for _ in 0..10 {
            let _ = fs::read(&desktop_file)?;
        }
        assert!(
            timeout(WATCH_DEBOUNCE * 3, changes.changed())
                .await
                .is_err()
        );

        let mut file = OpenOptions::new().append(true).open(&desktop_file)?;
        file.write_all(b"Comment=Updated\n")?;
        drop(file);
        timeout(Duration::from_secs(2), changes.changed()).await??;
        drain_changes(&mut changes).await;

        let renamed = directory.0.join("renamed-watch-test.desktop");
        fs::rename(&desktop_file, &renamed)?;
        timeout(Duration::from_secs(2), changes.changed()).await??;
        drain_changes(&mut changes).await;

        fs::remove_file(&renamed)?;
        timeout(Duration::from_secs(2), changes.changed()).await??;
        drop(watcher);
        Ok(())
    }

    #[cfg(target_os = "linux")]
    async fn drain_changes(changes: &mut watch::Receiver<()>) {
        while matches!(timeout(WATCH_DEBOUNCE, changes.changed()).await, Ok(Ok(()))) {}
    }

    #[cfg(target_os = "linux")]
    struct TemporaryDirectory(PathBuf);

    #[cfg(target_os = "linux")]
    impl TemporaryDirectory {
        fn new() -> io::Result<Self> {
            let unique = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(io::Error::other)?
                .as_nanos();
            let path = std::env::temp_dir().join(format!(
                "hyprbaric-launcher-watch-{}-{unique}",
                std::process::id()
            ));
            fs::create_dir(&path)?;
            Ok(Self(path))
        }
    }

    #[cfg(target_os = "linux")]
    impl Drop for TemporaryDirectory {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }
}
