import { useCallback, useEffect, useRef, useState } from "react";
import {
  Maximize,
  Minimize,
  Pause,
  PictureInPicture2,
  Play,
  Volume1,
  Volume2,
  VolumeX,
} from "lucide-react";
import { cn } from "@/lib/utils";

const HIDE_CONTROLS_AFTER_MS = 2200;
const SEEK_STEP_SECONDS = 5;
const SPEEDS = [0.5, 1, 1.25, 1.5, 2];

function formatTime(seconds: number): string {
  if (!Number.isFinite(seconds)) return "0:00";
  const whole = Math.floor(seconds);
  const hours = Math.floor(whole / 3600);
  const minutes = Math.floor((whole % 3600) / 60);
  const secs = whole % 60;
  const padded = `${minutes.toString().padStart(hours ? 2 : 1, "0")}:${secs
    .toString()
    .padStart(2, "0")}`;
  return hours ? `${hours}:${padded}` : padded;
}

/** Playback state of one media element, kept in sync from the element's own
 * events rather than from our calls — that way the state stays right even when
 * something else drives it (keyboard media keys, picture-in-picture, autoplay
 * policies refusing to start). */
function useMediaController(ref: React.RefObject<HTMLMediaElement | null>) {
  const [playing, setPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [buffered, setBuffered] = useState(0);
  const [volume, setVolumeState] = useState(1);
  const [muted, setMuted] = useState(false);
  const [speed, setSpeedState] = useState(1);

  useEffect(() => {
    const media = ref.current;
    if (!media) return;

    const onTime = () => setCurrentTime(media.currentTime);
    const onDuration = () => setDuration(media.duration);
    const onPlay = () => setPlaying(true);
    const onPause = () => setPlaying(false);
    const onVolume = () => {
      setVolumeState(media.volume);
      setMuted(media.muted);
    };
    const onProgress = () => {
      // Only the range that covers the playhead is worth drawing — the others
      // are behind or ahead of a seek and would read as a jumbled bar.
      for (let i = 0; i < media.buffered.length; i += 1) {
        if (
          media.buffered.start(i) <= media.currentTime &&
          media.buffered.end(i) >= media.currentTime
        ) {
          setBuffered(media.buffered.end(i));
          return;
        }
      }
    };

    media.addEventListener("timeupdate", onTime);
    media.addEventListener("durationchange", onDuration);
    media.addEventListener("loadedmetadata", onDuration);
    media.addEventListener("play", onPlay);
    media.addEventListener("pause", onPause);
    media.addEventListener("volumechange", onVolume);
    media.addEventListener("progress", onProgress);
    return () => {
      media.removeEventListener("timeupdate", onTime);
      media.removeEventListener("durationchange", onDuration);
      media.removeEventListener("loadedmetadata", onDuration);
      media.removeEventListener("play", onPlay);
      media.removeEventListener("pause", onPause);
      media.removeEventListener("volumechange", onVolume);
      media.removeEventListener("progress", onProgress);
    };
  }, [ref]);

  const toggle = useCallback(() => {
    const media = ref.current;
    if (!media) return;
    if (media.paused) void media.play().catch(() => {});
    else media.pause();
  }, [ref]);

  const seek = useCallback(
    (seconds: number) => {
      const media = ref.current;
      if (!media || !Number.isFinite(seconds)) return;
      media.currentTime = Math.min(Math.max(seconds, 0), media.duration || 0);
      setCurrentTime(media.currentTime);
    },
    [ref],
  );

  const setVolume = useCallback(
    (next: number) => {
      const media = ref.current;
      if (!media) return;
      media.volume = Math.min(Math.max(next, 0), 1);
      // Nudging the slider up is also how you undo a mute.
      media.muted = media.volume === 0;
    },
    [ref],
  );

  const toggleMute = useCallback(() => {
    const media = ref.current;
    if (!media) return;
    media.muted = !media.muted;
    if (!media.muted && media.volume === 0) media.volume = 1;
  }, [ref]);

  const setSpeed = useCallback(
    (next: number) => {
      const media = ref.current;
      if (!media) return;
      media.playbackRate = next;
      setSpeedState(next);
    },
    [ref],
  );

  return {
    playing,
    currentTime,
    duration,
    buffered,
    volume,
    muted,
    speed,
    toggle,
    seek,
    setVolume,
    toggleMute,
    setSpeed,
  };
}

/** Draggable progress/volume track. One control for both, since they are the
 * same interaction: a fraction you can click into or scrub along. */
function Scrubber({
  value,
  max,
  buffered = 0,
  onChange,
  className,
  ariaLabel,
}: {
  value: number;
  max: number;
  buffered?: number;
  onChange: (value: number) => void;
  className?: string;
  ariaLabel: string;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState(false);

  const valueFromEvent = (clientX: number): number => {
    const track = trackRef.current;
    // `max` is the duration, which is NaN until metadata arrives — and NaN
    // fails every comparison, so it has to be excluded explicitly.
    if (!track || !Number.isFinite(max) || max <= 0) return 0;
    const rect = track.getBoundingClientRect();
    const fraction = Math.min(Math.max((clientX - rect.left) / rect.width, 0), 1);
    return fraction * max;
  };

  const percent = (part: number) => (max > 0 ? `${Math.min((part / max) * 100, 100)}%` : "0%");

  return (
    <div
      ref={trackRef}
      role="slider"
      aria-label={ariaLabel}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={value}
      tabIndex={-1}
      onPointerDown={(event) => {
        event.preventDefault();
        // Capture on the track so a fast drag that leaves the element keeps
        // scrubbing instead of dropping the gesture halfway.
        event.currentTarget.setPointerCapture(event.pointerId);
        setDragging(true);
        onChange(valueFromEvent(event.clientX));
      }}
      onPointerMove={(event) => {
        if (dragging) onChange(valueFromEvent(event.clientX));
      }}
      onPointerUp={(event) => {
        event.currentTarget.releasePointerCapture(event.pointerId);
        setDragging(false);
      }}
      className={cn("group/track relative flex h-4 cursor-pointer items-center", className)}
    >
      <div className="relative h-1 w-full overflow-hidden rounded-full bg-white/15">
        <div className="absolute inset-y-0 left-0 bg-white/25" style={{ width: percent(buffered) }} />
        <div className="absolute inset-y-0 left-0 bg-primary" style={{ width: percent(value) }} />
      </div>
      <div
        className={cn(
          "pointer-events-none absolute size-3 -translate-x-1/2 rounded-full bg-primary shadow transition-opacity",
          dragging ? "opacity-100" : "opacity-0 group-hover/track:opacity-100",
        )}
        style={{ left: percent(value) }}
      />
    </div>
  );
}

function ControlButton({
  onClick,
  label,
  children,
  className,
}: {
  onClick: () => void;
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={label}
      aria-label={label}
      className={cn(
        "flex size-7 shrink-0 items-center justify-center rounded-md text-white/85 transition-colors hover:bg-white/15 hover:text-white",
        className,
      )}
    >
      {children}
    </button>
  );
}

function VolumeControl({
  volume,
  muted,
  onToggleMute,
  onVolume,
}: {
  volume: number;
  muted: boolean;
  onToggleMute: () => void;
  onVolume: (value: number) => void;
}) {
  const Icon = muted || volume === 0 ? VolumeX : volume < 0.5 ? Volume1 : Volume2;

  return (
    <div className="group/volume flex items-center">
      <ControlButton onClick={onToggleMute} label={muted ? "Unmute" : "Mute"}>
        <Icon className="size-4" />
      </ControlButton>
      {/* Slides open on hover so the bar stays uncluttered at rest. */}
      <div className="w-0 overflow-hidden transition-[width] group-hover/volume:w-16 focus-within:w-16">
        <Scrubber
          value={muted ? 0 : volume}
          max={1}
          onChange={onVolume}
          ariaLabel="Volume"
          className="mx-1.5 w-[52px]"
        />
      </div>
    </div>
  );
}

export function VideoPlayer({ src, className }: { src: string; className?: string }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const hideTimer = useRef<number | null>(null);
  const [controlsVisible, setControlsVisible] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);
  const [speedOpen, setSpeedOpen] = useState(false);

  const media = useMediaController(videoRef);
  const started = media.currentTime > 0 || media.playing;

  useEffect(() => {
    const onChange = () => setFullscreen(document.fullscreenElement === containerRef.current);
    document.addEventListener("fullscreenchange", onChange);
    return () => document.removeEventListener("fullscreenchange", onChange);
  }, []);

  // Controls stay put while paused — they only get out of the way of moving
  // picture, and only while the pointer is still.
  const revealControls = useCallback(() => {
    setControlsVisible(true);
    if (hideTimer.current !== null) window.clearTimeout(hideTimer.current);
    hideTimer.current = window.setTimeout(() => {
      if (videoRef.current && !videoRef.current.paused) setControlsVisible(false);
    }, HIDE_CONTROLS_AFTER_MS);
  }, []);

  useEffect(() => {
    if (!media.playing) setControlsVisible(true);
  }, [media.playing]);

  useEffect(() => () => {
    if (hideTimer.current !== null) window.clearTimeout(hideTimer.current);
  }, []);

  const toggleFullscreen = () => {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void containerRef.current?.requestFullscreen().catch(() => {});
  };

  const togglePictureInPicture = () => {
    if (document.pictureInPictureElement) void document.exitPictureInPicture();
    else void videoRef.current?.requestPictureInPicture().catch(() => {});
  };

  return (
    <div
      ref={containerRef}
      tabIndex={0}
      onMouseMove={revealControls}
      onMouseLeave={() => media.playing && setControlsVisible(false)}
      onKeyDown={(event) => {
        // A focused button already answers space and enter itself; handling it
        // here as well would toggle playback twice and land back where it was.
        if (event.target instanceof HTMLElement && event.target.closest("button")) return;

        const handlers: Record<string, () => void> = {
          " ": media.toggle,
          k: media.toggle,
          m: media.toggleMute,
          f: toggleFullscreen,
          ArrowRight: () => media.seek(media.currentTime + SEEK_STEP_SECONDS),
          ArrowLeft: () => media.seek(media.currentTime - SEEK_STEP_SECONDS),
        };
        const handler = handlers[event.key];
        if (!handler) return;
        // Space would otherwise scroll the message list out from under the video.
        event.preventDefault();
        handler();
        revealControls();
      }}
      className={cn(
        "group/player relative overflow-hidden rounded-xl border border-glass-border bg-black outline-none focus-visible:border-ember-tint-border",
        fullscreen ? "flex h-full w-full items-center justify-center rounded-none" : "max-w-md",
        className,
      )}
    >
      <video
        ref={videoRef}
        src={src}
        preload="metadata"
        playsInline
        onClick={() => {
          media.toggle();
          revealControls();
        }}
        onDoubleClick={toggleFullscreen}
        className={cn("w-full cursor-pointer", fullscreen ? "max-h-full" : "max-h-80")}
      />

      {!started && (
        <button
          type="button"
          onClick={() => media.toggle()}
          aria-label="Play"
          className="absolute inset-0 flex items-center justify-center bg-black/25 transition-colors hover:bg-black/15"
        >
          <span className="flex size-14 items-center justify-center rounded-full bg-primary/90 text-primary-foreground shadow-lg backdrop-blur-sm">
            <Play className="size-6 translate-x-0.5 fill-current" />
          </span>
        </button>
      )}

      <div
        onClick={(event) => event.stopPropagation()}
        className={cn(
          "absolute inset-x-0 bottom-0 bg-linear-to-t from-black/80 via-black/50 to-transparent px-2.5 pt-6 pb-1.5 transition-opacity",
          controlsVisible ? "opacity-100" : "pointer-events-none opacity-0",
        )}
      >
        <Scrubber
          value={media.currentTime}
          max={media.duration}
          buffered={media.buffered}
          onChange={media.seek}
          ariaLabel="Seek"
        />

        <div className="mt-0.5 flex items-center gap-1">
          <ControlButton onClick={media.toggle} label={media.playing ? "Pause" : "Play"}>
            {media.playing ? (
              <Pause className="size-4 fill-current" />
            ) : (
              <Play className="size-4 fill-current" />
            )}
          </ControlButton>

          <VolumeControl
            volume={media.volume}
            muted={media.muted}
            onToggleMute={media.toggleMute}
            onVolume={media.setVolume}
          />

          <span className="ml-1 font-mono text-[11px] text-white/75 tabular-nums">
            {formatTime(media.currentTime)} / {formatTime(media.duration)}
          </span>

          <div className="relative ml-auto">
            <button
              type="button"
              onClick={() => setSpeedOpen((open) => !open)}
              onBlur={() => setSpeedOpen(false)}
              title="Playback speed"
              className="rounded-md px-1.5 py-1 font-mono text-[11px] text-white/85 transition-colors hover:bg-white/15 hover:text-white"
            >
              {media.speed}x
            </button>
            {speedOpen && (
              <div className="absolute right-0 bottom-full mb-1 overflow-hidden rounded-md border border-white/10 bg-black/90 backdrop-blur-sm">
                {SPEEDS.map((option) => (
                  <button
                    key={option}
                    type="button"
                    // Runs before the button's blur closes the menu.
                    onMouseDown={(event) => {
                      event.preventDefault();
                      media.setSpeed(option);
                      setSpeedOpen(false);
                    }}
                    className={cn(
                      "block w-full px-3 py-1 text-right font-mono text-[11px] transition-colors hover:bg-white/15",
                      option === media.speed ? "text-primary" : "text-white/85",
                    )}
                  >
                    {option}x
                  </button>
                ))}
              </div>
            )}
          </div>

          {document.pictureInPictureEnabled && (
            <ControlButton onClick={togglePictureInPicture} label="Picture in picture">
              <PictureInPicture2 className="size-4" />
            </ControlButton>
          )}

          <ControlButton
            onClick={toggleFullscreen}
            label={fullscreen ? "Exit fullscreen" : "Fullscreen"}
          >
            {fullscreen ? <Minimize className="size-4" /> : <Maximize className="size-4" />}
          </ControlButton>
        </div>
      </div>
    </div>
  );
}

/** Same controls, no picture — so an audio clip in the message list reads as
 * part of the same player rather than as the browser's grey bar. */
export function AudioPlayer({ src, filename }: { src: string; filename: string }) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const media = useMediaController(audioRef);

  return (
    <div className="max-w-md rounded-xl border border-glass-border bg-glass px-3 py-2.5">
      <audio ref={audioRef} src={src} preload="metadata" />
      <p className="mb-1.5 truncate text-xs text-muted-foreground">{filename}</p>

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={media.toggle}
          aria-label={media.playing ? "Pause" : "Play"}
          className="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/90 text-primary-foreground transition-colors hover:bg-primary"
        >
          {media.playing ? (
            <Pause className="size-4 fill-current" />
          ) : (
            <Play className="size-4 translate-x-px fill-current" />
          )}
        </button>

        <Scrubber
          value={media.currentTime}
          max={media.duration}
          buffered={media.buffered}
          onChange={media.seek}
          ariaLabel="Seek"
          className="flex-1"
        />

        <span className="shrink-0 font-mono text-[11px] text-muted-foreground tabular-nums">
          {formatTime(media.currentTime)} / {formatTime(media.duration)}
        </span>
      </div>
    </div>
  );
}
