import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import { EventEmitter } from "node:events";
import ts from "typescript";

// Exercise the actual TypeScript with browser/Tauri boundaries mocked. No
// display, permissions, network or additional test-runner dependency required.
function load(relative, imports = {}, globals = {}) {
  const source = readFileSync(new URL(relative, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  });
  const exports = {};
  vm.runInNewContext(outputText, {
    exports, require: (name) => {
      assert.ok(name in imports, `Unexpected import: ${name}`);
      return imports[name];
    },
    setTimeout, clearTimeout, ...globals,
  });
  return exports;
}

const profileModule = load("../src/lib/screenShareProfile.ts");
test("quality budgets match resolution and FPS, with bounded native bitrate", () => {
  const { screenShareProfile: profile } = profileModule;
  assert.equal(profile("1080p", 30).resolution.height, 1080);
  assert.equal(profile("1080p", 30).maxBitrate, 6_000_000);
  assert.equal(profile("720p", 60).maxBitrate, 4_500_000);
  assert.equal(profile("native", 120).fps, 60);
  assert.equal(profile("native", 120).maxBitrate, 10_000_000);
  assert.equal(profile("1080p", 60).contentHint, "motion");
  assert.equal(profile("1080p", 60).degradationPreference, "maintain-framerate");
  assert.equal(profile("1080p", 30, true).maxBitrate, 12_000_000);
  assert.equal(profile("1080p", 30, true).contentHint, "motion");
  assert.equal(profile("1080p", 30, true).priority, "high");
  assert.equal(profile("native", 30).maxHeight, 0);
  assert.equal(profile("1080p", NaN).fps, 30);
});

for (const scenario of ["peer returns", "local reconnect", "new room", "empty DM"]) {
  test(`empty-call grace: ${scenario}`, (t) => {
    t.mock.timers.enable({ apis: ["setTimeout"] });
    const { emptyCallGrace } = load("../src/livekit/emptyCallGrace.ts");
    let eligible = true;
    let leaves = 0;
    const grace = emptyCallGrace(() => eligible, () => leaves++);
    grace.schedule();
    t.mock.timers.tick(29_999);
    assert.equal(leaves, 0);
    if (scenario === "peer returns" || scenario === "local reconnect") grace.cancel();
    if (scenario === "new room") eligible = false;
    t.mock.timers.tick(1);
    assert.equal(leaves, scenario === "empty DM" ? 1 : 0);
  });
}

/** An H.264 access unit as the Rust GPU path frames it: a 32-byte header,
 * then optional SPS/PPS, then the payload. */
function gpuFrame({ keyframe = true, parameterSets = null, payload = [0, 0, 1, 0x65], timestamp = 0 } = {}) {
  const config = parameterSets ?? [];
  const buffer = new ArrayBuffer(32 + config.length + payload.length);
  const view = new DataView(buffer);
  const bytes = new Uint8Array(buffer);
  bytes.set([0x43, 0x46, 0x56, 0x31], 0); // "CFV1"
  view.setUint8(4, 1);
  view.setUint8(5, (keyframe ? 1 : 0) | (config.length ? 2 : 0));
  view.setBigUint64(12, BigInt(timestamp), true);
  view.setUint16(20, 1920, true);
  view.setUint16(22, 1080, true);
  view.setUint32(24, config.length, true);
  view.setUint32(28, payload.length, true);
  bytes.set(config, 32);
  bytes.set(payload, 32 + config.length);
  return buffer;
}

/** A minimal SPS announcing High profile, so the codec string is derived from
 * the stream rather than the fallback. */
const TEST_SPS = [0, 0, 1, 0x67, 0x64, 0x00, 0x28];

function captureHarness(t, start, overrides = {}) {
  t.mock.timers.enable({ apis: ["setTimeout", "setInterval"] });
  let stops = 0;
  let acknowledgements = 0;
  let trackStops = 0;
  let keyframeRequests = 0;
  let written = 0;
  let channel;
  let decoder;
  const track = { kind: "video", requestFrame() {}, stop() { trackStops++; } };
  const generator = {
    track,
    writable: {
      getWriter: () => ({
        ready: Promise.resolve(),
        write: async () => { written++; },
        close: async () => {},
      }),
    },
  };
  const frame = (timestamp = 0) => ({
    timestamp,
    displayWidth: 1920,
    displayHeight: 1080,
    close() {},
    clone() { return frame(timestamp); },
  });
  class VideoDecoder {
    static configs = [];
    static async isConfigSupported(config) {
      VideoDecoder.configs.push(config);
      return { supported: config.codec.startsWith("avc3") };
    }
    constructor(handlers) { this.handlers = handlers; this.decodeQueueSize = 0; decoder = this; }
    configure(config) { this.config = config; }
    decode() { this.handlers.output(frame()); }
    reset() { this.wasReset = true; }
    close() { this.closed = true; }
  }
  const api = load("../src/lib/screenCapture.ts", {
    "./screenShareProfile": profileModule,
    "./clientLog": { logToFile() {} },
    "@tauri-apps/api/core": {
      Channel: class {},
      isTauri: () => true,
      invoke: async (command, args) => {
        if (command === "stop_capture") { stops++; return; }
        if (command === "acknowledge_capture") { acknowledgements++; return; }
        if (command === "request_keyframe") { keyframeRequests++; return; }
        channel = args.onFrame;
        await start(channel);
      },
    },
  }, {
    ArrayBuffer, Blob, DataView, Uint8Array, performance,
    crypto: { randomUUID: () => "test-capture-id" },
    window: { setTimeout, clearTimeout, setInterval, clearInterval },
    VideoDecoder,
    EncodedVideoChunk: class { constructor(init) { Object.assign(this, init); } },
    VideoFrame: class { constructor(source, init) { Object.assign(this, frame(init?.timestamp ?? 0)); } },
    VideoTrackGenerator: class { constructor() { return generator; } },
    ImageBitmap: class {},
    createImageBitmap: async () => ({ width: 1920, height: 1080, close() {} }),
    ...overrides,
  });
  return {
    api, track, generator,
    get stops() { return stops; },
    get trackStops() { return trackStops; },
    get acknowledgements() { return acknowledgements; },
    get keyframeRequests() { return keyframeRequests; },
    get written() { return written; },
    get decoder() { return decoder; },
    get decoderConfigs() { return VideoDecoder.configs; },
    send: (message) => channel.onmessage(message),
  };
}

test("a first decoded frame arriving before the IPC reply starts a static screen", async (t) => {
  const h = captureHarness(t, async (channel) => {
    channel.onmessage(gpuFrame({ parameterSets: TEST_SPS }));
    // The decode and the sink write both settle before invoke returns.
    for (let tick = 0; tick < 8; tick += 1) await Promise.resolve();
  });
  const capture = await h.api.startNativeCapture("screen:1", "1080p", 30, assert.fail);
  assert.equal(h.api.isNativeCaptureAvailable(), true);
  assert.equal(capture.track, h.track);
  assert.equal(capture.maxBitrate, 6_000_000);
  // Published straight from the track generator: no canvas draw per frame.
  assert.equal(h.written, 1);
  assert.equal(h.acknowledgements, 1);
  // Configured for the profile the stream's own SPS announced.
  assert.equal(h.decoder.config.codec, "avc3.640028");
  assert.equal(h.decoder.config.optimizeForLatency, true);
  assert.equal(h.decoder.config.hardwareAcceleration, "prefer-hardware");
  await capture.stop();
  assert.equal(h.stops, 1);
  assert.equal(h.trackStops, 1);
  assert.equal(h.decoder.closed, true);
  const written = h.written;
  t.mock.timers.tick(10_000);
  h.send(gpuFrame());
  await Promise.resolve();
  assert.equal(h.written, written);
});

test("a JPEG frame from the CPU fallback path still paints a canvas track", async (t) => {
  const canvasTrack = { kind: "video", requestFrame() {}, stop() {} };
  let paints = 0;
  const canvas = {
    width: 0, height: 0,
    getContext: () => ({ drawImage() { paints++; } }),
    captureStream: () => ({ getVideoTracks: () => [canvasTrack] }),
  };
  const h = captureHarness(t, async (channel) => {
    // No GPU header: the frontend has to recognise a JPEG and fall back.
    channel.onmessage(new Uint8Array([0xff, 0xd8, 0xff, 0xe0]).buffer);
    for (let tick = 0; tick < 8; tick += 1) await Promise.resolve();
  }, { document: { createElement: () => canvas } });
  const capture = await h.api.startNativeCapture("screen:1", "720p", 30, assert.fail);
  assert.equal(capture.track, canvasTrack);
  assert.equal(canvas.width, 1920);
  assert.ok(paints >= 1);
  assert.equal(h.decoder, undefined, "a JPEG stream must not configure a video decoder");
  await capture.stop();
});

test("deltas before the first keyframe are skipped and acknowledged", async (t) => {
  const h = captureHarness(t, async (channel) => {
    channel.onmessage(gpuFrame({ parameterSets: TEST_SPS }));
    for (let tick = 0; tick < 8; tick += 1) await Promise.resolve();
  });
  const capture = await h.api.startNativeCapture("screen:1", "720p", 30, assert.fail);
  // A decoder error resets the stream; everything until the next keyframe is
  // unusable, and the Rust side has to be asked for one.
  h.decoder.handlers.error(new Error("decode failed"));
  assert.equal(h.keyframeRequests, 1);
  const before = h.written;
  h.send(gpuFrame({ keyframe: false }));
  await Promise.resolve();
  assert.equal(h.written, before, "a delta after a reset must not be decoded");
  h.send(gpuFrame({ keyframe: true }));
  for (let tick = 0; tick < 8; tick += 1) await Promise.resolve();
  assert.equal(h.written, before + 1, "the next keyframe resumes the stream");
  await capture.stop();
});

test("an early native error rejects immediately and releases capture", async (t) => {
  const h = captureHarness(t, async (channel) => channel.onmessage({ error: "Window closed" }));
  await assert.rejects(h.api.startNativeCapture("window:1", "720p", 30, assert.fail), /Window closed/);
  assert.equal(h.stops, 1);
});

test("missing first frame times out and releases capture", async (t) => {
  const h = captureHarness(t, async () => {});
  const started = h.api.startNativeCapture("screen:1", "720p", 30, assert.fail);
  const rejected = assert.rejects(started, /didn't produce any frames/);
  // Let the start IPC promise settle and install its frame timeout.
  await new Promise((resolve) => setImmediate(resolve));
  t.mock.timers.tick(8_000);
  await rejected;
  assert.equal(h.stops, 1);
});

test("no usable decoder configuration releases the native capture", async (t) => {
  class Unsupported {
    static async isConfigSupported() { return { supported: false }; }
  }
  const h = captureHarness(t, async (channel) => {
    channel.onmessage(gpuFrame({ parameterSets: TEST_SPS }));
    for (let tick = 0; tick < 8; tick += 1) await Promise.resolve();
  }, { VideoDecoder: Unsupported });
  await assert.rejects(
    h.api.startNativeCapture("screen:1", "720p", 30, assert.fail),
    /No hardware decoder/,
  );
  assert.equal(h.stops, 1);
});

function voiceHarness(t, nativeCaptureAvailable = false) {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const rooms = [];
  const state = {
    localMuted: true, localDeafened: false, localScreenShareEnabled: false,
    participantVolumes: {}, screenShareVolumes: {}, mutedScreenShares: {},
    viewingScreenShares: { peer: true }, availableScreenShares: { peer: true },
    setConnection(id, status) { this.connectedChannelId = id; this.connectionStatus = status; },
    setParticipantMuted() {}, setParticipantDeafened() {},
    setLocalScreenShareEnabled(enabled) { this.localScreenShareEnabled = enabled; },
    setScreenShareViewing(id, viewing) { this.viewingScreenShares[id] = viewing; },
    setScreenShareVolume(id, volume) { this.screenShareVolumes[id] = volume; },
    setScreenShareMuted(id, muted) {
      if (muted) this.mutedScreenShares[id] = true;
      else delete this.mutedScreenShares[id];
    },
    setScreenShareAvailable(id, available) {
      this.availableScreenShares[id] = available;
      if (!available) delete this.viewingScreenShares[id];
    },
    setScreenShareTrack() {},
  };
  const settings = {
    audioInputDeviceId: null, audioOutputDeviceId: null,
    inputVolume: 1, outputVolume: 1,
    noiseSuppressionEnabled: true, noiseGateMode: "standard",
    setAudioInputDeviceId(deviceId) { this.audioInputDeviceId = deviceId; },
    setAudioOutputDeviceId(deviceId) { this.audioOutputDeviceId = deviceId; },
    setInputVolume(volume) { this.inputVolume = volume; },
    setOutputVolume(volume) { this.outputVolume = volume; },
  };
  const sounds = { streamStarts: 0, streamStops: 0 };
  class Room extends EventEmitter {
    state = "connected";
    remoteParticipants = new Map();
    disconnects = 0;
    deviceSwitches = [];
    publishedTracks = [];
    unpublishedTracks = [];
    localParticipant = {
      identity: "self",
      setAttributes: async () => {},
      setScreenShareEnabled: async (...args) => { this.screenOptions = args; },
      publishTrack: async (track, options) => { this.publishedTracks.push([track, options]); },
      unpublishTrack: async (track) => { this.unpublishedTracks.push(track); },
      getTrackPublication: () => undefined,
    };
    constructor(options) { super(); this.options = options; rooms.push(this); }
    async connect() {}
    async disconnect() { this.disconnects++; this.emit("Disconnected"); }
    async switchActiveDevice(kind, deviceId) {
      this.deviceSwitches.push([kind, deviceId]);
      return true;
    }
  }
  const presets = { h360fps15: { height: 360 }, h720fps30: { height: 720 } };
  const api = load("../src/livekit/voice.ts", {
    "livekit-client": {
      Room, RoomEvent: new Proxy({}, { get: (_, name) => name }),
      ConnectionState: { Connected: "connected", Reconnecting: "reconnecting" },
      ScreenSharePresets: presets, AudioPresets: {},
      Track: { Source: { Microphone: "microphone", ScreenShare: "screen", ScreenShareAudio: "screen-audio" }, Kind: { Video: "video" } },
    },
    "./emptyCallGrace": load("../src/livekit/emptyCallGrace.ts"),
    "@/lib/screenShareProfile": profileModule,
    "@/lib/screenCapture": {
      isNativeCaptureAvailable: () => nativeCaptureAvailable,
      startNativeCapture: async (_sourceId, quality, fps, _onError, _audio, _onAudioError, gameMode) => ({
        track: { kind: "video" },
        audioTrack: null,
        maxBitrate: profileModule.screenShareProfile(quality, fps, gameMode).maxBitrate,
        stop: async () => {},
      }),
    },
    "@/api/endpoints": {
      getVoiceToken: async () => ({ token: "test", url: "test" }),
      updateOwnVoiceState: async () => {},
    },
    "@/state/voice": { useVoiceStore: { getState: () => state } },
    "@/state/dms": { useDmsStore: { getState: () => ({ conversations: [{ id: "dm" }] }) } },
    "@/state/channels": {},
    "@/state/settings": { useSettingsStore: { getState: () => settings } },
    "@/lib/noiseGate": { NoiseGateProcessor: class {} },
    "@/lib/audioDiagnostics": {
      startAudioDiagnosticsSession() {}, endAudioDiagnosticsSession() {}, logAudioEvent() {},
    },
    "@/lib/clientLog": { logToFile() {} },
    "@/lib/sounds": {
      playJoinSound() {}, playLeaveSound() {},
      playDeafenSound() {}, playMicrophoneMuteSound() {},
      playMicrophoneUnmuteSound() {}, playUndeafenSound() {},
      playStreamStartSound() { sounds.streamStarts++; },
      playStreamStopSound() { sounds.streamStops++; },
    },
    sonner: { toast: {} },
    // The sender-stats monitor is diagnostics, not behaviour under test; a
    // real interval here would also keep the test process alive.
  }, { queueMicrotask, console, setInterval: () => 1, clearInterval: () => {} });
  return { api, state, settings, rooms, sounds };
}

test("screen share sounds play once for each real start and stop", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("voice");
  const room = h.rooms[0];
  const publication = { source: "screen", track: { kind: "video" } };
  const participant = { identity: "self" };

  room.emit("LocalTrackPublished", publication, participant);
  room.emit("LocalTrackPublished", publication, participant);
  assert.equal(h.sounds.streamStarts, 1);
  assert.equal(h.state.availableScreenShares.self, true);

  room.emit("LocalTrackUnpublished", publication, participant);
  room.emit("LocalTrackUnpublished", publication, participant);
  assert.equal(h.sounds.streamStops, 1);
  assert.equal(h.state.availableScreenShares.self, false);
  await h.api.leaveVoiceChannel();
});

test("remote screen share publication notifies every connected client", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("voice");
  const room = h.rooms[0];
  const publication = {
    source: "screen",
    isDesired: false,
    setSubscribed(watching) { this.isDesired = watching; },
  };
  const participant = {
    identity: "streamer",
    getTrackPublication: () => undefined,
  };

  room.emit("TrackPublished", publication, participant);
  assert.equal(h.sounds.streamStarts, 1);
  assert.equal(h.state.availableScreenShares.streamer, true);

  room.emit("TrackUnpublished", publication, participant);
  await Promise.resolve();
  assert.equal(h.sounds.streamStops, 1);
  assert.equal(h.state.availableScreenShares.streamer, false);
  await h.api.leaveVoiceChannel();
});

test("audio device and master volume changes persist without leaving the room", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("voice");
  await h.api.switchAudioInputDevice("microphone-2");
  await h.api.switchAudioOutputDevice("speaker-2");
  await h.api.applyInputVolume(1.25);
  h.api.applyOutputVolume(0.75);

  assert.equal(h.settings.audioInputDeviceId, "microphone-2");
  assert.equal(h.settings.audioOutputDeviceId, "speaker-2");
  assert.equal(h.settings.inputVolume, 1.25);
  assert.equal(h.settings.outputVolume, 0.75);
  assert.deepEqual(h.rooms[0].deviceSwitches, [
    ["audioinput", "microphone-2"],
    ["audiooutput", "speaker-2"],
  ]);
});

test("each viewer can mute a stream and raise its volume to 200%", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("voice");
  const appliedVolumes = [];
  const participant = {
    identity: "streamer",
    setVolume(volume, source) { appliedVolumes.push([volume, source]); },
  };
  h.rooms[0].remoteParticipants.set("streamer", participant);
  h.settings.outputVolume = 0.5;

  h.api.setScreenShareVolume("streamer", 5);
  assert.equal(h.state.screenShareVolumes.streamer, 2);
  assert.deepEqual(appliedVolumes.at(-1), [1, "screen-audio"]);

  h.api.setScreenShareMuted("streamer", true);
  assert.equal(h.state.mutedScreenShares.streamer, true);
  assert.deepEqual(appliedVolumes.at(-1), [0, "screen-audio"]);

  h.api.setScreenShareVolume("streamer", 1.5);
  assert.deepEqual(appliedVolumes.at(-1), [0, "screen-audio"]);

  h.api.setScreenShareMuted("streamer", false);
  assert.equal(h.state.mutedScreenShares.streamer, undefined);
  assert.deepEqual(appliedVolumes.at(-1), [0.75, "screen-audio"]);
  await h.api.leaveVoiceChannel();
});

test("SDK full-restart order preserves the DM and watch choice", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("dm");
  const room = h.rooms[0];
  const publication = { source: "screen", isDesired: false, setSubscribed(watching) { this.isDesired = watching; } };
  const participant = {
    identity: "peer", attributes: {}, setVolume() {},
    getTrackPublication: () => undefined,
    trackPublications: new Map([["new-sid", publication]]),
  };
  // Real SDK emits publication/participant removal BEFORE Reconnecting.
  room.emit("TrackUnpublished", publication, participant);
  room.emit("ParticipantDisconnected", participant);
  room.state = "reconnecting";
  room.emit("Reconnecting");
  await Promise.resolve();
  t.mock.timers.tick(60_000);
  assert.equal(room.disconnects, 0);
  assert.equal(h.state.connectionStatus, "reconnecting");
  assert.equal(h.state.viewingScreenShares.peer, true);
  room.remoteParticipants.set("peer", participant);
  room.state = "connected";
  room.emit("Reconnected");
  assert.equal(publication.isDesired, true);
  assert.equal(h.state.connectionStatus, "connected");
  await h.api.leaveVoiceChannel();
});

test("a stale room disconnect cannot clear a newer call", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("dm");
  const oldRoom = h.rooms[0];
  await h.api.joinVoiceChannel("channel");
  oldRoom.emit("Disconnected");
  assert.equal(h.state.connectedChannelId, "channel");
  assert.equal(h.state.connectionStatus, "connected");
  await h.api.leaveVoiceChannel();
});

test("browser publication applies chosen quality and an intermediate layer", async (t) => {
  const h = voiceHarness(t);
  await h.api.joinVoiceChannel("channel");
  await h.api.startWebViewScreenShare(false, "1080p", 60);
  const [enabled, capture, publish] = h.rooms[0].screenOptions;
  assert.equal(enabled, true);
  assert.equal(capture.resolution.height, 1080);
  assert.equal(capture.resolution.frameRate, 60);
  assert.equal(publish.screenShareEncoding.maxBitrate, 8_000_000);
  assert.equal(publish.screenShareSimulcastLayers[1].height, 720);
  assert.equal(publish.degradationPreference, "maintain-framerate");
  assert.equal(h.rooms[0].options.adaptiveStream.pixelDensity, "screen");
  await h.api.leaveVoiceChannel();
});

test("native game capture publishes one high-priority H.264 layer", async (t) => {
  const h = voiceHarness(t, true);
  await h.api.joinVoiceChannel("channel");
  await h.api.startNativeScreenShare("window:42", "1080p", 30, false, true);

  const [, publish] = h.rooms[0].publishedTracks[0];
  assert.equal(publish.videoCodec, "h264");
  assert.equal(publish.backupCodec, false);
  assert.equal(publish.simulcast, false);
  assert.equal(publish.screenShareEncoding.maxBitrate, 12_000_000);
  assert.equal(publish.screenShareEncoding.priority, "high");
  assert.equal(publish.degradationPreference, "maintain-framerate");
  await h.api.stopScreenShare();
  await h.api.leaveVoiceChannel();
});

test("desktop client refuses the browser screen-capture picker", async (t) => {
  const h = voiceHarness(t, true);
  await h.api.joinVoiceChannel("channel");
  await assert.rejects(
    h.api.startWebViewScreenShare(false, "1080p", 30),
    /disabled in the desktop client/,
  );
  assert.equal(h.rooms[0].screenOptions, undefined);
  await h.api.leaveVoiceChannel();
});
