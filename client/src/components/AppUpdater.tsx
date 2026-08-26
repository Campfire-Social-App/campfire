import { useEffect } from "react";
import { isTauri } from "@tauri-apps/api/core";
import { relaunch } from "@tauri-apps/plugin-process";
import { check, type Update } from "@tauri-apps/plugin-updater";
import { toast } from "sonner";

let automaticCheckStarted = false;
let checkInProgress: Promise<void> | null = null;
let installInProgress = false;

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function installUpdate(update: Update): Promise<void> {
  if (installInProgress) return;
  installInProgress = true;

  const toastId = toast.loading(`Downloading Campfire ${update.version}…`, {
    description: "You can continue using the app while the update downloads.",
    duration: Infinity,
  });
  let downloaded = 0;
  let contentLength: number | undefined;
  let lastPercent = -1;

  try {
    await update.downloadAndInstall((event) => {
      if (event.event === "Started") {
        contentLength = event.data.contentLength;
        return;
      }
      if (event.event === "Progress") {
        downloaded += event.data.chunkLength;
        if (!contentLength) return;
        const percent = Math.min(100, Math.floor((downloaded / contentLength) * 100));
        if (percent === lastPercent) return;
        lastPercent = percent;
        toast.loading(`Downloading Campfire ${update.version}… ${percent}%`, {
          id: toastId,
          description: "You can continue using the app while the update downloads.",
          duration: Infinity,
        });
        return;
      }
      toast.loading("Installing update…", {
        id: toastId,
        description: "Campfire will restart automatically.",
        duration: Infinity,
      });
    });

    toast.success("Update installed. Restarting Campfire…", { id: toastId });
    await relaunch();
  } catch (error) {
    installInProgress = false;
    toast.error("Couldn't install the update.", {
      id: toastId,
      description: errorMessage(error),
      duration: 8000,
    });
  }
}

export function checkForAppUpdate(notifyIfCurrent = false): Promise<void> {
  if (!isTauri()) {
    if (notifyIfCurrent) toast.info("Updates are available only in the desktop app.");
    return Promise.resolve();
  }
  if (checkInProgress) return checkInProgress;

  checkInProgress = check({ timeout: 15_000 })
    .then((update) => {
      if (!update) {
        if (notifyIfCurrent) toast.success("Campfire is up to date.");
        return;
      }

      toast.info(`Campfire ${update.version} is available.`, {
        description: update.body || "Download and install it without leaving the app.",
        duration: Infinity,
        action: {
          label: "Update now",
          onClick: () => void installUpdate(update),
        },
      });
    })
    .catch((error) => {
      // Automatic checks must not turn a temporary network problem into a
      // startup error. A manual check still reports enough detail to diagnose.
      console.warn("Could not check for Campfire updates.", error);
      if (notifyIfCurrent) {
        toast.error("Couldn't check for updates.", {
          description: errorMessage(error),
        });
      }
    })
    .finally(() => {
      checkInProgress = null;
    });

  return checkInProgress;
}

export function AppUpdater() {
  useEffect(() => {
    if (!isTauri() || automaticCheckStarted) return;
    const timer = window.setTimeout(() => {
      automaticCheckStarted = true;
      void checkForAppUpdate();
    }, 3000);
    return () => window.clearTimeout(timer);
  }, []);

  return null;
}
