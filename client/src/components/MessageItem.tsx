import { useMemo, useState } from "react";
import { format } from "date-fns";
import { CornerUpLeft, Pencil, Reply, Trash2 } from "lucide-react";
import { AttachmentList } from "@/components/AttachmentList";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { UserModerationMenu } from "@/components/UserModerationMenu";
import { Textarea } from "@/components/ui/textarea";
import { useAuthStore } from "@/state/auth";
import { useUsersStore } from "@/state/users";
import { useChannelsStore } from "@/state/channels";
import {
  addMessageReaction,
  deleteMessage,
  editMessage,
  removeMessageReaction,
} from "@/api/endpoints";
import type { Channel, Message, ReactionType } from "@/lib/types";
import { cn } from "@/lib/utils";
import { messageMentionsUser, splitMentions } from "@/lib/mentions";
import { useMessagesStore } from "@/state/messages";
import { useModerationStore } from "@/state/moderation";

const REACTIONS: ReadonlyArray<{ type: ReactionType; emoji: string; label: string }> = [
  { type: "like", emoji: "👍", label: "Like" },
  { type: "love", emoji: "❤️", label: "Love" },
  { type: "laugh", emoji: "😂", label: "Laugh" },
];

interface MessageItemProps {
  message: Message;
  showHeader: boolean;
  onReply: (message: Message) => void;
}

export function MessageItem({ message, showHeader, onReply }: MessageItemProps) {
  const currentUser = useAuthStore((s) => s.user);
  const usersById = useUsersStore((s) => s.byId);
  const channels = useChannelsStore((s) => s.channels);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(message.content);
  const [pendingReaction, setPendingReaction] = useState<ReactionType | null>(null);
  // Older server instances and messages cached before reactions existed do not
  // carry this field. Treat them as having no reactions instead of crashing
  // the entire authenticated shell.
  const reactions = message.reactions ?? [];

  const isOwn = currentUser?.id === message.author.id;
  const canModify = isOwn || currentUser?.is_admin;
  const isMentioned = !!currentUser && messageMentionsUser(message.content, currentUser.username);

  const knownUsernames = useMemo(
    () => new Set(Object.values(usersById).map((u) => u.username.toLowerCase())),
    [usersById],
  );
  const channelsByName = useMemo(
    () => new Map(channels.map((c) => [c.name.toLowerCase(), c])),
    [channels],
  );

  const saveEdit = async () => {
    const trimmed = draft.trim();
    if (trimmed && trimmed !== message.content) {
      await editMessage(message.id, trimmed);
    }
    setEditing(false);
  };

  const time = format(new Date(message.created_at), "HH:mm");

  const toggleReaction = async (type: ReactionType) => {
    if (!currentUser || pendingReaction) return;
    const current = reactions.find((reaction) => reaction.type === type);
    setPendingReaction(type);
    try {
      const result = current?.reacted_by_me
        ? await removeMessageReaction(message.id, type)
        : await addMessageReaction(message.id, type);
      useMessagesStore.getState().applyReactionUpdate(
        {
          message_id: message.id,
          channel_id: message.channel_id,
          type,
          count: result.count,
          user_id: currentUser.id,
          reacted: result.reacted_by_me,
        },
        currentUser.id,
      );
    } finally {
      setPendingReaction(null);
    }
  };

  return (
    <div
      className={cn(
        // Flat, always-left-aligned row that highlights on hover — no bubble,
        // no reversed layout for own messages.
        "group relative flex gap-3 px-4 py-0.5 hover:bg-white/2.5",
        showHeader ? "mt-3" : "",
        isMentioned && "bg-ember-tint/10 hover:bg-ember-tint/15",
      )}
    >
      <div className="w-9 shrink-0 pt-0.5 text-center">
        {showHeader ? (
          <UserModerationMenu user={message.author}>
            <button
              type="button"
              disabled={!currentUser?.is_admin}
              title={currentUser?.is_admin ? `Moderate ${message.author.username}` : undefined}
              onClick={() => useModerationStore.getState().openUser(message.author)}
              className="rounded-full disabled:cursor-default"
            >
              <UserAvatar username={message.author.username} />
            </button>
          </UserModerationMenu>
        ) : (
          <span className="text-[10px] text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100">
            {time}
          </span>
        )}
      </div>

      <div className="min-w-0 flex-1">
        {message.reply_to && (
          <div className="mb-0.5 flex min-w-0 items-center gap-1.5 text-xs text-muted-foreground/80">
            <CornerUpLeft className="size-3 shrink-0 -scale-x-100" />
            <span
              className={cn(
                "shrink-0 font-medium",
                usernameColorFor(message.reply_to.author.username),
              )}
            >
              {message.reply_to.author.username}
            </span>
            <span className="min-w-0 truncate">
              {message.reply_to.content.trim() ||
                (message.reply_to.has_attachments ? "Attachment" : "")}
            </span>
          </div>
        )}

        {showHeader && (
          <div className="flex items-baseline gap-2">
            <span className={cn("text-[15px] font-semibold", usernameColorFor(message.author.username))}>
              {isOwn ? "You" : message.author.username}
            </span>
            <span className="text-[11px] text-muted-foreground">{time}</span>
          </div>
        )}

        {editing ? (
          <div className="mt-0.5 max-w-lg space-y-1">
            <Textarea
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void saveEdit();
                } else if (e.key === "Escape") {
                  setEditing(false);
                  setDraft(message.content);
                }
              }}
              className="min-h-0 resize-none rounded-md border-glass-border bg-glass p-2 shadow-none focus-visible:ring-0"
            />
            <p className="text-xs text-muted-foreground">escape to cancel · enter to save</p>
          </div>
        ) : (
          // A message can be attachments alone — an empty paragraph would still
          // take up a line under the author's name.
          message.content.trim() && (
            <p className="text-[15px] leading-snug wrap-break-word whitespace-pre-wrap text-foreground">
              <MentionText
                content={message.content}
                knownUsernames={knownUsernames}
                channelsByName={channelsByName}
                currentUsername={currentUser?.username}
              />
              {message.edited_at && (
                <span className="ml-1.5 text-[10px] text-muted-foreground">(edited)</span>
              )}
            </p>
          )
        )}

        {message.attachments.length > 0 && (
          <AttachmentList attachments={message.attachments} />
        )}

        {reactions.length > 0 && (
          <div className="mt-1 flex flex-wrap gap-1">
            {REACTIONS.map(({ type, emoji, label }) => {
              const reaction = reactions.find((item) => item.type === type);
              if (!reaction) return null;
              return (
                <button
                  key={type}
                  type="button"
                  title={label}
                  aria-label={`${label}: ${reaction.count}`}
                  aria-pressed={reaction.reacted_by_me}
                  disabled={pendingReaction === type}
                  onClick={() => void toggleReaction(type)}
                  className={cn(
                    "flex h-7 items-center gap-1 rounded-md border px-2 text-xs transition-colors",
                    reaction.reacted_by_me
                      ? "border-primary/50 bg-primary/15 text-foreground"
                      : "border-glass-border bg-white/3 text-muted-foreground hover:bg-white/8",
                  )}
                >
                  <span aria-hidden="true">{emoji}</span>
                  <span>{reaction.count}</span>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {!editing && (
        // Stays mounted (as flex, not display:none) at all times so it never
        // enters/leaves the layout tree on hover — toggling display instead of
        // opacity here made the scrollable message list's content bounds
        // recompute on every hover, which visibly resized/jumped the list.
        <div className="pointer-events-none absolute -top-3 right-4 flex items-center gap-0.5 rounded-md border border-glass-border bg-popover p-0.5 opacity-0 shadow-md transition-opacity group-hover:pointer-events-auto group-hover:opacity-100">
          {REACTIONS.map(({ type, emoji, label }) => (
            <button
              key={type}
              type="button"
              title={label}
              aria-label={`React with ${label}`}
              disabled={pendingReaction !== null}
              onClick={() => void toggleReaction(type)}
              className="rounded-md px-1.5 py-1 text-sm text-muted-foreground hover:bg-white/10 hover:text-foreground disabled:opacity-50"
            >
              {emoji}
            </button>
          ))}
          <button
            onClick={() => onReply(message)}
            className="rounded-md p-1.5 text-muted-foreground hover:bg-white/10 hover:text-foreground"
          >
            <Reply className="size-3.5" />
          </button>
          {canModify && (
            <>
              <button
                onClick={() => setEditing(true)}
                className="rounded-md p-1.5 text-muted-foreground hover:bg-white/10 hover:text-foreground"
              >
                <Pencil className="size-3.5" />
              </button>
              <button
                onClick={() => void deleteMessage(message.id)}
                className="rounded-md p-1.5 text-muted-foreground hover:bg-white/10 hover:text-destructive"
              >
                <Trash2 className="size-3.5" />
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}

function MentionText({
  content,
  knownUsernames,
  channelsByName,
  currentUsername,
}: {
  content: string;
  knownUsernames: Set<string>;
  channelsByName: Map<string, Channel>;
  currentUsername: string | undefined;
}) {
  const segments = splitMentions(content, knownUsernames, channelsByName);
  return (
    <>
      {segments.map((segment, i) => {
        if (!segment.mention) return <span key={i}>{segment.text}</span>;

        if (segment.mention === "channel") {
          return (
            <button
              key={i}
              onClick={() => useChannelsStore.getState().selectChannel(segment.channelId!)}
              className="rounded bg-ember-tint/40 px-1 py-0.5 font-medium text-primary hover:bg-ember-tint hover:text-foreground"
            >
              {segment.text}
            </button>
          );
        }

        const isSelf =
          segment.mention === "everyone" ||
          segment.text.slice(1).toLowerCase() === currentUsername?.toLowerCase();
        return (
          <span
            key={i}
            className={cn(
              "rounded px-1 py-0.5 font-medium text-primary",
              isSelf ? "bg-ember-tint text-foreground" : "bg-ember-tint/40",
            )}
          >
            {segment.text}
          </span>
        );
      })}
    </>
  );
}
