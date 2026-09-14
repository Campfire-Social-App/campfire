import { invoke, isTauri } from "@tauri-apps/api/core";

export interface AudioDeviceLists {
  inputs: MediaDeviceInfo[];
  outputs: MediaDeviceInfo[];
}

export async function listAudioDevices(): Promise<AudioDeviceLists> {
  if (!navigator.mediaDevices?.enumerateDevices) return { inputs: [], outputs: [] };
  const devices = await navigator.mediaDevices.enumerateDevices();
  return {
    inputs: devices.filter((device) => device.kind === "audioinput"),
    outputs: devices.filter((device) => device.kind === "audiooutput"),
  };
}

export async function openSystemSoundSettings(page: "sound" | "mixer" = "sound"): Promise<void> {
  if (isTauri()) {
    await invoke("open_windows_sound_settings", { page });
    return;
  }
  throw new Error("System sound settings are available in the Windows client.");
}
