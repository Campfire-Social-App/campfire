import { create } from "zustand";
import type { LocalVideoTrack, RemoteVideoTrack } from "livekit-client";
import type { VoiceParticipantState, VoiceStateUpdateData } from "@/lib/types";

export type VoiceConnectionStatus = "disconnected" | "connecting" | "connected";
export type VideoTrack = LocalVideoTrack | RemoteVideoTrack;

interface VoiceState {
  states: VoiceParticipantState[];
  connectedChannelId: string | null;
  connectionStatus: VoiceConnectionStatus;
  localMuted: boolean;
  localDeafened: boolean;
  localCameraEnabled: boolean;
  localScreenShareEnabled: boolean;
  speakingUserIds: Record<string, true>;
  /** Camera/screen-share video tracks keyed by participant user id. */
  cameraTracks: Record<string, VideoTrack>;
  screenShareTracks: Record<string, VideoTrack>;

  setVoiceStates: (states: VoiceParticipantState[]) => void;
  applyVoiceStateUpdate: (data: VoiceStateUpdateData) => void;
  setConnection: (channelId: string | null, status: VoiceConnectionStatus) => void;
  setLocalMuted: (muted: boolean) => void;
  setLocalDeafened: (deafened: boolean) => void;
  setLocalCameraEnabled: (enabled: boolean) => void;
  setLocalScreenShareEnabled: (enabled: boolean) => void;
  setSpeaking: (userIds: string[]) => void;
  setCameraTrack: (userId: string, track: VideoTrack | null) => void;
  setScreenShareTrack: (userId: string, track: VideoTrack | null) => void;
  participantsInChannel: (channelId: string) => VoiceParticipantState[];
}

export const useVoiceStore = create<VoiceState>()((set, get) => ({
  states: [],
  connectedChannelId: null,
  connectionStatus: "disconnected",
  localMuted: false,
  localDeafened: false,
  localCameraEnabled: false,
  localScreenShareEnabled: false,
  speakingUserIds: {},
  cameraTracks: {},
  screenShareTracks: {},

  setVoiceStates: (states) => set({ states }),

  applyVoiceStateUpdate: (data) =>
    set((state) => {
      if (data.action === "joined" && data.user_id && data.channel_id) {
        const next = state.states.filter((s) => s.user_id !== data.user_id);
        next.push({
          user_id: data.user_id,
          username: data.username ?? data.user_id,
          channel_id: data.channel_id,
          muted: false,
          speaking: false,
        });
        return { states: next };
      }
      if (data.action === "left" && data.user_id) {
        return { states: state.states.filter((s) => s.user_id !== data.user_id) };
      }
      if (data.action === "room_finished" && data.channel_id) {
        return { states: state.states.filter((s) => s.channel_id !== data.channel_id) };
      }
      return state;
    }),

  setConnection: (channelId, status) =>
    set({
      connectedChannelId: status === "disconnected" ? null : channelId,
      connectionStatus: status,
      ...(status === "disconnected"
        ? {
            speakingUserIds: {},
            cameraTracks: {},
            screenShareTracks: {},
            localCameraEnabled: false,
            localScreenShareEnabled: false,
          }
        : {}),
    }),

  setLocalMuted: (muted) => set({ localMuted: muted }),
  setLocalDeafened: (deafened) => set({ localDeafened: deafened }),
  setLocalCameraEnabled: (enabled) => set({ localCameraEnabled: enabled }),
  setLocalScreenShareEnabled: (enabled) => set({ localScreenShareEnabled: enabled }),

  setSpeaking: (userIds) =>
    set({ speakingUserIds: Object.fromEntries(userIds.map((id) => [id, true])) }),

  setCameraTrack: (userId, track) =>
    set((state) => {
      const next = { ...state.cameraTracks };
      if (track) next[userId] = track;
      else delete next[userId];
      return { cameraTracks: next };
    }),

  setScreenShareTrack: (userId, track) =>
    set((state) => {
      const next = { ...state.screenShareTracks };
      if (track) next[userId] = track;
      else delete next[userId];
      return { screenShareTracks: next };
    }),

  participantsInChannel: (channelId) => get().states.filter((s) => s.channel_id === channelId),
}));
