import { useAuthStore } from "@/state/auth";
import { useChannelsStore } from "@/state/channels";
import { useDmsStore } from "@/state/dms";
import { useSettingsStore } from "@/state/settings";

export interface NotificationTarget {
  serverUrl: string;
  userId: string;
  channelId: string;
  kind: "dm" | "channel";
}

/** Capture the origin when the event arrives, before permission prompts resolve. */
export function notificationTarget(channelId: string, kind: NotificationTarget["kind"]): NotificationTarget | undefined {
  const serverUrl = useSettingsStore.getState().serverUrl;
  const userId = useAuthStore.getState().user?.id;
  return serverUrl && userId ? { serverUrl, userId, channelId, kind } : undefined;
}

export function openNotificationTarget(target: NotificationTarget): boolean {
  // The client has one active server/account. An old notification must never
  // resolve its channel ID against a different session after switching accounts.
  const auth = useAuthStore.getState();
  if (target.serverUrl !== useSettingsStore.getState().serverUrl ||
      target.userId !== auth.user?.id || auth.status !== "authenticated") return false;

  if (target.kind === "dm") {
    const dms = useDmsStore.getState();
    if (!dms.conversations.some((conversation) => conversation.id === target.channelId)) return false;
    dms.selectDm(target.channelId);
    return true;
  }
  if (target.kind === "channel") {
    const channels = useChannelsStore.getState();
    if (!channels.channels.some((channel) => channel.id === target.channelId)) return false;
    useDmsStore.getState().selectDm(null);
    channels.selectChannel(target.channelId);
    return true;
  }
  return false;
}
