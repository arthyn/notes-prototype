use std::collections::HashMap;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};
use tracing::{debug, info, warn};

use crate::urbit::client::UrbitClient;
use crate::urbit::types::{Event, Folder};

use super::path_mapper;
use super::state::{FolderSync, NoteSync, NotebookSync, SyncState};

/// Perform a full initial sync for a notebook: scry everything, write to disk.
pub async fn initial_sync(
    client: &UrbitClient,
    flag: &str,
    notebook_title: &str,
    sync_root: &Path,
    state: &mut SyncState,
) -> Result<(), SyncError> {
    info!("Initial sync for notebook {}", flag);

    info!("Scrying folders for {}", flag);
    let folders_vec = client.get_folders(flag).await?;
    info!("Got {} folders", folders_vec.len());

    info!("Scrying notes for {}", flag);
    let notes_vec = client.get_notes(flag).await?;
    info!("Got {} notes", notes_vec.len());

    let folders = path_mapper::folder_map(folders_vec);
    let notes = path_mapper::note_map(notes_vec);

    let notebook_dir = path_mapper::sanitize_filename(notebook_title);

    // Create notebook directory
    let nb_path = sync_root.join(&notebook_dir);
    std::fs::create_dir_all(&nb_path)?;

    // Build folder sync entries and create directories
    let mut folder_syncs: HashMap<u64, FolderSync> = HashMap::new();
    for (fid, folder) in &folders {
        let rel_path = path_mapper::folder_path(*fid, &folders);
        let rel_str = rel_path.to_string_lossy().to_string();

        // Create directory on disk (skip root folder which has empty path)
        if !rel_str.is_empty() {
            let abs_path = nb_path.join(&rel_path);
            std::fs::create_dir_all(&abs_path)?;
        }

        folder_syncs.insert(
            *fid,
            FolderSync {
                folder_id: *fid,
                name: folder.name.clone(),
                parent_folder_id: folder.parent_folder_id,
                local_path: rel_str,
            },
        );
    }

    // Write notes and build note sync entries
    let mut note_syncs: HashMap<u64, NoteSync> = HashMap::new();
    let mut used_paths: HashMap<String, Vec<String>> = HashMap::new(); // dir -> filenames

    for (nid, note) in &notes {
        let rel_path = path_mapper::note_path(&notebook_dir, note, &folders);
        let rel_str = rel_path.to_string_lossy().to_string();

        // Disambiguate if needed
        let dir = rel_path
            .parent()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default();
        let filename = rel_path
            .file_name()
            .map(|f| f.to_string_lossy().to_string())
            .unwrap_or_default();

        let existing = used_paths.entry(dir.clone()).or_default();
        let final_filename = path_mapper::disambiguate(&filename, existing);
        existing.push(final_filename.clone());

        let final_rel = if dir.is_empty() {
            final_filename.clone()
        } else {
            format!("{}/{}", dir, final_filename)
        };

        // Write the markdown file
        let abs_path = sync_root.join(&final_rel);
        if let Some(parent) = abs_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&abs_path, &note.body_md)?;

        let hash = content_hash(&note.body_md);
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        note_syncs.insert(
            *nid,
            NoteSync {
                note_id: *nid,
                title: note.title.clone(),
                folder_id: note.folder_id,
                revision: note.revision,
                content_hash: hash,
                local_path: final_rel,
                last_synced_at: now,
            },
        );

        debug!("Wrote note {} -> {}", note.title, rel_str);
    }

    // Get notebook_id from first note or folder, or use 0
    let notebook_id = notes
        .values()
        .next()
        .map(|n| n.notebook_id)
        .or_else(|| folders.values().next().map(|f| f.notebook_id))
        .unwrap_or(0);

    state.notebooks.insert(
        flag.to_string(),
        NotebookSync {
            notebook_id,
            title: notebook_title.to_string(),
            local_dir: notebook_dir,
            folders: folder_syncs,
            notes: note_syncs,
        },
    );
    state.touch();
    state.save(sync_root)?;

    info!(
        "Initial sync complete for {}: {} folders, {} notes",
        flag,
        folders.len(),
        notes.len()
    );

    Ok(())
}

/// Apply a live SSE event to the local filesystem.
/// Returns the set of paths that were written (for suppression).
pub fn apply_event(
    event: &Event,
    flag: &str,
    sync_root: &Path,
    state: &mut SyncState,
) -> Result<Vec<PathBuf>, SyncError> {
    let mut written_paths = Vec::new();

    let nb = match state.notebooks.get_mut(flag) {
        Some(nb) => nb,
        None => {
            warn!("Received event for unknown notebook {}", flag);
            return Ok(written_paths);
        }
    };

    match event {
        Event::NoteCreated { note, .. } => {
            let folders: HashMap<u64, Folder> = nb
                .folders
                .iter()
                .map(|(id, fs)| {
                    (
                        *id,
                        Folder {
                            id: fs.folder_id,
                            notebook_id: nb.notebook_id,
                            name: fs.name.clone(),
                            parent_folder_id: fs.parent_folder_id,
                            created_by: String::new(),
                            created_at: 0,
                            updated_at: 0,
                        },
                    )
                })
                .collect();

            let rel_path = path_mapper::note_path(&nb.local_dir, note, &folders);
            let abs_path = sync_root.join(&rel_path);

            if let Some(parent) = abs_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::write(&abs_path, &note.body_md)?;
            written_paths.push(abs_path);

            let hash = content_hash(&note.body_md);
            let now_ts = now();
            let rel_str = rel_path.to_string_lossy().to_string();

            nb.notes.insert(
                note.id,
                NoteSync {
                    note_id: note.id,
                    title: note.title.clone(),
                    folder_id: note.folder_id,
                    revision: note.revision,
                    content_hash: hash,
                    local_path: rel_str,
                    last_synced_at: now_ts,
                },
            );
            info!("Created note: {}", note.title);
        }

        Event::NoteUpdated { note, .. } => {
            if let Some(ns) = nb.notes.get_mut(&note.id) {
                let new_hash = content_hash(&note.body_md);

                // Check if local file was also modified (conflict detection)
                let abs_path = sync_root.join(&ns.local_path);
                if abs_path.exists() {
                    let local_content = std::fs::read_to_string(&abs_path)?;
                    let local_hash = content_hash(&local_content);

                    if local_hash != ns.content_hash && new_hash != local_hash {
                        // Conflict: local was modified AND remote is different
                        let conflict_path = conflict_path(&abs_path);
                        std::fs::write(&conflict_path, &local_content)?;
                        written_paths.push(conflict_path);
                        warn!("Conflict detected for {}, saved local as .conflict.md", ns.title);
                    }
                }

                std::fs::write(&abs_path, &note.body_md)?;
                written_paths.push(abs_path);

                ns.revision = note.revision;
                ns.content_hash = new_hash;
                ns.last_synced_at = now();

                debug!("Updated note: {} (rev {})", note.title, note.revision);
            }
        }

        Event::NoteRenamed {
            note_id, title, ..
        } => {
            if let Some(ns) = nb.notes.get_mut(note_id) {
                let old_abs = sync_root.join(&ns.local_path);
                let new_filename = format!("{}.md", path_mapper::sanitize_filename(title));
                let new_abs = old_abs.with_file_name(&new_filename);

                if old_abs.exists() && old_abs != new_abs {
                    std::fs::rename(&old_abs, &new_abs)?;
                    written_paths.push(old_abs);
                    written_paths.push(new_abs.clone());
                }

                // Update state path
                let new_rel = new_abs
                    .strip_prefix(sync_root)
                    .unwrap_or(&new_abs)
                    .to_string_lossy()
                    .to_string();
                ns.title = title.clone();
                ns.local_path = new_rel;

                info!("Renamed note to: {}", title);
            }
        }

        Event::NoteMoved {
            note_id,
            folder_id,
            ..
        } => {
            if let Some(ns) = nb.notes.get_mut(note_id) {
                let old_abs = sync_root.join(&ns.local_path);
                let filename = old_abs
                    .file_name()
                    .map(|f| f.to_string_lossy().to_string())
                    .unwrap_or_default();

                // Build new directory path from the target folder
                let folder_rel = nb
                    .folders
                    .get(folder_id)
                    .map(|f| f.local_path.clone())
                    .unwrap_or_default();

                let mut new_rel = PathBuf::from(&nb.local_dir);
                if !folder_rel.is_empty() {
                    new_rel.push(&folder_rel);
                }
                new_rel.push(&filename);

                let new_abs = sync_root.join(&new_rel);
                if let Some(parent) = new_abs.parent() {
                    std::fs::create_dir_all(parent)?;
                }

                if old_abs.exists() && old_abs != new_abs {
                    std::fs::rename(&old_abs, &new_abs)?;
                    written_paths.push(old_abs);
                    written_paths.push(new_abs);
                }

                ns.folder_id = *folder_id;
                ns.local_path = new_rel.to_string_lossy().to_string();

                info!("Moved note {} to folder {}", ns.title, folder_id);
            }
        }

        Event::NoteDeleted { note_id, .. } => {
            if let Some(ns) = nb.notes.remove(note_id) {
                let abs_path = sync_root.join(&ns.local_path);
                if abs_path.exists() {
                    std::fs::remove_file(&abs_path)?;
                    written_paths.push(abs_path);
                }
                info!("Deleted note: {}", ns.title);
            }
        }

        Event::FolderCreated { folder, .. } => {
            let folders: HashMap<u64, Folder> = nb
                .folders
                .iter()
                .map(|(id, fs)| {
                    (
                        *id,
                        Folder {
                            id: fs.folder_id,
                            notebook_id: nb.notebook_id,
                            name: fs.name.clone(),
                            parent_folder_id: fs.parent_folder_id,
                            created_by: String::new(),
                            created_at: 0,
                            updated_at: 0,
                        },
                    )
                })
                .collect();

            // Build path including the new folder's parent chain
            let mut all_folders = folders;
            all_folders.insert(folder.id, folder.clone());

            let rel_path = path_mapper::folder_path(folder.id, &all_folders);
            let rel_str = rel_path.to_string_lossy().to_string();

            if !rel_str.is_empty() {
                let abs_path = sync_root.join(&nb.local_dir).join(&rel_path);
                std::fs::create_dir_all(&abs_path)?;
                written_paths.push(abs_path);
            }

            nb.folders.insert(
                folder.id,
                FolderSync {
                    folder_id: folder.id,
                    name: folder.name.clone(),
                    parent_folder_id: folder.parent_folder_id,
                    local_path: rel_str,
                },
            );

            info!("Created folder: {}", folder.name);
        }

        Event::FolderRenamed {
            folder_id, name, ..
        } => {
            if let Some(fs) = nb.folders.get_mut(folder_id) {
                let old_abs = sync_root.join(&nb.local_dir).join(&fs.local_path);
                let new_name = path_mapper::sanitize_filename(name);
                let new_abs = old_abs.with_file_name(&new_name);

                if old_abs.exists() && old_abs != new_abs {
                    std::fs::rename(&old_abs, &new_abs)?;
                    written_paths.push(old_abs);
                    written_paths.push(new_abs);
                }

                fs.name = name.clone();
                // Update local_path - replace the last component
                let parent = PathBuf::from(&fs.local_path)
                    .parent()
                    .map(|p| p.to_path_buf())
                    .unwrap_or_default();
                fs.local_path = if parent.as_os_str().is_empty() {
                    new_name
                } else {
                    format!("{}/{}", parent.display(), new_name)
                };

                info!("Renamed folder to: {}", name);
            }
        }

        Event::FolderMoved {
            folder_id,
            new_parent_folder_id,
            ..
        } => {
            // Get old path before modifying
            let old_local_path = nb
                .folders
                .get(folder_id)
                .map(|f| f.local_path.clone())
                .unwrap_or_default();
            let folder_name = nb
                .folders
                .get(folder_id)
                .map(|f| f.name.clone())
                .unwrap_or_default();

            let old_abs = sync_root.join(&nb.local_dir).join(&old_local_path);

            // Build new parent path
            let new_parent_path = nb
                .folders
                .get(new_parent_folder_id)
                .map(|f| f.local_path.clone())
                .unwrap_or_default();

            let new_rel = if new_parent_path.is_empty() {
                path_mapper::sanitize_filename(&folder_name)
            } else {
                format!(
                    "{}/{}",
                    new_parent_path,
                    path_mapper::sanitize_filename(&folder_name)
                )
            };

            let new_abs = sync_root.join(&nb.local_dir).join(&new_rel);

            if old_abs.exists() && old_abs != new_abs {
                if let Some(parent) = new_abs.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::rename(&old_abs, &new_abs)?;
                written_paths.push(old_abs);
                written_paths.push(new_abs);
            }

            if let Some(fs) = nb.folders.get_mut(folder_id) {
                fs.parent_folder_id = Some(*new_parent_folder_id);
                fs.local_path = new_rel;
            }

            info!("Moved folder {}", folder_name);
        }

        Event::FolderDeleted { folder_id, .. } => {
            if let Some(fs) = nb.folders.remove(folder_id) {
                let abs_path = sync_root.join(&nb.local_dir).join(&fs.local_path);
                if abs_path.exists() {
                    // Only remove if empty; otherwise leave it (notes should have been deleted first)
                    if std::fs::read_dir(&abs_path)
                        .map(|mut d| d.next().is_none())
                        .unwrap_or(true)
                    {
                        let _ = std::fs::remove_dir(&abs_path);
                        written_paths.push(abs_path);
                    } else {
                        warn!("Folder {} not empty, leaving on disk", fs.name);
                    }
                }
                info!("Deleted folder: {}", fs.name);
            }
        }

        Event::NotebookRenamed { title, .. } => {
            let old_dir = nb.local_dir.clone();
            let new_dir = path_mapper::sanitize_filename(title);
            let old_abs = sync_root.join(&old_dir);
            let new_abs = sync_root.join(&new_dir);

            if old_abs.exists() && old_abs != new_abs {
                std::fs::rename(&old_abs, &new_abs)?;
                written_paths.push(old_abs);
                written_paths.push(new_abs);
            }

            nb.title = title.clone();
            nb.local_dir = new_dir;

            info!("Renamed notebook to: {}", title);
        }

        // Events we don't need to handle for filesystem sync
        Event::NotebookCreated { .. }
        | Event::MemberJoined { .. }
        | Event::MemberLeft { .. } => {}
    }

    state.touch();
    state.save(sync_root)?;

    Ok(written_paths)
}

/// Generate a .conflict.md path from an original path
fn conflict_path(original: &Path) -> PathBuf {
    let stem = original
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    original.with_file_name(format!("{}.conflict.md", stem))
}

/// SHA-256 hash of content as hex string
pub fn content_hash(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

#[derive(Debug, thiserror::Error)]
pub enum SyncError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Urbit error: {0}")]
    Urbit(#[from] crate::urbit::client::UrbitError),
}
