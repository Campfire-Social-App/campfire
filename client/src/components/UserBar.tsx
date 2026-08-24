import { useState } from "react";
import {
  Headphones,
  Mic,
  MicOff,
  PhoneOff,
  Repeat,
  ScreenShare,
  ScreenShareOff,
  Settings,
  Video,
  VideoOff,
  VolumeX,
  Wifi,
  UserRound,
  AudioLines,
} from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
import { UserProfileHoverCard } from "@/components/UserProfileHoverCard";
import { ProfileDialog } from "@/components/ProfileDialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { useVoiceStore } from "@/state/voice";
import { useChannelsStore } from "@/state/channels";
import { useDmsStore } from "@/state/dms";
import {
  leaveVoiceChannel,
  setCameraEnabled,
  setDeafened,
  setMicrophoneMuted,
  requestScreenShare,
  stopScreenShare,
  applyNoiseSuppression,
} from "@/livekit/voice";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

export function UserBar() {
  const [profileOpen, setProfileOpen] = useState(false);
  const user = useAuthStore((s) => s.user);
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const localMuted = useVoiceStore((s) => s.localMuted);
  const localDeafened = useVoiceStore((s) => s.localDeafened);
  const localCameraEnabled = useVoiceStore((s) => s.localCameraEnabled);
  const localScreenShareEnabled = useVoiceStore((s) => s.localScreenShareEnabled);
  const noiseSuppressionEnabled = useSettingsStore((s) => s.noiseSuppressionEnabled);
  const channelName = useChannelsStore(
    (s) => s.channels.find((c) => c.id === connectedChannelId)?.name,
  );
  // A DM call's room is the conversation, which has no channel name — label it
  // with whoever is on the other end instead.
  const dmRecipient = useDmsStore(
    (s) => s.conversations.find((c) => c.id === connectedChannelId)?.recipient.username,
  );
  const inVoice = connectionStatus !== "disconnected";
  const connected = connectionStatus === "connected";

  const handleToggleCamera = async () => {
    try {
      await setCameraEnabled(!localCameraEnabled);
    } catch {
      toast.error("Couldn't access the camera.");
    }
  };

  // Volta para o começo do fluxo: sem servidor configurado o App cai na
  // ServerConnectScreen e, depois dela, no login — que é onde se troca de conta
  // e de servidor. Sair da sala antes disso faz o SFU ver uma desconexão limpa
  // em vez de esperar o timeout do participante.
  const handleSwitchAccount = async () => {
    if (inVoice) await leaveVoiceChannel();
    useAuthStore.getState().logout();
    useSettingsStore.getState().clearServerUrl();
  };

  const handleToggleScreenShare = async () => {
    try {
      if (localScreenShareEnabled) await stopScreenShare();
      else await requestScreenShare();
    } catch (err) {
      // Cancelling the browser's share picker also rejects with NotAllowedError — not a real error.
      if (err instanceof DOMException && err.name === "NotAllowedError") return;
      toast.error("Couldn't share the screen.");
    }
  };

  const handleNoiseSuppression = async (enabled: boolean) => {
    useSettingsStore.getState().setNoiseSuppressionEnabled(enabled);
    try {
      await applyNoiseSuppression(enabled);
    } catch {
      // Preserve the preference for the next capture even if this device cannot
      // change constraints on a microphone that is already running.
      toast.error("Noise suppression will be applied the next time the microphone starts.");
    }
  };

  if (!user) return null;

  return (
    <div className="shrink-0 px-3 pb-6">
      {/* Same bottom inset and border-only (no fill) treatment as the message
          composer, so the two floating panels align and read as one system
          instead of the card popping out against the translucent sidebar. */}
      <div className="overflow-hidden rounded-[14px] border border-glass-border">
        {inVoice && (
          <div className="flex items-center justify-between gap-2 px-3 py-2.5">
            <div className="min-w-0">
              <p className="flex items-center gap-1.5 text-sm font-medium text-online">
                <Wifi className="size-3.5 shrink-0" />
                {connectionStatus === "connecting"
                  ? "Connecting…"
                  : dmRecipient
                    ? "In call"
                    : "Voice connected"}
              </p>
              <p className="mt-0.5 truncate text-xs text-muted-foreground">
                {channelName ?? dmRecipient ?? ""}
              </p>
            </div>
            <div className="flex shrink-0 items-center gap-1.5">
              <Tooltip>
                <TooltipTrigger asChild>
                  <button
                    onClick={() => void leaveVoiceChannel()}
                    className="flex size-8 shrink-0 items-center justify-center rounded-full text-muted-foreground hover:bg-destructive/15 hover:text-destructive"
                  >
                    <PhoneOff className="size-4" />
                  </button>
                </TooltipTrigger>
                <TooltipContent>Disconnect</TooltipContent>
              </Tooltip>
            </div>
          </div>
        )}

        {connected && (
          <div className="grid grid-cols-2 gap-1.5 px-2.5 pb-2.5">
            <MediaTile
              active={localCameraEnabled}
              onClick={() => void handleToggleCamera()}
              label={localCameraEnabled ? "Turn off camera" : "Turn on camera"}
            >
              {localCameraEnabled ? <Video className="size-4" /> : <VideoOff className="size-4" />}
            </MediaTile>
            <MediaTile
              active={localScreenShareEnabled}
              onClick={() => void handleToggleScreenShare()}
              label={localScreenShareEnabled ? "Stop screen share" : "Share screen"}
            >
              {localScreenShareEnabled ? (
                <ScreenShare className="size-4" />
              ) : (
                <ScreenShareOff className="size-4" />
              )}
            </MediaTile>
          </div>
        )}

        <div
          className={cn(
            // Fixed to the composer's own rendered height (rather than
            // letting padding+content derive it) so the two floating panels'
            // top edges land flush too, not just their bottom edges.
            "flex h-14.5 items-center gap-2 px-2.5",
            inVoice && "border-t border-glass-border",
          )}
        >
          <UserProfileHoverCard user={user}>
            <div className="flex min-w-0 flex-1 items-center gap-2">
              <UserAvatar username={user.username} avatarUrl={user.avatar_url} size="sm" />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-foreground">{user.username}</p>
                <p className="truncate text-xs text-muted-foreground">
                  {user.is_admin ? "Admin" : "Member"}
                </p>
              </div>
            </div>
          </UserProfileHoverCard>

          <IconToggle
            active={localMuted}
            onClick={() => void setMicrophoneMuted(!localMuted)}
            label={localMuted ? "Unmute microphone" : "Mute microphone"}
          >
            {localMuted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
          </IconToggle>

          <IconToggle
            active={localDeafened}
            onClick={() => void setDeafened(!localDeafened)}
            label={localDeafened ? "Undeafen" : "Deafen"}
          >
            {localDeafened ? <VolumeX className="size-4" /> : <Headphones className="size-4" />}
          </IconToggle>

          <DropdownMenu>
            <Tooltip>
              <TooltipTrigger asChild>
                <DropdownMenuTrigger asChild>
                  <button
                    aria-label="Settings"
                    className="flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-white/10 hover:text-foreground data-open:bg-white/10 data-open:text-foreground"
                  >
                    <Settings className="size-4" />
                  </button>
                </DropdownMenuTrigger>
              </TooltipTrigger>
              <TooltipContent>Settings</TooltipContent>
            </Tooltip>
            {/* Para cima e alinhado à direita: a barra mora no rodapé da sidebar. */}
            <DropdownMenuContent side="top" align="end" className="w-56">
              <DropdownMenuCheckboxItem
                checked={noiseSuppressionEnabled}
                onCheckedChange={(checked) => void handleNoiseSuppression(checked === true)}
                onSelect={(event) => event.preventDefault()}
              >
                <AudioLines className="size-4" /> Noise suppression
              </DropdownMenuCheckboxItem>
              <DropdownMenuItem onSelect={() => setProfileOpen(true)}>
                <UserRound className="size-4" /> Profile
              </DropdownMenuItem>
              <DropdownMenuItem onSelect={() => void handleSwitchAccount()}>
                <Repeat className="size-4" /> Switch account
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <ProfileDialog open={profileOpen} onOpenChange={setProfileOpen} />
        </div>
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

function MediaTile({
  active,
  onClick,
  label,
  children,
}: {
  active: boolean;
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
            "flex items-center justify-center rounded-lg bg-white/5 py-2 text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground",
            active && "bg-primary/15 text-primary hover:bg-primary/20",
          )}
        >
          {children}
        </button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}
