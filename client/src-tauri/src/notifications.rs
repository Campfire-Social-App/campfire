use serde::{Deserialize, Serialize};
use tauri::{Emitter, Manager};

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationTarget {
    server_url: String,
    user_id: String,
    channel_id: String,
    kind: String,
}

fn activate(app: &tauri::AppHandle, target: &NotificationTarget) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
        let _ = window.emit("notification-activated", target);
    }
}

#[tauri::command]
pub async fn send_chat_notification(
    app: tauri::AppHandle,
    title: String,
    body: String,
    target: NotificationTarget,
) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || send(app, title, body, target))
        .await
        .map_err(|error| error.to_string())?
}

#[cfg(target_os = "windows")]
fn send(
    app: tauri::AppHandle,
    title: String,
    body: String,
    target: NotificationTarget,
) -> Result<(), String> {
    use tauri_winrt_notification::Toast;

    // Match the plugin's AppUserModelID convention: installed builds use the
    // identifier registered by the installer, development uses PowerShell.
    let exe = tauri::utils::platform::current_exe().map_err(|error| error.to_string())?;
    let directory = exe.parent().ok_or("Missing executable directory")?;
    let development = directory.ends_with("target/debug") || directory.ends_with("target/release");
    let app_id = if development {
        Toast::POWERSHELL_APP_ID
    } else {
        &app.config().identifier
    };
    Toast::new(app_id)
        .title(&title)
        .text1(&body)
        // Keep activation independent of dismissal/timeout: a toast can still
        // be clicked later from the Windows notification center.
        .on_activated(move |_| {
            activate(&app, &target);
            Ok(())
        })
        .show()
        .map_err(|error| error.to_string())
}

#[cfg(not(target_os = "windows"))]
fn send(
    app: tauri::AppHandle,
    title: String,
    body: String,
    target: NotificationTarget,
) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    let _ = notify_rust::set_application(if tauri::is_dev() {
        "com.apple.Terminal"
    } else {
        &app.config().identifier
    });

    let mut notification = notify_rust::Notification::new();
    notification
        .summary(&title)
        .body(&body)
        .auto_icon()
        .action("default", "Open conversation");
    let handle = notification.show().map_err(|error| error.to_string())?;
    // Waiting must not occupy the async runtime or hold the JS invocation open.
    std::thread::spawn(move || {
        let _ = handle.wait_for_response(|response: &notify_rust::NotificationResponse| {
            if matches!(response, notify_rust::NotificationResponse::Default)
                || matches!(response, notify_rust::NotificationResponse::Action(key) if key == "default") {
                activate(&app, &target);
            }
        });
    });
    Ok(())
}
