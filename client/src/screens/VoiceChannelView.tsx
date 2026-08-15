import { LogIn, Mic, MicOff, Volume2 } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/UserAvatar";
import { useVoiceStore } from "@/state/voice";
import { usePresenceStore } from "@/state/presence";
import { joinVoiceChannel } from "@/livekit/voice";
import type { Channel } from "@/lib/types";
import { toast } from "sonner";
import { ApiError } from "@/lib/types";
import { cn } from "@/lib/utils";

interface VoiceChannelViewProps {
  channel: Channel;
}

export function VoiceChannelView({ channel }: VoiceChannelViewProps) {
  const participants = useVoiceStore(useShallow((s) => s.participantsInChannel(channel.id)));
  const speakingUserIds = useVoiceStore((s) => s.speakingUserIds);
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);

  const isThisChannelConnected = connectedChannelId === channel.id;

  const handleJoin = async () => {
    try {
      await joinVoiceChannel(channel.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Falha ao entrar no canal de voz.");
    }
  };

  return (
    <div className="flex min-w-0 flex-1 flex-col">
      <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
        <Volume2 className="size-5 text-muted-foreground" />
        <span className="font-semibold text-foreground">{channel.name}</span>
      </header>

      <div className="flex flex-1 flex-col items-center justify-center gap-6 p-8">
        {participants.length === 0 ? (
          <div className="flex flex-col items-center gap-3 text-center">
            <Volume2 className="size-12 text-muted-foreground" />
            <p className="text-muted-foreground">Ninguém está no canal de voz.</p>
            {!isThisChannelConnected && (
              <Button onClick={() => void handleJoin()}>
                <LogIn className="size-4" /> Entrar no canal
              </Button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-8 sm:grid-cols-3 md:grid-cols-4">
            {participants.map((p) => (
              <div key={p.user_id} className="flex flex-col items-center gap-2">
                <div
                  className={cn(
                    "flex size-20 items-center justify-center rounded-full ring-4 ring-transparent transition-all",
                    speakingUserIds[p.user_id] && "ring-online",
                  )}
                >
                  <UserAvatar
                    username={p.username}
                    size="lg"
                    status={onlineUserIds[p.user_id] ? "online" : "offline"}
                    className="size-20 *:text-2xl"
                  />
                </div>
                <div className="flex items-center gap-1.5">
                  {p.muted ? (
                    <MicOff className="size-3.5 text-destructive" />
                  ) : (
                    <Mic className="size-3.5 text-muted-foreground" />
                  )}
                  <span className="text-sm text-foreground">{p.username}</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {!isThisChannelConnected && connectionStatus !== "connecting" && participants.length > 0 && (
          <Button onClick={() => void handleJoin()}>
            <LogIn className="size-4" /> Entrar no canal
          </Button>
        )}
      </div>
    </div>
  );
}
