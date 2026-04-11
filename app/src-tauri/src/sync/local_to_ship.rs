use std::path::{Path, PathBuf};

use serde_json::json;
use tracing::{debug, info, warn};

use crate::urbit::channel::EyreChannel;

use super::ship_to_local::content_hash;
use super::state::SyncState;

/// A filesystem event detected by the watcher, after debouncing and filtering
#[derive(Debug, Clone)]
pub enum FsChange {
    FileModified(PathBuf),
    FileCreated(PathBuf),
    FileDeleted(PathBuf),
    FileRenamed { from: PathBuf, to: PathBuf },
    DirCreated(PathBuf),
    DirDeleted(PathBuf),
    DirRenamed { from: PathBuf, to: PathBuf },
}

/// Process a local filesystem change and push it to the ship.
/// Returns the paths that should be suppressed from further FS events.
pub async fn handle_fs_change(
    change: &FsChange,
    sync_root: &Path,
    state: &mut SyncState,
    channel: &mut EyreChannel,
    client: &crate::urbit::client::UrbitClient,
    ship: &str,
) -> Result<Vec<PathBuf>, LocalSyncError> {
    let suppress = Vec::new();

    match change {
        FsChange::FileModified(path) | FsChange::FileCreated(path) => {
            // Only handle .md files
            if path.extension().and_then(|e| e.to_str()) != Some("md") {
                return Ok(suppress);
            }

            let rel = path
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            // If the file is already tracked, treat as an update (even if
            // the event was "Created" — editors do atomic saves via
            // write-tmp-then-rename which macOS reports as Create).
            if let Some((flag, notebook_id, note_sync)) = state.find_note_by_path(&rel) {
                let content = std::fs::read_to_string(path)?;
                let new_hash = content_hash(&content);

                // Skip if content hasn't actually changed
                if new_hash == note_sync.content_hash {
                    debug!("File unchanged (hash match), skipping: {}", rel);
                    return Ok(suppress);
                }

                let flag = flag.to_string();
                let note_id = note_sync.note_id;

                // Send expectedRevision as 0 to force-update — the
                // subscriber's local revision is unreliable (may be stale).
                // The host agent accepts 0 as "skip revision check".
                let action = json!({
                    "update-note": {
                        "notebookId": notebook_id,
                        "noteId": note_id,
                        "bodyMd": content,
                        "expectedRevision": 0
                    }
                });

                channel.poke(ship, "notes-action", action).await?;
                info!("Pushed update for note {}", note_id);

                // Update state hash so we don't re-send the same content
                if let Some(nb) = state.notebooks.get_mut(&flag) {
                    if let Some(ns) = nb.notes.get_mut(&note_id) {
                        ns.content_hash = new_hash;
                        ns.last_synced_at = now();
                    }
                }
                state.save(sync_root)?;
                return Ok(suppress);
            }

            // Not tracked — create it on the ship
            info!("File not tracked, will create on ship: {}", rel);

            // Determine which notebook and folder this belongs to
            let components: Vec<&str> = rel.split('/').collect();
            if components.is_empty() {
                return Ok(suppress);
            }

            let notebook_dir = components[0];
            if let Some((flag, nb)) = state.find_notebook_by_dir(notebook_dir) {
                let flag = flag.to_string();
                let notebook_id = nb.notebook_id;

                // Find the folder ID from the path
                let folder_path_str = if components.len() > 2 {
                    components[1..components.len() - 1].join("/")
                } else {
                    String::new()
                };

                // Find the root folder (the one with name "/")
                let folder_id = if folder_path_str.is_empty() {
                    // Root folder
                    nb.folders
                        .values()
                        .find(|f| f.name == "/")
                        .map(|f| f.folder_id)
                        .unwrap_or(0)
                } else {
                    nb.folders
                        .values()
                        .find(|f| f.local_path == folder_path_str)
                        .map(|f| f.folder_id)
                        .unwrap_or(0)
                };

                let title = path
                    .file_stem()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| "Untitled".to_string());
                let content = std::fs::read_to_string(path)?;

                let action = json!({
                    "create-note": {
                        "notebookId": notebook_id,
                        "folderId": folder_id,
                        "title": title,
                        "bodyMd": content
                    }
                });

                channel.poke(ship, "notes-action", action).await?;
                info!("Created note on ship: {} in folder {}", title, folder_id);

                // Wait for the create to propagate from host back to
                // subscriber, then scry to find the real note ID
                let hash = content_hash(&content);
                let mut real_id = None;
                for attempt in 0..3 {
                    if attempt > 0 {
                        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                    }
                    match client.get_notes(&flag).await {
                        Ok(notes) => {
                            if let Some(n) = notes.iter()
                                .filter(|n| n.title == title && n.folder_id == folder_id)
                                .max_by_key(|n| n.id)
                            {
                                info!("Found created note with real ID {} (attempt {})", n.id, attempt);
                                real_id = Some(n.id);
                                break;
                            }
                        }
                        Err(e) => {
                            warn!("Scry attempt {} failed: {}", attempt, e);
                        }
                    }
                }

                // Add to state with real ID (or placeholder if scry failed)
                let note_id = real_id.unwrap_or_else(|| now() + (std::process::id() as u64));
                if let Some(nb) = state.notebooks.get_mut(&flag) {
                    nb.notes.insert(
                        note_id,
                        super::state::NoteSync {
                            note_id,
                            title: title.clone(),
                            folder_id,
                            revision: 0,
                            content_hash: hash,
                            local_path: rel.clone(),
                            last_synced_at: now(),
                        },
                    );
                }
                state.save(sync_root)?;
            } else {
                debug!("Created file not in any synced notebook: {}", rel);
            }
        }

        FsChange::FileDeleted(path) => {
            let rel = path
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            if let Some((flag, notebook_id, note_sync)) = state.find_note_by_path(&rel) {
                let flag = flag.to_string();
                let note_id = note_sync.note_id;

                let action = json!({
                    "delete-note": {
                        "noteId": note_id,
                        "notebookId": notebook_id
                    }
                });

                channel.poke(ship, "notes-action", action).await?;
                info!("Deleted note on ship: {}", note_id);

                // Remove from state
                if let Some(nb) = state.notebooks.get_mut(&flag) {
                    nb.notes.remove(&note_id);
                }
                state.save(sync_root)?;
            }
        }

        FsChange::FileRenamed { from, to } => {
            let old_rel = from
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            if let Some((flag, notebook_id, note_sync)) = state.find_note_by_path(&old_rel) {
                let flag = flag.to_string();
                let note_id = note_sync.note_id;

                let new_title = to
                    .file_stem()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| "Untitled".to_string());

                let action = json!({
                    "rename-note": {
                        "notebookId": notebook_id,
                        "noteId": note_id,
                        "title": new_title
                    }
                });

                channel.poke(ship, "notes-action", action).await?;
                info!("Renamed note on ship: {} -> {}", note_id, new_title);

                // Update state
                let new_rel = to
                    .strip_prefix(sync_root)
                    .map_err(|_| LocalSyncError::PathOutsideRoot)?
                    .to_string_lossy()
                    .to_string();

                if let Some(nb) = state.notebooks.get_mut(&flag) {
                    if let Some(ns) = nb.notes.get_mut(&note_id) {
                        ns.title = new_title;
                        ns.local_path = new_rel;
                    }
                }
                state.save(sync_root)?;
            }
        }

        FsChange::DirCreated(path) => {
            let rel = path
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            let components: Vec<&str> = rel.split('/').collect();
            if components.len() < 2 {
                // Top-level dir — could be a new notebook, skip for now
                return Ok(suppress);
            }

            let notebook_dir = components[0];
            if let Some((flag, nb)) = state.find_notebook_by_dir(notebook_dir) {
                let flag = flag.to_string();
                let notebook_id = nb.notebook_id;

                // Find parent folder
                let parent_path = if components.len() > 2 {
                    components[1..components.len() - 1].join("/")
                } else {
                    String::new()
                };

                let parent_folder_id = if parent_path.is_empty() {
                    // Parent is the root folder
                    nb.folders
                        .values()
                        .find(|f| f.name == "/")
                        .map(|f| f.folder_id)
                } else {
                    nb.folders
                        .values()
                        .find(|f| f.local_path == parent_path)
                        .map(|f| f.folder_id)
                };

                let folder_name = components.last().unwrap_or(&"");

                let action = json!({
                    "create-folder": {
                        "notebookId": notebook_id,
                        "parentFolderId": parent_folder_id,
                        "name": folder_name
                    }
                });

                channel.poke(ship, "notes-action", action).await?;
                info!("Created folder on ship: {}", folder_name);
            }
        }

        FsChange::DirDeleted(path) => {
            let rel = path
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            let components: Vec<&str> = rel.split('/').collect();
            if components.len() < 2 {
                return Ok(suppress);
            }

            let notebook_dir = components[0];
            let folder_rel = components[1..].join("/");

            if let Some((flag, nb)) = state.find_notebook_by_dir(notebook_dir) {
                if let Some(folder) = nb.folders.values().find(|f| f.local_path == folder_rel) {
                    let flag = flag.to_string();
                    let folder_id = folder.folder_id;
                    let notebook_id = nb.notebook_id;

                    let action = json!({
                        "delete-folder": {
                            "notebookId": notebook_id,
                            "folderId": folder_id,
                            "recursive": true
                        }
                    });

                    channel.poke(ship, "notes-action", action).await?;
                    info!("Deleted folder on ship: {}", folder_id);

                    // Remove from state
                    if let Some(nb) = state.notebooks.get_mut(&flag) {
                        nb.folders.retain(|_, f| f.folder_id != folder_id);
                    }
                    state.save(sync_root)?;
                }
            }
        }

        FsChange::DirRenamed { from, to } => {
            let old_rel = from
                .strip_prefix(sync_root)
                .map_err(|_| LocalSyncError::PathOutsideRoot)?
                .to_string_lossy()
                .to_string();

            let old_components: Vec<&str> = old_rel.split('/').collect();
            if old_components.len() < 2 {
                return Ok(suppress);
            }

            let notebook_dir = old_components[0];
            let folder_rel = old_components[1..].join("/");

            if let Some((flag, nb)) = state.find_notebook_by_dir(notebook_dir) {
                if let Some(folder) = nb.folders.values().find(|f| f.local_path == folder_rel) {
                    let flag = flag.to_string();
                    let folder_id = folder.folder_id;
                    let notebook_id = nb.notebook_id;

                    let new_name = to
                        .file_name()
                        .map(|s| s.to_string_lossy().to_string())
                        .unwrap_or_default();

                    let action = json!({
                        "rename-folder": {
                            "notebookId": notebook_id,
                            "folderId": folder_id,
                            "name": new_name
                        }
                    });

                    channel.poke(ship, "notes-action", action).await?;
                    info!("Renamed folder on ship: {} -> {}", folder_id, new_name);

                    // Update state
                    let new_rel = to
                        .strip_prefix(sync_root)
                        .map_err(|_| LocalSyncError::PathOutsideRoot)?
                        .to_string_lossy()
                        .to_string();
                    let new_folder_rel = new_rel
                        .strip_prefix(&format!("{}/", notebook_dir))
                        .unwrap_or(&new_rel)
                        .to_string();

                    if let Some(nb) = state.notebooks.get_mut(&flag) {
                        if let Some(fs) = nb.folders.get_mut(&folder_id) {
                            fs.name = new_name;
                            fs.local_path = new_folder_rel;
                        }
                    }
                    state.save(sync_root)?;
                }
            }
        }
    }

    Ok(suppress)
}

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

#[derive(Debug, thiserror::Error)]
pub enum LocalSyncError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Channel error: {0}")]
    Channel(#[from] crate::urbit::channel::ChannelError),
    #[error("Path is outside sync root")]
    PathOutsideRoot,
}
