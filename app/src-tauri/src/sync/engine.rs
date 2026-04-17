use std::path::PathBuf;
use std::sync::Arc;

use tokio::sync::{mpsc, RwLock as TokioRwLock};
use tracing::{error, info, warn};

use crate::commands::{AppConfig, NotebookInfo};
use crate::fs::watcher::FsWatcher;
use crate::urbit::channel::{EyreChannel, SseMessage};
use crate::urbit::client::{UrbitClient, UrbitError};
use crate::urbit::types::{Event, Response};

use super::conflict;
use super::local_to_ship::{self, FsChange};
use super::ship_to_local;
use super::state::SyncState;

/// The sync engine coordinates bidirectional sync between ship and filesystem.
pub struct SyncEngine {
    config: AppConfig,
    client: Option<UrbitClient>,
    channel: Option<EyreChannel>,
    state: Arc<TokioRwLock<SyncState>>,
    watcher: FsWatcher,
    connected: bool,
    sse_task: Option<tokio::task::JoinHandle<()>>,
    fs_task: Option<tokio::task::JoinHandle<()>>,
    activity_tx: mpsc::Sender<String>,
    activity_rx: Option<mpsc::Receiver<String>>,
    pub activity_log: Arc<std::sync::Mutex<Vec<String>>>,
}

impl SyncEngine {
    pub fn new() -> Self {
        let (activity_tx, activity_rx) = mpsc::channel::<String>(64);
        Self {
            config: AppConfig::load(),
            client: None,
            channel: None,
            state: Arc::new(TokioRwLock::new(SyncState::default())),
            watcher: FsWatcher::new(),
            connected: false,
            sse_task: None,
            fs_task: None,
            activity_tx,
            activity_rx: Some(activity_rx),
            activity_log: Arc::new(std::sync::Mutex::new(Vec::new())),
        }
    }

    /// Take the activity receiver (call once to set up the event relay)
    pub fn take_activity_rx(&mut self) -> Option<mpsc::Receiver<String>> {
        self.activity_rx.take()
    }

    pub fn is_connected(&self) -> bool {
        self.connected
    }

    pub fn ship_name(&self) -> Option<&str> {
        self.client.as_ref().and_then(|c| c.ship_name())
    }

    pub fn ship_url(&self) -> Option<&str> {
        self.client.as_ref().map(|c| c.base_url.as_str())
    }

    pub async fn last_sync_time(&self) -> Option<u64> {
        self.state.read().await.last_sync
    }

    pub fn conflict_count(&self) -> u32 {
        let sync_root = PathBuf::from(&self.config.sync_dir);
        conflict::list_conflicts(&sync_root).len() as u32
    }

    pub fn config(&self) -> &AppConfig {
        &self.config
    }

    pub fn set_config(&mut self, config: AppConfig) {
        self.config = config;
    }

    /// Connect to the ship: authenticate, load state, subscribe to notebooks
    pub async fn connect(&mut self) -> Result<(), EngineError> {
        if self.config.ship_url.is_empty() {
            return Err(EngineError::Config("Ship URL is required".into()));
        }

        info!("Connecting to {}", self.config.ship_url);

        // Create HTTP client and authenticate
        let mut client = UrbitClient::new(&self.config.ship_url);
        client.login(&self.config.access_code).await?;

        let ship = client
            .ship_name()
            .ok_or_else(|| EngineError::Config("Failed to get ship name".into()))?
            .to_string();

        info!("Authenticated as {}", ship);

        // Load existing sync state or create new
        let sync_root = PathBuf::from(&self.config.sync_dir);
        std::fs::create_dir_all(&sync_root)?;
        info!("Loading sync state from {}", sync_root.display());
        let mut loaded_state = SyncState::load(&sync_root).unwrap_or_else(|_| SyncState::new(&ship));
        loaded_state.ship = ship.clone();
        info!("State has {} notebooks", loaded_state.notebooks.len());
        self.state = Arc::new(TokioRwLock::new(loaded_state));

        // Create eyre channel
        let channel = EyreChannel::new(&self.config.ship_url, client.http_client().clone());

        self.client = Some(client);
        self.channel = Some(channel);
        self.connected = true;

        // Do initial sync for selected notebooks, then start the sync loop
        info!("Selected notebooks: {:?}", self.config.selected_notebooks);
        if !self.config.selected_notebooks.is_empty() {
            info!("Starting sync_selected_notebooks...");
            self.sync_selected_notebooks().await?;
            info!("Starting start_sync...");
            self.start_sync().await?;
            info!("Sync fully started");
        } else {
            info!("No notebooks selected, skipping sync");
        }

        Ok(())
    }

    /// Run the initial sync and start background SSE + FS watcher loops.
    /// Call this after connect() and select_notebooks().
    pub async fn start_sync(&mut self) -> Result<(), EngineError> {
        let sync_root = PathBuf::from(&self.config.sync_dir);

        let ship = self
            .client
            .as_ref()
            .and_then(|c| c.ship_name())
            .ok_or(EngineError::NotConnected)?
            .to_string();

        let http_client = self.client.as_ref().unwrap().http_client().clone();

        // Create a dedicated channel for SSE subscriptions
        let mut sse_channel = EyreChannel::new(&self.config.ship_url, http_client.clone());
        for flag in &self.config.selected_notebooks {
            let path = format!("/v0/notes/{}/stream", flag);
            sse_channel.subscribe(&ship, &path).await.map_err(|e| {
                EngineError::Channel(format!("Failed to subscribe to {}: {}", flag, e))
            })?;
        }

        let (sse_tx, sse_rx) = mpsc::channel::<SseMessage>(256);
        let sse_handle = tokio::spawn(async move {
            if let Err(e) = sse_channel.start_sse(sse_tx).await {
                error!("SSE task error: {}", e);
            }
        });
        self.sse_task = Some(sse_handle);

        // Start FS watcher
        let (fs_tx, fs_rx) = mpsc::channel::<FsChange>(256);
        info!("Starting FS watcher on {}", sync_root.display());
        self.watcher.start(sync_root.clone(), fs_tx)?;
        info!("FS watcher started");

        // Start the main sync processing loop in the background
        let state = self.state.clone();
        let ship_for_loop = ship.clone();
        let url_for_loop = self.config.ship_url.clone();
        let activity_tx = self.activity_tx.clone();

        let fs_handle = tokio::spawn(async move {
            run_sync_loop(
                sse_rx,
                fs_rx,
                state,
                &ship_for_loop,
                &url_for_loop,
                http_client,
                sync_root,
                activity_tx,
            )
            .await;
        });
        self.fs_task = Some(fs_handle);

        let _ = self.activity_tx.send("Sync started".to_string()).await;
        info!("Sync started");
        Ok(())
    }

    async fn sync_selected_notebooks(&mut self) -> Result<(), EngineError> {
        let client = self.client.as_ref().ok_or(EngineError::NotConnected)?;
        let sync_root = PathBuf::from(&self.config.sync_dir);

        let notebooks = client.get_notebooks().await?;

        for flag in &self.config.selected_notebooks {
            // Find the notebook metadata
            let nb_entry = notebooks.iter().find(|nb| {
                let entry_flag = format!("{}/{}", nb.host, nb.flag_name);
                entry_flag == *flag
            });

            if let Some(entry) = nb_entry {
                let already_synced = {
                    let state = self.state.read().await;
                    state.notebooks.contains_key(flag)
                };

                if !already_synced {
                    // First time — full initial sync
                    let mut state = self.state.write().await;
                    ship_to_local::initial_sync(
                        client,
                        flag,
                        &entry.notebook.title,
                        &sync_root,
                        &mut state,
                    )
                    .await?;
                } else {
                    // Already synced — reconcile diffs
                    info!("Reconciling diffs for notebook {}", flag);
                    let mut state = self.state.write().await;
                    ship_to_local::reconcile(
                        client,
                        flag,
                        &sync_root,
                        &mut state,
                    )
                    .await?;
                }
            } else {
                warn!("Notebook {} not found on ship, skipping", flag);
            }
        }

        Ok(())
    }

    pub async fn disconnect(&mut self) {
        // Stop FS watcher
        self.watcher.stop();

        // Abort background tasks
        if let Some(handle) = self.sse_task.take() {
            handle.abort();
        }
        if let Some(handle) = self.fs_task.take() {
            handle.abort();
        }

        // Delete the eyre channel
        if let Some(ref mut channel) = self.channel {
            let _ = channel.delete().await;
        }

        self.client = None;
        self.channel = None;
        self.connected = false;
        info!("Disconnected");
    }

    pub async fn list_notebooks(&self) -> Result<Vec<NotebookInfo>, UrbitError> {
        let client = self.client.as_ref().ok_or(UrbitError::NotConnected)?;
        let entries = client.get_notebooks().await?;
        Ok(entries
            .into_iter()
            .map(|e| NotebookInfo {
                flag: format!("{}/{}", e.host, e.flag_name),
                title: e.notebook.title,
                host: e.host,
            })
            .collect())
    }

    pub async fn select_notebooks(&mut self, flags: Vec<String>) -> Result<(), EngineError> {
        self.config.selected_notebooks = flags;
        self.config.save();

        if self.connected && self.fs_task.is_none() {
            self.sync_selected_notebooks().await?;
            self.start_sync().await?;
        }

        Ok(())
    }
}

/// Main sync loop: processes SSE events and FS changes concurrently.
async fn run_sync_loop(
    mut sse_rx: mpsc::Receiver<SseMessage>,
    mut fs_rx: mpsc::Receiver<FsChange>,
    state: Arc<TokioRwLock<SyncState>>,
    ship: &str,
    base_url: &str,
    http_client: reqwest::Client,
    sync_root: PathBuf,
    activity: mpsc::Sender<String>,
) {
    // Create a dedicated channel for pokes from the FS watcher side
    let mut poke_channel = EyreChannel::new(base_url, http_client.clone());
    let scry_client = UrbitClient::from_existing(base_url, http_client);

    // Track paths we've recently poked to avoid duplicate creates from
    // multiple macOS FS events per save
    let mut recently_poked: std::collections::HashMap<PathBuf, std::time::Instant> =
        std::collections::HashMap::new();

    info!("Sync loop running, waiting for SSE events and FS changes...");

    let mut sse_alive = true;

    loop {
        tokio::select! {
            // Handle SSE events from ship (only if still connected)
            msg = sse_rx.recv(), if sse_alive => {
                match msg {
                    Some(SseMessage::Response(Response::Snapshot { host, flag_name })) => {
                        info!("Received snapshot for {}/{}", host, flag_name);
                        let _ = activity.send(format!("Connected to {}/{}", host, flag_name)).await;
                    }
                    Some(SseMessage::Response(Response::Update { update })) => {
                        let event_desc = describe_event(&update);
                        let notebook_id = event_notebook_id(&update);
                        let flag = {
                            let s = state.read().await;
                            s.notebooks.iter()
                                .find(|(_, nb)| nb.notebook_id == notebook_id)
                                .map(|(f, _)| f.clone())
                        };

                        if let Some(flag) = flag {
                            let mut s = state.write().await;
                            match ship_to_local::apply_event(&update, &flag, &sync_root, &mut s) {
                                Ok(written_paths) => {
                                    if !written_paths.is_empty() {
                                        let _ = activity.send(format!("\u{2193} {}", event_desc)).await;
                                    }
                                }
                                Err(e) => {
                                    error!("Failed to apply ship event: {}", e);
                                    let _ = activity.send(format!("Error: {}", e)).await;
                                }
                            }
                        } else {
                            warn!("SSE event for unknown notebook_id {}", notebook_id);
                        }
                    }
                    Some(SseMessage::Error(err)) => {
                        warn!("SSE error: {}", err);
                    }
                    Some(SseMessage::Disconnected) | None => {
                        warn!("SSE disconnected — local->ship sync continues, ship->local paused");
                        sse_alive = false;
                    }
                }
            }

            // Handle FS events from local watcher (always active)
            Some(change) = fs_rx.recv() => {
                // Deduplicate: skip if we poked this path in the last 2 seconds
                let path = match &change {
                    FsChange::FileModified(p) | FsChange::FileCreated(p) |
                    FsChange::FileDeleted(p) | FsChange::DirCreated(p) |
                    FsChange::DirDeleted(p) => p.clone(),
                    FsChange::FileRenamed { to, .. } | FsChange::DirRenamed { to, .. } => to.clone(),
                };
                let now = std::time::Instant::now();
                // Clean expired entries
                recently_poked.retain(|_, t| now.duration_since(*t) < std::time::Duration::from_secs(2));
                if let Some(last) = recently_poked.get(&path) {
                    if now.duration_since(*last) < std::time::Duration::from_secs(2) {
                        debug!("Skipping duplicate FS event for {:?}", path);
                        continue;
                    }
                }
                recently_poked.insert(path, now);

                let filename = match &change {
                    FsChange::FileModified(p) | FsChange::FileCreated(p) |
                    FsChange::FileDeleted(p) => p.file_name().map(|f| f.to_string_lossy().to_string()),
                    FsChange::FileRenamed { to, .. } => to.file_name().map(|f| f.to_string_lossy().to_string()),
                    _ => None,
                };

                let mut s = state.write().await;
                match local_to_ship::handle_fs_change(
                    &change,
                    &sync_root,
                    &mut s,
                    &mut poke_channel,
                    &scry_client,
                    ship,
                ).await {
                    Ok(_suppress) => {
                        if let Some(name) = filename {
                            let verb = match &change {
                                FsChange::FileModified(_) | FsChange::FileCreated(_) => "Updated",
                                FsChange::FileDeleted(_) => "Deleted",
                                FsChange::FileRenamed { .. } => "Renamed",
                                _ => "Synced",
                            };
                            let _ = activity.send(format!("\u{2191} {} {}", verb, name)).await;
                        }
                    }
                    Err(e) => {
                        error!("Failed to push local change to ship: {}", e);
                        let _ = activity.send(format!("Error: {}", e)).await;
                    }
                }
            }

            // Only exit if FS watcher also dies
            else => {
                warn!("All channels closed, sync loop exiting");
                break;
            }
        }
    }

    info!("Sync loop exited");
}

/// Extract the notebook_id from an event
fn event_notebook_id(event: &Event) -> u64 {
    match event {
        Event::NotebookCreated { notebook, .. } => notebook.id,
        Event::NotebookRenamed { notebook_id, .. } => *notebook_id,
        Event::MemberJoined { notebook_id, .. } => *notebook_id,
        Event::MemberLeft { notebook_id, .. } => *notebook_id,
        Event::FolderCreated { notebook_id, .. } => *notebook_id,
        Event::FolderRenamed { notebook_id, .. } => *notebook_id,
        Event::FolderMoved { notebook_id, .. } => *notebook_id,
        Event::FolderDeleted { notebook_id, .. } => *notebook_id,
        Event::NoteCreated { notebook_id, .. } => *notebook_id,
        Event::NoteRenamed { notebook_id, .. } => *notebook_id,
        Event::NoteMoved { notebook_id, .. } => *notebook_id,
        Event::NoteDeleted { notebook_id, .. } => *notebook_id,
        Event::NoteUpdated { notebook_id, .. } => *notebook_id,
    }
}

/// Human-readable description of an SSE event
fn describe_event(event: &Event) -> String {
    match event {
        Event::NoteCreated { note, .. } => format!("Created {}", note.title),
        Event::NoteUpdated { note, .. } => format!("Updated {}", note.title),
        Event::NoteRenamed { title, .. } => format!("Renamed to {}", title),
        Event::NoteDeleted { .. } => "Deleted note".to_string(),
        Event::NoteMoved { .. } => "Moved note".to_string(),
        Event::FolderCreated { folder, .. } => format!("Created folder {}", folder.name),
        Event::FolderRenamed { name, .. } => format!("Renamed folder to {}", name),
        Event::FolderDeleted { .. } => "Deleted folder".to_string(),
        Event::FolderMoved { .. } => "Moved folder".to_string(),
        Event::NotebookCreated { notebook, .. } => format!("Created notebook {}", notebook.title),
        Event::NotebookRenamed { title, .. } => format!("Renamed notebook to {}", title),
        Event::MemberJoined { who, .. } => format!("{} joined", who),
        Event::MemberLeft { who, .. } => format!("{} left", who),
    }
}

use tracing::debug;

#[derive(Debug, thiserror::Error)]
pub enum EngineError {
    #[error("Config error: {0}")]
    Config(String),
    #[error("Urbit error: {0}")]
    Urbit(#[from] UrbitError),
    #[error("Sync error: {0}")]
    Sync(#[from] ship_to_local::SyncError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Channel error: {0}")]
    Channel(String),
    #[error("Not connected")]
    NotConnected,
    #[error("FS watcher error: {0}")]
    Watcher(#[from] notify::Error),
}
