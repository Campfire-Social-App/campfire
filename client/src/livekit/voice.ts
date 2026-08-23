import {
  Room,
  RoomEvent,
  Track,
  type LocalTrackPublication,
  type Participant,
  type RemoteTrack,
  type RemoteTrackPublication,
  type TrackPublication,
  type LocalVideoTrack,
  type RemoteVideoTrack,
} from "livekit-client";
import { toast } from "sonner";
import { getVoiceToken } from "@/api/endpoints";
import {
  isNativeCaptureAvailable,
  startNativeCapture,
  type CaptureQuality,
  type NativeCapture,
} from "@/lib/screenCapture";
import { useDmsStore } from "@/state/dms";
import { useChannelsStore } from "@/state/channels";
import { useVoiceStore } from "@/state/voice";
import {
  playJoinSound,
  playLeaveSound,
  playDeafenSound,
  playMicrophoneMuteSound,
  playMicrophoneUnmuteSound,
  playUndeafenSound,
} from "@/lib/sounds";

let room: Room | null = null;
/** Set while the screen share is coming from our own capture rather than the
 * WebView's — it owns a Rust capture thread that has to be torn down with it. */
let nativeCapture: NativeCapture | null = null;
/** Remote audio elements keyed by track SID, so they can be torn down on unsubscribe. */
const audioElements = new Map<string, HTMLMediaElement>();
/** Whether deafening, rather than the microphone button, caused the current
 * microphone mute. Only an automatic mute may be automatically undone. */
let microphoneMutedByDeafen = false;

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

export interface JoinOptions {
  /** Publish the camera as soon as we're in — how a video call starts as one. */
  camera?: boolean;
}

export async function joinVoiceChannel(
  channelId: string,
  options: JoinOptions = {},
): Promise<void> {
  await leaveVoiceChannel();

  useVoiceStore.getState().setConnection(channelId, "connecting");
  const { token, url } = await getVoiceToken(channelId);

  const nextRoom = new Room();
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
    .on(
      RoomEvent.TrackSubscribed,
      (track: RemoteTrack, publication: RemoteTrackPublication, participant) => {
        if (track.kind === Track.Kind.Video) {
          if (!publication.isMuted) setVideoTrackForSource(participant, track.source, track as RemoteVideoTrack);
          return;
        }
        if (publication.source === Track.Source.Microphone) {
          useVoiceStore.getState().setParticipantMuted(participant.identity, publication.isMuted);
        }
        const el = track.attach();
        el.autoplay = true;
        audioElements.set(publication.trackSid, el);
      },
    )
    .on(
      RoomEvent.TrackUnsubscribed,
      (track: RemoteTrack, publication: RemoteTrackPublication, participant) => {
        if (track.kind === Track.Kind.Video) {
          setVideoTrackForSource(participant, track.source, null);
          return;
        }
        const el = audioElements.get(publication.trackSid);
        if (el) {
          el.remove();
          audioElements.delete(publication.trackSid);
        }
      },
    )
    .on(RoomEvent.LocalTrackPublished, (publication: LocalTrackPublication, participant) => {
      if (publication.track?.kind === Track.Kind.Video) {
        setVideoTrackForSource(participant, publication.source, publication.track as LocalVideoTrack);
      }
    })
    .on(RoomEvent.LocalTrackUnpublished, (publication: LocalTrackPublication, participant) => {
      if (publication.track?.kind !== Track.Kind.Video) return;
      setVideoTrackForSource(participant, publication.source, null);
      // Catches screen share stopped via the browser's native "Stop sharing" UI,
      // which bypasses our own setScreenShareEnabled(false) call.
      if (publication.source === Track.Source.ScreenShare) {
        useVoiceStore.getState().setLocalScreenShareEnabled(false);
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
    const localMuted = useVoiceStore.getState().localMuted;
    await nextRoom.localParticipant.setMicrophoneEnabled(!localMuted);
    useVoiceStore.getState().setParticipantMuted(nextRoom.localParticipant.identity, localMuted);
    const localDeafened = useVoiceStore.getState().localDeafened;
    // Presence decoration must never make an otherwise healthy voice join
    // fail (for example while talking to an older server token without the
    // metadata grant).
    await nextRoom.localParticipant
      .setAttributes({ deafened: String(localDeafened) })
      .catch(() => {});
    useVoiceStore
      .getState()
      .setParticipantDeafened(nextRoom.localParticipant.identity, localDeafened);
    for (const participant of nextRoom.remoteParticipants.values()) {
      useVoiceStore
        .getState()
        .setParticipantDeafened(participant.identity, participant.attributes.deafened === "true");
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
  options: { playFeedback?: boolean; syncAudio?: boolean } = {},
): Promise<void> {
  // A direct microphone action takes ownership of its state, even while the
  // output audio is deafened.
  microphoneMutedByDeafen = false;
  const wasDeafened = useVoiceStore.getState().localDeafened;
  await room?.localParticipant.setMicrophoneEnabled(!muted);
  const voiceState = useVoiceStore.getState();
  voiceState.setLocalMuted(muted);
  if (room) voiceState.setParticipantMuted(room.localParticipant.identity, muted);
  // Unmuting the microphone while deafened enables the audio too. Let the
  // undeafen transition provide the single feedback sound for both changes.
  const willUndeafenAudio = !muted && wasDeafened && options.syncAudio !== false;
  if (options.playFeedback !== false && !willUndeafenAudio) {
    if (muted) playMicrophoneMuteSound();
    else playMicrophoneUnmuteSound();
  }
  if (willUndeafenAudio) await setDeafened(false);
}

export async function setDeafened(deafened: boolean): Promise<void> {
  if (deafened) {
    // Only remember an automatic mute when the microphone was active. If it
    // was already muted, that was the user's choice and must be preserved.
    if (!useVoiceStore.getState().localMuted) {
      await setMicrophoneMuted(true, { playFeedback: false });
      microphoneMutedByDeafen = true;
    } else {
      microphoneMutedByDeafen = false;
    }
  } else {
    // Undo only the mute introduced by deafening. A microphone muted before
    // the audio was deafened remains muted until its own button is clicked.
    if (microphoneMutedByDeafen && useVoiceStore.getState().localMuted) {
      await setMicrophoneMuted(false, { playFeedback: false, syncAudio: false });
    }
    microphoneMutedByDeafen = false;
  }
  useVoiceStore.getState().setLocalDeafened(deafened);
  for (const el of audioElements.values()) el.muted = deafened;
  if (room) {
    useVoiceStore.getState().setParticipantDeafened(room.localParticipant.identity, deafened);
    await room.localParticipant.setAttributes({ deafened: String(deafened) }).catch(() => {});
  }
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
      // Screen content degrades badly when scaled: drop frames before pixels.
      simulcast: false,
      degradationPreference: "maintain-resolution",
      videoEncoding: { maxBitrate: capture.maxBitrate, maxFramerate: fps },
    });
  } catch (err) {
    await capture.stop();
    throw err;
  }

  nativeCapture = capture;
  useVoiceStore.getState().setLocalScreenShareEnabled(true);
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

/** The WebView's own picker — the fallback outside the desktop app. */
export async function startWebViewScreenShare(): Promise<void> {
  if (!room) return;
  try {
    await room.localParticipant.setScreenShareEnabled(true, { audio: true });
    useVoiceStore.getState().setLocalScreenShareEnabled(true);
  } catch (err) {
    useVoiceStore.getState().setLocalScreenShareEnabled(false);
    throw err;
  }
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
