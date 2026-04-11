use std::collections::HashMap;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

/// Persistent sync state stored in .notes-sync/state.json
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SyncState {
    pub version: u32,
    pub ship: String,
    pub last_sync: Option<u64>,
    pub notebooks: HashMap<String, NotebookSync>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotebookSync {
    pub notebook_id: u64,
    pub title: String,
    pub local_dir: String,
    pub folders: HashMap<u64, FolderSync>,
    pub notes: HashMap<u64, NoteSync>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FolderSync {
    pub folder_id: u64,
    pub name: String,
    pub parent_folder_id: Option<u64>,
    pub local_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NoteSync {
    pub note_id: u64,
    pub title: String,
    pub folder_id: u64,
    pub revision: u64,
    pub content_hash: String,
    pub local_path: String,
    pub last_synced_at: u64,
}

impl SyncState {
    pub fn new(ship: &str) -> Self {
        Self {
            version: 1,
            ship: ship.to_string(),
            last_sync: None,
            notebooks: HashMap::new(),
        }
    }

    /// Load state from the .notes-sync directory
    pub fn load(sync_root: &Path) -> Result<Self, std::io::Error> {
        let state_path = sync_root.join(".notes-sync").join("state.json");
        if !state_path.exists() {
            return Ok(Self::default());
        }
        let data = std::fs::read_to_string(&state_path)?;
        let state: Self = serde_json::from_str(&data)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        Ok(state)
    }

    /// Persist state to the .notes-sync directory
    pub fn save(&self, sync_root: &Path) -> Result<(), std::io::Error> {
        let sync_dir = sync_root.join(".notes-sync");
        std::fs::create_dir_all(&sync_dir)?;
        let state_path = sync_dir.join("state.json");
        let data = serde_json::to_string_pretty(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
        // Atomic write: write to temp file then rename
        let tmp_path = sync_dir.join("state.json.tmp");
        std::fs::write(&tmp_path, &data)?;
        std::fs::rename(&tmp_path, &state_path)?;
        Ok(())
    }

    /// Look up a note by its local filesystem path (relative to sync root).
    /// Returns (flag, notebook_id, NoteSync).
    pub fn find_note_by_path(&self, rel_path: &str) -> Option<(&str, u64, &NoteSync)> {
        for (flag, nb) in &self.notebooks {
            for note in nb.notes.values() {
                if note.local_path == rel_path {
                    return Some((flag, nb.notebook_id, note));
                }
            }
        }
        None
    }

    /// Look up a folder by its local filesystem path (relative to sync root)
    pub fn find_folder_by_path(&self, rel_path: &str) -> Option<(&str, &FolderSync)> {
        for (flag, nb) in &self.notebooks {
            for folder in nb.folders.values() {
                if folder.local_path == rel_path {
                    return Some((flag, folder));
                }
            }
        }
        None
    }

    /// Find which notebook a path belongs to based on the top-level directory
    pub fn find_notebook_by_dir(&self, dir_name: &str) -> Option<(&str, &NotebookSync)> {
        for (flag, nb) in &self.notebooks {
            if nb.local_dir == dir_name {
                return Some((flag, nb));
            }
        }
        None
    }

    /// Update last sync timestamp to now
    pub fn touch(&mut self) {
        self.last_sync = Some(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        );
    }
}
