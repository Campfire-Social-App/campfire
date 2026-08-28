import { relaunch } from "@tauri-apps/plugin-process";
import { check, type Update } from "@tauri-apps/plugin-updater";
import { toast } from "sonner";

const isTauri = "__TAURI_INTERNALS__" in window;

// Closing the window only hides it to the tray, so a session can last days —
// checking once at startup would miss every release published in between.
const CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000;

/** Version already offered, so a re-check doesn't stack a second toast for it. */
let offeredVersion: string | null = null;
let installing = false;

/**
 * Starts the update polling. Returns a cleanup that stops it.
 * A no-op outside Tauri — the same frontend runs in a plain browser via `npm run dev`.
 */
export function initUpdater(): () => void {
  if (!isTauri) return () => {};

  void checkForUpdate();
  const timer = setInterval(() => void checkForUpdate(), CHECK_INTERVAL_MS);
  return () => clearInterval(timer);
}

async function checkForUpdate(): Promise<void> {
  if (installing) return;

  let update: Update | null = null;
  try {
    update = await check();
  } catch {
    // Offline, GitHub unreachable, or no release published yet. Silent by
    // design: an update check is never what the user came here to do.
    return;
  }
  if (!update) return;

  if (offeredVersion === update.version) {
    // Already on screen (or dismissed) — release the handle instead of leaking
    // one per check.
    await update.close();
    return;
  }
  offeredVersion = update.version;

  toast(`Campfire ${update.version} disponível`, {
    description: "A atualização é instalada e o app reinicia sozinho.",
    duration: Infinity,
    action: { label: "Atualizar", onClick: () => void install(update) },
  });
}

async function install(update: Update): Promise<void> {
  if (installing) return;
  installing = true;

  const id = toast.loading("Baixando atualização…");
  try {
    let total = 0;
    let downloaded = 0;

    await update.downloadAndInstall((event) => {
      switch (event.event) {
        case "Started":
          total = event.data.contentLength ?? 0;
          break;
        case "Progress":
          downloaded += event.data.chunkLength;
          toast.loading(
            total
              ? `Baixando atualização… ${Math.round((downloaded / total) * 100)}%`
              : "Baixando atualização…",
            { id },
          );
          break;
        case "Finished":
          toast.loading("Instalando…", { id });
          break;
      }
    });

    // On Windows the NSIS installer closes the app itself, so this line often
    // never runs. It is what restarts the app on the platforms where it does.
    toast.success("Atualizado. Reiniciando…", { id });
    await relaunch();
  } catch (error) {
    installing = false;
    // Let the next check offer this version again — the failure may have been
    // a dropped connection.
    offeredVersion = null;
    toast.error("Não foi possível atualizar", {
      id,
      description: error instanceof Error ? error.message : String(error),
    });
  }
}
