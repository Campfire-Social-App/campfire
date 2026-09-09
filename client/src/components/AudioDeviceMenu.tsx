import { useEffect, useMemo, useState } from "react";
import { AudioLines, ChevronUp, Settings, SlidersHorizontal } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { listAudioDevices, openSystemSoundSettings } from "@/lib/audioDevices";
import type { NoiseGateMode } from "@/lib/noiseGate";
import {
  applyInputVolume,
  applyNoiseGate,
  applyNoiseSuppression,
  applyOutputVolume,
  switchAudioInputDevice,
  switchAudioOutputDevice,
} from "@/livekit/voice";
import { useSettingsStore } from "@/state/settings";
import { toast } from "sonner";

type AudioDeviceKind = "input" | "output";

export function AudioDeviceMenu({ kind }: { kind: AudioDeviceKind }) {
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const inputDeviceId = useSettingsStore((state) => state.audioInputDeviceId);
  const outputDeviceId = useSettingsStore((state) => state.audioOutputDeviceId);
  const inputVolume = useSettingsStore((state) => state.inputVolume);
  const outputVolume = useSettingsStore((state) => state.outputVolume);
  const noiseSuppression = useSettingsStore((state) => state.noiseSuppressionEnabled);
  const noiseGate = useSettingsStore((state) => state.noiseGateMode);
  const selectedDeviceId = kind === "input" ? inputDeviceId : outputDeviceId;
  const volume = kind === "input" ? inputVolume : outputVolume;

  const refresh = async () => {
    try {
      const listed = await listAudioDevices();
      setDevices(kind === "input" ? listed.inputs : listed.outputs);
    } catch {
      toast.error("Couldn't list the audio devices.");
    }
  };

  useEffect(() => {
    const changed = () => void refresh();
    navigator.mediaDevices?.addEventListener("devicechange", changed);
    return () => navigator.mediaDevices?.removeEventListener("devicechange", changed);
    // The listener only needs the current menu kind when the component mounts.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [kind]);

  const selectedLabel = useMemo(() => {
    const selected = devices.find((device) => device.deviceId === selectedDeviceId);
    return selected?.label || (kind === "input" ? "System microphone" : "System output");
  }, [devices, kind, selectedDeviceId]);

  const selectDevice = async (deviceId: string) => {
    try {
      if (kind === "input") await switchAudioInputDevice(deviceId);
      else await switchAudioOutputDevice(deviceId);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Couldn't change the audio device.");
    }
  };

  const changeNoiseSuppression = async (enabled: boolean) => {
    useSettingsStore.getState().setNoiseSuppressionEnabled(enabled);
    await applyNoiseSuppression(enabled).catch(() => {
      toast.warning("This profile will be applied when the microphone starts again.");
    });
  };

  const changeNoiseGate = async (mode: NoiseGateMode) => {
    useSettingsStore.getState().setNoiseGateMode(mode);
    await applyNoiseGate(mode).catch(() => {
      toast.warning("This profile will be applied when the microphone starts again.");
    });
  };

  return (
    <DropdownMenu onOpenChange={(open) => { if (open) void refresh(); }}>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          aria-label={kind === "input" ? "Microphone options" : "Audio output options"}
          className="flex h-8 w-4 items-center justify-center rounded-r-md bg-white/5 text-muted-foreground hover:bg-white/10 hover:text-foreground data-open:bg-white/10"
        >
          <ChevronUp className="size-3" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent side="top" align="start" className="w-64">
        <DropdownMenuLabel>
          <span className="block">{kind === "input" ? "Input device" : "Output device"}</span>
          <span className="mt-0.5 block truncate text-xs font-normal text-muted-foreground">
            {selectedLabel}
          </span>
        </DropdownMenuLabel>
        <DropdownMenuRadioGroup
          value={selectedDeviceId ?? "default"}
          onValueChange={(deviceId) => void selectDevice(deviceId)}
        >
          {devices.map((device, index) => (
            <DropdownMenuRadioItem key={`${device.deviceId}:${index}`} value={device.deviceId}>
              <span className="truncate">
                {device.label || `${kind === "input" ? "Microphone" : "Speaker"} ${index + 1}`}
              </span>
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>

        {kind === "input" && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuLabel>Input profile</DropdownMenuLabel>
            <DropdownMenuCheckboxItem
              checked={noiseSuppression}
              onCheckedChange={(checked) => void changeNoiseSuppression(checked === true)}
              onSelect={(event) => event.preventDefault()}
            >
              <AudioLines className="size-4" /> Noise suppression
            </DropdownMenuCheckboxItem>
            <DropdownMenuRadioGroup
              value={noiseGate}
              onValueChange={(mode) => void changeNoiseGate(mode as NoiseGateMode)}
            >
              <DropdownMenuRadioItem value="off" onSelect={(event) => event.preventDefault()}>
                Gate off
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="standard" onSelect={(event) => event.preventDefault()}>
                Standard
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value="strong" onSelect={(event) => event.preventDefault()}>
                Strong
              </DropdownMenuRadioItem>
            </DropdownMenuRadioGroup>
          </>
        )}

        <DropdownMenuSeparator />
        <div className="px-2 py-2">
          <div className="mb-2 flex items-center justify-between text-xs">
            <span>{kind === "input" ? "Input volume" : "Output volume"}</span>
            <span className="text-muted-foreground">{Math.round(volume * 100)}%</span>
          </div>
          <input
            type="range"
            min="0"
            max="200"
            step="1"
            value={Math.round(volume * 100)}
            aria-label={kind === "input" ? "Input volume" : "Output volume"}
            onChange={(event) => {
              const next = Number(event.target.value) / 100;
              if (kind === "input") void applyInputVolume(next);
              else applyOutputVolume(next);
            }}
            className="h-1.5 w-full cursor-pointer accent-primary"
          />
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onSelect={() => void openSystemSoundSettings().catch((error) => {
            toast.error(error instanceof Error ? error.message : "Couldn't open sound settings.");
          })}
        >
          <Settings className="size-4" /> Windows sound settings
        </DropdownMenuItem>
        <DropdownMenuItem
          onSelect={() => void openSystemSoundSettings("mixer").catch((error) => {
            toast.error(error instanceof Error ? error.message : "Couldn't open the volume mixer.");
          })}
        >
          <SlidersHorizontal className="size-4" /> Windows volume mixer
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
