use std::time::{SystemTime, UNIX_EPOCH};

use futures_util::StreamExt;
use reqwest::Client;
use reqwest_eventsource::{Event as SseEvent, EventSource};
use serde_json::{json, Value};
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

use super::types::Response;

/// Eyre channel — manages subscriptions, pokes, acks, and SSE event stream.
///
/// Mirrors the protocol from the JS frontend:
/// - PUT to /~/channel/{id} with JSON array of actions
/// - GET (EventSource) on /~/channel/{id} for SSE stream
pub struct EyreChannel {
    base_url: String,
    channel_id: String,
    client: Client,
    msg_id: u64,
    last_acked: u64,
}

impl EyreChannel {
    pub fn new(base_url: &str, client: Client) -> Self {
        let ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis();
        let channel_id = format!("notes-sync-{}", ts);

        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            channel_id,
            client,
            msg_id: 1,
            last_acked: 0,
        }
    }

    fn channel_url(&self) -> String {
        format!("{}/~/channel/{}", self.base_url, self.channel_id)
    }

    fn next_id(&mut self) -> u64 {
        let id = self.msg_id;
        self.msg_id += 1;
        id
    }

    /// Send a batch of actions to the channel via PUT
    async fn send(&self, actions: Vec<Value>) -> Result<(), ChannelError> {
        let resp = self
            .client
            .put(&self.channel_url())
            .json(&actions)
            .send()
            .await?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(ChannelError::PutFailed {
                status: status.as_u16(),
                body,
            });
        }
        Ok(())
    }

    /// Subscribe to a watch path on the notes agent.
    /// Returns the subscription ID.
    pub async fn subscribe(&mut self, ship: &str, path: &str) -> Result<u64, ChannelError> {
        let id = self.next_id();
        let ship_bare = ship.trim_start_matches('~');
        let action = json!({
            "id": id,
            "action": "subscribe",
            "ship": ship_bare,
            "app": "notes",
            "path": path
        });
        self.send(vec![action]).await?;
        info!("Subscribed to {} (sub_id={})", path, id);
        Ok(id)
    }

    /// Unsubscribe from a subscription
    pub async fn unsubscribe(&mut self, subscription_id: u64) -> Result<(), ChannelError> {
        let id = self.next_id();
        let action = json!({
            "id": id,
            "action": "unsubscribe",
            "subscription": subscription_id
        });
        self.send(vec![action]).await?;
        debug!("Unsubscribed (sub_id={})", subscription_id);
        Ok(())
    }

    /// Poke the notes agent with an action
    pub async fn poke(&mut self, ship: &str, mark: &str, json_body: Value) -> Result<u64, ChannelError> {
        let id = self.next_id();
        let ship_bare = ship.trim_start_matches('~');
        let action = json!({
            "id": id,
            "action": "poke",
            "ship": ship_bare,
            "app": "notes",
            "mark": mark,
            "json": json_body
        });
        self.send(vec![action]).await?;
        debug!("Poked {} mark={} (msg_id={})", ship, mark, id);
        Ok(id)
    }

    /// Acknowledge receipt of an event (prevents channel reaping)
    pub async fn ack(&mut self, event_id: u64) -> Result<(), ChannelError> {
        let id = self.next_id();
        let action = json!({
            "id": id,
            "action": "ack",
            "event-id": event_id
        });
        self.send(vec![action]).await?;
        self.last_acked = event_id;
        Ok(())
    }

    /// Start the SSE event stream and forward parsed events to the channel.
    /// Runs until the connection drops or the sender is closed.
    /// Acks events every 20 messages to prevent channel reaping.
    pub async fn start_sse(&mut self, tx: mpsc::Sender<SseMessage>) -> Result<(), ChannelError> {
        let url = self.channel_url();
        let mut es = EventSource::new(
            self.client.get(&url)
        ).map_err(|e| ChannelError::SseSetup(e.to_string()))?;

        let mut unacked_count: u64 = 0;

        info!("SSE stream started on {}", url);

        while let Some(event) = es.next().await {
            match event {
                Ok(SseEvent::Open) => {
                    debug!("SSE connection opened");
                }
                Ok(SseEvent::Message(msg)) => {
                    let parsed: Result<Value, _> = serde_json::from_str(&msg.data);
                    match parsed {
                        Ok(data) => {
                            // Extract the event ID for acking
                            let event_id = data.get("id").and_then(|v| v.as_u64()).unwrap_or(0);

                            // Try to parse the json field as a Response
                            if let Some(json_val) = data.get("json") {
                                match serde_json::from_value::<Response>(json_val.clone()) {
                                    Ok(response) => {
                                        if tx.send(SseMessage::Response(response)).await.is_err() {
                                            info!("SSE receiver dropped, stopping");
                                            break;
                                        }
                                    }
                                    Err(e) => {
                                        debug!("Non-response SSE message: {} (data: {})", e, json_val);
                                    }
                                }
                            }

                            // Check for error responses (e.g., poke failures)
                            if let Some(err) = data.get("err").and_then(|v| v.as_str()) {
                                warn!("Channel error for event {}: {}", event_id, err);
                                let _ = tx.send(SseMessage::Error(err.to_string())).await;
                            }

                            // Ack every 20 events
                            unacked_count += 1;
                            if unacked_count >= 20 {
                                if let Err(e) = self.ack(event_id).await {
                                    warn!("Failed to ack event {}: {}", event_id, e);
                                }
                                unacked_count = 0;
                            }
                        }
                        Err(e) => {
                            debug!("Failed to parse SSE data: {}", e);
                        }
                    }
                }
                Err(reqwest_eventsource::Error::StreamEnded) => {
                    info!("SSE stream ended");
                    break;
                }
                Err(e) => {
                    error!("SSE error: {}", e);
                    let _ = tx.send(SseMessage::Disconnected).await;
                    break;
                }
            }
        }

        Ok(())
    }

    /// Delete the channel (cleanup on disconnect)
    pub async fn delete(&mut self) -> Result<(), ChannelError> {
        let id = self.next_id();
        let action = json!({
            "id": id,
            "action": "delete"
        });
        let _ = self.send(vec![action]).await;
        debug!("Channel {} deleted", self.channel_id);
        Ok(())
    }
}

/// Messages delivered from the SSE stream to the sync engine
#[derive(Debug, Clone)]
pub enum SseMessage {
    Response(Response),
    Error(String),
    Disconnected,
}

#[derive(Debug, thiserror::Error)]
pub enum ChannelError {
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("PUT failed: HTTP {status} - {body}")]
    PutFailed { status: u16, body: String },
    #[error("SSE setup error: {0}")]
    SseSetup(String),
}
