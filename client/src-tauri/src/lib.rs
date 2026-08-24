mod capture;

#[cfg(target_os = "windows")]
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager,
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
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .manage(capture::CaptureManager::default())
        .invoke_handler(tauri::generate_handler![
            capture::list_capture_sources,
            capture::start_capture,
            capture::stop_capture,
        ])
        .setup(|_app| {
            #[cfg(target_os = "windows")]
            {
                let open = MenuItem::with_id(_app, "open", "Abrir", true, None::<&str>)?;
                let quit = MenuItem::with_id(_app, "quit", "Fechar", true, None::<&str>)?;
                let menu = Menu::with_items(_app, &[&open, &quit])?;

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
