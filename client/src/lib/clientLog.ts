import { invoke, isTauri } from "@tauri-apps/api/core";

/** Mirrors a diagnostic line into the Rust-side log file (see
 * `log_client_event` in src-tauri/src/lib.rs), in addition to the console.
 * DevTools and a visible console aren't always reachable in a packaged
 * build, but the log file always is — this is what makes the screen-share
 * frame-timing diagnostics actually inspectable after the fact. No-op in the
 * browser build, which has no Rust side to forward to. */
export function logToFile(message: string, level: "info" | "warn" | "error" = "info"): void {
  if (!isTauri()) return;
  void invoke("log_client_event", { level, message }).catch(() => {});
}
