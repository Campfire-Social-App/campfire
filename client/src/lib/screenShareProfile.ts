export type CaptureQuality = "720p" | "1080p" | "native";

/** Ceilings, not reserved bandwidth: WebRTC still adapts to congestion. Game
 * capture gets enough headroom for continuous full-frame changes while detail
 * capture keeps the lower bandwidth profile used by text and applications. */
export function screenShareProfile(
  quality: CaptureQuality,
  requestedFps: number,
  gameMode = false,
) {
  const fps = Number.isFinite(requestedFps) ? Math.max(1, Math.min(60, requestedFps)) : 30;
  const maxHeight = { "720p": 720, "1080p": 1080, native: 0 }[quality];
  const baseBitrate = { "720p": 3_000_000, "1080p": 6_000_000, native: 8_000_000 }[quality];
  // The regular motion profile leaves congestion-control headroom at 60 FPS.
  // Game mode has a higher ceiling because most pixels can change every frame;
  // congestion control can still select a lower rate when upload is limited.
  const motionBitrate = gameMode
    ? { "720p": 6_000_000, "1080p": 12_000_000, native: 15_000_000 }[quality]
    : { "720p": 4_500_000, "1080p": 8_000_000, native: 10_000_000 }[quality];
  const prioritiseMotion = gameMode || fps > 30;
  return {
    fps,
    maxHeight,
    maxBitrate: prioritiseMotion ? motionBitrate : baseBitrate,
    priority: gameMode ? "high" as const : undefined,
    contentHint: prioritiseMotion ? "motion" as const : "detail" as const,
    degradationPreference: prioritiseMotion ? "maintain-framerate" as const : "maintain-resolution" as const,
    resolution: maxHeight === 0
      ? undefined
      : { width: maxHeight * 16 / 9, height: maxHeight, frameRate: fps },
  };
}
