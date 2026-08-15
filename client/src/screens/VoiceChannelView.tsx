import { useEffect, useRef } from "react";
import { LogIn, Mic, MicOff, MonitorPlay, Volume2 } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/UserAvatar";
import { useVoiceStore, type VideoTrack } from "@/state/voice";
import { usePresenceStore } from "@/state/presence";
import { useAuthStore } from "@/state/auth";
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
  const cameraTracks = useVoiceStore((s) => s.cameraTracks);
  const screenShareTracks = useVoiceStore((s) => s.screenShareTracks);
  const connectedChannelId = useVoiceStore((s) => s.connectedChannelId);
  const connectionStatus = useVoiceStore((s) => s.connectionStatus);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);
  const ownUserId = useAuthStore((s) => s.user?.id);

  const isThisChannelConnected = connectedChannelId === channel.id;
  const screenShares = isThisChannelConnected
    ? participants.filter((p) => screenShareTracks[p.user_id])
    : [];

  const handleJoin = async () => {
    try {
      await joinVoiceChannel(channel.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to join the voice channel.");
    }
  };

  return (
    <div className="flex min-w-0 flex-1 flex-col">
      <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
        <Volume2 className="size-5 text-muted-foreground" />
        <span className="font-semibold text-foreground">{channel.name}</span>
      </header>

      <div className="flex flex-1 flex-col items-center justify-center gap-6 overflow-y-auto p-8">
        {participants.length === 0 ? (
          <div className="flex flex-col items-center gap-3 text-center">
            <Volume2 className="size-12 text-muted-foreground" />
            <p className="text-muted-foreground">No one is in the voice channel.</p>
            {!isThisChannelConnected && (
              <Button onClick={() => void handleJoin()}>
                <LogIn className="size-4" /> Join channel
              </Button>
            )}
          </div>
        ) : (
          <>
            {screenShares.length > 0 && (
              <div className="flex w-full max-w-4xl flex-col gap-4">
                {screenShares.map((p) => (
                  <div key={p.user_id} className="flex flex-col gap-1.5">
                    <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
                      <MonitorPlay className="size-4 text-primary" />
                      {p.username} is sharing their screen
                    </div>
                    <div className="overflow-hidden rounded-xl border border-border bg-black shadow-lg">
                      <VideoTile track={screenShareTracks[p.user_id]} className="max-h-[60vh] w-full" />
                    </div>
                  </div>
                ))}
              </div>
            )}

            <div className="grid grid-cols-2 gap-8 sm:grid-cols-3 md:grid-cols-4">
              {participants.map((p) => {
                const cameraTrack = cameraTracks[p.user_id];
                return (
                  <div key={p.user_id} className="flex flex-col items-center gap-2">
                    {cameraTrack ? (
                      <div
                        className={cn(
                          "size-32 overflow-hidden rounded-xl bg-black ring-4 ring-transparent transition-all",
                          speakingUserIds[p.user_id] &&
                            "ring-primary shadow-[0_0_20px_2px_rgba(255,122,61,0.45)]",
                        )}
                      >
                        <VideoTile
                          track={cameraTrack}
                          className="size-full object-cover"
                          mirror={p.user_id === ownUserId}
                        />
                      </div>
                    ) : (
                      <div
                        className={cn(
                          "flex size-20 items-center justify-center rounded-full ring-4 ring-transparent transition-all",
                          speakingUserIds[p.user_id] &&
                            "ring-primary shadow-[0_0_20px_2px_rgba(255,122,61,0.45)]",
                        )}
                      >
                        <UserAvatar
                          username={p.username}
                          size="lg"
                          status={onlineUserIds[p.user_id] ? "online" : "offline"}
                          className="size-20 *:text-2xl"
                        />
                      </div>
                    )}
                    <div className="flex items-center gap-1.5">
                      {p.muted ? (
                        <MicOff className="size-3.5 text-destructive" />
                      ) : (
                        <Mic className="size-3.5 text-muted-foreground" />
                      )}
                      <span className="text-sm text-foreground">{p.username}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}

        {!isThisChannelConnected && connectionStatus !== "connecting" && participants.length > 0 && (
          <Button onClick={() => void handleJoin()}>
            <LogIn className="size-4" /> Join channel
          </Button>
        )}
      </div>
    </div>
  );
}

function VideoTile({
  track,
  className,
  mirror,
}: {
  track: VideoTrack;
  className?: string;
  mirror?: boolean;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;
    track.attach(el);
    return () => {
      track.detach(el);
    };
  }, [track]);

  return (
    <video
      ref={videoRef}
      autoPlay
      playsInline
      muted
      className={cn(mirror && "-scale-x-100", className)}
    />
  );
}
