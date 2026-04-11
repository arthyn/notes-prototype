use serde::{Deserialize, Serialize};

/// Notebook metadata from /notebooks scry
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotebookEntry {
    pub host: String,
    pub flag_name: String,
    pub notebook: Notebook,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Notebook {
    pub id: u64,
    pub title: String,
    pub created_by: String,
    pub created_at: u64,
    pub updated_at: u64,
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

/// SSE response envelope from /stream subscription
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "response")]
pub enum Response {
    #[serde(rename = "snapshot")]
    Snapshot { host: String, flag_name: String },
    #[serde(rename = "update")]
    Update { update: Event },
}

/// Note events from the update stream (enriched JSON)
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type")]
pub enum Event {
    #[serde(rename = "notebook-created")]
    NotebookCreated {
        notebook_id: u64,
        notebook: Notebook,
        actor: String,
    },
    #[serde(rename = "notebook-renamed")]
    NotebookRenamed {
        notebook_id: u64,
        title: String,
        actor: String,
    },
    #[serde(rename = "member-joined")]
    MemberJoined {
        notebook_id: u64,
        who: String,
        actor: String,
    },
    #[serde(rename = "member-left")]
    MemberLeft {
        notebook_id: u64,
        who: String,
        actor: String,
    },
    #[serde(rename = "folder-created")]
    FolderCreated {
        folder_id: u64,
        notebook_id: u64,
        folder: Folder,
        actor: String,
    },
    #[serde(rename = "folder-renamed")]
    FolderRenamed {
        folder_id: u64,
        notebook_id: u64,
        name: String,
        actor: String,
    },
    #[serde(rename = "folder-moved")]
    FolderMoved {
        folder_id: u64,
        notebook_id: u64,
        new_parent_folder_id: u64,
        actor: String,
    },
    #[serde(rename = "folder-deleted")]
    FolderDeleted {
        folder_id: u64,
        notebook_id: u64,
        actor: String,
    },
    #[serde(rename = "note-created")]
    NoteCreated {
        note_id: u64,
        notebook_id: u64,
        note: Note,
        actor: String,
    },
    #[serde(rename = "note-renamed")]
    NoteRenamed {
        note_id: u64,
        notebook_id: u64,
        title: String,
        actor: String,
    },
    #[serde(rename = "note-moved")]
    NoteMoved {
        note_id: u64,
        notebook_id: u64,
        folder_id: u64,
        actor: String,
    },
    #[serde(rename = "note-deleted")]
    NoteDeleted {
        note_id: u64,
        notebook_id: u64,
        actor: String,
    },
    #[serde(rename = "note-updated")]
    NoteUpdated {
        note_id: u64,
        notebook_id: u64,
        revision: u64,
        note: Note,
        actor: String,
    },
}

/// Eyre channel message envelope (what SSE delivers)
#[derive(Debug, Clone, Deserialize)]
pub struct ChannelMessage {
    pub id: u64,
    pub response: Option<String>,
    pub json: Option<serde_json::Value>,
    pub err: Option<String>,
}

/// Action payloads for pokes to the notes agent
#[derive(Debug, Clone, Serialize)]
#[serde(untagged)]
pub enum Action {
    CreateNotebook(CreateNotebook),
    CreateFolder(CreateFolder),
    RenameFolder(RenameFolder),
    DeleteFolder(DeleteFolder),
    CreateNote(CreateNote),
    RenameNote(RenameNote),
    MoveNote(MoveNote),
    DeleteNote(DeleteNote),
    UpdateNote(UpdateNote),
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateNotebook {
    #[serde(rename = "create-notebook")]
    pub create_notebook: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateFolder {
    #[serde(rename = "create-folder")]
    pub create_folder: CreateFolderInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateFolderInner {
    pub notebook_id: u64,
    pub parent_folder_id: Option<u64>,
    pub name: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RenameFolder {
    #[serde(rename = "rename-folder")]
    pub rename_folder: RenameFolderInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenameFolderInner {
    pub notebook_id: u64,
    pub folder_id: u64,
    pub name: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct DeleteFolder {
    #[serde(rename = "delete-folder")]
    pub delete_folder: DeleteFolderInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteFolderInner {
    pub notebook_id: u64,
    pub folder_id: u64,
    pub recursive: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateNote {
    #[serde(rename = "create-note")]
    pub create_note: CreateNoteInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateNoteInner {
    pub notebook_id: u64,
    pub folder_id: u64,
    pub title: String,
    pub body_md: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RenameNote {
    #[serde(rename = "rename-note")]
    pub rename_note: RenameNoteInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RenameNoteInner {
    pub notebook_id: u64,
    pub note_id: u64,
    pub title: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct MoveNote {
    #[serde(rename = "move-note")]
    pub move_note: MoveNoteInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MoveNoteInner {
    pub note_id: u64,
    pub notebook_id: u64,
    pub folder_id: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct DeleteNote {
    #[serde(rename = "delete-note")]
    pub delete_note: DeleteNoteInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteNoteInner {
    pub note_id: u64,
    pub notebook_id: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateNote {
    #[serde(rename = "update-note")]
    pub update_note: UpdateNoteInner,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateNoteInner {
    pub notebook_id: u64,
    pub note_id: u64,
    pub body_md: String,
    pub expected_revision: u64,
}
