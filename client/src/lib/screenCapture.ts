import { Channel, invoke, isTauri } from "@tauri-apps/api/core";
import { screenShareProfile, type CaptureQuality } from "./screenShareProfile";
export type { CaptureQuality } from "./screenShareProfile";

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

/** No native capture outside the desktop app (`npm run dev` in a browser) — the
 * caller falls back to the WebView's own picker there. */
export const isNativeCaptureAvailable = (): boolean => isTauri();

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
 * after each paint avoids both timer quantisation latency and duplicate frames.
 */
export async function startNativeCapture(
  sourceId: string,
  quality: CaptureQuality,
  fps: number,
  onError: (message: string) => void,
): Promise<NativeCapture> {
  const profile = screenShareProfile(quality, fps);
  const captureId = crypto.randomUUID();
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
  let hasFirstFrame = false;
  let captureError: string | null = null;
  let rejectFirstFrame: ((error: Error) => void) | null = null;

  const paint = async (buffer: ArrayBuffer): Promise<void> => {
    if (decoding) {
      // Replacing a stale queued frame releases its producer credit immediately.
      if (queued) void invoke("acknowledge_capture", { captureId });
      queued = buffer;
      return;
    }
    decoding = true;
    try {
      const bitmap = await createImageBitmap(new Blob([buffer], { type: "image/jpeg" }));
      if (stopped) {
        bitmap.close();
        return;
      }
      if (canvas.width !== bitmap.width || canvas.height !== bitmap.height) {
        canvas.width = bitmap.width;
        canvas.height = bitmap.height;
      }
      context.drawImage(bitmap, 0, 0);
      outputTrack?.requestFrame();
      bitmap.close();
      hasFirstFrame = true;
      onFirstFrame?.();
      onFirstFrame = null;
    } catch {
      // A single corrupt frame isn't worth tearing the share down for.
    } finally {
      void invoke("acknowledge_capture", { captureId });
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
      captureError = message.error;
      if (outputTrack) onError(message.error);
      else rejectFirstFrame?.(new Error(message.error));
    }
  };

  const stop = async (): Promise<void> => {
    if (stopped) return;
    stopped = true;
    queued = null;
    onFirstFrame = null;
    rejectFirstFrame = null;
    await invoke("stop_capture", { captureId }).catch(() => {});
  };

  let firstFrameTimer: number | undefined;
  try {
    await invoke("start_capture", {
      sourceId,
      captureId,
      maxHeight: profile.maxHeight,
      fps: profile.fps,
      onFrame: channel,
    });
    if (captureError) throw new Error(captureError);
    await new Promise<void>((resolve, reject) => {
      // The IPC response can arrive after the first (and only, for a static
      // desktop) frame. Remember it instead of waiting for a second frame.
      if (hasFirstFrame) return resolve();
      rejectFirstFrame = reject;
      firstFrameTimer = window.setTimeout(
        () => reject(new Error("The capture didn't produce any frames.")),
        FIRST_FRAME_TIMEOUT_MS,
      );
      onFirstFrame = resolve;
    });
  } catch (err) {
    await stop();
    throw err;
  } finally {
    window.clearTimeout(firstFrameTimer);
    rejectFirstFrame = null;
    onFirstFrame = null;
  }

  // Sized off the first frame, so the track never starts at the canvas default
  // and then jumps to the real resolution.
  let track: CanvasCaptureMediaStreamTrack;
  try {
    track = canvas.captureStream(0).getVideoTracks()[0] as CanvasCaptureMediaStreamTrack;
    if (!track) throw new Error("Couldn't create the screen video track.");
  } catch (error) {
    await stop();
    throw error;
  }
  outputTrack = track;
  // Repaint the first frame now that its track exists. A sparse keepalive does
  // the same for keyframe requests while the shared desktop is fully static.
  context.drawImage(canvas, 0, 0);
  track.requestFrame();
  const keepAlive = window.setInterval(() => {
    if (stopped) return;
    context.drawImage(canvas, 0, 0);
    track.requestFrame();
  }, 1000);
  track.contentHint = profile.contentHint;

  return {
    track,
    maxBitrate: profile.maxBitrate,
    stop: async () => {
      window.clearInterval(keepAlive);
      await stop();
      track.stop();
    },
  };
}
