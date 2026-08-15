import { create } from "zustand";
import { markDmRead, openDmWith } from "@/api/endpoints";
import type { DMConversation } from "@/lib/types";

interface DMState {
  conversations: DMConversation[];
  /** Non-null means the DM view is showing instead of the server's channels. */
  activeDmId: string | null;
  setConversations: (conversations: DMConversation[]) => void;
  upsertConversation: (conversation: DMConversation) => void;
  selectDm: (id: string | null) => void;
  /** Opens (creating if needed) the conversation with a member and shows it. */
  openWithUser: (userId: string) => Promise<void>;
}

/** Most recent first; a conversation with no messages yet stays pinned at the
 * top, matching how the server orders the initial list. */
function sortConversations(conversations: DMConversation[]): DMConversation[] {
  return [...conversations].sort((a, b) => {
    if (a.last_message_at === b.last_message_at) return 0;
    if (a.last_message_at === null) return -1;
    if (b.last_message_at === null) return 1;
    return b.last_message_at.localeCompare(a.last_message_at);
  });
}

export const useDmsStore = create<DMState>()((set, get) => ({
  conversations: [],
  activeDmId: null,

  setConversations: (conversations) => set({ conversations: sortConversations(conversations) }),

  upsertConversation: (conversation) =>
    set((state) => {
      // While a conversation is on screen, its messages are read by definition —
      // don't let the server's unread count (computed before we saw it) put a
      // badge on the DM the user is literally looking at.
      const next =
        conversation.id === state.activeDmId
          ? { ...conversation, unread_count: 0 }
          : conversation;
      if (next.unread_count === 0 && conversation.unread_count > 0) {
        void markDmRead(next.id).catch(() => {
          // Read receipts are best-effort; a failed one just re-badges on reload.
        });
      }
      const exists = state.conversations.some((c) => c.id === next.id);
      return {
        conversations: sortConversations(
          exists
            ? state.conversations.map((c) => (c.id === next.id ? next : c))
            : [...state.conversations, next],
        ),
      };
    }),

  selectDm: (id) => {
    set({ activeDmId: id });
    if (id === null) return;
    const conversation = get().conversations.find((c) => c.id === id);
    if (!conversation || conversation.unread_count === 0) return;
    set((state) => ({
      conversations: state.conversations.map((c) =>
        c.id === id ? { ...c, unread_count: 0 } : c,
      ),
    }));
    void markDmRead(id).catch(() => {
      // See above — best-effort.
    });
  },

  openWithUser: async (userId) => {
    const conversation = await openDmWith(userId);
    get().upsertConversation(conversation);
    get().selectDm(conversation.id);
  },
}));
