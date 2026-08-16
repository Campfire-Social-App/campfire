mod capture;

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
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
