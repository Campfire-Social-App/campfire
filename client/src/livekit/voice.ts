import { Room, RoomEvent, Track, type RemoteTrack, type RemoteTrackPublication } from "livekit-client";
import { getVoiceToken } from "@/api/endpoints";
import { useVoiceStore } from "@/state/voice";

let room: Room | null = null;
/** Remote audio elements keyed by track SID, so they can be torn down on unsubscribe. */
const audioElements = new Map<string, HTMLMediaElement>();

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
    .on(RoomEvent.TrackSubscribed, (track: RemoteTrack, publication: RemoteTrackPublication) => {
      if (track.kind !== Track.Kind.Audio) return;
      const el = track.attach();
      el.autoplay = true;
      audioElements.set(publication.trackSid, el);
    })
    .on(RoomEvent.TrackUnsubscribed, (_track, publication: RemoteTrackPublication) => {
      const el = audioElements.get(publication.trackSid);
      if (el) {
        el.remove();
        audioElements.delete(publication.trackSid);
      }
    })
    .on(RoomEvent.Disconnected, () => {
      cleanupAudioElements();
      useVoiceStore.getState().setConnection(null, "disconnected");
      room = null;
    });

  try {
    await nextRoom.connect(url, token);
    await nextRoom.localParticipant.setMicrophoneEnabled(!useVoiceStore.getState().localMuted);
    useVoiceStore.getState().setConnection(channelId, "connected");
  } catch (err) {
    cleanupAudioElements();
    useVoiceStore.getState().setConnection(null, "disconnected");
    room = null;
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

function cleanupAudioElements(): void {
  for (const el of audioElements.values()) el.remove();
  audioElements.clear();
}
