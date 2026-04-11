use serde::{Deserialize, Serialize};
use tauri::State;

use crate::AppState;

#[derive(Debug, Clone, Serialize)]
pub struct SyncStatus {
    pub connected: bool,
    pub ship: Option<String>,
    pub url: Option<String>,
    pub last_sync: Option<u64>,
    pub conflicts: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub ship_url: String,
    pub access_code: String,
    pub sync_dir: String,
    pub selected_notebooks: Vec<String>,
    pub sync_on_launch: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            ship_url: String::new(),
            access_code: String::new(),
            sync_dir: dirs_next::home_dir()
                .map(|h| h.join("Notes").to_string_lossy().to_string())
                .unwrap_or_default(),
            selected_notebooks: Vec::new(),
            sync_on_launch: true,
        }
    }
}

impl AppConfig {
    /// Path to the persisted config file
    fn config_path() -> std::path::PathBuf {
        let dir = dirs_next::config_dir()
            .unwrap_or_else(|| dirs_next::home_dir().unwrap_or_default())
            .join("notes-sync");
        dir.join("config.json")
    }

    /// Load config from disk, falling back to defaults
    pub fn load() -> Self {
        let path = Self::config_path();
        if path.exists() {
            if let Ok(data) = std::fs::read_to_string(&path) {
                if let Ok(config) = serde_json::from_str(&data) {
                    return config;
                }
            }
        }
        Self::default()
    }

    /// Persist config to disk
    pub fn save(&self) {
        let path = Self::config_path();
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        if let Ok(data) = serde_json::to_string_pretty(self) {
            let _ = std::fs::write(&path, data);
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct NotebookInfo {
    pub flag: String,
    pub title: String,
    pub host: String,
}

#[tauri::command]
pub async fn get_status(state: State<'_, AppState>) -> Result<SyncStatus, String> {
    let engine = state.engine.read().await;
    let last_sync = engine.last_sync_time().await;
    Ok(SyncStatus {
        connected: engine.is_connected(),
        ship: engine.ship_name().map(|s| s.to_string()),
        url: engine.ship_url().map(|s| s.to_string()),
        last_sync,
        conflicts: engine.conflict_count(),
    })
}

#[tauri::command]
pub async fn get_config(state: State<'_, AppState>) -> Result<AppConfig, String> {
    let engine = state.engine.read().await;
    Ok(engine.config().clone())
}

#[tauri::command]
pub async fn save_config(config: AppConfig, state: State<'_, AppState>) -> Result<(), String> {
    config.save();
    let mut engine = state.engine.write().await;
    engine.set_config(config);
    Ok(())
}

#[tauri::command]
pub async fn connect(state: State<'_, AppState>) -> Result<(), String> {
    let mut engine = state.engine.write().await;
    engine.connect().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn disconnect(state: State<'_, AppState>) -> Result<(), String> {
    let mut engine = state.engine.write().await;
    engine.disconnect().await;
    Ok(())
}

#[tauri::command]
pub async fn get_notebooks(state: State<'_, AppState>) -> Result<Vec<NotebookInfo>, String> {
    let engine = state.engine.read().await;
    engine.list_notebooks().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn select_notebooks(
    flags: Vec<String>,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let mut engine = state.engine.write().await;
    engine
        .select_notebooks(flags)
        .await
        .map_err(|e| e.to_string())
}
