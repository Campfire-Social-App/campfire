import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createSecureStorage } from "./persist";
import type { NoiseGateMode } from "@/lib/noiseGate";

interface SettingsState {
  serverUrl: string | null;
  noiseSuppressionEnabled: boolean;
  noiseGateMode: NoiseGateMode;
  setServerUrl: (url: string) => void;
  clearServerUrl: () => void;
  setNoiseSuppressionEnabled: (enabled: boolean) => void;
  setNoiseGateMode: (mode: NoiseGateMode) => void;
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
      noiseGateMode: "standard",
      setServerUrl: (url) => set({ serverUrl: normalizeServerUrl(url) }),
      clearServerUrl: () => set({ serverUrl: null }),
      setNoiseSuppressionEnabled: (enabled) => set({ noiseSuppressionEnabled: enabled }),
      setNoiseGateMode: (mode) => set({ noiseGateMode: mode }),
    }),
    {
      name: "campfire-settings",
      storage: createSecureStorage(),
    },
  ),
);
