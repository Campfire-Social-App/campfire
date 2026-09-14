import { Headphones, VolumeX, Mic, MicOff, Phone, PhoneOff, ScreenShare, ScreenShareOff, Video, VideoOff } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { CallStage } from "@/components/CallStage";
import { AudioDeviceMenu } from "@/components/AudioDeviceMenu";
import { useCallsStore } from "@/state/calls";
import { useVoiceStore } from "@/state/voice";
import {
  joinVoiceChannel,
  setCameraEnabled,
  setDeafened,
  setMicrophoneMuted,
  requestScreenShare,
  stopScreenShare,
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
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const localDeafened = useVoiceStore((s) => s.localDeafened);
  const localMuted = useVoiceStore((s) => s.localMuted);
  const localCameraEnabled = useVoiceStore((s) => s.localCameraEnabled);
  const localScreenShareEnabled = useVoiceStore((s) => s.localScreenShareEnabled);
  const isRinging = useCallsStore((s) => s.outgoing === conversation.id);

  const inThisCall = connectedChannelId === conversation.id;
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
    if (localScreenShareEnabled) {
      await stopScreenShare().catch(() => {
        toast.error("Couldn't stop sharing the screen.");
      });
      return;
    }
    try {
      await requestScreenShare();
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
      : inThisCall && connectionStatus === "reconnecting"
        ? "Reconnecting…"
      : inThisCall
        ? "In call"
        : `${conversation.recipient.username} is on a call`;

  return (
    <div className="group/call shrink-0 max-h-[65vh] overflow-y-auto border-b border-glass-border bg-glass/40 px-4 py-3">
      <div className="flex items-center justify-between gap-3">
        <p className="flex items-center gap-2 text-sm font-medium text-foreground">
          <Phone className={cn("size-4 text-primary", isRinging && "animate-pulse")} />
          {status}
        </p>
      </div>
      {inThisCall && <CallStage channelId={conversation.id} compact />}
      <div
        role="group"
        aria-label="Call controls"
        className="mt-3 flex items-center justify-center gap-1.5 opacity-0 pointer-events-none transition-opacity duration-200 group-hover/call:pointer-events-auto group-hover/call:opacity-100 focus-within:pointer-events-auto focus-within:opacity-100 has-[[data-state=open]]:pointer-events-auto has-[[data-state=open]]:opacity-100 [@media(hover:none)]:pointer-events-auto [@media(hover:none)]:opacity-100"
      >
        {inThisCall ? (
          <>
            <div className="flex items-center">
              <CallControl
                active={localMuted}
                onClick={() => void setMicrophoneMuted(!localMuted)}
                label={localMuted ? "Unmute microphone" : "Mute microphone"}
              >
                {localMuted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
              </CallControl>
              <AudioDeviceMenu kind="input" />
            </div>
            <div className="flex items-center">
              <CallControl
                active={localDeafened}
                onClick={() => void setDeafened(!localDeafened)}
                label={localDeafened ? "Undeafen" : "Deafen"}
              >
                {localDeafened ? <VolumeX className="size-4" /> : <Headphones className="size-4" />}
              </CallControl>
              <AudioDeviceMenu kind="output" />
            </div>
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
              label={localScreenShareEnabled ? "Stop screen sharing" : "Share screen"}
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
                type="button"
                aria-label={isRinging ? "Cancel call" : "Hang up"}
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
          type="button"
          aria-label={label}
          aria-pressed={active}
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
