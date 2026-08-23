import { useEffect, useMemo, useRef, useState } from "react";
import { LogIn, Maximize2, Minimize2, Theater, Volume2, X } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { Button } from "@/components/ui/button";
import { TileVisual, buildTiles, type CallTile } from "@/components/CallTiles";
import { useVoiceStore } from "@/state/voice";
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
  const focusedKey = useVoiceStore((s) => s.focusedCallTileKey);
  const setFocusedKey = useVoiceStore((s) => s.setFocusedCallTileKey);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const theaterStageRef = useRef<HTMLDivElement>(null);

  const isThisChannelConnected = connectedChannelId === channel.id;

  const tiles = useMemo<CallTile[]>(
    () =>
      buildTiles(
        participants,
        isThisChannelConnected ? cameraTracks : {},
        isThisChannelConnected ? screenShareTracks : {},
      ),
    [participants, cameraTracks, screenShareTracks, isThisChannelConnected],
  );

  const focusedTile = tiles.find((t) => t.key === focusedKey) ?? null;
  useEffect(() => {
    if (focusedKey && !focusedTile) setFocusedKey(null);
  }, [focusedKey, focusedTile]);

  useEffect(() => {
    const handleFullscreenChange = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", handleFullscreenChange);
    return () => document.removeEventListener("fullscreenchange", handleFullscreenChange);
  }, []);

  const focusTile = (key: string) => {
    setFocusedKey(key);
  };

  const toggleFullscreen = async (element: HTMLElement | null = theaterStageRef.current) => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await element?.requestFullscreen();
    } catch {
      toast.error("Couldn't open full screen mode.");
    }
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

      <div className="flex min-h-0 flex-1 flex-col items-center justify-center gap-5 overflow-y-auto p-6">
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
          <div className="flex min-h-0 w-full flex-1 flex-col gap-3">
            <div
              ref={theaterStageRef}
              className="relative min-h-0 w-full flex-1 overflow-hidden rounded-2xl border border-glass-border bg-black shadow-2xl fullscreen:rounded-none fullscreen:border-0"
            >
              <TileVisual
                tile={focusedTile}
                isOwn={focusedTile.participant.user_id === ownUserId}
                online={!!onlineUserIds[focusedTile.participant.user_id]}
                large
              />
              <div className="absolute top-3 right-3 flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => void toggleFullscreen()}
                  aria-label={isFullscreen ? "Exit full screen" : "Full screen"}
                  title={isFullscreen ? "Exit full screen" : "Full screen"}
                  className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-white/10 bg-black/50 text-white backdrop-blur-sm transition-colors hover:bg-black/70"
                >
                  {isFullscreen ? <Minimize2 className="size-4" /> : <Maximize2 className="size-4" />}
                </button>
                <button
                  type="button"
                  onClick={() => setFocusedKey(null)}
                  aria-label="Back to call grid"
                  title="Back to call grid"
                  className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-white/10 bg-black/50 text-white backdrop-blur-sm transition-colors hover:bg-black/70"
                >
                  <X className="size-4" />
                </button>
              </div>
            </div>
            {tiles.length > 1 && (
              <div className="shrink-0 overflow-x-auto pb-1">
                <div className="flex w-max min-w-full justify-center gap-2">
                  {tiles.filter((tile) => tile.key !== focusedTile.key).map((tile) => (
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
              </div>
            )}
          </div>
        ) : (
          <div
            className="grid w-full max-w-6xl gap-3"
            style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}
          >
            {tiles.map((tile) => (
              <div
                key={tile.key}
                className={cn(
                  "group relative aspect-video overflow-hidden rounded-xl bg-glass ring-2 ring-glass-border transition-all hover:ring-ember-tint-border/60 fullscreen:size-full fullscreen:aspect-auto fullscreen:rounded-none fullscreen:ring-0",
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
                <button
                  type="button"
                  onClick={() => focusTile(tile.key)}
                  aria-label={tile.kind === "screen" ? "Open theater mode" : `Expand ${tile.participant.username}`}
                  className="absolute inset-0 z-10 cursor-pointer focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-[-2px]"
                >
                  <span
                    className={cn(
                      "pointer-events-none absolute top-2 flex items-center justify-center gap-1.5 rounded-full border border-white/10 bg-black/50 text-white opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100 group-focus-within:opacity-100",
                      tile.kind === "screen" ? "right-11 h-7 px-2.5 text-xs font-medium" : "right-2 size-6",
                    )}
                  >
                    {tile.kind === "screen" ? (
                      <>
                      <Theater className="size-3.5" /> Theater mode
                      </>
                    ) : (
                      <Maximize2 className="size-3.5" />
                    )}
                  </span>
                </button>
                {tile.kind === "screen" && (
                  <button
                    type="button"
                    onClick={(event) => void toggleFullscreen(event.currentTarget.parentElement)}
                    aria-label={isFullscreen ? "Exit full screen" : "Full screen"}
                    title={isFullscreen ? "Exit full screen" : "Full screen"}
                    className="absolute top-2 right-2 z-20 flex size-7 cursor-pointer items-center justify-center rounded-full border border-white/10 bg-black/50 text-white opacity-0 backdrop-blur-sm transition-opacity hover:bg-black/70 group-hover:opacity-100 focus-visible:opacity-100"
                  >
                    {isFullscreen ? (
                      <Minimize2 className="size-3.5" />
                    ) : (
                      <Maximize2 className="size-3.5" />
                    )}
                  </button>
                )}
              </div>
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
