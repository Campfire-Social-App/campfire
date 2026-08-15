import { create } from "zustand";
import type { VoiceParticipantState, VoiceStateUpdateData } from "@/lib/types";

export type VoiceConnectionStatus = "disconnected" | "connecting" | "connected";

interface VoiceState {
  states: VoiceParticipantState[];
  connectedChannelId: string | null;
  connectionStatus: VoiceConnectionStatus;
  localMuted: boolean;
  localDeafened: boolean;
  speakingUserIds: Record<string, true>;

  setVoiceStates: (states: VoiceParticipantState[]) => void;
  applyVoiceStateUpdate: (data: VoiceStateUpdateData) => void;
  setConnection: (channelId: string | null, status: VoiceConnectionStatus) => void;
  setLocalMuted: (muted: boolean) => void;
  setLocalDeafened: (deafened: boolean) => void;
  setSpeaking: (userIds: string[]) => void;
  participantsInChannel: (channelId: string) => VoiceParticipantState[];
}

export const useVoiceStore = create<VoiceState>()((set, get) => ({
  states: [],
  connectedChannelId: null,
  connectionStatus: "disconnected",
  localMuted: false,
  localDeafened: false,
  speakingUserIds: {},

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
      ...(status === "disconnected" ? { speakingUserIds: {} } : {}),
    }),

  setLocalMuted: (muted) => set({ localMuted: muted }),
  setLocalDeafened: (deafened) => set({ localDeafened: deafened }),

  setSpeaking: (userIds) =>
    set({ speakingUserIds: Object.fromEntries(userIds.map((id) => [id, true])) }),

  participantsInChannel: (channelId) => get().states.filter((s) => s.channel_id === channelId),
}));
