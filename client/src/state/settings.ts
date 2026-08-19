import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createSecureStorage } from "./persist";

interface SettingsState {
  serverUrl: string | null;
  setServerUrl: (url: string) => void;
  clearServerUrl: () => void;
  /** Capture device the camera should use, as picked in the camera menu. Kept
   * across restarts because the pick is about the machine, not the session —
   * whoever runs a virtual camera wants it every time, not once. */
  cameraDeviceId: string | null;
  setCameraDeviceId: (deviceId: string) => void;
}

function normalizeServerUrl(url: string): string {
  const trimmed = url.trim().replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(trimmed)) {
    return `https://${trimmed}`;
  }
  return trimmed;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      serverUrl: null,
      setServerUrl: (url) => set({ serverUrl: normalizeServerUrl(url) }),
      clearServerUrl: () => set({ serverUrl: null }),
      cameraDeviceId: null,
      setCameraDeviceId: (deviceId) => set({ cameraDeviceId: deviceId }),
    }),
    {
      name: "campfire-settings",
      storage: createSecureStorage(),
    },
  ),
);
