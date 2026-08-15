import { useEffect, useMemo, useRef, useState } from "react";
import { LogIn, Maximize2, Mic, MicOff, MonitorPlay, Volume2, X } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/UserAvatar";
import { useVoiceStore, type VideoTrack } from "@/state/voice";
import { usePresenceStore } from "@/state/presence";
import { useAuthStore } from "@/state/auth";
import { joinVoiceChannel } from "@/livekit/voice";
import type { Channel, VoiceParticipantState } from "@/lib/types";
import { toast } from "sonner";
import { ApiError } from "@/lib/types";
import { cn } from "@/lib/utils";

interface VoiceChannelViewProps {
  channel: Channel;
}

interface Tile {
  key: string;
  kind: "camera" | "screen";
  participant: VoiceParticipantState;
  track: VideoTrack | null;
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
  const [focusedKey, setFocusedKey] = useState<string | null>(null);

  const isThisChannelConnected = connectedChannelId === channel.id;

  const tiles = useMemo<Tile[]>(() => {
    const camTracks = isThisChannelConnected ? cameraTracks : {};
    const scrTracks = isThisChannelConnected ? screenShareTracks : {};
    return participants.flatMap((p) => {
      const tile: Tile = { key: `cam:${p.user_id}`, kind: "camera", participant: p, track: camTracks[p.user_id] ?? null };
      const screenTrack = scrTracks[p.user_id];
      if (!screenTrack) return [tile];
      return [tile, { key: `scr:${p.user_id}`, kind: "screen", participant: p, track: screenTrack } satisfies Tile];
    });
  }, [participants, cameraTracks, screenShareTracks, isThisChannelConnected]);

  const focusedTile = tiles.find((t) => t.key === focusedKey) ?? null;
  useEffect(() => {
    if (focusedKey && !focusedTile) setFocusedKey(null);
  }, [focusedKey, focusedTile]);

  const [focusedRatio, setFocusedRatio] = useState(16 / 9);
  const focusTile = (key: string) => {
    setFocusedKey(key);
    setFocusedRatio(16 / 9);
  };

  const columns = Math.min(4, Math.max(1, Math.ceil(Math.sqrt(tiles.length))));

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
        <span className="font-heading text-sm font-semibold text-foreground">{channel.name}</span>
      </header>

      <div className="flex flex-1 flex-col items-center justify-center gap-5 overflow-y-auto p-6">
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
        ) : focusedTile ? (
          <div className="flex w-full max-w-6xl flex-1 flex-col gap-4">
            <div
              className="flex min-h-0 flex-1 items-center justify-center"
              style={{ containerType: "size" }}
            >
              {/* Sized to the fitted box rather than the full area: the width is
                  whichever of the two limits binds first, so the box always lands
                  exactly on the source's own ratio — no letterbox bars to hide and
                  nothing cropped off the edges. */}
              <div
                className="relative overflow-hidden rounded-2xl border border-glass-border bg-black shadow-2xl"
                style={{
                  aspectRatio: focusedRatio,
                  width: `min(100cqw, ${focusedRatio} * 100cqh)`,
                }}
              >
                <TileVisual
                  tile={focusedTile}
                  isOwn={focusedTile.participant.user_id === ownUserId}
                  online={!!onlineUserIds[focusedTile.participant.user_id]}
                  large
                  onAspectRatio={setFocusedRatio}
                />
                <button
                  type="button"
                  onClick={() => setFocusedKey(null)}
                  className="absolute top-3 right-3 flex size-8 cursor-pointer items-center justify-center rounded-full border border-white/10 bg-black/50 text-white backdrop-blur-sm transition-colors hover:bg-black/70"
                >
                  <X className="size-4" />
                </button>
              </div>
            </div>
            {tiles.length > 1 && (
              <div className="flex shrink-0 gap-2 overflow-x-auto pb-1">
                {tiles.map((tile) => (
                  <button
                    key={tile.key}
                    type="button"
                    onClick={() => focusTile(tile.key)}
                    className={cn(
                      "aspect-video h-28 shrink-0 cursor-pointer overflow-hidden rounded-lg border-2 bg-glass transition-all",
                      tile.key === focusedTile.key
                        ? "border-primary"
                        : "border-glass-border opacity-70 hover:border-ember-tint-border/60 hover:opacity-100",
                    )}
                  >
                    <TileVisual
                      tile={tile}
                      isOwn={tile.participant.user_id === ownUserId}
                      online={!!onlineUserIds[tile.participant.user_id]}
                      compact
                    />
                  </button>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div
            className="grid w-full max-w-6xl gap-3"
            style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}
          >
            {tiles.map((tile) => (
              <button
                key={tile.key}
                type="button"
                onClick={() => focusTile(tile.key)}
                className={cn(
                  "group relative aspect-video cursor-pointer overflow-hidden rounded-xl bg-glass ring-2 ring-glass-border transition-all hover:ring-ember-tint-border/60",
                  tile.kind === "camera" &&
                    speakingUserIds[tile.participant.user_id] &&
                    "ring-4 ring-primary shadow-[0_0_20px_2px_rgba(255,122,61,0.45)]",
                )}
              >
                <TileVisual
                  tile={tile}
                  isOwn={tile.participant.user_id === ownUserId}
                  online={!!onlineUserIds[tile.participant.user_id]}
                />
                <div className="pointer-events-none absolute inset-0 bg-black/0 transition-colors group-hover:bg-black/10" />
                <div className="pointer-events-none absolute top-2 right-2 flex size-6 items-center justify-center rounded-full border border-white/10 bg-black/50 opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100">
                  <Maximize2 className="size-3.5 text-white" />
                </div>
              </button>
            ))}
          </div>
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

function TileVisual({
  tile,
  isOwn,
  online,
  large,
  compact,
  onAspectRatio,
}: {
  tile: Tile;
  isOwn: boolean;
  online: boolean;
  large?: boolean;
  compact?: boolean;
  onAspectRatio?: (ratio: number) => void;
}) {
  const isScreen = tile.kind === "screen";

  return (
    <div className="relative size-full">
      {tile.track ? (
        <VideoTile
          track={tile.track}
          className="size-full bg-black object-contain"
          mirror={!isScreen && isOwn}
          onAspectRatio={onAspectRatio}
        />
      ) : (
        <div className="flex size-full items-center justify-center bg-linear-to-br from-muted to-muted/60">
          <UserAvatar
            username={tile.participant.username}
            size={large ? "lg" : "default"}
            status={compact ? undefined : online ? "online" : "offline"}
            className={cn(
              large ? "size-32 *:text-4xl" : compact ? "size-10 *:text-base" : "size-24 *:text-2xl",
            )}
          />
        </div>
      )}

      {!compact && (
        <div className="absolute inset-x-0 bottom-0 flex items-center gap-1.5 bg-linear-to-t from-black/70 to-transparent px-2.5 py-2">
          {isScreen ? (
            <MonitorPlay className="size-3.5 text-white" />
          ) : tile.participant.muted ? (
            <MicOff className="size-3.5 text-destructive" />
          ) : (
            <Mic className="size-3.5 text-white/80" />
          )}
          <span className="truncate text-sm font-medium text-white">
            {tile.participant.username}
            {isScreen && " · screen"}
          </span>
        </div>
      )}
    </div>
  );
}

function VideoTile({
  track,
  className,
  mirror,
  onAspectRatio,
}: {
  track: VideoTrack;
  className?: string;
  mirror?: boolean;
  onAspectRatio?: (ratio: number) => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;
    track.attach(el);

    const reportRatio = () => {
      if (el.videoWidth && el.videoHeight) onAspectRatio?.(el.videoWidth / el.videoHeight);
    };
    el.addEventListener("loadedmetadata", reportRatio);
    el.addEventListener("resize", reportRatio);
    reportRatio();

    return () => {
      el.removeEventListener("loadedmetadata", reportRatio);
      el.removeEventListener("resize", reportRatio);
      track.detach(el);
    };
  }, [track, onAspectRatio]);

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
