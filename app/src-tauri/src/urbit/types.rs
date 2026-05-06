use serde::{Deserialize, Serialize};

/// Notebook metadata from /v0/notebooks scry
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotebookEntry {
    pub host: String,
    pub flag_name: String,
    pub notebook: Notebook,
    #[serde(default)]
    pub visibility: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Notebook {
    pub id: u64,
    pub title: String,
    pub created_by: String,
    pub created_at: u64,
    pub updated_at: u64,
    pub updated_by: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Folder {
    pub id: u64,
    pub notebook_id: u64,
    pub name: String,
    pub parent_folder_id: Option<u64>,
    pub created_by: String,
    pub created_at: u64,
    pub updated_at: u64,
    pub updated_by: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: u64,
    pub notebook_id: u64,
    pub folder_id: u64,
    pub title: String,
    pub slug: Option<String>,
    pub body_md: String,
    pub created_by: String,
    pub created_at: u64,
    pub updated_by: String,
    pub updated_at: u64,
    pub revision: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NoteRevision {
    pub rev: u64,
    pub at: u64,
    pub author: String,
    pub title: String,
    pub body_md: String,
}

/// SSE response envelope from /v0/notes/<host>/<name>/stream
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", rename_all_fields = "camelCase")]
pub enum Response {
    Snapshot {
        host: String,
        flag_name: String,
        visibility: String,
    },
    Update {
        host: String,
        flag_name: String,
        time: u64,
        update: Event,
    },
}

/// Notebook-scoped update — the `update` field of Response::Update.
/// Mirrors `u-notebook` in sur/notes.hoon.
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", rename_all_fields = "camelCase")]
pub enum Event {
    NotebookCreated {
        notebook: Notebook,
        visibility: String,
    },
    NotebookUpdated {
        notebook: Notebook,
    },
    NotebookDeleted {},
    NotebookVisibilityChanged {
        visibility: String,
    },
    MemberJoined {
        who: String,
        role: String,
    },
    MemberLeft {
        who: String,
    },
    InviteReceived {
        from: String,
        title: String,
    },
    InviteRemoved {},
    FolderUpdate {
        folder_update: FolderEvent,
    },
    NoteUpdate {
        note_update: NoteEvent,
    },
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", rename_all_fields = "camelCase")]
pub enum FolderEvent {
    FolderCreated { id: u64, folder: Folder },
    FolderUpdated { id: u64, folder: Folder },
    FolderDeleted { id: u64 },
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "kebab-case", rename_all_fields = "camelCase")]
pub enum NoteEvent {
    NoteCreated { id: u64, note: Note },
    NoteUpdated { id: u64, note: Note },
    NoteDeleted { id: u64 },
    NotePublished { id: u64, html: String },
    NoteUnpublished { id: u64 },
    NoteHistoryArchived { id: u64, revision: NoteRevision },
}

/// Eyre channel message envelope (what SSE delivers)
#[derive(Debug, Clone, Deserialize)]
pub struct ChannelMessage {
    pub id: u64,
    pub response: Option<String>,
    pub json: Option<serde_json::Value>,
    pub err: Option<String>,
}
