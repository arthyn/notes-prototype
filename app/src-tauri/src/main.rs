// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod fs;
mod sync;
mod urbit;

use std::sync::Arc;
use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconEvent},
    ActivationPolicy, Emitter, Manager,
};
use tokio::sync::RwLock;

use sync::engine::SyncEngine;

/// Shared application state accessible from Tauri commands and the sync engine
pub struct AppState {
    pub engine: Arc<RwLock<SyncEngine>>,
}

fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "notes_sync=info".parse().unwrap()),
        )
        .init();

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            #[cfg(target_os = "macos")]
            app.set_activation_policy(ActivationPolicy::Accessory);

            let engine = Arc::new(RwLock::new(SyncEngine::new()));

            // Set up activity event relay: buffer + emit to frontend
            {
                let app_handle = app.handle().clone();
                let engine_for_relay = engine.clone();
                tauri::async_runtime::spawn(async move {
                    let (rx, log) = {
                        let mut e = engine_for_relay.write().await;
                        (e.take_activity_rx(), e.activity_log.clone())
                    };
                    if let Some(mut rx) = rx {
                        while let Some(msg) = rx.recv().await {
                            // Buffer for polling
                            if let Ok(mut l) = log.lock() {
                                l.push(msg.clone());
                                if l.len() > 50 { l.remove(0); }
                            }
                            // Emit to any open windows
                            let _ = app_handle.emit("sync-activity", &msg);
                        }
                    }
                });
            }

            app.manage(AppState {
                engine: engine.clone(),
            });

            // Auto-connect if we have saved credentials
            {
                let engine = engine.clone();
                tauri::async_runtime::spawn(async move {
                    let should_connect = {
                        let e = engine.read().await;
                        let cfg = e.config();
                        cfg.sync_on_launch && !cfg.ship_url.is_empty() && !cfg.access_code.is_empty()
                    };
                    if should_connect {
                        tracing::info!("Auto-connecting with saved credentials");
                        let mut e = engine.write().await;
                        if let Err(err) = e.connect().await {
                            tracing::warn!("Auto-connect failed: {}", err);
                            return;
                        }
                        if !e.config().selected_notebooks.is_empty() {
                            let flags = e.config().selected_notebooks.clone();
                            if let Err(err) = e.select_notebooks(flags).await {
                                tracing::warn!("Auto-sync failed: {}", err);
                            }
                        }
                    }
                });
            }

            // Pre-create the popover window (hidden) so first open is instant
            let popover_window = tauri::WebviewWindowBuilder::new(
                app,
                "popover",
                tauri::WebviewUrl::App("index.html".into()),
            )
            .title("Notes Sync")
            .inner_size(320.0, 480.0)
            .resizable(false)
            .decorations(false)
            .transparent(true)
            .always_on_top(true)
            .visible(false)
            .build()
            .expect("failed to pre-create popover window");

            // Hide the popover when it loses focus — standard menubar behavior
            let popover_for_blur = popover_window.clone();
            popover_window.on_window_event(move |event| {
                if let tauri::WindowEvent::Focused(false) = event {
                    let _ = popover_for_blur.hide();
                }
            });

            // No native tray menu — the popover UI has Quit built in
            if let Some(tray) = app.tray_by_id("main") {
                let app_handle = app.handle().clone();
                tray.on_tray_icon_event(move |_tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        rect,
                        ..
                    } = event
                    {
                        // Align the popover's left edge to the icon's left edge,
                        // just below the menu bar
                        let icon_x = match rect.position {
                            tauri::Position::Physical(p) => p.x as f64,
                            tauri::Position::Logical(p) => p.x,
                        };
                        let icon_y = match rect.position {
                            tauri::Position::Physical(p) => p.y as f64,
                            tauri::Position::Logical(p) => p.y,
                        };
                        let icon_h = match rect.size {
                            tauri::Size::Physical(s) => s.height as f64,
                            tauri::Size::Logical(s) => s.height,
                        };
                        toggle_popover(&app_handle, icon_x, icon_y + icon_h);
                    }
                });
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_status,
            commands::get_config,
            commands::save_config,
            commands::connect,
            commands::disconnect,
            commands::get_notebooks,
            commands::select_notebooks,
            commands::get_activity,
            commands::quit_app,
        ])
        .run(tauri::generate_context!())
        .expect("error while running application");
}

fn toggle_popover(app: &tauri::AppHandle, x: f64, y: f64) {
    let pos = tauri::PhysicalPosition::new(x as i32, y as i32);

    if let Some(window) = app.get_webview_window("popover") {
        if window.is_visible().unwrap_or(false) {
            let _ = window.hide();
        } else {
            let _ = window.set_position(pos);
            let _ = window.show();
            let _ = window.set_focus();
        }
    }
}
