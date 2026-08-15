import { create } from "zustand";
import type { Message } from "@/lib/types";
import { listMessages } from "@/api/endpoints";

interface ChannelMessages {
  messages: Message[];
  hasMore: boolean;
  loading: boolean;
}

interface MessagesState {
  byChannel: Record<string, ChannelMessages>;
  loadInitial: (channelId: string) => Promise<void>;
  loadMore: (channelId: string) => Promise<void>;
  addMessage: (message: Message) => void;
  updateMessage: (message: Message) => void;
  removeMessage: (channelId: string, messageId: string) => void;
}

export const useMessagesStore = create<MessagesState>()((set, get) => ({
  byChannel: {},

  loadInitial: async (channelId) => {
    set((state) => ({
      byChannel: {
        ...state.byChannel,
        [channelId]: { messages: [], hasMore: false, loading: true },
      },
    }));
    const page = await listMessages(channelId, { limit: 50 });
    set((state) => ({
      byChannel: {
        ...state.byChannel,
        [channelId]: { messages: page.messages, hasMore: page.has_more, loading: false },
      },
    }));
  },

  loadMore: async (channelId) => {
    const current = get().byChannel[channelId];
    if (!current || current.loading || !current.hasMore || current.messages.length === 0) return;

    set((state) => ({
      byChannel: { ...state.byChannel, [channelId]: { ...current, loading: true } },
    }));
    const oldestId = current.messages[0].id;
    const page = await listMessages(channelId, { before: oldestId, limit: 50 });
    set((state) => {
      const latest = state.byChannel[channelId] ?? current;
      return {
        byChannel: {
          ...state.byChannel,
          [channelId]: {
            messages: [...page.messages, ...latest.messages],
            hasMore: page.has_more,
            loading: false,
          },
        },
      };
    });
  },

  addMessage: (message) =>
    set((state) => {
      const existing = state.byChannel[message.channel_id];
      if (!existing) return state;
      if (existing.messages.some((m) => m.id === message.id)) return state;
      return {
        byChannel: {
          ...state.byChannel,
          [message.channel_id]: { ...existing, messages: [...existing.messages, message] },
        },
      };
    }),

  updateMessage: (message) =>
    set((state) => {
      const existing = state.byChannel[message.channel_id];
      if (!existing) return state;
      return {
        byChannel: {
          ...state.byChannel,
          [message.channel_id]: {
            ...existing,
            messages: existing.messages.map((m) => (m.id === message.id ? message : m)),
          },
        },
      };
    }),

  removeMessage: (channelId, messageId) =>
    set((state) => {
      const existing = state.byChannel[channelId];
      if (!existing) return state;
      return {
        byChannel: {
          ...state.byChannel,
          [channelId]: {
            ...existing,
            messages: existing.messages.filter((m) => m.id !== messageId),
          },
        },
      };
    }),
}));
