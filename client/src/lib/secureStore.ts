import { isTauri } from "@tauri-apps/api/core";

/**
 * Token persistence. Inside the Tauri shell this writes to a JSON file in the
 * app's data dir via `tauri-plugin-store`. In plain-browser dev (`npm run dev`
 * without `tauri dev`) it falls back to localStorage so the UI is iterable
 * without compiling the Rust side.
 *
 * NOTE: this is app-local storage, not OS keychain-backed. PLANO.md calls for
 * keychain storage — hardening this to `tauri-plugin-stronghold` (or an OS
 * keyring plugin) is a follow-up once the Tauri shell can be compiled/tested
 * in this environment.
 */

let tauriStorePromise: Promise<import("@tauri-apps/plugin-store").Store> | null = null;

async function getTauriStore() {
  if (!tauriStorePromise) {
    tauriStorePromise = import("@tauri-apps/plugin-store").then(({ Store }) =>
      Store.load("campfire-auth.json"),
    );
  }
  return tauriStorePromise;
}

export async function getItem(key: string): Promise<string | null> {
  if (isTauri()) {
    const store = await getTauriStore();
    const value = await store.get<string>(key);
    return value ?? null;
  }
  return localStorage.getItem(key);
}

export async function setItem(key: string, value: string): Promise<void> {
  if (isTauri()) {
    const store = await getTauriStore();
    await store.set(key, value);
    await store.save();
    return;
  }
  localStorage.setItem(key, value);
}

export async function removeItem(key: string): Promise<void> {
  if (isTauri()) {
    const store = await getTauriStore();
    await store.delete(key);
    await store.save();
    return;
  }
  localStorage.removeItem(key);
}
