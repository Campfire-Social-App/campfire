import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createSecureStorage } from "./persist";

interface SettingsState {
  serverUrl: string | null;
  noiseSuppressionEnabled: boolean;
  setServerUrl: (url: string) => void;
  clearServerUrl: () => void;
  setNoiseSuppressionEnabled: (enabled: boolean) => void;
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
      noiseSuppressionEnabled: true,
      setServerUrl: (url) => set({ serverUrl: normalizeServerUrl(url) }),
      clearServerUrl: () => set({ serverUrl: null }),
      setNoiseSuppressionEnabled: (enabled) => set({ noiseSuppressionEnabled: enabled }),
    }),
    {
      name: "campfire-settings",
      storage: createSecureStorage(),
    },
  ),
);
