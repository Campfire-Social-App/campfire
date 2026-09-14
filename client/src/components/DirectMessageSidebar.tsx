import { useState } from "react";
import { formatDistanceToNowStrict } from "date-fns";
import { Phone, Plus, Trash2 } from "lucide-react";
import { deleteDm } from "@/api/endpoints";
import { UserAvatar } from "@/components/UserAvatar";
import { UserProfileHoverCard } from "@/components/UserProfileHoverCard";
import { UserBar } from "@/components/UserBar";
import { NewDirectMessageDialog } from "@/components/NewDirectMessageDialog";
import { useDmsStore } from "@/state/dms";
import { usePresenceStore } from "@/state/presence";
import { useVoiceStore } from "@/state/voice";
import { cn } from "@/lib/utils";
import type { DMConversation } from "@/lib/types";
import { ApiError } from "@/lib/types";
import { toast } from "sonner";

/** Stands in for the channel sidebar while a DM is open — same column, same
 * bottom user bar, listing conversations instead of channels. */
export function DirectMessageSidebar() {
  const conversations = useDmsStore((s) => s.conversations);
  const activeDmId = useDmsStore((s) => s.activeDmId);
  const selectDm = useDmsStore((s) => s.selectDm);
  const removeConversation = useDmsStore((s) => s.removeConversation);
  const [newDmOpen, setNewDmOpen] = useState(false);

  return (
    <div className="flex w-68 shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      <div className="flex h-12 shrink-0 items-center justify-between border-b border-sidebar-border px-4 text-sidebar-foreground shadow-sm">
        <span className="font-heading text-sm font-semibold">Direct messages</span>
        <button
          onClick={() => setNewDmOpen(true)}
          className="text-muted-foreground hover:text-foreground"
          title="New direct message"
        >
          <Plus className="size-4" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-2 py-3">
        {conversations.length === 0 ? (
          <p className="px-2 py-6 text-center text-sm text-muted-foreground">
            No conversations yet. Click a member to start one.
          </p>
        ) : (
          <div className="space-y-0.5">
            {conversations.map((conversation) => (
              <ConversationRow
                key={conversation.id}
                conversation={conversation}
                active={activeDmId === conversation.id}
                onClick={() => selectDm(conversation.id)}
                onDelete={async () => {
                  if (!window.confirm(`Delete your conversation with ${conversation.recipient.username}?`)) return;
                  try {
                    await deleteDm(conversation.id);
                    removeConversation(conversation.id);
                  } catch (error) {
                    toast.error(error instanceof ApiError ? error.message : "Couldn't delete the conversation.");
                  }
                }}
              />
            ))}
          </div>
        )}
      </div>

      <UserBar />
      <NewDirectMessageDialog open={newDmOpen} onOpenChange={setNewDmOpen} />
    </div>
  );
}

function ConversationRow({
  conversation,
  active,
  onClick,
  onDelete,
}: {
  conversation: DMConversation;
  active: boolean;
  onClick: () => void;
  onDelete: () => Promise<void>;
}) {
  const isOnline = usePresenceStore((s) => !!s.onlineUserIds[conversation.recipient.id]);
  // Voice state for a DM only ever reaches its two members, so anyone in this
  // room means a call in this conversation.
  const inCall = useVoiceStore((s) => s.states.some((v) => v.channel_id === conversation.id));
  const unread = conversation.unread_count;

  return (
    <div className="group relative">
    <UserProfileHoverCard user={conversation.recipient}>
    <button
      onClick={onClick}
      className={cn(
        "flex w-full items-center gap-2 rounded-lg border border-transparent px-2 py-1.5 pr-8 text-sm text-muted-foreground transition-colors hover:bg-white/5 hover:text-foreground",
        active && "border-ember-tint-border/75 bg-ember-tint/50 font-semibold text-foreground",
        !active && unread > 0 && "font-semibold text-foreground",
      )}
    >
      <UserAvatar
        username={conversation.recipient.username}
        size="sm"
        status={isOnline ? "online" : "offline"}
      />
      <span className="min-w-0 flex-1 truncate text-left">
        {conversation.recipient.display_name ?? conversation.recipient.username}
      </span>
      {inCall && <Phone className="size-3.5 shrink-0 animate-pulse text-online" />}
      {unread > 0 ? (
        <span className="flex h-4.5 min-w-4.5 shrink-0 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold text-white">
          {unread > 99 ? "99+" : unread}
        </span>
      ) : (
        conversation.last_message_at && (
          <span className="shrink-0 text-[10px] text-muted-foreground">
            {formatDistanceToNowStrict(new Date(conversation.last_message_at), {
              addSuffix: false,
            })}
          </span>
        )
      )}
    </button>
    </UserProfileHoverCard>
    <button
      type="button"
      title="Delete conversation"
      aria-label={`Delete conversation with ${conversation.recipient.username}`}
      onClick={(event) => {
        event.stopPropagation();
        void onDelete();
      }}
      className="absolute top-1/2 right-2 -translate-y-1/2 rounded p-1 text-muted-foreground opacity-0 transition hover:bg-destructive/15 hover:text-destructive focus:opacity-100 group-hover:opacity-100"
    >
      <Trash2 className="size-3.5" />
    </button>
    </div>
  );
}
