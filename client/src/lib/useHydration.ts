import { useEffect, useState } from "react";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { useVoiceStore } from "@/state/voice";

/** True once every store needed by the first interactive screen has finished
 * reading from disk. Voice belongs in this gate too: otherwise the user can
 * enter a channel with the default controls before their muted/deafened
 * preferences have been restored. */
export function useHydration(): boolean {
  const [hydrated, setHydrated] = useState(
    () =>
      useAuthStore.persist.hasHydrated() &&
      useSettingsStore.persist.hasHydrated() &&
      useVoiceStore.persist.hasHydrated(),
  );

  useEffect(() => {
    const check = () => {
      if (
        useAuthStore.persist.hasHydrated() &&
        useSettingsStore.persist.hasHydrated() &&
        useVoiceStore.persist.hasHydrated()
      ) {
        setHydrated(true);
      }
    };
    const unsubAuth = useAuthStore.persist.onFinishHydration(check);
    const unsubSettings = useSettingsStore.persist.onFinishHydration(check);
    const unsubVoice = useVoiceStore.persist.onFinishHydration(check);
    check();
    return () => {
      unsubAuth();
      unsubSettings();
      unsubVoice();
    };
  }, []);

  return hydrated;
}
