import { create } from "zustand";
import type { ServerSettings } from "@/lib/types";

/** What the server says about itself. Filled from the gateway's READY frame, so
 * it is known before the first screen paints and never fetched separately. */
interface ServerState {
  name: string;
  iconUrl: string | null;
  maxUploadBytes: number;
  setServer: (settings: ServerSettings) => void;
}

/** Matches the server default (see MAX_UPLOAD_BYTES); only used before READY. */
const DEFAULT_MAX_UPLOAD_BYTES = 25 * 1024 * 1024;

export const useServerStore = create<ServerState>()((set) => ({
  name: "Campfire",
  iconUrl: null,
  maxUploadBytes: DEFAULT_MAX_UPLOAD_BYTES,

  setServer: (settings) =>
    set({
      name: settings.name,
      iconUrl: settings.icon_url,
      maxUploadBytes: settings.max_upload_bytes,
    }),
}));
