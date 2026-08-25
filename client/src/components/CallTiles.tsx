import { useEffect, useRef } from "react";
import { Loader2, MicOff, MonitorPlay, VolumeX } from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
import { ScreenShareLiveBadge } from "@/components/ScreenShareLiveBadge";
import type { VideoTrack } from "@/state/voice";
import type { VoiceParticipantState } from "@/lib/types";
import { cn } from "@/lib/utils";

/** One rectangle on a call stage. A participant always has a camera tile (their
 * avatar stands in while the camera is off) and gains a second one while they
 * share a screen. Shared by the voice channel view and the DM call panel. */
export interface CallTile {
  key: string;
  kind: "camera" | "screen";
  participant: VoiceParticipantState;
  track: VideoTrack | null;
  isScreenSharing: boolean;
  isWatchingScreenShare: boolean;
}

export function buildTiles(
  participants: VoiceParticipantState[],
  cameraTracks: Record<string, VideoTrack>,
  screenShareTracks: Record<string, VideoTrack>,
  availableScreenShares: Record<string, true>,
  viewingScreenShares: Record<string, true>,
): CallTile[] {
  return participants.flatMap((p) => {
    const isScreenSharing = !!availableScreenShares[p.user_id];
    const tile: CallTile = {
      key: `cam:${p.user_id}`,
      kind: "camera",
      participant: p,
      track: cameraTracks[p.user_id] ?? null,
      isScreenSharing,
      isWatchingScreenShare: false,
    };
    const screenTrack = screenShareTracks[p.user_id];
    if (!isScreenSharing) return [tile];
    return [
      tile,
      {
        key: `scr:${p.user_id}`,
        kind: "screen",
        participant: p,
        track: screenTrack ?? null,
        isScreenSharing: true,
        isWatchingScreenShare: !!viewingScreenShares[p.user_id],
      } satisfies CallTile,
    ];
  });
}

export function TileVisual({
  tile,
  isOwn,
  online,
  large,
  compact,
  onAspectRatio,
  onWatchScreenShare,
}: {
  tile: CallTile;
  isOwn: boolean;
  online: boolean;
  large?: boolean;
  compact?: boolean;
  onAspectRatio?: (ratio: number) => void;
  onWatchScreenShare?: () => void;
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
      ) : isScreen ? (
        <div className="flex size-full flex-col items-center justify-center gap-2.5 bg-linear-to-br from-muted to-muted/60 text-center">
          {tile.isWatchingScreenShare ? (
            <Loader2 className="size-8 animate-spin text-primary" />
          ) : (
            <MonitorPlay className="size-9 text-primary" />
          )}
          <p className="text-sm font-medium text-foreground">
            {tile.isWatchingScreenShare ? "Joining stream…" : `${tile.participant.username} is streaming`}
          </p>
          {!tile.isWatchingScreenShare && onWatchScreenShare && (
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                onWatchScreenShare();
              }}
              className="relative z-30 rounded-md bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground hover:bg-primary/90"
            >
              Watch stream
            </button>
          )}
          {!tile.isWatchingScreenShare && !onWatchScreenShare && (
            <span className="text-xs font-semibold text-primary">Watch stream</span>
          )}
        </div>
      ) : (
        <div className="flex size-full items-center justify-center bg-linear-to-br from-muted to-muted/60">
          {/* Expanded, camera off: the avatar carries the whole frame, so it's
              sized for it — and the presence dot is dropped, since a speck of a
              badge on a 10rem circle reads as an artifact, and "they're online"
              is already implied by them being in the call. */}
          <UserAvatar
            username={tile.participant.username}
            size={large ? "lg" : "default"}
            status={large || compact ? undefined : online ? "online" : "offline"}
            className={cn(
              large ? "size-40 *:text-5xl" : compact ? "size-10 *:text-base" : "size-24 *:text-2xl",
            )}
          />
        </div>
      )}

      {compact && isScreen && (
        <div className="absolute inset-x-0 bottom-0 flex items-center gap-1 bg-linear-to-t from-black/80 to-transparent px-2 py-1.5 text-white">
          <MonitorPlay className="size-3 shrink-0" />
          <span className="truncate text-[11px] font-medium">
            {tile.participant.username} · screen
          </span>
        </div>
      )}

      {!compact && (
        <div className="absolute inset-x-0 bottom-0 flex items-center gap-1.5 bg-linear-to-t from-black/70 to-transparent px-2.5 py-2">
          {isScreen ? (
            <MonitorPlay className="size-3.5 text-white" />
          ) : null}
          <span className="truncate text-sm font-medium text-white">
            {tile.participant.username}
            {isScreen && " · screen"}
          </span>
          {!isScreen &&
            (tile.isScreenSharing || tile.participant.muted || tile.participant.deafened) && (
              <div className="ml-auto flex shrink-0 items-center gap-1.5">
                {tile.participant.muted && (
                  <MicOff aria-label="Microphone muted" className="size-3.5 text-destructive" />
                )}
                {tile.participant.deafened && (
                  <VolumeX aria-label="Audio deafened" className="size-3.5 text-destructive" />
                )}
                {tile.isScreenSharing && <ScreenShareLiveBadge />}
              </div>
            )}
        </div>
      )}
    </div>
  );
}

export function VideoTile({
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
