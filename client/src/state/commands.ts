import { create } from "zustand";
import type { SlashCommand } from "@/lib/types";
import { listCommands } from "@/api/endpoints";

interface CommandsState {
  commands: SlashCommand[];
  /** Fetched once per session on the shell's mount. A failure leaves the list
   * empty, which just means no `/` menu — never a blocked composer. */
  fetch: () => Promise<void>;
}

export const useCommandsStore = create<CommandsState>()((set) => ({
  commands: [],
  fetch: async () => {
    try {
      set({ commands: await listCommands() });
    } catch {
      set({ commands: [] });
    }
  },
}));
