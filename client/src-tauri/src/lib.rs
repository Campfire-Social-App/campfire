mod capture;
mod notifications;

use tauri::Manager;

#[tauri::command]
fn open_windows_sound_settings(page: Option<String>) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer.exe")
            .arg(if page.as_deref() == Some("mixer") {
                "ms-settings:apps-volume"
            } else {
                "ms-settings:sound"
            })
            .spawn()
            .map_err(|error| error.to_string())?;
        return Ok(());
    }
    #[cfg(not(target_os = "windows"))]
    Err("Windows sound settings are only available on Windows".to_string())
}

/// Forwards a diagnostic line from the frontend (screen-share frame timing,
/// WebRTC sender stats — see `src/lib/clientLog.ts`) into the same log file as
/// the native capture pipeline's own `log::info!` calls, so a single file has
/// the whole picture instead of it being split across stderr and a WebView
/// console that may not even be reachable in a packaged build.
#[tauri::command]
fn log_client_event(level: String, message: String) {
    match level.as_str() {
        "warn" => log::warn!(target: "client", "{message}"),
        "error" => log::error!(target: "client", "{message}"),
        _ => log::info!(target: "client", "{message}"),
    }
}

#[tauri::command]
fn open_log_folder(app: tauri::AppHandle) -> Result<(), String> {
    let dir = app.path().app_log_dir().map_err(|error| error.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|error| error.to_string())?;
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer.exe")
            .arg(&dir)
            .spawn()
            .map_err(|error| error.to_string())?;
        return Ok(());
    }
    #[cfg(not(target_os = "windows"))]
    Err(format!("Open this folder manually: {}", dir.display()))
}

#[cfg(target_os = "windows")]
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
};

#[cfg(target_os = "windows")]
fn show_main_window(app: &tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(
            tauri_plugin_log::Builder::new()
                .target(tauri_plugin_log::Target::new(
                    tauri_plugin_log::TargetKind::LogDir { file_name: None },
                ))
                .target(tauri_plugin_log::Target::new(tauri_plugin_log::TargetKind::Stdout))
                .level(log::LevelFilter::Info)
                .build(),
        )
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .manage(capture::CaptureManager::default())
        .invoke_handler(tauri::generate_handler![
            capture::list_capture_sources,
            capture::start_capture,
            capture::acknowledge_capture,
            capture::stop_capture,
            open_windows_sound_settings,
            log_client_event,
            open_log_folder,
            notifications::send_chat_notification,
        ])
        .setup(|_app| {
            #[cfg(target_os = "windows")]
            {
                let open = MenuItem::with_id(_app, "open", "Abrir", true, None::<&str>)?;
                let logs =
                    MenuItem::with_id(_app, "logs", "Abrir pasta de logs", true, None::<&str>)?;
                let quit = MenuItem::with_id(_app, "quit", "Fechar", true, None::<&str>)?;
                let menu = Menu::with_items(_app, &[&open, &logs, &quit])?;

                TrayIconBuilder::new()
                    .icon(
                        _app.default_window_icon()
                            .expect("the application icon must be configured")
                            .clone(),
                    )
                    .tooltip("Campfire")
                    .menu(&menu)
                    .show_menu_on_left_click(false)
                    .on_menu_event(|app, event| match event.id().as_ref() {
                        "open" => show_main_window(app),
                        "logs" => {
                            let _ = open_log_folder(app.clone());
                        }
                        "quit" => app.exit(0),
                        _ => {}
                    })
                    .on_tray_icon_event(|tray, event| {
                        if let TrayIconEvent::Click {
                            button: MouseButton::Left,
                            button_state: MouseButtonState::Up,
                            ..
                        } = event
                        {
                            show_main_window(tray.app_handle());
                        }
                    })
                    .build(_app)?;
            }

            Ok(())
        })
        .on_window_event(|_window, _event| {
            #[cfg(target_os = "windows")]
            if let tauri::WindowEvent::CloseRequested { api, .. } = _event {
                api.prevent_close();
                let _ = _window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
