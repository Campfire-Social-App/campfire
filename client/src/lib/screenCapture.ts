import { Channel, invoke } from "@tauri-apps/api/core";

/** A window or screen the user can share, as listed by the Rust side. */
export interface CaptureSource {
  id: string;
  kind: "screen" | "window";
  title: string;
  appName: string;
  width: number;
  height: number;
  /** JPEG data URL. */
  thumbnail: string;
}

export type CaptureQuality = "720p" | "1080p" | "native";

/** Height the capture is scaled down to; 0 means "leave it at the source's own". */
const MAX_HEIGHT: Record<CaptureQuality, number> = { "720p": 720, "1080p": 1080, native: 0 };

/** Bitrate ceiling per quality — screen content is mostly static, so these sit
 * below what the same resolution would need for camera video. */
const MAX_BITRATE: Record<CaptureQuality, number> = {
  "720p": 2_000_000,
  "1080p": 5_000_000,
  native: 7_000_000,
};

/** No native capture outside the desktop app (`npm run dev` in a browser) — the
 * caller falls back to the WebView's own picker there. */
export const isNativeCaptureAvailable = (): boolean => "__TAURI_INTERNALS__" in window;

export const listCaptureSources = (): Promise<CaptureSource[]> =>
  invoke<CaptureSource[]>("list_capture_sources");

export interface NativeCapture {
  track: MediaStreamTrack;
  maxBitrate: number;
  stop: () => Promise<void>;
}

/** Frames stop arriving long before a human would call it broken, so this only
 * guards the first one — if capture can't start at all, fail fast and loudly. */
const FIRST_FRAME_TIMEOUT_MS = 8000;

/**
 * Starts capturing `sourceId` in Rust and turns the frames into a track.
 *
 * The bridge is a canvas: each JPEG frame is decoded and painted, and the canvas
 * becomes a manually-driven `MediaStreamTrack`. Requesting a frame immediately
 * before each paint avoids both timer quantisation latency and duplicate frames.
 */
export async function startNativeCapture(
  sourceId: string,
  quality: CaptureQuality,
  fps: number,
  onError: (message: string) => void,
): Promise<NativeCapture> {
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d", { alpha: false });
  if (!context) throw new Error("Couldn't create the capture canvas.");

  let stopped = false;
  let decoding = false;
  let outputTrack: CanvasCaptureMediaStreamTrack | null = null;
  /** Newest frame that arrived while we were still decoding the previous one —
   * only the latest is worth keeping, the rest are already stale. */
  let queued: ArrayBuffer | null = null;
  let onFirstFrame: (() => void) | null = null;

  const paint = async (buffer: ArrayBuffer): Promise<void> => {
    if (decoding) {
      queued = buffer;
      return;
    }
    decoding = true;
    try {
      const bitmap = await createImageBitmap(new Blob([buffer], { type: "image/jpeg" }));
      if (canvas.width !== bitmap.width || canvas.height !== bitmap.height) {
        canvas.width = bitmap.width;
        canvas.height = bitmap.height;
      }
      outputTrack?.requestFrame();
      context.drawImage(bitmap, 0, 0);
      bitmap.close();
      onFirstFrame?.();
      onFirstFrame = null;
    } catch {
      // A single corrupt frame isn't worth tearing the share down for.
    } finally {
      decoding = false;
      const next = queued;
      queued = null;
      if (next && !stopped) void paint(next);
    }
  };

  const channel = new Channel<ArrayBuffer | { error: string }>();
  channel.onmessage = (message) => {
    if (stopped) return;
    if (message instanceof ArrayBuffer) {
      void paint(message);
    } else if (typeof message === "object" && "error" in message) {
      onError(message.error);
    }
  };

  await invoke("start_capture", {
    sourceId,
    maxHeight: MAX_HEIGHT[quality],
    fps,
    onFrame: channel,
  });

  const stop = async (): Promise<void> => {
    stopped = true;
    await invoke("stop_capture").catch(() => {});
  };

  try {
    await new Promise<void>((resolve, reject) => {
      const timer = window.setTimeout(
        () => reject(new Error("The capture didn't produce any frames.")),
        FIRST_FRAME_TIMEOUT_MS,
      );
      onFirstFrame = () => {
        window.clearTimeout(timer);
        resolve();
      };
    });
  } catch (err) {
    await stop();
    throw err;
  }

  // Sized off the first frame, so the track never starts at the canvas default
  // and then jumps to the real resolution.
  const track = canvas.captureStream(0).getVideoTracks()[0] as CanvasCaptureMediaStreamTrack;
  outputTrack = track;
  // Repaint the first frame now that its track exists. A sparse keepalive does
  // the same for keyframe requests while the shared desktop is fully static.
  track.requestFrame();
  context.drawImage(canvas, 0, 0);
  const keepAlive = window.setInterval(() => {
    if (stopped) return;
    track.requestFrame();
    context.drawImage(canvas, 0, 0);
  }, 1000);
  // Tells the encoder to favour sharpness over smoothness — text stays readable.
  track.contentHint = "detail";

  return {
    track,
    maxBitrate: MAX_BITRATE[quality],
    stop: async () => {
      window.clearInterval(keepAlive);
      await stop();
      track.stop();
    },
  };
}
