import { create } from "zustand";
import type { Channel } from "@/lib/types";

interface ChannelsState {
  channels: Channel[];
  selectedChannelId: string | null;
  /** True once the gateway's initial READY dump has been applied. */
  ready: boolean;
  setChannels: (channels: Channel[]) => void;
  upsertChannel: (channel: Channel) => void;
  removeChannel: (id: string) => void;
  selectChannel: (id: string | null) => void;
}

export const useChannelsStore = create<ChannelsState>()((set, get) => ({
  channels: [],
  selectedChannelId: null,
  ready: false,

  setChannels: (channels) => {
    const sorted = [...channels].sort((a, b) => a.position - b.position);
    set({ channels: sorted, ready: true });
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
    set((state) => ({
      channels: state.channels.filter((c) => c.id !== id),
      selectedChannelId: state.selectedChannelId === id ? null : state.selectedChannelId,
    })),

  selectChannel: (id) => set({ selectedChannelId: id }),
}));
