import { useRef, useState } from "react";
import { AtSign, File, Hash, Paperclip, Reply, Send, Slash, X } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { runCommand, sendMessage, uploadAttachment } from "@/api/endpoints";
import { gatewayClient } from "@/ws/gateway";
import { useUsersStore } from "@/state/users";
import { useCommandsStore } from "@/state/commands";
import { useAuthStore } from "@/state/auth";
import { useChannelsStore } from "@/state/channels";
import { useServerStore } from "@/state/server";
import { formatBytes } from "@/lib/files";
import { resolveAssetUrl } from "@/api/client";
import { ApiError, type Attachment, type Message } from "@/lib/types";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  activeMentionQuery,
  mentionCandidates,
  type MentionCandidate,
  type MentionQuery,
} from "@/lib/mentions";
import {
  activeCommandQuery,
  commandCandidates,
  parseCommand,
  type CommandQuery,
} from "@/lib/commands";

const TYPING_THROTTLE_MS = 3000;

/** A file on its way up: shown in the strip with its own progress bar. */
interface PendingUpload {
  key: string;
  name: string;
  progress: number;
  previewUrl?: string;
}

interface MessageComposerProps {
  /** Text channel or DM conversation to post into. */
  channelId: string;
  placeholder: string;
  replyingTo?: Message | null;
  onCancelReply?: () => void;
  onSent?: () => void;
}

export function MessageComposer({
  channelId,
  placeholder,
  replyingTo,
  onCancelReply,
  onSent,
}: MessageComposerProps) {
  const [content, setContent] = useState("");
  const [pendingAttachments, setPendingAttachments] = useState<Attachment[]>([]);
  const [uploads, setUploads] = useState<PendingUpload[]>([]);
  const [sending, setSending] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const [mentionQuery, setMentionQuery] = useState<MentionQuery | null>(null);
  const [mentionIndex, setMentionIndex] = useState(0);
  const [commandQuery, setCommandQuery] = useState<CommandQuery | null>(null);
  const [commandIndex, setCommandIndex] = useState(0);
  const lastTypingSentAt = useRef(0);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const users = useUsersStore((s) => s.users);
  const currentUserId = useAuthStore((s) => s.user?.id);
  const channels = useChannelsStore((s) => s.channels);
  const maxUploadBytes = useServerStore((s) => s.maxUploadBytes);
  const commands = useCommandsStore((s) => s.commands);
  const mentionCandidatesList = mentionQuery
    ? mentionCandidates(mentionQuery.trigger, mentionQuery.query, users, channels, currentUserId)
    : [];
  const commandCandidatesList = commandQuery
    ? commandCandidates(commandQuery.query, commands)
    : [];

  const notifyTyping = () => {
    const now = Date.now();
    if (now - lastTypingSentAt.current > TYPING_THROTTLE_MS) {
      lastTypingSentAt.current = now;
      gatewayClient.sendTyping(channelId);
    }
  };

  const handleFiles = async (files: FileList | File[]) => {
    // One at a time and in order, so a batch of photos arrives in the message in
    // the order they were picked rather than in whichever finished first.
    for (const file of Array.from(files)) {
      if (file.size > maxUploadBytes) {
        toast.error(`${file.name} is larger than ${formatBytes(maxUploadBytes)}.`);
        continue;
      }

      const key = crypto.randomUUID();
      // Local preview while it uploads — the server URL only exists afterwards.
      const previewUrl = file.type.startsWith("image/") ? URL.createObjectURL(file) : undefined;
      setUploads((prev) => [...prev, { key, name: file.name, progress: 0, previewUrl }]);

      try {
        const attachment = await uploadAttachment(file, (fraction) =>
          setUploads((prev) =>
            prev.map((upload) => (upload.key === key ? { ...upload, progress: fraction } : upload)),
          ),
        );
        setPendingAttachments((prev) => [...prev, attachment]);
      } catch (err) {
        toast.error(err instanceof ApiError ? err.message : `Couldn't upload ${file.name}.`);
      } finally {
        setUploads((prev) => prev.filter((upload) => upload.key !== key));
        if (previewUrl) URL.revokeObjectURL(previewUrl);
      }
    }
  };

  const updateMentionState = (value: string, cursor: number) => {
    const next = activeMentionQuery(value, cursor);
    setMentionQuery(next);
    setMentionIndex(0);
    // The two menus are mutually exclusive: a command only ever starts the
    // line, a mention never does.
    setCommandQuery(commands.length > 0 ? activeCommandQuery(value, cursor) : null);
    setCommandIndex(0);
  };

  const selectCommand = (name: string) => {
    if (!textareaRef.current) return;
    const nextContent = `/${name} `;
    setContent(nextContent);
    setCommandQuery(null);
    requestAnimationFrame(() => {
      textareaRef.current?.focus();
      textareaRef.current?.setSelectionRange(nextContent.length, nextContent.length);
    });
  };

  const selectMention = (candidate: MentionCandidate) => {
    if (!mentionQuery || !textareaRef.current) return;
    const cursor = textareaRef.current.selectionStart;
    const before = content.slice(0, mentionQuery.start);
    const after = content.slice(cursor);
    const inserted = `${mentionQuery.trigger}${candidate.insert} `;
    const nextContent = `${before}${inserted}${after}`;
    setContent(nextContent);
    setMentionQuery(null);

    const nextCursor = before.length + inserted.length;
    requestAnimationFrame(() => {
      textareaRef.current?.focus();
      textareaRef.current?.setSelectionRange(nextCursor, nextCursor);
    });
  };

  const handleSend = async () => {
    const trimmed = content.trim();
    if (!trimmed && pendingAttachments.length === 0) return;
    if (uploads.length > 0) {
      toast.error("Still uploading — one moment.");
      return;
    }

    // A recognised command is handed to the bot instead of being posted: the
    // way Discord does it, what you typed never shows up in the channel. Text
    // that merely opens with a slash is still an ordinary message.
    const parsed = parseCommand(trimmed, commands);
    if (parsed && pendingAttachments.length === 0) {
      setSending(true);
      try {
        await runCommand(channelId, parsed.command.name, parsed.args);
        setContent("");
        setCommandQuery(null);
        onCancelReply?.();
        onSent?.();
      } catch (err) {
        toast.error(err instanceof ApiError ? err.message : "Failed to run that command.");
      } finally {
        setSending(false);
      }
      return;
    }

    setSending(true);
    try {
      await sendMessage(
        channelId,
        trimmed,
        pendingAttachments.map((a) => a.id),
        replyingTo?.id,
      );
      setContent("");
      setPendingAttachments([]);
      setMentionQuery(null);
      setCommandQuery(null);
      onCancelReply?.();
      onSent?.();
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to send message.");
    } finally {
      setSending(false);
    }
  };

  return (
    <div
      className="relative shrink-0 px-4 pb-6"
      onDragOver={(e) => {
        e.preventDefault();
        setDragActive(true);
      }}
      onDragLeave={() => setDragActive(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragActive(false);
        if (e.dataTransfer.files.length > 0) void handleFiles(e.dataTransfer.files);
      }}
    >
      {commandQuery && commandCandidatesList.length > 0 && (
        <div className="absolute inset-x-4 bottom-full mb-1.5 overflow-hidden rounded-lg border border-glass-border bg-popover shadow-md">
          {commandCandidatesList.map((command, i) => (
            <button
              key={command.name}
              onMouseDown={(e) => {
                // Fires before the textarea's blur — keeps focus in the field.
                e.preventDefault();
                selectCommand(command.name);
              }}
              onMouseEnter={() => setCommandIndex(i)}
              className={cn(
                "flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm",
                i === commandIndex && "bg-ember-tint/50",
              )}
            >
              <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-glass text-muted-foreground">
                <Slash className="size-3.5" />
              </span>
              <span className="shrink-0 font-medium text-foreground">/{command.name}</span>
              {command.usage && (
                <span className="shrink-0 text-xs text-muted-foreground">{command.usage}</span>
              )}
              <span className="ml-auto truncate pl-3 text-xs text-muted-foreground">
                {command.description}
              </span>
            </button>
          ))}
        </div>
      )}

      {mentionQuery && mentionCandidatesList.length > 0 && (
        <div className="absolute inset-x-4 bottom-full mb-1.5 overflow-hidden rounded-lg border border-glass-border bg-popover shadow-md">
          {mentionCandidatesList.map((candidate, i) => (
            <button
              key={candidate.key}
              onMouseDown={(e) => {
                // Fires before the textarea's blur — keeps focus in the field.
                e.preventDefault();
                selectMention(candidate);
              }}
              onMouseEnter={() => setMentionIndex(i)}
              className={cn(
                "flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm text-foreground",
                i === mentionIndex && "bg-ember-tint/50",
              )}
            >
              {mentionQuery?.trigger === "#" ? (
                <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-glass text-muted-foreground">
                  <Hash className="size-3.5" />
                </span>
              ) : candidate.key === "everyone" ? (
                <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-glass text-muted-foreground">
                  <AtSign className="size-3.5" />
                </span>
              ) : (
                <UserAvatar username={candidate.label} size="sm" />
              )}
              <span
                className={cn("truncate", mentionQuery?.trigger === "#" ? "text-foreground" : usernameColorFor(candidate.label))}
              >
                {candidate.label}
              </span>
            </button>
          ))}
        </div>
      )}

      <div
        className={cn(
          // Soft-cornered outline rather than a pill, and no fill of its own —
          // the shell's glow reads straight through it. Only the hairline
          // defines the field, warming to ember on focus.
          "overflow-hidden rounded-[14px] border border-glass-border transition-colors focus-within:border-ember-tint-border",
          dragActive && "border-primary border-dashed",
        )}
      >
        {replyingTo && (
          <div className="flex items-center justify-between gap-2 border-b border-glass-border px-3.5 py-1.5 text-xs">
            <span className="flex min-w-0 items-center gap-1.5 text-muted-foreground">
              <Reply className="size-3.5 shrink-0" />
              Replying to{" "}
              <span className={cn("font-medium", usernameColorFor(replyingTo.author.username))}>
                {replyingTo.author.username}
              </span>
            </span>
            <button
              onClick={onCancelReply}
              className="shrink-0 rounded p-0.5 text-muted-foreground hover:bg-white/10 hover:text-foreground"
            >
              <X className="size-3.5" />
            </button>
          </div>
        )}

        {(pendingAttachments.length > 0 || uploads.length > 0) && (
          <div className="flex flex-wrap gap-2 border-b border-glass-border p-2">
            {pendingAttachments.map((attachment) => (
              <div
                key={attachment.id}
                className="group relative overflow-hidden rounded-lg border border-glass-border bg-glass"
              >
                {attachment.content_type.startsWith("image/") ? (
                  <img
                    src={resolveAssetUrl(attachment.url)}
                    alt={attachment.filename}
                    className="size-16 object-cover"
                  />
                ) : (
                  <div className="flex size-16 flex-col items-center justify-center gap-1 px-1">
                    <File className="size-5 text-muted-foreground" />
                    <span className="w-full truncate text-center text-[10px] text-muted-foreground">
                      {attachment.filename}
                    </span>
                  </div>
                )}
                <button
                  onClick={() =>
                    setPendingAttachments((prev) => prev.filter((a) => a.id !== attachment.id))
                  }
                  className="absolute top-0.5 right-0.5 flex size-5 items-center justify-center rounded-full bg-black/60 text-white opacity-0 transition-opacity group-hover:opacity-100"
                >
                  <X className="size-3" />
                </button>
              </div>
            ))}

            {uploads.map((upload) => (
              <div
                key={upload.key}
                className="relative size-16 overflow-hidden rounded-lg border border-glass-border bg-glass"
              >
                {upload.previewUrl ? (
                  <img src={upload.previewUrl} alt="" className="size-full object-cover opacity-40" />
                ) : (
                  <div className="flex size-full items-center justify-center">
                    <File className="size-5 text-muted-foreground" />
                  </div>
                )}
                <div className="absolute inset-x-1 bottom-1 h-1 overflow-hidden rounded-full bg-black/50">
                  <div
                    className="h-full bg-primary transition-[width]"
                    style={{ width: `${Math.round(upload.progress * 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="flex items-end gap-2.5 px-4.5 py-3.5">
          <button
            onClick={() => fileInputRef.current?.click()}
            className="flex size-6 shrink-0 items-center justify-center text-muted-foreground hover:text-foreground"
          >
            <Paperclip className="size-5" />
          </button>
          <input
            ref={fileInputRef}
            type="file"
            multiple
            hidden
            onChange={(e) => {
              if (e.target.files?.length) void handleFiles(e.target.files);
              e.target.value = "";
            }}
          />

          <Textarea
            ref={textareaRef}
            value={content}
            onChange={(e) => {
              setContent(e.target.value);
              updateMentionState(e.target.value, e.target.selectionStart);
              notifyTyping();
            }}
            onKeyDown={(e) => {
              if (commandQuery && commandCandidatesList.length > 0) {
                if (e.key === "ArrowDown") {
                  e.preventDefault();
                  setCommandIndex((i) => (i + 1) % commandCandidatesList.length);
                  return;
                }
                if (e.key === "ArrowUp") {
                  e.preventDefault();
                  setCommandIndex(
                    (i) => (i - 1 + commandCandidatesList.length) % commandCandidatesList.length,
                  );
                  return;
                }
                // Enter picks the highlighted command rather than sending it —
                // most of them still want an argument typed after the name.
                if (e.key === "Enter" || e.key === "Tab") {
                  e.preventDefault();
                  selectCommand(commandCandidatesList[commandIndex].name);
                  return;
                }
                if (e.key === "Escape") {
                  e.preventDefault();
                  setCommandQuery(null);
                  return;
                }
              }

              if (mentionQuery && mentionCandidatesList.length > 0) {
                if (e.key === "ArrowDown") {
                  e.preventDefault();
                  setMentionIndex((i) => (i + 1) % mentionCandidatesList.length);
                  return;
                }
                if (e.key === "ArrowUp") {
                  e.preventDefault();
                  setMentionIndex(
                    (i) => (i - 1 + mentionCandidatesList.length) % mentionCandidatesList.length,
                  );
                  return;
                }
                if (e.key === "Enter" || e.key === "Tab") {
                  e.preventDefault();
                  selectMention(mentionCandidatesList[mentionIndex]);
                  return;
                }
                if (e.key === "Escape") {
                  e.preventDefault();
                  setMentionQuery(null);
                  return;
                }
              }

              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                void handleSend();
              } else if (e.key === "Escape" && replyingTo) {
                onCancelReply?.();
              }
            }}
            onClick={(e) => updateMentionState(content, e.currentTarget.selectionStart)}
            onPaste={(e) => {
              // Screenshots arrive as files on the clipboard; text keeps the
              // default paste behaviour.
              if (e.clipboardData.files.length > 0) {
                e.preventDefault();
                void handleFiles(e.clipboardData.files);
              }
            }}
            placeholder={placeholder}
            className="max-h-40 min-h-6 flex-1 resize-none border-0 bg-transparent px-0 py-1 text-[14.5px] shadow-none placeholder:text-muted-foreground focus-visible:ring-0 dark:bg-transparent"
            rows={1}
          />

          <button
            onClick={() => void handleSend()}
            disabled={sending || (!content.trim() && pendingAttachments.length === 0)}
            className="flex size-7 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:text-foreground disabled:opacity-40"
          >
            <Send className="size-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
