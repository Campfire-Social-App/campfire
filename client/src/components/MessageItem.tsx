import { useState } from "react";
import { format } from "date-fns";
import { Pencil, Trash2 } from "lucide-react";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { Textarea } from "@/components/ui/textarea";
import { useAuthStore } from "@/state/auth";
import { editMessage, deleteMessage } from "@/api/endpoints";
import { resolveAssetUrl } from "@/api/client";
import type { Message } from "@/lib/types";
import { cn } from "@/lib/utils";

const IMAGE_TYPES = new Set(["image/png", "image/jpeg", "image/gif", "image/webp"]);

interface MessageItemProps {
  message: Message;
  showHeader: boolean;
}

export function MessageItem({ message, showHeader }: MessageItemProps) {
  const currentUser = useAuthStore((s) => s.user);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(message.content);

  const isOwn = currentUser?.id === message.author.id;
  const canModify = isOwn || currentUser?.is_admin;

  const saveEdit = async () => {
    const trimmed = draft.trim();
    if (trimmed && trimmed !== message.content) {
      await editMessage(message.id, trimmed);
    }
    setEditing(false);
  };

  const time = format(new Date(message.created_at), "HH:mm");

  return (
    <div
      className={cn(
        // Flat, always-left-aligned row that highlights on hover — no bubble,
        // no reversed layout for own messages.
        "group relative flex gap-3 px-4 py-0.5 hover:bg-white/2.5",
        showHeader ? "mt-3" : "",
      )}
    >
      <div className="w-9 shrink-0 pt-0.5 text-center">
        {showHeader ? (
          <UserAvatar username={message.author.username} />
        ) : (
          <span className="text-[10px] text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100">
            {time}
          </span>
        )}
      </div>

      <div className="min-w-0 flex-1">
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
          <p className="text-[15px] leading-snug wrap-break-word whitespace-pre-wrap text-foreground">
            {message.content}
            {message.edited_at && (
              <span className="ml-1.5 text-[10px] text-muted-foreground">(edited)</span>
            )}
          </p>
        )}

        {message.attachments.length > 0 && (
          <div className="mt-1.5 flex flex-wrap gap-2">
            {message.attachments.map((att) =>
              IMAGE_TYPES.has(att.content_type) ? (
                <img
                  key={att.id}
                  src={resolveAssetUrl(att.url)}
                  alt={att.filename}
                  className="max-h-72 max-w-xs rounded-md border border-glass-border object-contain"
                />
              ) : (
                <a
                  key={att.id}
                  href={resolveAssetUrl(att.url)}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-md border border-glass-border bg-glass px-3 py-2 text-sm text-primary hover:underline"
                >
                  {att.filename}
                </a>
              ),
            )}
          </div>
        )}
      </div>

      {canModify && !editing && (
        // Stays mounted (as flex, not display:none) at all times so it never
        // enters/leaves the layout tree on hover — toggling display instead of
        // opacity here made the scrollable message list's content bounds
        // recompute on every hover, which visibly resized/jumped the list.
        <div className="pointer-events-none absolute -top-3 right-4 flex items-center gap-0.5 rounded-md border border-glass-border bg-popover p-0.5 opacity-0 shadow-md transition-opacity group-hover:pointer-events-auto group-hover:opacity-100">
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
        </div>
      )}
    </div>
  );
}
