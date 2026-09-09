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

function captureHarness(t, start, overrides = {}) {
  t.mock.timers.enable({ apis: ["setTimeout", "setInterval"] });
  let stops = 0;
  let acknowledgements = 0;
  let trackStops = 0;
  let paints = 0;
  let channel;
  const track = { requestFrame() {}, stop() { trackStops++; } };
  const canvas = {
    width: 0, height: 0,
    getContext: () => ({ drawImage() { paints++; } }),
    captureStream: () => ({ getVideoTracks: () => [track] }),
  };
  const api = load("../src/lib/screenCapture.ts", {
    "./screenShareProfile": profileModule,
    "@tauri-apps/api/core": {
      Channel: class {},
      isTauri: () => true,
      invoke: async (command, args) => {
        if (command === "stop_capture") { stops++; return; }
        if (command === "acknowledge_capture") { acknowledgements++; return; }
        channel = args.onFrame;
        await start(channel);
      },
    },
  }, {
    ArrayBuffer, Blob, crypto: { randomUUID: () => "test-capture-id" },
    window: { setTimeout, clearTimeout, setInterval, clearInterval },
    document: { createElement: () => canvas },
    createImageBitmap: async () => ({ width: 1920, height: 1080, close() {} }),
    ...overrides,
  });
  return {
    api, canvas, track,
    get stops() { return stops; },
    get trackStops() { return trackStops; },
    get acknowledgements() { return acknowledgements; },
    get paints() { return paints; },
    send: (message) => channel.onmessage(message),
  };
}

test("a first frame arriving before the IPC reply starts a static screen", async (t) => {
  const h = captureHarness(t, async (channel) => {
    channel.onmessage(new ArrayBuffer(1));
    await Promise.resolve(); // decode completes before invoke returns
  });
  const capture = await h.api.startNativeCapture("screen:1", "1080p", 30, assert.fail);
  assert.equal(h.api.isNativeCaptureAvailable(), true);
  assert.equal(capture.track, h.track);
  assert.equal(h.canvas.width, 1920);
  assert.equal(capture.maxBitrate, 6_000_000);
  assert.equal(h.acknowledgements, 1);
  await capture.stop();
  assert.equal(h.stops, 1);
  assert.equal(h.trackStops, 1);
  const paints = h.paints;
  t.mock.timers.tick(10_000);
  h.send(new ArrayBuffer(1));
  await Promise.resolve();
  assert.equal(h.paints, paints);
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

test("canvas track failure also releases the native recorder", async (t) => {
  const h = captureHarness(t, async (channel) => {
    channel.onmessage(new ArrayBuffer(1));
    await Promise.resolve();
  });
  h.canvas.captureStream = () => { throw new Error("Unsupported canvas capture"); };
  await assert.rejects(h.api.startNativeCapture("screen:1", "720p", 30, assert.fail), /Unsupported/);
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
    "@/lib/sounds": {
      playJoinSound() {}, playLeaveSound() {},
      playDeafenSound() {}, playMicrophoneMuteSound() {},
      playMicrophoneUnmuteSound() {}, playUndeafenSound() {},
      playStreamStartSound() { sounds.streamStarts++; },
      playStreamStopSound() { sounds.streamStops++; },
    },
    sonner: { toast: {} },
  }, { queueMicrotask, console });
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
