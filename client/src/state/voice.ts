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
  /** Publishers currently offering a screen stream, subscribed or not. */
  availableScreenShares: Record<string, true>;
  /** Remote screen streams this client explicitly chose to watch. */
  viewingScreenShares: Record<string, true>;
  /** Local playback gain per remote participant. 1 is 100%, 2 is 200%. */
  participantVolumes: Record<string, number>;
  /** Local playback gain and mute state for remote screen-share audio. */
  screenShareVolumes: Record<string, number>;
  mutedScreenShares: Record<string, true>;

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
  setScreenShareAvailable: (userId: string, available: boolean) => void;
  setScreenShareViewing: (userId: string, viewing: boolean) => void;
  setParticipantVolume: (userId: string, volume: number) => void;
  setScreenShareVolume: (userId: string, volume: number) => void;
  setScreenShareMuted: (userId: string, muted: boolean) => void;
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
  availableScreenShares: {},
  viewingScreenShares: {},
  participantVolumes: {},
  screenShareVolumes: {},
  mutedScreenShares: {},

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
          screen_sharing: data.screen_sharing ?? false,
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
                  ...(data.screen_sharing !== undefined
                    ? { screen_sharing: data.screen_sharing }
                    : {}),
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
            availableScreenShares: {},
            viewingScreenShares: {},
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

  setScreenShareAvailable: (userId, available) =>
    set((state) => {
      const nextAvailable = { ...state.availableScreenShares };
      const nextViewing = { ...state.viewingScreenShares };
      const nextTracks = { ...state.screenShareTracks };
      if (available) {
        nextAvailable[userId] = true;
      } else {
        delete nextAvailable[userId];
        delete nextViewing[userId];
        delete nextTracks[userId];
      }
      return {
        availableScreenShares: nextAvailable,
        viewingScreenShares: nextViewing,
        screenShareTracks: nextTracks,
        ...(!available && state.focusedCallTileKey === `scr:${userId}`
          ? { focusedCallTileKey: null }
          : {}),
      };
    }),

  setScreenShareViewing: (userId, viewing) =>
    set((state) => {
      const next = { ...state.viewingScreenShares };
      if (viewing) next[userId] = true;
      else delete next[userId];
      return { viewingScreenShares: next };
    }),

  setParticipantVolume: (userId, volume) =>
    set((state) => ({
      participantVolumes: {
        ...state.participantVolumes,
        [userId]: Math.max(0, Math.min(2, volume)),
      },
    })),

  setScreenShareVolume: (userId, volume) =>
    set((state) => ({
      screenShareVolumes: {
        ...state.screenShareVolumes,
        [userId]: Math.max(0, Math.min(2, volume)),
      },
    })),

  setScreenShareMuted: (userId, muted) =>
    set((state) => {
      const next = { ...state.mutedScreenShares };
      if (muted) next[userId] = true;
      else delete next[userId];
      return { mutedScreenShares: next };
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
      participantVolumes: state.participantVolumes,
      screenShareVolumes: state.screenShareVolumes,
      mutedScreenShares: state.mutedScreenShares,
    }) as VoiceState,
}));
