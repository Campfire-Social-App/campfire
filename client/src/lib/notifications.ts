import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";

const isTauri = "__TAURI_INTERNALS__" in window;

let permissionGranted = false;

/** Requests OS notification permission once, at app startup. */
export async function initNotifications(): Promise<void> {
  try {
    if (isTauri) {
      permissionGranted = await isPermissionGranted();
      if (!permissionGranted) {
        permissionGranted = (await requestPermission()) === "granted";
      }
    } else if ("Notification" in window) {
      permissionGranted = Notification.permission === "granted";
      if (Notification.permission === "default") {
        permissionGranted = (await Notification.requestPermission()) === "granted";
      }
    }
  } catch {
    // Notifications are a nice-to-have — never block startup on this.
  }
}

export function notify(title: string, body: string): void {
  if (!permissionGranted) return;
  try {
    if (isTauri) {
      sendNotification({ title, body });
    } else if ("Notification" in window) {
      new Notification(title, { body });
    }
  } catch {
    // Best-effort; a failed OS notification shouldn't surface to the user.
  }
}
