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
import { useVoiceStore } from "@/state/voice";
import { playJoinSound, playLeaveSound } from "@/lib/sounds";

let room: Room | null = null;
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
    .on(
      RoomEvent.TrackSubscribed,
      (track: RemoteTrack, publication: RemoteTrackPublication, participant) => {
        if (track.kind === Track.Kind.Video) {
          if (!publication.isMuted) setVideoTrackForSource(participant, track.source, track as RemoteVideoTrack);
          return;
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
      if (publication.kind !== Track.Kind.Video) return;
      setVideoTrackForSource(participant, publication.source, null);
    })
    .on(RoomEvent.TrackUnmuted, (publication: TrackPublication, participant) => {
      if (publication.kind !== Track.Kind.Video || !publication.track) return;
      setVideoTrackForSource(
        participant,
        publication.source,
        publication.track as LocalVideoTrack | RemoteVideoTrack,
      );
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
    await nextRoom.localParticipant.setMicrophoneEnabled(!useVoiceStore.getState().localMuted);
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

export async function setMicrophoneMuted(muted: boolean): Promise<void> {
  useVoiceStore.getState().setLocalMuted(muted);
  await room?.localParticipant.setMicrophoneEnabled(!muted);
}

export function setDeafened(deafened: boolean): void {
  useVoiceStore.getState().setLocalDeafened(deafened);
  for (const el of audioElements.values()) el.muted = deafened;
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
