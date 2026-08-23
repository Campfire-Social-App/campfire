import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";

const isTauri = "__TAURI_INTERNALS__" in window;

let permissionGranted = false;
let initialization: Promise<void> | null = null;

/** Requests OS notification permission once, at app startup. */
export function initNotifications(): Promise<void> {
  initialization ??= (async () => {
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
  })();
  return initialization;
}

export function notify(title: string, body: string): void {
  // A gateway frame can arrive while the OS permission dialog is still open.
  // Queue that notification behind initialization instead of silently losing it.
  if (initialization) {
    void initialization.then(() => send(title, body));
    return;
  }
  send(title, body);
}

function send(title: string, body: string): void {
  if (!permissionGranted) return;
  try {
    if (isTauri) {
      sendNotification({ title, body });
    } else if ("Notification" in window) {
      const notification = new Notification(title, { body });
      notification.onclick = () => {
        window.focus();
        notification.close();
      };
    }
  } catch {
    // Best-effort; a failed OS notification shouldn't surface to the user.
  }
}
