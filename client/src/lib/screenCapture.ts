import { Channel, invoke, isTauri } from "@tauri-apps/api/core";
import { logToFile } from "./clientLog";
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
  audioTrack: MediaStreamTrack | null;
  maxBitrate: number;
  stop: () => Promise<void>;
}

/** Frames stop arriving long before a human would call it broken, so this only
 * guards the first one — if capture can't start at all, fail fast and loudly. */
const FIRST_FRAME_TIMEOUT_MS = 8000;

/** How often the running frame-timing counters below are flushed to the
 * console. Driven by a timer rather than by frame arrival, so a total stall
 * (nothing arriving over IPC at all) still prints "receivedFps=0" instead of
 * going silent — useful when diagnosing frame-rate drops, e.g. once a game
 * is launched alongside the share. */
const STATS_LOG_INTERVAL_MS = 2000;

const SYSTEM_AUDIO_WORKLET = `
class CampfireSystemAudioProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.queue = [];
    this.offset = 0;
    this.queuedFrames = 0;
    this.port.onmessage = ({ data }) => {
      const samples = new Float32Array(data);
      this.queue.push(samples);
      this.queuedFrames += samples.length / 2;
      while (this.queuedFrames > 24000 && this.queue.length > 1) {
        const dropped = this.queue.shift();
        this.queuedFrames -= dropped.length / 2;
        this.offset = 0;
      }
    };
  }
  process(_inputs, outputs) {
    const output = outputs[0];
    const left = output[0];
    const right = output[1];
    for (let frame = 0; frame < left.length; frame += 1) {
      const chunk = this.queue[0];
      if (!chunk) {
        left[frame] = 0;
        right[frame] = 0;
        continue;
      }
      const index = this.offset * 2;
      left[frame] = chunk[index] ?? 0;
      right[frame] = chunk[index + 1] ?? left[frame];
      this.offset += 1;
      this.queuedFrames -= 1;
      if (this.offset * 2 >= chunk.length) {
        this.queue.shift();
        this.offset = 0;
      }
    }
    return true;
  }
}
registerProcessor("campfire-system-audio", CampfireSystemAudioProcessor);
`;

async function createSystemAudioTrack(): Promise<{
  track: MediaStreamTrack;
  push: (buffer: ArrayBuffer) => void;
  close: () => Promise<void>;
}> {
  const context = new AudioContext({ sampleRate: 48_000, latencyHint: "interactive" });
  const moduleUrl = URL.createObjectURL(new Blob([SYSTEM_AUDIO_WORKLET], { type: "text/javascript" }));
  try {
    await context.audioWorklet.addModule(moduleUrl);
  } finally {
    URL.revokeObjectURL(moduleUrl);
  }
  const processor = new AudioWorkletNode(context, "campfire-system-audio", {
    numberOfInputs: 0,
    numberOfOutputs: 1,
    outputChannelCount: [2],
  });
  const destination = context.createMediaStreamDestination();
  processor.connect(destination);
  await context.resume();
  const track = destination.stream.getAudioTracks()[0];
  if (!track) {
    await context.close();
    throw new Error("Couldn't create the system audio track.");
  }
  track.contentHint = "music";
  return {
    track,
    push: (buffer) => processor.port.postMessage(buffer, [buffer]),
    close: async () => {
      processor.disconnect();
      track.stop();
      await context.close().catch(() => {});
    },
  };
}

/** Header the Rust GPU path puts in front of every H.264 access unit. JPEG
 * frames from the CPU fallback path start with the JPEG marker instead, which
 * is how a frame's pipeline is identified without extra signalling. */
const GPU_FRAME_MAGIC = 0x31564643; // "CFV1", little-endian
const GPU_FRAME_HEADER = 32;

interface EncodedFrame {
  keyframe: boolean;
  timestamp: number;
  width: number;
  height: number;
  /** SPS/PPS, present on the first frame and after a forced recovery. */
  parameterSets: Uint8Array | null;
  data: Uint8Array;
}

function parseEncodedFrame(buffer: ArrayBuffer): EncodedFrame | null {
  if (buffer.byteLength < GPU_FRAME_HEADER) return null;
  const view = new DataView(buffer);
  if (view.getUint32(0, true) !== GPU_FRAME_MAGIC) return null;
  const flags = view.getUint8(5);
  const configLength = view.getUint32(24, true);
  const dataLength = view.getUint32(28, true);
  const configStart = GPU_FRAME_HEADER;
  const dataStart = configStart + configLength;
  if (dataStart + dataLength > buffer.byteLength) return null;
  return {
    keyframe: (flags & 1) !== 0,
    timestamp: Number(view.getBigUint64(12, true)),
    width: view.getUint16(20, true),
    height: view.getUint16(22, true),
    parameterSets:
      configLength > 0 ? new Uint8Array(buffer, configStart, configLength) : null,
    data: new Uint8Array(buffer, dataStart, dataLength),
  };
}

/** Builds the WebCodecs codec string from the stream's own SPS, so the decoder
 * is configured for the profile the encoder actually chose rather than a guess.
 * `avc3` is the honest signal that parameter sets arrive in-band. */
function codecCandidates(parameterSets: Uint8Array | null): string[] {
  const candidates: string[] = [];
  if (parameterSets) {
    for (let at = 0; at + 6 < parameterSets.length; at += 1) {
      const startCode =
        parameterSets[at] === 0 && parameterSets[at + 1] === 0 && parameterSets[at + 2] === 1;
      if (!startCode || (parameterSets[at + 3] & 0x1f) !== 7) continue;
      const profile = parameterSets
        .subarray(at + 4, at + 7)
        .reduce((text, byte) => text + byte.toString(16).padStart(2, "0"), "");
      candidates.push(`avc3.${profile}`, `avc1.${profile}`);
      break;
    }
  }
  // High 4.0 covers every resolution the picker offers if the SPS is missing.
  candidates.push("avc3.640028", "avc1.640028");
  return candidates;
}

/** Turns decoded frames into the published track. Which implementation is used
 * depends on what the WebView supports, and is logged — the generator path
 * hands frames straight to WebRTC, while the canvas path still costs a draw
 * per frame. */
interface FrameSink {
  readonly kind: string;
  readonly track: MediaStreamTrack;
  write: (frame: VideoFrame | ImageBitmap) => Promise<void>;
  /** A static screen produces no frames, but the WebRTC encoder still needs
   * input to keep the stream alive and answer keyframe requests. */
  refresh: () => void;
  close: () => void;
}

type GeneratorTrack = MediaStreamTrack & { writable: WritableStream<VideoFrame> };
type VideoTrackGeneratorLike = { track: MediaStreamTrack; writable: WritableStream<VideoFrame> };

function createGeneratorSink(first: VideoFrame): FrameSink | null {
  const scope = globalThis as unknown as {
    VideoTrackGenerator?: new () => VideoTrackGeneratorLike;
    MediaStreamTrackGenerator?: new (init: { kind: string }) => GeneratorTrack;
  };
  let track: MediaStreamTrack;
  let writable: WritableStream<VideoFrame>;
  let kind: string;
  try {
    if (scope.VideoTrackGenerator) {
      const generator = new scope.VideoTrackGenerator();
      ({ track, writable } = generator);
      kind = "video-track-generator";
    } else if (scope.MediaStreamTrackGenerator) {
      const generator = new scope.MediaStreamTrackGenerator({ kind: "video" });
      track = generator;
      writable = generator.writable;
      kind = "media-stream-track-generator";
    } else {
      return null;
    }
  } catch {
    return null;
  }

  const writer = writable.getWriter();
  let last: VideoFrame | null = null;
  let lastTimestamp = first.timestamp;
  return {
    kind,
    track,
    write: async (frame) => {
      const videoFrame = frame as VideoFrame;
      await writer.ready;
      last?.close();
      // The writer consumes the frame, so the keepalive needs its own copy.
      last = videoFrame.clone();
      lastTimestamp = videoFrame.timestamp;
      await writer.write(videoFrame);
    },
    refresh: () => {
      if (!last) return;
      // A duplicate timestamp would be dropped, so nudge it forward.
      lastTimestamp += 1000;
      const repeat = new VideoFrame(last, { timestamp: lastTimestamp });
      void writer.write(repeat).catch(() => repeat.close());
    },
    close: () => {
      last?.close();
      last = null;
      void writer.close().catch(() => {});
      track.stop();
    },
  };
}

function createCanvasSink(first: VideoFrame | ImageBitmap): FrameSink {
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d", { alpha: false });
  if (!context) throw new Error("Couldn't create the capture canvas.");

  const paint = (frame: VideoFrame | ImageBitmap) => {
    const width = "displayWidth" in frame ? frame.displayWidth : frame.width;
    const height = "displayHeight" in frame ? frame.displayHeight : frame.height;
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    context.drawImage(frame as CanvasImageSource, 0, 0);
  };

  // Painted before the track exists so it is sized off the real frame instead
  // of starting at the canvas default and jumping.
  paint(first);
  first.close();
  const track = canvas.captureStream(0).getVideoTracks()[0] as CanvasCaptureMediaStreamTrack;
  if (!track) throw new Error("Couldn't create the screen video track.");
  track.requestFrame();

  return {
    kind: "canvas",
    track,
    write: async (frame) => {
      paint(frame);
      track.requestFrame();
      frame.close();
    },
    refresh: () => {
      context.drawImage(canvas, 0, 0);
      track.requestFrame();
    },
    close: () => track.stop(),
  };
}

/**
 * Starts capturing `sourceId` in Rust and turns the frames into a track.
 *
 * Frames arrive already encoded (H.264 from the GPU pipeline, or JPEG from the
 * CPU fallback), are decoded by the WebView — by hardware, for H.264 — and
 * written to a `MediaStreamTrack` that LiveKit publishes like any other.
 */
export async function startNativeCapture(
  sourceId: string,
  quality: CaptureQuality,
  fps: number,
  onError: (message: string) => void,
  captureAudio = false,
  onAudioError: (message: string) => void = onError,
  gameMode = false,
): Promise<NativeCapture> {
  const profile = screenShareProfile(quality, fps, gameMode);
  const captureId = crypto.randomUUID();

  let stopped = false;
  const sinkRef: { current: FrameSink | null } = { current: null };
  let decoder: VideoDecoder | null = null;
  /** Kept so a reset reconfigures exactly as the stream was negotiated. */
  let decoderConfig: VideoDecoderConfig | null = null;
  let codec = "";
  /** After a reset the decoder cannot use anything before the next keyframe. */
  let awaitingKeyframe = false;
  let onFirstFrame: (() => void) | null = null;
  let hasFirstFrame = false;
  let captureError: string | null = null;
  let rejectFirstFrame: ((error: Error) => void) | null = null;
  const systemAudio = captureAudio ? await createSystemAudioTrack() : null;

  // Diagnostic counters, reset every STATS_LOG_INTERVAL_MS. Names are kept
  // comparable with the JPEG pipeline's so logs from before and after the GPU
  // path can be read side by side.
  let received = 0;
  let processed = 0;
  let keyWaits = 0;
  let decoderErrors = 0;
  let decodeMsSum = 0;
  let decodeMsMax = 0;
  let arrivalGapSum = 0;
  let arrivalGapMax = 0;
  let lastArrival: number | null = null;
  /** Submission times, to attribute decode latency to the frame that comes out. */
  const submitted: number[] = [];
  const logStats = (): void => {
    const secs = STATS_LOG_INTERVAL_MS / 1000;
    const line =
      `[screen-share] captureId=${captureId} receivedFps=${(received / secs).toFixed(1)} ` +
      `processedFps=${(processed / secs).toFixed(1)} sink=${sinkRef.current?.kind ?? "none"} codec=${codec || "jpeg"} ` +
      `decodeAvgMs=${(processed ? decodeMsSum / processed : 0).toFixed(1)} decodeMaxMs=${decodeMsMax.toFixed(1)} ` +
      `decodeQueue=${decoder?.decodeQueueSize ?? 0} keyWaits=${keyWaits} decoderErrors=${decoderErrors} ` +
      `arrivalGapAvgMs=${(received > 1 ? arrivalGapSum / (received - 1) : 0).toFixed(1)} ` +
      `arrivalGapMaxMs=${arrivalGapMax.toFixed(1)}`;
    console.info(line);
    logToFile(line);
    received = 0;
    processed = 0;
    keyWaits = 0;
    decoderErrors = 0;
    decodeMsSum = 0;
    decodeMsMax = 0;
    arrivalGapSum = 0;
    arrivalGapMax = 0;
  };
  const statsTimer = window.setInterval(logStats, STATS_LOG_INTERVAL_MS);

  const acknowledge = () => void invoke("acknowledge_capture", { captureId }).catch(() => {});

  /** Serialises sink writes without dropping anything: an H.264 stream with a
   * hole in it stays broken until the next keyframe, so backpressure has to
   * push back on the producer instead (which the Rust side handles by pausing
   * capture, never by discarding output). */
  let writes: Promise<void> = Promise.resolve();
  /** `video` tells the two pipelines apart: only decoded `VideoFrame`s can go
   * to a track generator, while JPEG bitmaps always need the canvas. */
  const enqueue = (frame: VideoFrame | ImageBitmap, video: boolean) => {
    writes = writes
      .then(async () => {
        if (stopped) {
          frame.close();
          return;
        }
        if (!sinkRef.current) {
          sinkRef.current =
            (video ? createGeneratorSink(frame as VideoFrame) : null) ??
            createCanvasSink(frame);
          // The canvas sink consumed the first frame while sizing itself.
          if (sinkRef.current.kind !== "canvas") await sinkRef.current.write(frame);
        } else {
          await sinkRef.current.write(frame);
        }
        const startedAt = submitted.shift();
        if (startedAt !== undefined) {
          const elapsed = performance.now() - startedAt;
          decodeMsSum += elapsed;
          decodeMsMax = Math.max(decodeMsMax, elapsed);
        }
        processed += 1;
        acknowledge();
        hasFirstFrame = true;
        onFirstFrame?.();
        onFirstFrame = null;
      })
      .catch(() => {
        // One bad frame is not worth tearing the share down for.
        acknowledge();
      });
  };

  const fail = (message: string) => {
    captureError = message;
    if (sinkRef.current) onError(message);
    else rejectFirstFrame?.(new Error(message));
  };

  const recoverDecoder = () => {
    decoderErrors += 1;
    awaitingKeyframe = true;
    submitted.length = 0;
    try {
      decoder?.reset();
      if (decoder && decoderConfig) decoder.configure(decoderConfig);
    } catch {
      // A decoder that cannot be reset is replaced on the next keyframe.
      decoder = null;
    }
    void invoke("request_keyframe", { captureId }).catch(() => {});
  };

  const selectDecoder = async (frame: EncodedFrame): Promise<boolean> => {
    if (typeof VideoDecoder === "undefined") {
      fail("This version of the app can't decode the GPU capture stream.");
      return false;
    }
    for (const candidate of codecCandidates(frame.parameterSets)) {
      for (const acceleration of ["prefer-hardware", "no-preference"] as const) {
        const config: VideoDecoderConfig = {
          codec: candidate,
          optimizeForLatency: true,
          hardwareAcceleration: acceleration,
        };
        const support = await VideoDecoder.isConfigSupported(config).catch(() => null);
        if (!support?.supported) continue;
        decoder = new VideoDecoder({
          output: (decoded) => enqueue(decoded, true),
          error: () => recoverDecoder(),
        });
        decoder.configure(config);
        decoderConfig = config;
        codec = candidate;
        return true;
      }
    }
    fail("No hardware decoder for the capture stream.");
    return false;
  };

  /** Shared so that frames arriving while the first one is still picking a
   * codec don't each build a decoder of their own. */
  let decoderSetup: Promise<boolean> | null = null;
  const ensureDecoder = (frame: EncodedFrame): Promise<boolean> => {
    if (decoder) return Promise.resolve(true);
    decoderSetup ??= selectDecoder(frame);
    return decoderSetup;
  };

  const onEncodedFrame = async (frame: EncodedFrame) => {
    if (!(await ensureDecoder(frame))) return;
    if (awaitingKeyframe) {
      if (!frame.keyframe) {
        // Feeding deltas across a reset would only produce garbage.
        keyWaits += 1;
        acknowledge();
        return;
      }
      awaitingKeyframe = false;
    }
    try {
      submitted.push(performance.now());
      decoder?.decode(
        new EncodedVideoChunk({
          type: frame.keyframe ? "key" : "delta",
          timestamp: frame.timestamp,
          data: frame.data,
        }),
      );
    } catch {
      submitted.pop();
      acknowledge();
      recoverDecoder();
    }
  };

  const onJpegFrame = (buffer: ArrayBuffer) => {
    submitted.push(performance.now());
    writes = writes
      .then(async () => {
        if (stopped) return;
        const bitmap = await createImageBitmap(new Blob([buffer], { type: "image/jpeg" }));
        enqueue(bitmap, false);
      })
      .catch(() => {
        submitted.shift();
        acknowledge();
      });
  };

  const channel = new Channel<ArrayBuffer | { error: string }>();
  channel.onmessage = (message) => {
    if (stopped) return;
    if (message instanceof ArrayBuffer) {
      const now = performance.now();
      received += 1;
      if (lastArrival !== null) {
        const gap = now - lastArrival;
        arrivalGapSum += gap;
        arrivalGapMax = Math.max(arrivalGapMax, gap);
      }
      lastArrival = now;
      const encoded = parseEncodedFrame(message);
      if (encoded) void onEncodedFrame(encoded);
      else onJpegFrame(message);
    } else if (typeof message === "object" && "error" in message) {
      fail(message.error);
    }
  };

  const audioChannel = new Channel<ArrayBuffer | { error: string }>();
  audioChannel.onmessage = (message) => {
    if (stopped || !systemAudio) return;
    if (message instanceof ArrayBuffer) systemAudio.push(message);
    else if (typeof message === "object" && "error" in message) onAudioError(message.error);
  };

  const stop = async (): Promise<void> => {
    if (stopped) return;
    stopped = true;
    window.clearInterval(statsTimer);
    onFirstFrame = null;
    rejectFirstFrame = null;
    await invoke("stop_capture", { captureId }).catch(() => {});
    try {
      decoder?.close();
    } catch {
      // Already closed by its own error path.
    }
    decoder = null;
    await systemAudio?.close();
  };

  let firstFrameTimer: number | undefined;
  try {
    await invoke("start_capture", {
      sourceId,
      captureId,
      maxHeight: profile.maxHeight,
      fps: profile.fps,
      onFrame: channel,
      captureAudio,
      gameMode,
      onAudio: audioChannel,
    });
    if (captureError) throw new Error(captureError);
    await new Promise<void>((resolve, reject) => {
      // Resolved by the first frame that decoded and reached the sink, not by
      // the first blob: a decoder that cannot start would otherwise publish a
      // track nothing will ever feed.
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
    sinkRef.current?.close();
    throw err;
  } finally {
    window.clearTimeout(firstFrameTimer);
    rejectFirstFrame = null;
    onFirstFrame = null;
  }

  const track = sinkRef.current?.track;
  if (!track) {
    await stop();
    throw new Error("Couldn't create the screen video track.");
  }
  const keepAlive = window.setInterval(() => {
    if (!stopped) sinkRef.current?.refresh();
  }, 1000);
  track.contentHint = profile.contentHint;
  logToFile(`[screen-share] captureId=${captureId} sink=${sinkRef.current?.kind} codec=${codec || "jpeg"}`);

  return {
    track,
    audioTrack: systemAudio?.track ?? null,
    maxBitrate: profile.maxBitrate,
    stop: async () => {
      window.clearInterval(keepAlive);
      await stop();
      sinkRef.current?.close();
    },
  };
}
