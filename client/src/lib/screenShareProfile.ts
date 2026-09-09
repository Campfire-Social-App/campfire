export type CaptureQuality = "720p" | "1080p" | "native";

/** Ceilings, not reserved bandwidth: WebRTC still adapts to congestion. Give
 * motion at 60 FPS more room than 30 FPS, without unlimited native bitrates. */
export function screenShareProfile(quality: CaptureQuality, requestedFps: number) {
  const fps = Number.isFinite(requestedFps) ? Math.max(1, Math.min(60, requestedFps)) : 30;
  const maxHeight = { "720p": 720, "1080p": 1080, native: 0 }[quality];
  const baseBitrate = { "720p": 3_000_000, "1080p": 6_000_000, native: 8_000_000 }[quality];
  // Leave congestion-control headroom at 60 FPS. Doubling bitrate with FPS can
  // make WebRTC's frame dropper oscillate when upload bandwidth is near its cap.
  const motionBitrate = { "720p": 4_500_000, "1080p": 8_000_000, native: 10_000_000 }[quality];
  const prioritiseMotion = fps > 30;
  return {
    fps,
    maxHeight,
    maxBitrate: prioritiseMotion ? motionBitrate : baseBitrate,
    contentHint: prioritiseMotion ? "motion" as const : "detail" as const,
    degradationPreference: prioritiseMotion ? "maintain-framerate" as const : "maintain-resolution" as const,
    resolution: maxHeight === 0
      ? undefined
      : { width: maxHeight * 16 / 9, height: maxHeight, frameRate: fps },
  };
}
