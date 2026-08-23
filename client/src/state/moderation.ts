import { create } from "zustand";
import type { User } from "@/lib/types";

interface ModerationState {
  selectedUser: User | null;
  openUser: (user: User) => void;
  close: () => void;
}

export const useModerationStore = create<ModerationState>()((set) => ({
  selectedUser: null,
  openUser: (selectedUser) => set({ selectedUser }),
  close: () => set({ selectedUser: null }),
}));
