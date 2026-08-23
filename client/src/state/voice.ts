import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { LocalVideoTrack, RemoteVideoTrack } from "livekit-client";
import type { VoiceParticipantState, VoiceStateUpdateData } from "@/lib/types";
import { createSecureStorage } from "@/state/persist";

export type VoiceConnectionStatus = "disconnected" | "connecting" | "connected";
export type VideoTrack = LocalVideoTrack | RemoteVideoTrack;

interface VoiceState {
  states: VoiceParticipantState[];
  connectedChannelId: string | null;
  connectionStatus: VoiceConnectionStatus;
  localMuted: boolean;
  localDeafened: boolean;
  /** Distinguishes a deafen-induced mic mute from an explicit user mute. */
  microphoneMutedByDeafen: boolean;
  localCameraEnabled: boolean;
  localScreenShareEnabled: boolean;
  /** Tile currently expanded in theater mode; kept while navigating through chat. */
  focusedCallTileKey: string | null;
  /** Our own source picker — global, since the share button lives in two places. */
  screenPickerOpen: boolean;
  speakingUserIds: Record<string, true>;
  /** Camera/screen-share video tracks keyed by participant user id. */
  cameraTracks: Record<string, VideoTrack>;
  screenShareTracks: Record<string, VideoTrack>;

  setVoiceStates: (states: VoiceParticipantState[]) => void;
  applyVoiceStateUpdate: (data: VoiceStateUpdateData) => void;
  setConnection: (channelId: string | null, status: VoiceConnectionStatus) => void;
  setLocalMuted: (muted: boolean) => void;
  setMicrophoneMutedByDeafen: (muted: boolean) => void;
  setParticipantMuted: (userId: string, muted: boolean) => void;
  setParticipantDeafened: (userId: string, deafened: boolean) => void;
  setLocalDeafened: (deafened: boolean) => void;
  setLocalCameraEnabled: (enabled: boolean) => void;
  setLocalScreenShareEnabled: (enabled: boolean) => void;
  setFocusedCallTileKey: (key: string | null) => void;
  setScreenPickerOpen: (open: boolean) => void;
  setSpeaking: (userIds: string[]) => void;
  setCameraTrack: (userId: string, track: VideoTrack | null) => void;
  setScreenShareTrack: (userId: string, track: VideoTrack | null) => void;
  participantsInChannel: (channelId: string) => VoiceParticipantState[];
}

export const useVoiceStore = create<VoiceState>()(persist((set, get) => ({
  states: [],
  connectedChannelId: null,
  connectionStatus: "disconnected",
  localMuted: false,
  localDeafened: false,
  microphoneMutedByDeafen: false,
  localCameraEnabled: false,
  localScreenShareEnabled: false,
  focusedCallTileKey: null,
  screenPickerOpen: false,
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
          muted: data.muted ?? false,
          deafened: data.deafened ?? false,
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
      if (data.action === "updated" && data.user_id) {
        return {
          states: state.states.map((participant) =>
            participant.user_id === data.user_id
              ? {
                  ...participant,
                  ...(data.muted !== undefined ? { muted: data.muted } : {}),
                  ...(data.deafened !== undefined ? { deafened: data.deafened } : {}),
                }
              : participant,
          ),
        };
      }
      return state;
    }),

  setConnection: (channelId, status) =>
    set({
      connectedChannelId: status === "disconnected" ? null : channelId,
      connectionStatus: status,
      ...(status === "disconnected"
        ? {
            screenPickerOpen: false,
            speakingUserIds: {},
            cameraTracks: {},
            screenShareTracks: {},
            localCameraEnabled: false,
            localScreenShareEnabled: false,
            focusedCallTileKey: null,
          }
        : {}),
    }),

  setLocalMuted: (muted) => set({ localMuted: muted }),
  setMicrophoneMutedByDeafen: (muted) => set({ microphoneMutedByDeafen: muted }),
  setParticipantMuted: (userId, muted) =>
    set((state) => ({
      states: state.states.map((participant) =>
        participant.user_id === userId ? { ...participant, muted } : participant,
      ),
    })),
  setParticipantDeafened: (userId, deafened) =>
    set((state) => ({
      states: state.states.map((participant) =>
        participant.user_id === userId ? { ...participant, deafened } : participant,
      ),
    })),
  setLocalDeafened: (deafened) => set({ localDeafened: deafened }),
  setLocalCameraEnabled: (enabled) => set({ localCameraEnabled: enabled }),
  setLocalScreenShareEnabled: (enabled) => set({ localScreenShareEnabled: enabled }),
  setFocusedCallTileKey: (key) => set({ focusedCallTileKey: key }),
  setScreenPickerOpen: (open) => set({ screenPickerOpen: open }),

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
}), {
  name: "campfire-voice-preferences",
  storage: createSecureStorage(),
  partialize: (state) =>
    ({
      localMuted: state.localMuted,
      localDeafened: state.localDeafened,
      microphoneMutedByDeafen: state.microphoneMutedByDeafen,
    }) as VoiceState,
}));
