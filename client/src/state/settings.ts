import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createSecureStorage } from "./persist";
import type { NoiseGateMode } from "@/lib/noiseGate";
import type { ThemeId } from "@/lib/themes";

interface SettingsState {
  serverUrl: string | null;
  audioInputDeviceId: string | null;
  audioOutputDeviceId: string | null;
  inputVolume: number;
  outputVolume: number;
  noiseSuppressionEnabled: boolean;
  noiseGateMode: NoiseGateMode;
  theme: ThemeId;
  setServerUrl: (url: string) => void;
  clearServerUrl: () => void;
  setAudioInputDeviceId: (deviceId: string | null) => void;
  setAudioOutputDeviceId: (deviceId: string | null) => void;
  setInputVolume: (volume: number) => void;
  setOutputVolume: (volume: number) => void;
  setNoiseSuppressionEnabled: (enabled: boolean) => void;
  setNoiseGateMode: (mode: NoiseGateMode) => void;
  setTheme: (theme: ThemeId) => void;
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
      audioInputDeviceId: null,
      audioOutputDeviceId: null,
      inputVolume: 1,
      outputVolume: 1,
      noiseSuppressionEnabled: true,
      noiseGateMode: "standard",
      theme: "ember",
      setServerUrl: (url) => set({ serverUrl: normalizeServerUrl(url) }),
      clearServerUrl: () => set({ serverUrl: null }),
      setAudioInputDeviceId: (deviceId) => set({ audioInputDeviceId: deviceId }),
      setAudioOutputDeviceId: (deviceId) => set({ audioOutputDeviceId: deviceId }),
      setInputVolume: (volume) => set({ inputVolume: Math.max(0, Math.min(2, volume)) }),
      setOutputVolume: (volume) => set({ outputVolume: Math.max(0, Math.min(2, volume)) }),
      setNoiseSuppressionEnabled: (enabled) => set({ noiseSuppressionEnabled: enabled }),
      setNoiseGateMode: (mode) => set({ noiseGateMode: mode }),
      setTheme: (theme) => set({ theme }),
    }),
    {
      name: "campfire-settings",
      storage: createSecureStorage(),
    },
  ),
);
