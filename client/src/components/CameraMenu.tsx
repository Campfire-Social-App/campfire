import { useState } from "react";
import { VideoOff } from "lucide-react";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import {
  describeCameraError,
  getActiveCameraDeviceId,
  listCameras,
  selectCamera,
  setCameraEnabled,
} from "@/livekit/voice";
import { useSettingsStore } from "@/state/settings";
import { useVoiceStore } from "@/state/voice";

/**
 * The camera button's menu: every capture device the OS reports, so a virtual
 * camera (OBS, a phone bridged as a webcam) is a choice rather than something
 * the app has to guess at. Wraps the button itself — the caller renders it as
 * the menu's trigger, since the two places a camera control lives style theirs
 * differently.
 */
export function CameraMenu({
  side = "top",
  align = "start",
  children,
}: {
  side?: "top" | "bottom" | "left" | "right";
  align?: "start" | "center" | "end";
  children: React.ReactNode;
}) {
  /** null while the list hasn't been read yet — distinct from "read, found none". */
  const [devices, setDevices] = useState<MediaDeviceInfo[] | null>(null);
  const [activeDeviceId, setActiveDeviceId] = useState<string | undefined>(undefined);
  const localCameraEnabled = useVoiceStore((s) => s.localCameraEnabled);
  const preferredDeviceId = useSettingsStore((s) => s.cameraDeviceId);

  // Enumerated on every open rather than once on mount: a virtual camera comes
  // and goes with the app behind it, so the list is only true at the moment
  // it's read.
  const handleOpen = async (open: boolean) => {
    if (!open) return;
    setActiveDeviceId(getActiveCameraDeviceId());
    try {
      setDevices(await listCameras());
    } catch (err) {
      setDevices([]);
      toast.error(describeCameraError(err));
    }
  };

  const handleSelect = async (deviceId: string) => {
    try {
      await selectCamera(deviceId);
    } catch (err) {
      toast.error(describeCameraError(err));
    }
  };

  const handleTurnOff = async () => {
    try {
      await setCameraEnabled(false);
    } catch (err) {
      toast.error(describeCameraError(err));
    }
  };

  return (
    <DropdownMenu onOpenChange={(open) => void handleOpen(open)}>
      {children}
      <DropdownMenuContent side={side} align={align} className="w-64">
        <DropdownMenuLabel>Camera</DropdownMenuLabel>
        {devices === null ? (
          <DropdownMenuItem disabled>Looking for cameras…</DropdownMenuItem>
        ) : devices.length === 0 ? (
          <DropdownMenuItem disabled>No cameras found</DropdownMenuItem>
        ) : (
          <DropdownMenuRadioGroup
            value={preferredDeviceId ?? activeDeviceId ?? ""}
            onValueChange={(deviceId) => void handleSelect(deviceId)}
          >
            {devices.map((device, index) => (
              <DropdownMenuRadioItem key={device.deviceId} value={device.deviceId}>
                {/* Unlabelled devices happen when permission was granted for a
                    different origin — number them so they stay tellable apart. */}
                <span className="truncate">{device.label || `Camera ${index + 1}`}</span>
              </DropdownMenuRadioItem>
            ))}
          </DropdownMenuRadioGroup>
        )}
        {localCameraEnabled && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => void handleTurnOff()}>
              <VideoOff className="size-4" /> Turn off camera
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
