import { useEffect, useState } from "react";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";

/** True once both persisted stores have finished reading from disk. */
export function useHydration(): boolean {
  const [hydrated, setHydrated] = useState(
    () => useAuthStore.persist.hasHydrated() && useSettingsStore.persist.hasHydrated(),
  );

  useEffect(() => {
    const check = () => {
      if (useAuthStore.persist.hasHydrated() && useSettingsStore.persist.hasHydrated()) {
        setHydrated(true);
      }
    };
    const unsubAuth = useAuthStore.persist.onFinishHydration(check);
    const unsubSettings = useSettingsStore.persist.onFinishHydration(check);
    check();
    return () => {
      unsubAuth();
      unsubSettings();
    };
  }, []);

  return hydrated;
}
