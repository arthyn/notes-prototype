use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

use notify::event::ModifyKind;
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tokio::sync::mpsc;
use tracing::{debug, error, warn};

use crate::sync::local_to_ship::FsChange;

/// Filesystem watcher that detects changes in the sync directory.
/// Debounces rapid events and filters out our own writes via suppression.
pub struct FsWatcher {
    watcher: Option<RecommendedWatcher>,
    suppressed: Arc<RwLock<Vec<(PathBuf, Instant)>>>,
}

impl FsWatcher {
    pub fn new() -> Self {
        Self {
            watcher: None,
            suppressed: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Start watching a directory. Sends FsChange events to the channel.
    pub fn start(
        &mut self,
        sync_root: PathBuf,
        tx: mpsc::Sender<FsChange>,
    ) -> Result<(), notify::Error> {
        let suppressed = self.suppressed.clone();
        let watch_path = sync_root.clone();

        let mut watcher =
            notify::recommended_watcher(move |res: Result<Event, notify::Error>| match res {
                Ok(event) => {
                    if let Some(change) = process_event(&event, &suppressed) {
                        if let Err(e) = tx.blocking_send(change) {
                            error!("Failed to send FS change: {}", e);
                        }
                    }
                }
                Err(e) => {
                    warn!("FS watcher error: {}", e);
                }
            })?;

        watcher.watch(&watch_path, RecursiveMode::Recursive)?;
        self.watcher = Some(watcher);

        Ok(())
    }

    /// Stop watching
    pub fn stop(&mut self) {
        self.watcher = None;
    }

    /// Add paths to the suppression set (to ignore events from our own writes).
    /// Entries auto-expire after 2 seconds.
    pub fn suppress(&self, paths: &[PathBuf]) {
        let now = Instant::now();
        if let Ok(mut suppressed) = self.suppressed.write() {
            // Clean expired entries
            suppressed.retain(|(_, t)| now.duration_since(*t) < Duration::from_secs(2));
            // Add new entries
            for path in paths {
                suppressed.push((path.clone(), now));
            }
        }
    }
}

/// Convert a notify event to an FsChange, applying filters.
fn process_event(
    event: &Event,
    suppressed: &Arc<RwLock<Vec<(PathBuf, Instant)>>>,
) -> Option<FsChange> {
    let paths = &event.paths;
    if paths.is_empty() {
        return None;
    }

    let path = &paths[0];

    // Filter: ignore dotfiles and dot directories
    for component in path.components() {
        if let std::path::Component::Normal(name) = component {
            if name.to_string_lossy().starts_with('.') {
                return None;
            }
        }
    }

    // Filter: ignore temp files
    let filename = path
        .file_name()
        .map(|f| f.to_string_lossy().to_string())
        .unwrap_or_default();
    if filename.ends_with(".tmp")
        || filename.ends_with(".swp")
        || filename.starts_with('~')
        || filename.starts_with('#')
    {
        return None;
    }

    // Check suppression
    if let Ok(suppressed) = suppressed.read() {
        let now = Instant::now();
        for (suppressed_path, ts) in suppressed.iter() {
            if now.duration_since(*ts) < Duration::from_secs(2) && suppressed_path == path {
                debug!("Suppressed FS event for: {}", path.display());
                return None;
            }
        }
    }

    // Determine if this is a directory or file event.
    // On macOS, FSEvents uses CreateKind::Any / ModifyKind::Any / RemoveKind::Any
    // rather than specific subtypes, so we match broadly and use path inspection.
    let is_dir = path.is_dir();
    let is_md = path.extension().and_then(|e| e.to_str()) == Some("md");

    match &event.kind {
        // Create events
        EventKind::Create(_) => {
            if is_dir {
                debug!("FS: dir created {}", path.display());
                Some(FsChange::DirCreated(path.clone()))
            } else if is_md {
                debug!("FS: file created {}", path.display());
                Some(FsChange::FileCreated(path.clone()))
            } else {
                None
            }
        }
        // Modify events (content change or rename)
        EventKind::Modify(ModifyKind::Name(_)) => {
            // Rename: notify gives us both paths
            if paths.len() >= 2 {
                let from = &paths[0];
                let to = &paths[1];
                debug!("FS: rename {} -> {}", from.display(), to.display());
                if to.is_dir() || from.is_dir() {
                    Some(FsChange::DirRenamed {
                        from: from.clone(),
                        to: to.clone(),
                    })
                } else {
                    Some(FsChange::FileRenamed {
                        from: from.clone(),
                        to: to.clone(),
                    })
                }
            } else {
                None
            }
        }
        EventKind::Modify(_) => {
            // Content modification (Data, Metadata, Any, etc.)
            if is_md && path.exists() {
                debug!("FS: file modified {}", path.display());
                Some(FsChange::FileModified(path.clone()))
            } else {
                None
            }
        }
        // Remove events
        EventKind::Remove(_) => {
            // Can't check is_dir/is_md on a deleted path, so infer from extension
            if path.extension().and_then(|e| e.to_str()) == Some("md") {
                debug!("FS: file deleted {}", path.display());
                Some(FsChange::FileDeleted(path.clone()))
            } else if path.extension().is_none() {
                // Probably a directory (no extension)
                debug!("FS: dir deleted {}", path.display());
                Some(FsChange::DirDeleted(path.clone()))
            } else {
                None
            }
        }
        _ => None,
    }
}
