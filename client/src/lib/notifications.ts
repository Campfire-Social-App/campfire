import { isPermissionGranted, requestPermission } from "@tauri-apps/plugin-notification";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { openNotificationTarget, type NotificationTarget } from "@/lib/notificationTarget";
import { toast } from "sonner";

const isTauri = "__TAURI_INTERNALS__" in window;
let permissionGranted = false;
let initialization: Promise<void> | null = null;

function activate(target: NotificationTarget): void {
  if (!openNotificationTarget(target)) {
    toast("This conversation is no longer available in the current server/account.");
  }
}

/** Register activation before any notification can be sent. Lives for the app session. */
export function initNotifications(): Promise<void> {
  initialization ??= (async () => {
    try {
      if (isTauri) {
        // The desktop plugin only sends notifications; the native command keeps
        // the activation callback and restores hidden/minimized windows.
        await listen<NotificationTarget>("notification-activated", ({ payload }) => activate(payload));
        permissionGranted = await isPermissionGranted();
        if (!permissionGranted) permissionGranted = (await requestPermission()) === "granted";
      } else if ("Notification" in window) {
        permissionGranted = Notification.permission === "granted";
        if (Notification.permission === "default") {
          permissionGranted = (await Notification.requestPermission()) === "granted";
        }
      }
    } catch {
      // A failed notification integration must not prevent startup.
    }
  })();
  return initialization;
}

export function notify(title: string, body: string, target: NotificationTarget | undefined): void {
  if (!target) return;
  void initNotifications().then(() => send(title, body, target));
}

async function send(title: string, body: string, target: NotificationTarget): Promise<void> {
  if (!permissionGranted) return;
  try {
    if (isTauri) {
      await invoke("send_chat_notification", { title, body, target });
    } else if ("Notification" in window) {
      const notification = new Notification(title, { body });
      notification.onclick = () => {
        window.focus();
        activate(target);
        notification.close();
      };
    }
  } catch {
    // Best-effort; a failed OS notification shouldn't interrupt the conversation.
  }
}
