import { useRef, useState } from "react";
import { Loader2, Paperclip, Send, X } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { sendMessage, uploadAttachment } from "@/api/endpoints";
import { gatewayClient } from "@/ws/gateway";
import { ApiError, type Attachment, type Channel } from "@/lib/types";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

const TYPING_THROTTLE_MS = 3000;

interface MessageComposerProps {
  channel: Channel;
}

export function MessageComposer({ channel }: MessageComposerProps) {
  const [content, setContent] = useState("");
  const [pendingAttachments, setPendingAttachments] = useState<Attachment[]>([]);
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const lastTypingSentAt = useRef(0);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const notifyTyping = () => {
    const now = Date.now();
    if (now - lastTypingSentAt.current > TYPING_THROTTLE_MS) {
      lastTypingSentAt.current = now;
      gatewayClient.sendTyping(channel.id);
    }
  };

  const handleFiles = async (files: FileList | File[]) => {
    setUploading(true);
    try {
      for (const file of Array.from(files)) {
        const attachment = await uploadAttachment(file);
        setPendingAttachments((prev) => [...prev, attachment]);
      }
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Falha ao enviar arquivo.");
    } finally {
      setUploading(false);
    }
  };

  const handleSend = async () => {
    const trimmed = content.trim();
    if (!trimmed && pendingAttachments.length === 0) return;
    setSending(true);
    try {
      await sendMessage(
        channel.id,
        trimmed,
        pendingAttachments.map((a) => a.id),
      );
      setContent("");
      setPendingAttachments([]);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Falha ao enviar mensagem.");
    } finally {
      setSending(false);
    }
  };

  return (
    <div
      className="shrink-0 px-4 pb-6"
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
      <div
        className={cn(
          "rounded-lg border border-transparent bg-muted",
          dragActive && "border-primary border-dashed",
        )}
      >
        {(pendingAttachments.length > 0 || uploading) && (
          <div className="flex flex-wrap gap-2 border-b border-border p-2">
            {pendingAttachments.map((att) => (
              <div
                key={att.id}
                className="flex items-center gap-1 rounded-md bg-card px-2 py-1 text-xs text-foreground"
              >
                {att.filename}
                <button
                  onClick={() =>
                    setPendingAttachments((prev) => prev.filter((a) => a.id !== att.id))
                  }
                  className="text-muted-foreground hover:text-destructive"
                >
                  <X className="size-3" />
                </button>
              </div>
            ))}
            {uploading && <Loader2 className="size-4 animate-spin text-muted-foreground" />}
          </div>
        )}

        <div className="flex items-end gap-2 px-3 py-2.5">
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
            value={content}
            onChange={(e) => {
              setContent(e.target.value);
              notifyTyping();
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                void handleSend();
              }
            }}
            placeholder={`Conversar em #${channel.name}`}
            className="max-h-40 min-h-6 flex-1 resize-none border-0 bg-transparent px-0 py-1 shadow-none focus-visible:ring-0 dark:bg-transparent"
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
