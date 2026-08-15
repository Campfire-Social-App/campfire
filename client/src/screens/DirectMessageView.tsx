import { ChatPane } from "@/components/ChatPane";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { usePresenceStore } from "@/state/presence";
import { cn } from "@/lib/utils";
import type { DMConversation } from "@/lib/types";

interface DirectMessageViewProps {
  conversation: DMConversation;
}

export function DirectMessageView({ conversation }: DirectMessageViewProps) {
  const isOnline = usePresenceStore((s) => !!s.onlineUserIds[conversation.recipient.id]);
  const { username } = conversation.recipient;

  return (
    <ChatPane
      channelId={conversation.id}
      composerPlaceholder={`Message @${username}`}
      header={
        <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
          <UserAvatar
            username={username}
            size="sm"
            status={isOnline ? "online" : "offline"}
          />
          <span className="font-heading text-sm font-semibold text-foreground">{username}</span>
          <span className="text-xs text-muted-foreground">{isOnline ? "Online" : "Offline"}</span>
        </header>
      }
      empty={
        <div className="flex h-full flex-col items-center justify-center gap-2 px-8 text-center">
          <UserAvatar username={username} size="lg" />
          <p className={cn("font-heading text-lg font-semibold", usernameColorFor(username))}>
            {username}
          </p>
          <p className="text-sm text-muted-foreground">
            This is the beginning of your direct messages with {username}.
          </p>
        </div>
      }
    />
  );
}
