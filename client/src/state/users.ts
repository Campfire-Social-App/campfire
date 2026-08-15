import { create } from "zustand";
import type { User } from "@/lib/types";
import { listUsers } from "@/api/endpoints";

interface UsersState {
  users: User[];
  byId: Record<string, User>;
  fetch: () => Promise<void>;
  /** Cheap way to learn about a newly-registered member without a full refetch —
   * gateway events like MESSAGE_CREATE already carry the full author object. */
  upsertUser: (user: User) => void;
}

export const useUsersStore = create<UsersState>()((set, get) => ({
  users: [],
  byId: {},
  fetch: async () => {
    const users = await listUsers();
    set({ users, byId: Object.fromEntries(users.map((u) => [u.id, u])) });
  },
  upsertUser: (user) => {
    if (get().byId[user.id]) return;
    set((state) => ({
      users: [...state.users, user],
      byId: { ...state.byId, [user.id]: user },
    }));
  },
}));
