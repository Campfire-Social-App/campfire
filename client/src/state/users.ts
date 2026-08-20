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

export const useUsersStore = create<UsersState>()((set) => ({
  users: [],
  byId: {},
  fetch: async () => {
    const users = await listUsers();
    set({ users, byId: Object.fromEntries(users.map((u) => [u.id, u])) });
  },
  upsertUser: (user) => {
    set((state) => ({
      users: state.byId[user.id]
        ? state.users.map((item) => (item.id === user.id ? user : item))
        : [...state.users, user],
      byId: { ...state.byId, [user.id]: user },
    }));
  },
}));
