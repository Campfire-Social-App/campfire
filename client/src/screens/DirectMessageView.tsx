import { Phone, Video } from "lucide-react";
import { ChatPane } from "@/components/ChatPane";
import { DirectCallPanel } from "@/components/DirectCallPanel";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useCallsStore } from "@/state/calls";
import { usePresenceStore } from "@/state/presence";
import { useVoiceStore } from "@/state/voice";
import { startCall } from "@/lib/calls";
import { ApiError, type DMConversation } from "@/lib/types";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface DirectMessageViewProps {
  conversation: DMConversation;
}

export function DirectMessageView({ conversation }: DirectMessageViewProps) {
  const isOnline = usePresenceStore((s) => !!s.onlineUserIds[conversation.recipient.id]);
  const inThisCall = useVoiceStore((s) => s.connectedChannelId === conversation.id);
  const isRinging = useCallsStore((s) => s.outgoing === conversation.id);
  const { username } = conversation.recipient;

  // While a call is up (or ringing), the panel owns it — a second "call" button
  // in the header would just be another way to start the one already running.
  const canStartCall = !inThisCall && !isRinging;

  const handleStartCall = async (video: boolean) => {
    try {
      await startCall(conversation.id, { video });
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Couldn't start the call.");
    }
  };

  return (
    <ChatPane
      channelId={conversation.id}
      composerPlaceholder={`Message @${username}`}
      header={
        <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
          <UserAvatar
            username={username}
            size="sm"
            status={isOnline ? "online" : "offline"}
          />
          <span className="font-heading text-sm font-semibold text-foreground">{username}</span>
          <span className="text-xs text-muted-foreground">{isOnline ? "Online" : "Offline"}</span>

          {canStartCall && (
            <div className="ml-auto flex items-center gap-1">
              <CallButton label={`Call ${username}`} onClick={() => void handleStartCall(false)}>
                <Phone className="size-4" />
              </CallButton>
              <CallButton
                label={`Video call ${username}`}
                onClick={() => void handleStartCall(true)}
              >
                <Video className="size-4" />
              </CallButton>
            </div>
          )}
        </header>
      }
      banner={<DirectCallPanel conversation={conversation} />}
      empty={
        <div className="flex h-full flex-col items-center justify-center gap-2 px-8 text-center">
          <UserAvatar username={username} size="lg" />
          <p className={cn("font-heading text-lg font-semibold", usernameColorFor(username))}>
            {username}
          </p>
          <p className="text-sm text-muted-foreground">
            This is the beginning of your direct messages with {username}.
          </p>
        </div>
      }
    />
  );
}

function CallButton({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          onClick={onClick}
          className="flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground"
        >
          {children}
        </button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}
