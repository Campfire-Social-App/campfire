import type { PersistStorage, StorageValue } from "zustand/middleware";
import { getItem, removeItem, setItem } from "@/lib/secureStore";

/** Adapts our async secure store to zustand's `persist` storage interface. */
export function createSecureStorage<T>(): PersistStorage<T> {
  return {
    getItem: async (name) => {
      const raw = await getItem(name);
      if (!raw) return null;
      return JSON.parse(raw) as StorageValue<T>;
    },
    setItem: async (name, value) => {
      await setItem(name, JSON.stringify(value));
    },
    removeItem: async (name) => {
      await removeItem(name);
    },
  };
}
