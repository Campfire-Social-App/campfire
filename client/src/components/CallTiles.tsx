import { useEffect, useRef } from "react";
import { Mic, MicOff, MonitorPlay } from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
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
}

export function buildTiles(
  participants: VoiceParticipantState[],
  cameraTracks: Record<string, VideoTrack>,
  screenShareTracks: Record<string, VideoTrack>,
): CallTile[] {
  return participants.flatMap((p) => {
    const tile: CallTile = {
      key: `cam:${p.user_id}`,
      kind: "camera",
      participant: p,
      track: cameraTracks[p.user_id] ?? null,
    };
    const screenTrack = screenShareTracks[p.user_id];
    if (!screenTrack) return [tile];
    return [
      tile,
      { key: `scr:${p.user_id}`, kind: "screen", participant: p, track: screenTrack } satisfies CallTile,
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
}: {
  tile: CallTile;
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
