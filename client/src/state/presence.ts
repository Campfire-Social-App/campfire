import { create } from "zustand";

interface PresenceState {
  onlineUserIds: Record<string, true>;
  typingByChannel: Record<string, Record<string, number>>; // channelId -> userId -> expiresAt (ms)
  setOnline: (userId: string) => void;
  setOffline: (userId: string) => void;
  setTyping: (channelId: string, userId: string) => void;
  pruneExpiredTyping: (channelId: string) => void;
}

const TYPING_TTL_MS = 8_000;

export const usePresenceStore = create<PresenceState>()((set, get) => ({
  onlineUserIds: {},
  typingByChannel: {},

  setOnline: (userId) =>
    set((state) => ({ onlineUserIds: { ...state.onlineUserIds, [userId]: true } })),

  setOffline: (userId) =>
    set((state) => {
      const next = { ...state.onlineUserIds };
      delete next[userId];
      return { onlineUserIds: next };
    }),

  setTyping: (channelId, userId) =>
    set((state) => ({
      typingByChannel: {
        ...state.typingByChannel,
        [channelId]: {
          ...state.typingByChannel[channelId],
          [userId]: Date.now() + TYPING_TTL_MS,
        },
      },
    })),

  pruneExpiredTyping: (channelId) => {
    const channelTyping = get().typingByChannel[channelId];
    if (!channelTyping) return;
    const now = Date.now();
    const next = Object.fromEntries(
      Object.entries(channelTyping).filter(([, expiresAt]) => expiresAt > now),
    );
    set((state) => ({ typingByChannel: { ...state.typingByChannel, [channelId]: next } }));
  },
}));
