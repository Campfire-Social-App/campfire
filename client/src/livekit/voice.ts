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
import { getVoiceToken } from "@/api/endpoints";
import { useVoiceStore } from "@/state/voice";
import { playJoinSound, playLeaveSound } from "@/lib/sounds";

let room: Room | null = null;
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

export async function joinVoiceChannel(channelId: string): Promise<void> {
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
    .on(RoomEvent.Disconnected, () => {
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

export async function setScreenShareEnabled(enabled: boolean): Promise<void> {
  if (!room) return;
  try {
    await room.localParticipant.setScreenShareEnabled(enabled, { audio: true });
    useVoiceStore.getState().setLocalScreenShareEnabled(enabled);
  } catch (err) {
    useVoiceStore.getState().setLocalScreenShareEnabled(false);
    throw err;
  }
}

function cleanupAudioElements(): void {
  for (const el of audioElements.values()) el.remove();
  audioElements.clear();
}
