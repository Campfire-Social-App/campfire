import { useEffect } from "react";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import { useAuthStore } from "@/state/auth";

export function TypingIndicator({ channelId }: { channelId: string }) {
  const typing = usePresenceStore((s) => s.typingByChannel[channelId]);
  const pruneExpiredTyping = usePresenceStore((s) => s.pruneExpiredTyping);
  const byId = useUsersStore((s) => s.byId);
  const currentUserId = useAuthStore((s) => s.user?.id);

  useEffect(() => {
    const interval = setInterval(() => pruneExpiredTyping(channelId), 2000);
    return () => clearInterval(interval);
  }, [channelId, pruneExpiredTyping]);

  const typingUserIds = Object.keys(typing ?? {}).filter((id) => id !== currentUserId);
  if (typingUserIds.length === 0) return <div className="h-5" />;

  const names = typingUserIds.map((id) => byId[id]?.username ?? "someone");
  const label =
    names.length === 1
      ? `${names[0]} is typing…`
      : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]} are typing…`;

  return <div className="h-5 px-4 text-xs text-muted-foreground">{label}</div>;
}
