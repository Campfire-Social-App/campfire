import { useState } from "react";
import { format } from "date-fns";
import { Pencil, Trash2 } from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
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

  const canModify = currentUser?.id === message.author.id || currentUser?.is_admin;

  const saveEdit = async () => {
    const trimmed = draft.trim();
    if (trimmed && trimmed !== message.content) {
      await editMessage(message.id, trimmed);
    }
    setEditing(false);
  };

  return (
    <div
      className={cn(
        "group flex gap-3 px-4 py-0.5 hover:bg-white/[0.02]",
        showHeader ? "mt-3 pt-1.5" : "",
      )}
    >
      <div className="w-10 shrink-0">
        {showHeader && <UserAvatar username={message.author.username} />}
      </div>

      <div className="min-w-0 flex-1">
        {showHeader && (
          <div className="flex items-baseline gap-2">
            <span className="font-medium text-foreground">{message.author.username}</span>
            <span className="text-xs text-muted-foreground">
              {format(new Date(message.created_at), "dd/MM/yyyy HH:mm")}
            </span>
          </div>
        )}

        {editing ? (
          <div className="space-y-1 pt-0.5">
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
              className="min-h-0 resize-none"
            />
            <p className="text-xs text-muted-foreground">
              escape to cancel · enter to save
            </p>
          </div>
        ) : (
          <p className="whitespace-pre-wrap break-words text-[15px] leading-snug text-foreground">
            {message.content}
            {message.edited_at && (
              <span className="ml-1 text-[10px] text-muted-foreground">(edited)</span>
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
                  className="max-h-72 max-w-xs rounded-md border border-border object-contain"
                />
              ) : (
                <a
                  key={att.id}
                  href={resolveAssetUrl(att.url)}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-md border border-border bg-card px-3 py-2 text-sm text-primary hover:underline"
                >
                  {att.filename}
                </a>
              ),
            )}
          </div>
        )}
      </div>

      {canModify && !editing && (
        <div className="hidden shrink-0 items-start gap-1 group-hover:flex">
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
