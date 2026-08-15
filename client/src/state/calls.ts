import { create } from "zustand";

export interface CallPeer {
  id: string;
  username: string;
}

interface CallState {
  /** A call ringing at us right now, if any — at most one, newest wins. */
  incoming: { channelId: string; from: CallPeer } | null;
  /** DM channel we're ringing and waiting on an answer for. */
  outgoing: string | null;

  setIncoming: (channelId: string, from: CallPeer) => void;
  setOutgoing: (channelId: string) => void;
  /** Both clears take the channel they mean, so a late frame from a call that's
   * already over can't wipe the state of the one that replaced it. */
  clearIncoming: (channelId: string) => void;
  clearOutgoing: (channelId: string) => void;
}

export const useCallsStore = create<CallState>()((set) => ({
  incoming: null,
  outgoing: null,

  setIncoming: (channelId, from) => set({ incoming: { channelId, from } }),
  setOutgoing: (channelId) => set({ outgoing: channelId }),

  clearIncoming: (channelId) =>
    set((state) => (state.incoming?.channelId === channelId ? { incoming: null } : state)),

  clearOutgoing: (channelId) =>
    set((state) => (state.outgoing === channelId ? { outgoing: null } : state)),
}));
