use std::path::{Path, PathBuf};

use tracing::info;

/// List all .conflict.md files under the sync root
pub fn list_conflicts(sync_root: &Path) -> Vec<PathBuf> {
    let mut conflicts = Vec::new();
    collect_conflicts(sync_root, &mut conflicts);
    conflicts
}

fn collect_conflicts(dir: &Path, out: &mut Vec<PathBuf>) {
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            if path
                .file_name()
                .map(|n| !n.to_string_lossy().starts_with('.'))
                .unwrap_or(false)
            {
                collect_conflicts(&path, out);
            }
        } else if path
            .file_name()
            .map(|n| n.to_string_lossy().ends_with(".conflict.md"))
            .unwrap_or(false)
        {
            out.push(path);
        }
    }
}

/// Resolve a conflict by keeping one version.
/// If `keep_conflict` is true, the .conflict.md version replaces the original.
/// If false, the .conflict.md file is simply deleted (keeping the ship version).
pub fn resolve_conflict(conflict_path: &Path, keep_conflict: bool) -> Result<(), std::io::Error> {
    if keep_conflict {
        // Replace the original with the conflict version
        let original = original_path_from_conflict(conflict_path);
        std::fs::copy(conflict_path, &original)?;
        info!(
            "Resolved conflict: kept local version for {}",
            original.display()
        );
    }

    std::fs::remove_file(conflict_path)?;
    info!("Removed conflict file: {}", conflict_path.display());
    Ok(())
}

/// Derive the original file path from a .conflict.md path
/// e.g. "Hello.conflict.md" → "Hello.md"
fn original_path_from_conflict(conflict: &Path) -> PathBuf {
    let name = conflict
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();

    if let Some(base) = name.strip_suffix(".conflict.md") {
        conflict.with_file_name(format!("{}.md", base))
    } else {
        conflict.with_extension("")
    }
}
