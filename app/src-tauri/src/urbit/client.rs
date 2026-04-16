use std::sync::Arc;

use reqwest::{cookie::Jar, Client};
use serde_json::Value;

use super::types::{Folder, Note, NotebookEntry};

/// HTTP client for Urbit's Eyre interface.
/// Handles authentication (cookie-based) and scry/poke operations.
pub struct UrbitClient {
    pub base_url: String,
    pub ship: Option<String>,
    client: Client,
    cookie_jar: Arc<Jar>,
}

impl UrbitClient {
    pub fn new(base_url: &str) -> Self {
        let cookie_jar = Arc::new(Jar::default());
        let client = Client::builder()
            .cookie_provider(cookie_jar.clone())
            .build()
            .expect("failed to build HTTP client");

        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            ship: None,
            client,
            cookie_jar,
        }
    }

    /// Create a client from an existing reqwest::Client (shares cookies/session)
    pub fn from_existing(base_url: &str, client: Client) -> Self {
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            ship: None,
            client,
            cookie_jar: Arc::new(Jar::default()), // unused, cookies are in the client
        }
    }

    /// Authenticate with the ship using the access code.
    /// Stores the session cookie for subsequent requests.
    pub async fn login(&mut self, code: &str) -> Result<(), UrbitError> {
        let url = format!("{}/~/login", self.base_url);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(format!("password={}", code))
            .send()
            .await?;

        if !resp.status().is_success() && !resp.status().is_redirection() {
            return Err(UrbitError::AuthFailed(resp.status().to_string()));
        }

        // Fetch our ship name
        let name_url = format!("{}/~/name", self.base_url);
        let name_resp = self.client.get(&name_url).send().await?;
        if name_resp.status().is_success() {
            let name = name_resp.text().await?.trim().to_string();
            self.ship = Some(name);
        }

        Ok(())
    }

    /// Perform a scry (read) against the notes agent.
    /// `path` should be like `/notebooks` or `/notes/~zod/my-book`
    pub async fn scry(&self, path: &str) -> Result<Value, UrbitError> {
        let url = format!("{}/~/scry/notes{}.json", self.base_url, path);
        let resp = self.client.get(&url).send().await?;
        if !resp.status().is_success() {
            return Err(UrbitError::ScryFailed {
                path: path.to_string(),
                status: resp.status().as_u16(),
            });
        }
        let json = resp.json().await?;
        Ok(json)
    }

    /// Get all notebooks visible to this ship
    pub async fn get_notebooks(&self) -> Result<Vec<NotebookEntry>, UrbitError> {
        let val = self.scry("/v0/notebooks").await?;
        let entries: Vec<NotebookEntry> = serde_json::from_value(val)?;
        Ok(entries)
    }

    /// Get all folders in a notebook (flag = "~ship/name")
    pub async fn get_folders(&self, flag: &str) -> Result<Vec<Folder>, UrbitError> {
        let val = self.scry(&format!("/v0/folders/{}", flag)).await?;
        let folders: Vec<Folder> = serde_json::from_value(val)?;
        Ok(folders)
    }

    /// Get all notes in a notebook (flag = "~ship/name")
    pub async fn get_notes(&self, flag: &str) -> Result<Vec<Note>, UrbitError> {
        let val = self.scry(&format!("/v0/notes/{}", flag)).await?;
        let notes: Vec<Note> = serde_json::from_value(val)?;
        Ok(notes)
    }

    /// Get a single note by ID
    pub async fn get_note(&self, flag: &str, note_id: u64) -> Result<Option<Note>, UrbitError> {
        let val = self.scry(&format!("/v0/note/{}/{}", flag, note_id)).await?;
        if val.is_null() {
            return Ok(None);
        }
        let note: Note = serde_json::from_value(val)?;
        Ok(Some(note))
    }

    /// Get a single folder by ID
    pub async fn get_folder(
        &self,
        flag: &str,
        folder_id: u64,
    ) -> Result<Option<Folder>, UrbitError> {
        let val = self
            .scry(&format!("/v0/folder/{}/{}", flag, folder_id))
            .await?;
        if val.is_null() {
            return Ok(None);
        }
        let folder: Folder = serde_json::from_value(val)?;
        Ok(Some(folder))
    }

    /// Get the underlying reqwest client (for channel operations)
    pub fn http_client(&self) -> &Client {
        &self.client
    }

    /// Get the ship name (e.g. "~zod"), available after login
    pub fn ship_name(&self) -> Option<&str> {
        self.ship.as_deref()
    }
}

#[derive(Debug, thiserror::Error)]
pub enum UrbitError {
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("Authentication failed: {0}")]
    AuthFailed(String),
    #[error("Scry failed for {path}: HTTP {status}")]
    ScryFailed { path: String, status: u16 },
    #[error("JSON parse error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("Channel error: {0}")]
    Channel(String),
    #[error("Not connected")]
    NotConnected,
}
