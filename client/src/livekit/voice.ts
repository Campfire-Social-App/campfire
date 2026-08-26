import {
  Room,
  RoomEvent,
  AudioPresets,
  ScreenSharePresets,
  Track,
  type AudioCaptureOptions,
  type LocalTrackPublication,
  type Participant,
  type RemoteParticipant,
  type RemoteTrack,
  type RemoteTrackPublication,
  type TrackPublication,
  type LocalVideoTrack,
  type LocalAudioTrack,
  type RemoteVideoTrack,
} from "livekit-client";
import { toast } from "sonner";
import { getVoiceToken, updateOwnVoiceState } from "@/api/endpoints";
import {
  isNativeCaptureAvailable,
  startNativeCapture,
  type CaptureQuality,
  type NativeCapture,
} from "@/lib/screenCapture";
import { useDmsStore } from "@/state/dms";
import { useChannelsStore } from "@/state/channels";
import { useVoiceStore } from "@/state/voice";
import { useSettingsStore } from "@/state/settings";
import { NoiseGateProcessor, type NoiseGateMode } from "@/lib/noiseGate";
import {
  playJoinSound,
  playLeaveSound,
  playDeafenSound,
  playMicrophoneMuteSound,
  playMicrophoneUnmuteSound,
  playUndeafenSound,
} from "@/lib/sounds";

let room: Room | null = null;

/** WebRTC's audio processing module runs before LiveKit hands the signal to
 * Opus. Keeping the complete speech preset here makes capture consistent
 * across Chromium/WebView versions instead of relying on SDK defaults. */
function microphoneCaptureOptions(
  noiseSuppressionEnabled: boolean,
  noiseGateMode: NoiseGateMode,
  enhancedVoiceIsolation = true,
): AudioCaptureOptions {
  const supported =
    typeof navigator === "undefined"
      ? undefined
      : navigator.mediaDevices?.getSupportedConstraints?.();
  return {
    echoCancellation: true,
    // AGC raises distant voices during pauses. Strong gate mode deliberately
    // keeps the physical distance between a close mic and a TV/background
    // speaker, allowing its calibrated threshold to reject the latter.
    autoGainControl: noiseGateMode !== "strong",
    ...(supported?.noiseSuppression !== false
      ? { noiseSuppression: noiseSuppressionEnabled }
      : {}),
    ...(enhancedVoiceIsolation && supported && "voiceIsolation" in supported
      ? { voiceIsolation: noiseSuppressionEnabled }
      : {}),
    channelCount: 1,
  };
}

const baselineMicrophoneCaptureOptions: AudioCaptureOptions = {
  echoCancellation: true,
  autoGainControl: true,
  channelCount: 1,
};
/** Set while the screen share is coming from our own capture rather than the
 * WebView's — it owns a Rust capture thread that has to be torn down with it. */
let nativeCapture: NativeCapture | null = null;
/** Remote audio elements keyed by track SID, so they can be torn down on unsubscribe. */
const audioElements = new Map<string, HTMLMediaElement>();
/** Camera/screen-share track visibility is keyed by participant + source, since
 * LiveKit mutes (rather than unpublishes) camera/mic tracks on disable — the
 * publish/unpublish events alone don't cover that case. */
function setVideoTrackForSource(
  participant: Participant,
  source: Track.Source,
  track: LocalVideoTrack | RemoteVideoTrack | null,
): void {
  if (source === Track.Source.ScreenShare) {
    useVoiceStore.getState().setScreenShareTrack(participant.identity, track);
  } else if (source === Track.Source.Camera) {
    useVoiceStore.getState().setCameraTrack(participant.identity, track);
  }
}

function applyParticipantPlaybackVolume(
  participant: RemoteParticipant,
  source: Track.Source.Microphone | Track.Source.ScreenShareAudio = Track.Source.Microphone,
): void {
  const voiceState = useVoiceStore.getState();
  const volume = voiceState.localDeafened
    ? 0
    : source === Track.Source.Microphone
      ? (voiceState.participantVolumes[participant.identity] ?? 1)
      : voiceState.mutedScreenShares[participant.identity]
        ? 0
        : (voiceState.screenShareVolumes[participant.identity] ?? 1);
  participant.setVolume(volume, source);
}

function configureRemoteScreenPublication(
  publication: RemoteTrackPublication,
  participant: RemoteParticipant,
): void {
  if (publication.source === Track.Source.ScreenShare) {
    useVoiceStore.getState().setScreenShareAvailable(participant.identity, true);
  }
  if (
    publication.source !== Track.Source.ScreenShare &&
    publication.source !== Track.Source.ScreenShareAudio
  ) {
    return;
  }
  const watching = !!useVoiceStore.getState().viewingScreenShares[participant.identity];
  if (publication.isDesired !== watching) publication.setSubscribed(watching);
}

function removeAttachedAudio(publication: RemoteTrackPublication): void {
  const element = audioElements.get(publication.trackSid);
  if (!element) return;
  publication.track?.detach(element);
  element.remove();
  audioElements.delete(publication.trackSid);
}

function attachRemoteAudio(
  track: RemoteTrack,
  publication: RemoteTrackPublication,
  participant: RemoteParticipant,
): void {
  if (audioElements.has(publication.trackSid)) return;
  if (
    publication.source === Track.Source.Microphone ||
    publication.source === Track.Source.ScreenShareAudio
  ) {
    applyParticipantPlaybackVolume(participant, publication.source);
  }
  const element = track.attach();
  element.autoplay = true;
  element.muted = useVoiceStore.getState().localDeafened;
  audioElements.set(publication.trackSid, element);
}

/** Keep the server-side roster accurate for clients that are not subscribed to
 * this LiveKit room. The join webhook and the media connection can complete in
 * either order, so a short retry window covers an initial 404 without making a
 * voice join wait on presence decoration. Each attempt reads the latest state,
 * preventing an older retry from overwriting a newer button action. */
async function syncOwnVoiceState(): Promise<void> {
  const retryDelays = [0, 200, 500, 1000];
  for (const delay of retryDelays) {
    if (!room) return;
    if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
    if (!room) return;
    const { localMuted, localDeafened, localScreenShareEnabled } = useVoiceStore.getState();
    try {
      await updateOwnVoiceState(localMuted, localDeafened, localScreenShareEnabled);
      return;
    } catch {
      // The LiveKit participant_joined webhook may still be in flight.
    }
  }
}

export interface JoinOptions {
  /** Publish the camera as soon as we're in — how a video call starts as one. */
  camera?: boolean;
}

/** Microphone setup must not decide whether the participant can join a room.
 * A processor can be unsupported by a WebView and a device can be absent or
 * denied; in both cases the call remains usable for listening and screen view. */
async function enableInitialMicrophone(participant: Room["localParticipant"]): Promise<boolean> {
  const settings = useSettingsStore.getState();
  try {
    await participant.setMicrophoneEnabled(
      true,
      microphoneCaptureOptions(settings.noiseSuppressionEnabled, settings.noiseGateMode),
    );
  } catch (enhancedError) {
    console.warn("Could not start enhanced microphone processing; retrying stable WebRTC options.", enhancedError);
    try {
      await participant.setMicrophoneEnabled(
        true,
        microphoneCaptureOptions(
          settings.noiseSuppressionEnabled,
          settings.noiseGateMode,
          false,
        ),
      );
      toast.warning("Voice isolation is unavailable; standard noise suppression is active.");
    } catch (suppressionError) {
      console.warn("Could not start noise suppression; retrying the microphone defaults.", suppressionError);
      try {
        await participant.setMicrophoneEnabled(true, baselineMicrophoneCaptureOptions);
        toast.warning("Noise suppression is unavailable on this device; the microphone is active.");
      } catch (microphoneError) {
        console.warn("Could not start the microphone; joining muted.", microphoneError);
        toast.warning("Microphone unavailable. You joined the voice channel muted.");
        return false;
      }
    }
  }

  // LiveKit 2.21 associates its AudioContext only after getUserMedia returns.
  // Installing a processor in AudioCaptureOptions makes capture itself fail;
  // attach the gate to the published track instead and keep it non-fatal.
  if (settings.noiseGateMode !== "off") {
    await applyNoiseGate(settings.noiseGateMode).catch((error) => {
      console.warn("Could not enable the noise gate; microphone remains active.", error);
      toast.warning("Noise gate unavailable. The microphone remains active.");
    });
  }
  return true;
}

export async function joinVoiceChannel(
  channelId: string,
  options: JoinOptions = {},
): Promise<void> {
  await leaveVoiceChannel();

  useVoiceStore.getState().setConnection(channelId, "connecting");
  const { localMuted, localDeafened } = useVoiceStore.getState();
  const { token, url } = await getVoiceToken(channelId, localMuted, localDeafened);

  const nextRoom = new Room({
    adaptiveStream: true,
    dynacast: true,
    // Per-participant gain above 100% requires Web Audio; HTMLMediaElement's
    // volume property is capped at 1. The LiveKit mixer keeps each remote track
    // on its own GainNode while preserving a single output device.
    webAudioMix: true,
    // Keep room defaults processor-free: LiveKit assigns the AudioContext only
    // after capture, and processors are installed on the published track.
    audioCaptureDefaults: baselineMicrophoneCaptureOptions,
    publishDefaults: {
      simulcast: true,
      screenShareEncoding: ScreenSharePresets.h720fps30.encoding,
      screenShareSimulcastLayers: [ScreenSharePresets.h360fps15],
    },
  });
  room = nextRoom;

  nextRoom
    .on(RoomEvent.ActiveSpeakersChanged, (speakers) => {
      useVoiceStore.getState().setSpeaking(speakers.map((p) => p.identity));
    })
    .on(RoomEvent.DataReceived, (payload, _participant, _kind, topic) => {
      if (topic !== "campfire.moderation") return;
      try {
        const command = JSON.parse(new TextDecoder().decode(payload)) as {
          action?: string;
          channel_id?: string;
          channel_name?: string;
        };
        if (command.action !== "move" || !command.channel_id) return;
        void joinVoiceChannel(command.channel_id)
          .then(() => {
            useChannelsStore.getState().selectChannel(command.channel_id!);
            toast(`A moderator moved you to ${command.channel_name ?? "another voice channel"}.`);
          })
          .catch(() => toast.error("A moderator tried to move you, but joining failed."));
      } catch {
        // Ignore data packets that are not valid Campfire moderation commands.
      }
    })
    .on(RoomEvent.ParticipantAttributesChanged, (attributes, participant) => {
      if (attributes.deafened !== undefined) {
        useVoiceStore
          .getState()
          .setParticipantDeafened(participant.identity, attributes.deafened === "true");
      }
    })
    .on(RoomEvent.ParticipantConnected, (participant) => {
      applyParticipantPlaybackVolume(participant);
      const voiceState = useVoiceStore.getState();
      // A participant who joins already muted may not publish/subscribe a mic
      // track at all, so derive the initial indicator from the participant too.
      voiceState.setParticipantMuted(participant.identity, !participant.isMicrophoneEnabled);
      voiceState.setParticipantDeafened(
        participant.identity,
        participant.attributes.deafened === "true",
      );
    })
    .on(RoomEvent.TrackPublished, (publication: RemoteTrackPublication, participant) => {
      configureRemoteScreenPublication(publication, participant);
      if (publication.source === Track.Source.Microphone) {
        useVoiceStore.getState().setParticipantMuted(participant.identity, publication.isMuted);
      }
    })
    .on(
      RoomEvent.TrackSubscribed,
      (track: RemoteTrack, publication: RemoteTrackPublication, participant) => {
        if (
          (publication.source === Track.Source.ScreenShare ||
            publication.source === Track.Source.ScreenShareAudio) &&
          !useVoiceStore.getState().viewingScreenShares[participant.identity]
        ) {
          publication.setSubscribed(false);
          return;
        }
        if (track.kind === Track.Kind.Video) {
          if (!publication.isMuted) setVideoTrackForSource(participant, track.source, track as RemoteVideoTrack);
          return;
        }
        if (publication.source === Track.Source.Microphone) {
          useVoiceStore.getState().setParticipantMuted(participant.identity, publication.isMuted);
        }
        attachRemoteAudio(track, publication, participant);
      },
    )
    .on(
      RoomEvent.TrackUnsubscribed,
      (track: RemoteTrack, publication: RemoteTrackPublication, participant) => {
        if (track.kind === Track.Kind.Video) {
          setVideoTrackForSource(participant, track.source, null);
          return;
        }
        removeAttachedAudio(publication);
      },
    )
    .on(RoomEvent.TrackUnpublished, (publication: RemoteTrackPublication, participant) => {
      if (publication.source === Track.Source.ScreenShare) {
        useVoiceStore.getState().setScreenShareAvailable(participant.identity, false);
      } else if (publication.source === Track.Source.ScreenShareAudio) {
        removeAttachedAudio(publication);
      }
    })
    .on(RoomEvent.LocalTrackPublished, (publication: LocalTrackPublication, participant) => {
      if (publication.source === Track.Source.ScreenShare) {
        const voiceState = useVoiceStore.getState();
        voiceState.setScreenShareAvailable(participant.identity, true);
        voiceState.setScreenShareViewing(participant.identity, true);
      }
      if (publication.track?.kind === Track.Kind.Video) {
        setVideoTrackForSource(participant, publication.source, publication.track as LocalVideoTrack);
      }
    })
    .on(RoomEvent.LocalTrackUnpublished, (publication: LocalTrackPublication, participant) => {
      if (publication.source === Track.Source.ScreenShare) {
        useVoiceStore.getState().setScreenShareAvailable(participant.identity, false);
      }
      if (publication.track?.kind !== Track.Kind.Video) return;
      setVideoTrackForSource(participant, publication.source, null);
      // Catches screen share stopped via the browser's native "Stop sharing" UI,
      // which bypasses our own setScreenShareEnabled(false) call.
      if (publication.source === Track.Source.ScreenShare) {
        useVoiceStore.getState().setLocalScreenShareEnabled(false);
        void syncOwnVoiceState();
      } else if (publication.source === Track.Source.Camera) {
        useVoiceStore.getState().setLocalCameraEnabled(false);
      }
    })
    // LiveKit mutes camera/mic tracks in place (rather than unpublishing) once
    // they've been published once, so track visibility has to react to mute too.
    .on(RoomEvent.TrackMuted, (publication: TrackPublication, participant) => {
      if (publication.source === Track.Source.Microphone) {
        useVoiceStore.getState().setParticipantMuted(participant.identity, true);
      } else if (publication.kind === Track.Kind.Video) {
        setVideoTrackForSource(participant, publication.source, null);
      }
    })
    .on(RoomEvent.TrackUnmuted, (publication: TrackPublication, participant) => {
      if (publication.source === Track.Source.Microphone) {
        useVoiceStore.getState().setParticipantMuted(participant.identity, false);
      } else if (publication.kind === Track.Kind.Video && publication.track) {
        setVideoTrackForSource(
          participant,
          publication.source,
          publication.track as LocalVideoTrack | RemoteVideoTrack,
        );
      }
    })
    .on(RoomEvent.ParticipantDisconnected, () => {
      // A 1:1 call is over the moment the other person leaves — unlike a voice
      // channel, where sitting in an empty room waiting for someone is normal.
      const isDm = useDmsStore
        .getState()
        .conversations.some((c) => c.id === useVoiceStore.getState().connectedChannelId);
      if (isDm && nextRoom.remoteParticipants.size === 0) void leaveVoiceChannel();
    })
    .on(RoomEvent.Disconnected, () => {
      void stopNativeCapture();
      cleanupAudioElements();
      // Only sound off if we'd actually finished joining — a mid-setup failure
      // (e.g. mic permission denied) disconnects too, but never played a join sound.
      const wasConnected = useVoiceStore.getState().connectionStatus === "connected";
      useVoiceStore.getState().setConnection(null, "disconnected");
      room = null;
      if (wasConnected) playLeaveSound();
    });

  try {
    await nextRoom.connect(url, token);
    const microphoneEnabled = localMuted
      ? false
      : await enableInitialMicrophone(nextRoom.localParticipant);
    const joinedMuted = localMuted || !microphoneEnabled;
    if (joinedMuted !== localMuted) useVoiceStore.getState().setLocalMuted(joinedMuted);
    useVoiceStore
      .getState()
      .setParticipantMuted(nextRoom.localParticipant.identity, joinedMuted);
    // Presence decoration must never make an otherwise healthy voice join
    // fail (for example while talking to an older server token without the
    // metadata grant).
    await nextRoom.localParticipant
      .setAttributes({ muted: String(joinedMuted), deafened: String(localDeafened) })
      .catch(() => {});
    useVoiceStore
      .getState()
      .setParticipantDeafened(nextRoom.localParticipant.identity, localDeafened);
    void syncOwnVoiceState();
    for (const participant of nextRoom.remoteParticipants.values()) {
      applyParticipantPlaybackVolume(participant);
      for (const publication of participant.trackPublications.values()) {
        configureRemoteScreenPublication(publication, participant);
      }
      const voiceState = useVoiceStore.getState();
      voiceState.setParticipantMuted(participant.identity, !participant.isMicrophoneEnabled);
      voiceState.setParticipantDeafened(
        participant.identity,
        participant.attributes.deafened === "true",
      );
    }
    useVoiceStore.getState().setConnection(channelId, "connected");
    playJoinSound();
    if (options.camera) {
      // After the join is committed: a camera that won't start (no device, denied
      // permission) shouldn't take the call down with it — it lands as audio-only.
      try {
        await nextRoom.localParticipant.setCameraEnabled(true);
        useVoiceStore.getState().setLocalCameraEnabled(true);
      } catch {
        useVoiceStore.getState().setLocalCameraEnabled(false);
      }
    }
  } catch (err) {
    cleanupAudioElements();
    useVoiceStore.getState().setConnection(null, "disconnected");
    room = null;
    // The signal connection may have succeeded even though a later setup step
    // (e.g. mic access) failed — disconnect it explicitly so it doesn't linger
    // as an orphaned session that gets forcibly kicked on the next join attempt.
    void nextRoom.disconnect();
    throw err;
  }
}

/** Changes only this client's microphone playback gain for a remote user. */
export function setParticipantVolume(userId: string, volume: number): void {
  const clamped = Math.max(0, Math.min(2, volume));
  const voiceState = useVoiceStore.getState();
  voiceState.setParticipantVolume(userId, clamped);
  if (!voiceState.localDeafened) {
    room?.remoteParticipants.get(userId)?.setVolume(clamped, Track.Source.Microphone);
  }
}

/** Changes only this client's playback gain for a remote screen share. */
export function setScreenShareVolume(userId: string, volume: number): void {
  const clamped = Math.max(0, Math.min(2, volume));
  const voiceState = useVoiceStore.getState();
  voiceState.setScreenShareVolume(userId, clamped);
  if (!voiceState.localDeafened && !voiceState.mutedScreenShares[userId]) {
    room?.remoteParticipants
      .get(userId)
      ?.setVolume(clamped, Track.Source.ScreenShareAudio);
  }
}

/** Mutes only the remote screen-share audio for this client. */
export function setScreenShareMuted(userId: string, muted: boolean): void {
  const voiceState = useVoiceStore.getState();
  voiceState.setScreenShareMuted(userId, muted);
  if (!voiceState.localDeafened) {
    const volume = muted ? 0 : (voiceState.screenShareVolumes[userId] ?? 1);
    room?.remoteParticipants
      .get(userId)
      ?.setVolume(volume, Track.Source.ScreenShareAudio);
  }
}

/** Opts this client into or out of a remote participant's screen video and
 * screen audio together. Camera and microphone subscriptions are untouched. */
export function setScreenShareViewing(userId: string, viewing: boolean): void {
  const voiceState = useVoiceStore.getState();
  voiceState.setScreenShareViewing(userId, viewing);
  const participant = room?.remoteParticipants.get(userId);
  if (!participant) return;

  for (const source of [Track.Source.ScreenShare, Track.Source.ScreenShareAudio] as const) {
    const publication = participant.getTrackPublication(source);
    if (!publication) continue;
    if (publication.isDesired !== viewing) publication.setSubscribed(viewing);
    if (viewing && publication.track) {
      if (source === Track.Source.ScreenShare && !publication.isMuted) {
        voiceState.setScreenShareTrack(userId, publication.track as RemoteVideoTrack);
      } else if (source === Track.Source.ScreenShareAudio) {
        attachRemoteAudio(publication.track, publication, participant);
      }
    }
    if (!viewing && source === Track.Source.ScreenShareAudio) removeAttachedAudio(publication);
  }
  if (!viewing) voiceState.setScreenShareTrack(userId, null);
}

export async function leaveVoiceChannel(): Promise<void> {
  if (!room) return;
  const current = room;
  room = null;
  await stopNativeCapture();
  await current.disconnect();
  cleanupAudioElements();
  useVoiceStore.getState().setConnection(null, "disconnected");
}

export async function setMicrophoneMuted(
  muted: boolean,
  options: { playFeedback?: boolean; syncAudio?: boolean; syncPresence?: boolean } = {},
): Promise<void> {
  // A direct microphone action takes ownership of its state, even while the
  // output audio is deafened.
  useVoiceStore.getState().setMicrophoneMutedByDeafen(false);
  const wasDeafened = useVoiceStore.getState().localDeafened;
  await room?.localParticipant.setMicrophoneEnabled(
    !muted,
    microphoneCaptureOptions(
      useSettingsStore.getState().noiseSuppressionEnabled,
      useSettingsStore.getState().noiseGateMode,
    ),
  );
  if (!muted) {
    await applyNoiseGate(useSettingsStore.getState().noiseGateMode).catch(() => {});
  }
  const voiceState = useVoiceStore.getState();
  voiceState.setLocalMuted(muted);
  if (room) voiceState.setParticipantMuted(room.localParticipant.identity, muted);
  await room?.localParticipant
    .setAttributes({ muted: String(muted), deafened: String(voiceState.localDeafened) })
    .catch(() => {});
  // Unmuting the microphone while deafened enables the audio too. Let the
  // undeafen transition provide the single feedback sound for both changes.
  const willUndeafenAudio = !muted && wasDeafened && options.syncAudio !== false;
  if (options.playFeedback !== false && !willUndeafenAudio) {
    if (muted) playMicrophoneMuteSound();
    else playMicrophoneUnmuteSound();
  }
  if (willUndeafenAudio) await setDeafened(false);
  else if (options.syncPresence !== false) {
    await syncOwnVoiceState();
  }
}

/** Applies a settings change to an already-open microphone without leaving the
 * room. When no mic exists yet (for example, the user joined muted), the next
 * unmute consumes the persisted setting through microphoneCaptureOptions. */
export async function applyNoiseSuppression(enabled: boolean): Promise<void> {
  const publication = room?.localParticipant.getTrackPublication(Track.Source.Microphone);
  const track = publication?.track as LocalAudioTrack | undefined;
  if (!track) return;
  const options = microphoneCaptureOptions(
    enabled,
    useSettingsStore.getState().noiseGateMode,
  );
  await track.applyConstraints({
    echoCancellation: options.echoCancellation,
    autoGainControl: options.autoGainControl,
    noiseSuppression: options.noiseSuppression,
    voiceIsolation: options.voiceIsolation,
  });
}

/** Installs or removes the adaptive gate on the already-published microphone.
 * The next unmute applies the persisted mode when no local track exists yet. */
export async function applyNoiseGate(mode: NoiseGateMode): Promise<void> {
  const publication = room?.localParticipant.getTrackPublication(Track.Source.Microphone);
  const track = publication?.track as LocalAudioTrack | undefined;
  if (!track) return;

  // Apply the matching capture gain policy immediately when switching modes.
  // This remains best-effort because some audio drivers expose AGC as a fixed
  // constraint even though WebRTC reports the property as supported.
  await track
    .applyConstraints({ autoGainControl: mode !== "strong" })
    .catch((error) => console.warn("Could not update microphone gain control.", error));

  const current = track.getProcessor();
  if (mode === "off") {
    if (current?.name.startsWith("campfire-noise-gate-")) await track.stopProcessor();
    return;
  }
  if (current instanceof NoiseGateProcessor && current.mode === mode) return;
  await track.setProcessor(new NoiseGateProcessor(mode));
}

export async function setDeafened(deafened: boolean): Promise<void> {
  if (deafened) {
    // Only remember an automatic mute when the microphone was active. If it
    // was already muted, that was the user's choice and must be preserved.
    if (!useVoiceStore.getState().localMuted) {
      await setMicrophoneMuted(true, { playFeedback: false, syncPresence: false });
      useVoiceStore.getState().setMicrophoneMutedByDeafen(true);
    } else {
      useVoiceStore.getState().setMicrophoneMutedByDeafen(false);
    }
  } else {
    // Undo only the mute introduced by deafening. A microphone muted before
    // the audio was deafened remains muted until its own button is clicked.
    if (
      useVoiceStore.getState().microphoneMutedByDeafen &&
      useVoiceStore.getState().localMuted
    ) {
      await setMicrophoneMuted(false, {
        playFeedback: false,
        syncAudio: false,
        syncPresence: false,
      });
    }
    useVoiceStore.getState().setMicrophoneMutedByDeafen(false);
  }
  useVoiceStore.getState().setLocalDeafened(deafened);
  for (const el of audioElements.values()) el.muted = deafened;
  if (room) {
    for (const participant of room.remoteParticipants.values()) {
      applyParticipantPlaybackVolume(participant, Track.Source.Microphone);
      applyParticipantPlaybackVolume(participant, Track.Source.ScreenShareAudio);
    }
    useVoiceStore.getState().setParticipantDeafened(room.localParticipant.identity, deafened);
    await room.localParticipant
      .setAttributes({
        muted: String(useVoiceStore.getState().localMuted),
        deafened: String(deafened),
      })
      .catch(() => {});
  }
  await syncOwnVoiceState();
  if (deafened) playDeafenSound();
  else playUndeafenSound();
}

export async function setCameraEnabled(enabled: boolean): Promise<void> {
  if (!room) return;
  try {
    await room.localParticipant.setCameraEnabled(enabled);
    useVoiceStore.getState().setLocalCameraEnabled(enabled);
  } catch (err) {
    useVoiceStore.getState().setLocalCameraEnabled(false);
    throw err;
  }
}

/** Shares a source the user picked in our own picker: the frames come from Rust
 * (see lib/screenCapture.ts) and are published as a normal screen-share track,
 * so the receiving end can't tell it apart from a WebView capture. */
export async function startNativeScreenShare(
  sourceId: string,
  quality: CaptureQuality,
  fps: number,
): Promise<void> {
  if (!room) return;
  const currentRoom = room;

  await stopScreenShare();
  const capture = await startNativeCapture(sourceId, quality, fps, (message) => {
    // The capture died on its own (window closed, device lost) — the track is
    // still published but nothing will ever feed it again.
    toast.error(message);
    void stopScreenShare();
  });

  try {
    await currentRoom.localParticipant.publishTrack(capture.track, {
      name: "screen",
      source: Track.Source.ScreenShare,
      // A half-resolution layer lets the SFU switch weak subscribers quickly;
      // dynacast stops paying for it when nobody needs it.
      simulcast: true,
      screenShareSimulcastLayers: [ScreenSharePresets.h360fps15],
      degradationPreference: "balanced",
      screenShareEncoding: { maxBitrate: capture.maxBitrate, maxFramerate: fps },
    });
  } catch (err) {
    await capture.stop();
    throw err;
  }

  nativeCapture = capture;
  useVoiceStore.getState().setLocalScreenShareEnabled(true);
  void syncOwnVoiceState();
}

/** What the share button calls: our own picker in the desktop app, the WebView's
 * built-in one in a browser, where native capture isn't reachable. */
export async function requestScreenShare(): Promise<void> {
  if (isNativeCaptureAvailable()) {
    useVoiceStore.getState().setScreenPickerOpen(true);
    return;
  }
  await startWebViewScreenShare();
}

/** The platform picker, used by browsers and by the desktop's audio-sharing
 * mode because getDisplayMedia must return screen video and system audio in a
 * single permission grant. */
export async function startWebViewScreenShare(captureAudio = true): Promise<void> {
  if (!room) return;
  try {
    await room.localParticipant.setScreenShareEnabled(true, {
      audio: captureAudio,
      resolution: ScreenSharePresets.h720fps30,
      contentHint: "detail",
      systemAudio: captureAudio ? "include" : "exclude",
      surfaceSwitching: "include",
    }, {
      // Screen audio is continuous program material, not speech. Disabling DTX
      // prevents voice activity from opening/closing the Opus stream, while a
      // stereo music preset avoids the narrow-band microphone defaults.
      audioPreset: AudioPresets.musicHighQualityStereo,
      forceStereo: true,
      dtx: false,
      red: false,
    });
    useVoiceStore.getState().setLocalScreenShareEnabled(true);
    void syncOwnVoiceState();
    if (captureAudio) {
      const publication = room.localParticipant.getTrackPublication(
        Track.Source.ScreenShareAudio,
      );
      const screenAudio = publication?.track as LocalAudioTrack | undefined;
      if (!screenAudio) {
        toast.warning("The selected source doesn't provide system audio. Sharing video only.");
      } else {
        await configureScreenShareAudio(screenAudio);
      }
    }
  } catch (err) {
    useVoiceStore.getState().setLocalScreenShareEnabled(false);
    throw err;
  }
}

/** Keeps screen audio independent from voice activity. Browser audio capture
 * can otherwise inherit microphone processing (AEC/AGC/noise suppression),
 * which audibly ducks music whenever another participant speaks. */
async function configureScreenShareAudio(track: LocalAudioTrack): Promise<void> {
  const mediaTrack = track.mediaStreamTrack;
  mediaTrack.contentHint = "music";

  const supported = navigator.mediaDevices.getSupportedConstraints?.();
  const constraints: MediaTrackConstraints = {
    ...(supported?.autoGainControl !== false ? { autoGainControl: false } : {}),
    ...(supported?.echoCancellation !== false ? { echoCancellation: false } : {}),
    ...(supported?.noiseSuppression !== false ? { noiseSuppression: false } : {}),
  };
  // Chromium can remove this application's call output from system capture,
  // preventing a remote voice from entering the shared track and triggering
  // the platform's echo-control ducking. Unknown optional constraints are
  // ignored by browsers that do not implement the extension.
  if (supported && "restrictOwnAudio" in supported) {
    Object.assign(constraints, { restrictOwnAudio: true });
  }
  if (supported && "voiceIsolation" in supported) {
    Object.assign(constraints, { voiceIsolation: false });
  }

  await mediaTrack.applyConstraints(constraints).catch(() => {
    // Capture remains useful on older WebViews even when they reject one of
    // the optional music-oriented constraints.
  });
}

export async function stopScreenShare(): Promise<void> {
  const capture = nativeCapture;
  nativeCapture = null;

  if (capture) {
    await room?.localParticipant.unpublishTrack(capture.track).catch(() => {});
    await capture.stop();
  } else {
    await room?.localParticipant.setScreenShareEnabled(false).catch(() => {});
  }
  useVoiceStore.getState().setLocalScreenShareEnabled(false);
  void syncOwnVoiceState();
}

/** Tears down the Rust capture without touching the room — for paths where the
 * room is already gone (disconnected) and unpublishing would be meaningless. */
async function stopNativeCapture(): Promise<void> {
  const capture = nativeCapture;
  nativeCapture = null;
  if (capture) await capture.stop();
}

function cleanupAudioElements(): void {
  for (const el of audioElements.values()) el.remove();
  audioElements.clear();
}
