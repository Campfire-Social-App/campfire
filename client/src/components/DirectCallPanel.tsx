import { useMemo } from "react";
import { Mic, MicOff, Phone, PhoneOff, ScreenShare, ScreenShareOff, Video, VideoOff } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { TileVisual, buildTiles, type CallTile } from "@/components/CallTiles";
import { ScreenShareAudioMenu } from "@/components/ScreenShareAudioMenu";
import { useAuthStore } from "@/state/auth";
import { useCallsStore } from "@/state/calls";
import { usePresenceStore } from "@/state/presence";
import { useVoiceStore } from "@/state/voice";
import {
  joinVoiceChannel,
  setCameraEnabled,
  setMicrophoneMuted,
  requestScreenShare,
  stopScreenShare,
  setScreenShareViewing,
} from "@/livekit/voice";
import { hangUp } from "@/lib/calls";
import { ApiError, type DMConversation } from "@/lib/types";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface DirectCallPanelProps {
  conversation: DMConversation;
}

/** The call stage inside a conversation. Sits between the DM header and the
 * message list, so a call never takes the chat away — you can keep typing while
 * it runs. Renders nothing at all when there's no call to show. */
export function DirectCallPanel({ conversation }: DirectCallPanelProps) {
  const participants = useVoiceStore(useShallow((s) => s.participantsInChannel(conversation.id)));
  const cameraTracks = useVoiceStore((s) => s.cameraTracks);
  const screenShareTracks = useVoiceStore((s) => s.screenShareTracks);
  const availableScreenShares = useVoiceStore((s) => s.availableScreenShares);
  const viewingScreenShares = useVoiceStore((s) => s.viewingScreenShares);
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const speakingUserIds = useVoiceStore((s) => s.speakingUserIds);
  const localMuted = useVoiceStore((s) => s.localMuted);
  const localCameraEnabled = useVoiceStore((s) => s.localCameraEnabled);
  const localScreenShareEnabled = useVoiceStore((s) => s.localScreenShareEnabled);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);
  const ownUserId = useAuthStore((s) => s.user?.id);
  const isRinging = useCallsStore((s) => s.outgoing === conversation.id);

  const inThisCall = connectedChannelId === conversation.id;
  const tiles = useMemo<CallTile[]>(
    () =>
      buildTiles(
        participants,
        inThisCall ? cameraTracks : {},
        inThisCall ? screenShareTracks : {},
        inThisCall ? availableScreenShares : {},
        inThisCall ? viewingScreenShares : {},
      ),
    [
      participants,
      cameraTracks,
      screenShareTracks,
      availableScreenShares,
      viewingScreenShares,
      inThisCall,
    ],
  );

  // Someone is in the room without us: a call we left, or one we declined and
  // they stayed on. Offer the way back in rather than pretending it's over.
  const callInProgressElsewhere = !inThisCall && participants.length > 0;
  if (!inThisCall && !isRinging && !callInProgressElsewhere) return null;

  const handleToggleCamera = async () => {
    try {
      await setCameraEnabled(!localCameraEnabled);
    } catch {
      toast.error("Couldn't access the camera.");
    }
  };

  const handleToggleScreenShare = async () => {
    try {
      if (localScreenShareEnabled) await stopScreenShare();
      else await requestScreenShare();
    } catch (err) {
      // Dismissing the browser's share picker rejects too — not a real failure.
      if (err instanceof DOMException && err.name === "NotAllowedError") return;
      toast.error("Couldn't share the screen.");
    }
  };

  const handleJoin = async () => {
    try {
      await joinVoiceChannel(conversation.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Couldn't join the call.");
    }
  };

  const status = isRinging
    ? `Ringing ${conversation.recipient.username}…`
    : connectionStatus === "connecting"
      ? "Connecting…"
      : inThisCall
        ? "In call"
        : `${conversation.recipient.username} is on a call`;

  const columns = Math.min(3, Math.max(1, tiles.length));

  return (
    <div className="shrink-0 border-b border-glass-border bg-glass/40 px-4 py-3">
      <div className="flex items-center justify-between gap-3">
        <p className="flex items-center gap-2 text-sm font-medium text-foreground">
          <Phone className={cn("size-4 text-primary", isRinging && "animate-pulse")} />
          {status}
        </p>

        <div className="flex items-center gap-1.5">
          {inThisCall ? (
            <>
              <CallControl
                active={localMuted}
                onClick={() => void setMicrophoneMuted(!localMuted)}
                label={localMuted ? "Unmute microphone" : "Mute microphone"}
              >
                {localMuted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
              </CallControl>
              <CallControl
                active={localCameraEnabled}
                activeClassName="bg-primary/15 text-primary"
                onClick={() => void handleToggleCamera()}
                label={localCameraEnabled ? "Turn off camera" : "Turn on camera"}
              >
                {localCameraEnabled ? <Video className="size-4" /> : <VideoOff className="size-4" />}
              </CallControl>
              <CallControl
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
              </CallControl>
            </>
          ) : (
            <Button size="sm" onClick={() => void handleJoin()}>
              <Phone className="size-4" /> Join call
            </Button>
          )}

          {(inThisCall || isRinging) && (
            <Tooltip>
              <TooltipTrigger asChild>
                <button
                  onClick={() => void hangUp(conversation.id)}
                  className="ml-1 flex size-8 items-center justify-center rounded-full bg-destructive/90 text-white transition-colors hover:bg-destructive"
                >
                  <PhoneOff className="size-4" />
                </button>
              </TooltipTrigger>
              <TooltipContent>{isRinging ? "Cancel call" : "Hang up"}</TooltipContent>
            </Tooltip>
          )}
        </div>
      </div>

      {inThisCall && tiles.length > 0 && (
        <div
          className="mt-3 grid gap-2"
          style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}
        >
          {tiles.map((tile) => (
            <ScreenShareAudioMenu
              key={tile.key}
              userId={tile.participant.user_id}
              username={tile.participant.username}
              disabled={tile.kind !== "screen" || tile.participant.user_id === ownUserId}
            >
              <div
                className={cn(
                  "relative aspect-video max-h-52 overflow-hidden rounded-xl bg-glass ring-2 ring-glass-border transition-all",
                  tile.kind === "camera" &&
                    speakingUserIds[tile.participant.user_id] &&
                    "ring-primary shadow-[0_0_16px_1px_rgba(255,122,61,0.4)]",
                )}
              >
                <TileVisual
                  tile={tile}
                  isOwn={tile.participant.user_id === ownUserId}
                  online={!!onlineUserIds[tile.participant.user_id]}
                  onWatchScreenShare={() =>
                    setScreenShareViewing(tile.participant.user_id, true)
                  }
                />
              </div>
            </ScreenShareAudioMenu>
          ))}
        </div>
      )}
    </div>
  );
}

function CallControl({
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
            "flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground",
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
