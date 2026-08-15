import {
  Headphones,
  Mic,
  MicOff,
  PhoneOff,
  ScreenShare,
  ScreenShareOff,
  Settings,
  Video,
  VideoOff,
  VolumeX,
} from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useAuthStore } from "@/state/auth";
import { useVoiceStore } from "@/state/voice";
import { useChannelsStore } from "@/state/channels";
import {
  leaveVoiceChannel,
  setCameraEnabled,
  setDeafened,
  setMicrophoneMuted,
  setScreenShareEnabled,
} from "@/livekit/voice";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

export function UserBar() {
  const user = useAuthStore((s) => s.user);
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const localMuted = useVoiceStore((s) => s.localMuted);
  const localDeafened = useVoiceStore((s) => s.localDeafened);
  const localCameraEnabled = useVoiceStore((s) => s.localCameraEnabled);
  const localScreenShareEnabled = useVoiceStore((s) => s.localScreenShareEnabled);
  const channelName = useChannelsStore(
    (s) => s.channels.find((c) => c.id === connectedChannelId)?.name,
  );
  const connected = connectionStatus === "connected";

  const handleToggleCamera = async () => {
    try {
      await setCameraEnabled(!localCameraEnabled);
    } catch {
      toast.error("Couldn't access the camera.");
    }
  };

  const handleToggleScreenShare = async () => {
    try {
      await setScreenShareEnabled(!localScreenShareEnabled);
    } catch (err) {
      // Cancelling the browser's share picker also rejects with NotAllowedError — not a real error.
      if (err instanceof DOMException && err.name === "NotAllowedError") return;
      toast.error("Couldn't share the screen.");
    }
  };

  if (!user) return null;

  return (
    <div className="shrink-0 border-t border-sidebar-border">
      {connectionStatus !== "disconnected" && (
        <div className="flex items-center justify-between gap-2 bg-sidebar-accent px-3 py-2">
          <div className="min-w-0">
            <p className="flex items-center gap-1.5 text-sm font-medium text-online">
              <span className="size-2 shrink-0 rounded-full bg-online" />
              {connectionStatus === "connecting" ? "Connecting…" : "Voice connected"}
            </p>
            <p className="truncate text-xs text-muted-foreground">{channelName ?? ""}</p>
          </div>
          <Tooltip>
            <TooltipTrigger asChild>
              <button
                onClick={() => void leaveVoiceChannel()}
                className="flex size-8 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-white/10 hover:text-destructive"
              >
                <PhoneOff className="size-4" />
              </button>
            </TooltipTrigger>
            <TooltipContent>Disconnect</TooltipContent>
          </Tooltip>
        </div>
      )}

      <div className="flex items-center gap-2 px-2 py-2">
        <UserAvatar username={user.username} size="sm" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium text-foreground">{user.username}</p>
          <p className="truncate text-xs text-muted-foreground">
            {user.is_admin ? "Admin" : "Member"}
          </p>
        </div>

        <IconToggle
          active={localMuted}
          onClick={() => void setMicrophoneMuted(!localMuted)}
          label={localMuted ? "Unmute microphone" : "Mute microphone"}
        >
          {localMuted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
        </IconToggle>

        <IconToggle
          active={localDeafened}
          onClick={() => setDeafened(!localDeafened)}
          label={localDeafened ? "Undeafen" : "Deafen"}
        >
          {localDeafened ? <VolumeX className="size-4" /> : <Headphones className="size-4" />}
        </IconToggle>

        {connected && (
          <IconToggle
            active={localCameraEnabled}
            activeClassName="bg-primary/15 text-primary"
            onClick={() => void handleToggleCamera()}
            label={localCameraEnabled ? "Turn off camera" : "Turn on camera"}
          >
            {localCameraEnabled ? <Video className="size-4" /> : <VideoOff className="size-4" />}
          </IconToggle>
        )}

        {connected && (
          <IconToggle
            active={localScreenShareEnabled}
            activeClassName="bg-primary/15 text-primary"
            onClick={() => void handleToggleScreenShare()}
            label={localScreenShareEnabled ? "Stop screen share" : "Share screen"}
          >
            {localScreenShareEnabled ? (
              <ScreenShare className="size-4" />
            ) : (
              <ScreenShareOff className="size-4" />
            )}
          </IconToggle>
        )}

        <Tooltip>
          <TooltipTrigger asChild>
            <button className="flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-white/10 hover:text-foreground">
              <Settings className="size-4" />
            </button>
          </TooltipTrigger>
          <TooltipContent>Settings</TooltipContent>
        </Tooltip>
      </div>
    </div>
  );
}

function IconToggle({
  active,
  activeClassName = "bg-white/10 text-destructive",
  onClick,
  label,
  children,
}: {
  active: boolean;
  activeClassName?: string;
  onClick: () => void;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          onClick={onClick}
          className={cn(
            "flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-white/10 hover:text-foreground",
            active && activeClassName,
          )}
        >
          {children}
        </button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}
