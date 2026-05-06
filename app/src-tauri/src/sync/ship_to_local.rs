use std::collections::HashMap;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};
use tracing::{debug, info, warn};

use crate::urbit::client::UrbitClient;
use crate::urbit::types::{Event, Folder, FolderEvent, Note, NoteEvent};

use super::path_mapper;
use super::state::{FolderSync, NoteSync, NotebookSync, SyncState};

/// Perform a full initial sync for a notebook: scry everything, write to disk.
pub async fn initial_sync(
    client: &UrbitClient,
    flag: &str,
    notebook_id: u64,
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

/// Reconcile diffs between ship state and local filesystem on startup.
/// Handles: new notes on ship, deleted notes on ship, content changes both ways.
pub async fn reconcile(
    client: &UrbitClient,
    flag: &str,
    sync_root: &Path,
    state: &mut SyncState,
) -> Result<(), SyncError> {
    let nb = match state.notebooks.get(flag) {
        Some(nb) => nb,
        None => return Ok(()),
    };
    let notebook_dir = nb.local_dir.clone();

    // Scry current state from ship
    let ship_folders_vec = client.get_folders(flag).await?;
    let ship_notes_vec = client.get_notes(flag).await?;

    let ship_folders = path_mapper::folder_map(ship_folders_vec);
    let ship_notes: HashMap<u64, Note> =
        ship_notes_vec.into_iter().map(|n| (n.id, n)).collect();

    info!(
        "Reconcile {}: {} ship notes, {} local notes",
        flag,
        ship_notes.len(),
        nb.notes.len()
    );

    let mut changes = 0;

    // Collect local note IDs and paths before mutating state
    let local_note_ids: Vec<u64> = nb.notes.keys().cloned().collect();
    let local_notes_snapshot: HashMap<u64, (String, String)> = nb
        .notes
        .iter()
        .map(|(nid, ns)| (*nid, (ns.content_hash.clone(), ns.local_path.clone())))
        .collect();

    // Drop the immutable borrow of nb so we can mutate state below
    drop(nb);

    // 1. Notes on ship but not in local state → write to disk
    for (nid, ship_note) in &ship_notes {
        if !local_notes_snapshot.contains_key(nid) {
            let rel_path = path_mapper::note_path(&notebook_dir, ship_note, &ship_folders);
            let abs_path = sync_root.join(&rel_path);
            if let Some(parent) = abs_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::write(&abs_path, &ship_note.body_md)?;

            let rel_str = rel_path.to_string_lossy().to_string();
            let hash = content_hash(&ship_note.body_md);

            if let Some(nb) = state.notebooks.get_mut(flag) {
                nb.notes.insert(
                    *nid,
                    NoteSync {
                        note_id: *nid,
                        title: ship_note.title.clone(),
                        folder_id: ship_note.folder_id,
                        revision: ship_note.revision,
                        content_hash: hash,
                        local_path: rel_str,
                        last_synced_at: now(),
                    },
                );
            }
            info!("Reconcile: new ship note → local: {}", ship_note.title);
            changes += 1;
        }
    }

    // 2. Notes in local state but no longer on ship → delete local file
    for nid in &local_note_ids {
        if !ship_notes.contains_key(nid) {
            if let Some(nb) = state.notebooks.get_mut(flag) {
                if let Some(ns) = nb.notes.remove(nid) {
                    let abs_path = sync_root.join(&ns.local_path);
                    if abs_path.exists() {
                        std::fs::remove_file(&abs_path)?;
                        info!("Reconcile: note deleted on ship → removed local: {}", ns.title);
                        changes += 1;
                    }
                }
            }
        }
    }

    // 3. Notes that exist both places → check for content changes
    let mut updates: Vec<(u64, String)> = Vec::new();

    for (nid, (stored_hash, local_path)) in &local_notes_snapshot {
        if let Some(ship_note) = ship_notes.get(nid) {
            let ship_hash = content_hash(&ship_note.body_md);
            let abs_path = sync_root.join(local_path);

            if abs_path.exists() {
                let local_content = std::fs::read_to_string(&abs_path)?;
                let local_hash = content_hash(&local_content);

                if local_hash != *stored_hash && ship_hash == *stored_hash {
                    // Local changed, ship unchanged → will be pushed by FS watcher
                    info!("Reconcile: local change detected for {}", ship_note.title);
                } else if ship_hash != *stored_hash && local_hash == *stored_hash {
                    // Ship changed, local unchanged → pull from ship
                    std::fs::write(&abs_path, &ship_note.body_md)?;
                    updates.push((*nid, ship_hash));
                    info!("Reconcile: ship change → updated local: {}", ship_note.title);
                    changes += 1;
                } else if ship_hash != *stored_hash && local_hash != *stored_hash {
                    if ship_hash == local_hash {
                        // Both changed to same content
                        updates.push((*nid, ship_hash));
                    } else {
                        // Conflict
                        let conflict = conflict_path(&abs_path);
                        std::fs::write(&conflict, &local_content)?;
                        std::fs::write(&abs_path, &ship_note.body_md)?;
                        updates.push((*nid, ship_hash));
                        warn!("Reconcile: conflict for {} — local saved as .conflict.md", ship_note.title);
                        changes += 1;
                    }
                }
            } else {
                // Local file missing — rewrite from ship
                if let Some(parent) = abs_path.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&abs_path, &ship_note.body_md)?;
                updates.push((*nid, ship_hash));
                info!("Reconcile: restored missing local file: {}", ship_note.title);
                changes += 1;
            }
        }
    }

    // Apply hash/revision updates
    if let Some(nb) = state.notebooks.get_mut(flag) {
        for (nid, new_hash) in &updates {
            if let Some(ns) = nb.notes.get_mut(nid) {
                ns.content_hash = new_hash.clone();
                if let Some(ship_note) = ship_notes.get(nid) {
                    ns.revision = ship_note.revision;
                }
                ns.last_synced_at = now();
            }
        }

        // Update folder state too
        nb.folders.clear();
        for (fid, folder) in &ship_folders {
            let rel_path = path_mapper::folder_path(*fid, &ship_folders);
            let rel_str = rel_path.to_string_lossy().to_string();

            if !rel_str.is_empty() {
                let abs_path = sync_root.join(&notebook_dir).join(&rel_path);
                let _ = std::fs::create_dir_all(&abs_path);
            }

            nb.folders.insert(
                *fid,
                FolderSync {
                    folder_id: *fid,
                    name: folder.name.clone(),
                    parent_folder_id: folder.parent_folder_id,
                    local_path: rel_str,
                },
            );
        }
    }

    state.touch();
    state.save(sync_root)?;

    info!("Reconcile complete for {}: {} changes", flag, changes);
    Ok(())
}

/// Synthesize a Folder lookup table from the notebook's stored folder syncs,
/// so path_mapper can resolve paths from folder IDs.
fn synth_folders(nb: &NotebookSync) -> HashMap<u64, Folder> {
    nb.folders
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
                    updated_by: String::new(),
                },
            )
        })
        .collect()
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
        Event::NoteUpdate { note_update } => match note_update {
            NoteEvent::NoteCreated { note, .. } => {
                let folders = synth_folders(nb);
                let rel_path = path_mapper::note_path(&nb.local_dir, note, &folders);
                let abs_path = sync_root.join(&rel_path);

                if let Some(parent) = abs_path.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&abs_path, &note.body_md)?;
                written_paths.push(abs_path);

                let hash = content_hash(&note.body_md);
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
                        last_synced_at: now(),
                    },
                );
                info!("Created note: {}", note.title);
            }

            NoteEvent::NoteUpdated { note, .. } => {
                let folders = synth_folders(nb);
                let new_rel = path_mapper::note_path(&nb.local_dir, note, &folders);
                let new_abs = sync_root.join(&new_rel);
                let new_hash = content_hash(&note.body_md);

                let existing = nb.notes.get(&note.id).cloned();
                let old_abs = existing
                    .as_ref()
                    .map(|ns| sync_root.join(&ns.local_path));
                let old_hash = existing.as_ref().map(|ns| ns.content_hash.clone());

                // Move the file if title or folder changed
                if let Some(ref old_abs) = old_abs {
                    if old_abs != &new_abs && old_abs.exists() {
                        if let Some(parent) = new_abs.parent() {
                            std::fs::create_dir_all(parent)?;
                        }
                        std::fs::rename(old_abs, &new_abs)?;
                        written_paths.push(old_abs.clone());
                        written_paths.push(new_abs.clone());
                    }
                }

                // Conflict-detect + write the new body
                let body_changed = old_hash.as_deref() != Some(new_hash.as_str());
                if body_changed && new_abs.exists() {
                    let local_content = std::fs::read_to_string(&new_abs)?;
                    let local_hash = content_hash(&local_content);
                    if Some(local_hash.as_str()) != old_hash.as_deref()
                        && local_hash != new_hash
                    {
                        let conflict = conflict_path(&new_abs);
                        std::fs::write(&conflict, &local_content)?;
                        written_paths.push(conflict);
                        warn!(
                            "Conflict detected for {}, saved local as .conflict.md",
                            note.title
                        );
                    }
                }
                if let Some(parent) = new_abs.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                std::fs::write(&new_abs, &note.body_md)?;
                written_paths.push(new_abs.clone());

                nb.notes.insert(
                    note.id,
                    NoteSync {
                        note_id: note.id,
                        title: note.title.clone(),
                        folder_id: note.folder_id,
                        revision: note.revision,
                        content_hash: new_hash,
                        local_path: new_rel.to_string_lossy().to_string(),
                        last_synced_at: now(),
                    },
                );

                debug!("Updated note: {} (rev {})", note.title, note.revision);
            }

            NoteEvent::NoteDeleted { id } => {
                if let Some(ns) = nb.notes.remove(id) {
                    let abs_path = sync_root.join(&ns.local_path);
                    if abs_path.exists() {
                        std::fs::remove_file(&abs_path)?;
                        written_paths.push(abs_path);
                    }
                    info!("Deleted note: {}", ns.title);
                }
            }

            // Publish/unpublish/history don't affect filesystem state
            NoteEvent::NotePublished { .. }
            | NoteEvent::NoteUnpublished { .. }
            | NoteEvent::NoteHistoryArchived { .. } => {}
        },

        Event::FolderUpdate { folder_update } => match folder_update {
            FolderEvent::FolderCreated { folder, .. } => {
                let mut all_folders = synth_folders(nb);
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

            FolderEvent::FolderUpdated { folder, .. } => {
                let mut all_folders = synth_folders(nb);
                all_folders.insert(folder.id, folder.clone());

                let new_rel = path_mapper::folder_path(folder.id, &all_folders);
                let new_rel_str = new_rel.to_string_lossy().to_string();
                let new_abs = sync_root.join(&nb.local_dir).join(&new_rel);

                let old_local_path = nb
                    .folders
                    .get(&folder.id)
                    .map(|f| f.local_path.clone())
                    .unwrap_or_default();
                let old_abs = sync_root.join(&nb.local_dir).join(&old_local_path);

                if old_abs != new_abs && old_abs.exists() {
                    if let Some(parent) = new_abs.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::rename(&old_abs, &new_abs)?;
                    written_paths.push(old_abs);
                    written_paths.push(new_abs);
                }

                nb.folders.insert(
                    folder.id,
                    FolderSync {
                        folder_id: folder.id,
                        name: folder.name.clone(),
                        parent_folder_id: folder.parent_folder_id,
                        local_path: new_rel_str,
                    },
                );

                info!("Updated folder: {}", folder.name);
            }

            FolderEvent::FolderDeleted { id } => {
                if let Some(fs) = nb.folders.remove(id) {
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
        },

        Event::NotebookUpdated { notebook } => {
            if nb.title != notebook.title {
                let old_dir = nb.local_dir.clone();
                let new_dir = path_mapper::sanitize_filename(&notebook.title);
                let old_abs = sync_root.join(&old_dir);
                let new_abs = sync_root.join(&new_dir);

                if old_abs.exists() && old_abs != new_abs {
                    std::fs::rename(&old_abs, &new_abs)?;
                    written_paths.push(old_abs);
                    written_paths.push(new_abs);
                }

                nb.title = notebook.title.clone();
                nb.local_dir = new_dir;
                info!("Renamed notebook to: {}", notebook.title);
            }
        }

        // Events that don't affect filesystem state
        Event::NotebookCreated { .. }
        | Event::NotebookDeleted {}
        | Event::NotebookVisibilityChanged { .. }
        | Event::MemberJoined { .. }
        | Event::MemberLeft { .. }
        | Event::InviteReceived { .. }
        | Event::InviteRemoved {} => {}
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
