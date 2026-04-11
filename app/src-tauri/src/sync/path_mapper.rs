use std::collections::HashMap;
use std::path::PathBuf;

use crate::urbit::types::{Folder, Note};

/// Sanitize a string for use as a filename.
/// Replaces filesystem-unsafe characters and trims edge cases.
pub fn sanitize_filename(name: &str) -> String {
    let mut s: String = name
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            _ => c,
        })
        .collect();

    // Trim leading/trailing whitespace and dots
    s = s.trim().trim_matches('.').to_string();

    // Ensure non-empty
    if s.is_empty() {
        s = "Untitled".to_string();
    }

    // Truncate to 200 chars for filesystem safety
    if s.len() > 200 {
        s.truncate(200);
    }

    s
}

/// Build the folder path chain for a given folder by walking parent_folder_id.
/// The root folder (name "/") is omitted — notes in it go directly in the notebook dir.
pub fn folder_path(folder_id: u64, folders: &HashMap<u64, Folder>) -> PathBuf {
    let mut parts: Vec<String> = Vec::new();
    let mut current_id = Some(folder_id);

    while let Some(fid) = current_id {
        if let Some(folder) = folders.get(&fid) {
            // Root folder (name "/") is the notebook root — don't include it as a directory
            if folder.name != "/" {
                parts.push(sanitize_filename(&folder.name));
            }
            current_id = folder.parent_folder_id;
        } else {
            break;
        }
    }

    parts.reverse();
    parts.iter().collect()
}

/// Compute the filesystem path for a note, relative to the sync root.
/// Result: {notebook_dir}/{folder_chain}/{note_title}.md
pub fn note_path(
    notebook_dir: &str,
    note: &Note,
    folders: &HashMap<u64, Folder>,
) -> PathBuf {
    let folder = folder_path(note.folder_id, folders);
    let filename = format!("{}.md", sanitize_filename(&note.title));

    let mut path = PathBuf::from(notebook_dir);
    if !folder.as_os_str().is_empty() {
        path.push(folder);
    }
    path.push(filename);
    path
}

/// Disambiguate duplicate filenames within the same directory.
/// Given a set of existing paths, returns a unique variant by appending " (N)".
pub fn disambiguate(desired: &str, existing: &[String]) -> String {
    if !existing.contains(&desired.to_string()) {
        return desired.to_string();
    }

    // Split off .md extension
    let (base, ext) = if let Some(b) = desired.strip_suffix(".md") {
        (b, ".md")
    } else {
        (desired, "")
    };

    let mut n = 2;
    loop {
        let candidate = format!("{} ({}){}", base, n, ext);
        if !existing.contains(&candidate) {
            return candidate;
        }
        n += 1;
    }
}

/// Build a folder ID → Folder lookup from a flat Vec
pub fn folder_map(folders: Vec<Folder>) -> HashMap<u64, Folder> {
    folders.into_iter().map(|f| (f.id, f)).collect()
}

/// Build a note ID → Note lookup from a flat Vec
pub fn note_map(notes: Vec<Note>) -> HashMap<u64, Note> {
    notes.into_iter().map(|n| (n.id, n)).collect()
}
