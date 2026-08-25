import { create } from "zustand";
import type { Channel } from "@/lib/types";

interface ChannelsState {
  channels: Channel[];
  selectedChannelId: string | null;
  unreadChannelIds: Record<string, true>;
  mentionCounts: Record<string, number>;
  /** True once the gateway's initial READY dump has been applied. */
  ready: boolean;
  setChannels: (channels: Channel[]) => void;
  upsertChannel: (channel: Channel) => void;
  removeChannel: (id: string) => void;
  selectChannel: (id: string | null) => void;
  markChannelUnread: (id: string) => void;
  incrementChannelMention: (id: string) => void;
  markChannelRead: (id: string) => void;
}

export const useChannelsStore = create<ChannelsState>()((set, get) => ({
  channels: [],
  selectedChannelId: null,
  unreadChannelIds: {},
  mentionCounts: {},
  ready: false,

  setChannels: (channels) => {
    const sorted = [...channels].sort((a, b) => a.position - b.position);
    const channelIds = new Set(sorted.map((channel) => channel.id));
    set((state) => ({
      channels: sorted,
      unreadChannelIds: Object.fromEntries(
        Object.entries(state.unreadChannelIds).filter(([id]) => channelIds.has(id)),
      ),
      mentionCounts: Object.fromEntries(
        Object.entries(state.mentionCounts).filter(([id]) => channelIds.has(id)),
      ),
      ready: true,
    }));
    if (!get().selectedChannelId && sorted.length > 0) {
      set({ selectedChannelId: sorted.find((c) => c.type === "text")?.id ?? sorted[0].id });
    }
  },

  upsertChannel: (channel) =>
    set((state) => {
      const exists = state.channels.some((c) => c.id === channel.id);
      const next = exists
        ? state.channels.map((c) => (c.id === channel.id ? channel : c))
        : [...state.channels, channel];
      next.sort((a, b) => a.position - b.position);
      return { channels: next };
    }),

  removeChannel: (id) =>
    set((state) => {
      const { [id]: _removed, ...unreadChannelIds } = state.unreadChannelIds;
      const { [id]: _removedMentions, ...mentionCounts } = state.mentionCounts;
      return {
        channels: state.channels.filter((c) => c.id !== id),
        selectedChannelId: state.selectedChannelId === id ? null : state.selectedChannelId,
        unreadChannelIds,
        mentionCounts,
      };
    }),

  selectChannel: (id) => {
    set({ selectedChannelId: id });
    if (id) get().markChannelRead(id);
  },

  markChannelUnread: (id) =>
    set((state) =>
      state.unreadChannelIds[id]
        ? state
        : { unreadChannelIds: { ...state.unreadChannelIds, [id]: true } },
    ),

  incrementChannelMention: (id) =>
    set((state) => ({
      mentionCounts: {
        ...state.mentionCounts,
        [id]: (state.mentionCounts[id] ?? 0) + 1,
      },
    })),

  markChannelRead: (id) =>
    set((state) => {
      if (!state.unreadChannelIds[id] && !state.mentionCounts[id]) return state;
      const { [id]: _read, ...unreadChannelIds } = state.unreadChannelIds;
      const { [id]: _readMentions, ...mentionCounts } = state.mentionCounts;
      return { unreadChannelIds, mentionCounts };
    }),
}));
