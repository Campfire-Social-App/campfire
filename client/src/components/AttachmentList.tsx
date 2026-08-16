import { useState } from "react";
import { Download, File, FileArchive, FileAudio, FileText, FileVideo } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { ImageLightbox } from "@/components/ImageLightbox";
import { downloadAttachment, formatBytes, isAudio, isImage, isVideo } from "@/lib/files";
import type { Attachment } from "@/lib/types";
import { cn } from "@/lib/utils";

interface AttachmentListProps {
  attachments: Attachment[];
}

/** How a message shows what came with it: photos as photos, video and audio with
 * players, anything else as a card you can save. */
export function AttachmentList({ attachments }: AttachmentListProps) {
  const images = attachments.filter(isImage);
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);

  return (
    <>
      <div className="mt-1.5 flex flex-col gap-2">
        {images.length > 0 && (
          <div
            className={cn(
              "flex flex-wrap gap-1.5",
              // A lone image gets room to breathe; a set reads as a strip of
              // thumbnails, so a dozen photos can't push the message off screen.
              images.length === 1 ? "max-w-md" : "max-w-lg",
            )}
          >
            {images.map((attachment, index) => (
              <button
                key={attachment.id}
                onClick={() => setLightboxIndex(index)}
                className={cn(
                  "overflow-hidden rounded-lg border border-glass-border transition-opacity hover:opacity-90",
                  images.length === 1 ? "max-w-full" : "size-40",
                )}
              >
                <img
                  src={resolveAssetUrl(attachment.url)}
                  alt={attachment.filename}
                  loading="lazy"
                  className={cn(
                    "bg-black",
                    images.length === 1
                      ? "max-h-80 max-w-full object-contain"
                      : "size-full object-cover",
                  )}
                />
              </button>
            ))}
          </div>
        )}

        {attachments.filter(isVideo).map((attachment) => (
          <video
            key={attachment.id}
            src={resolveAssetUrl(attachment.url)}
            controls
            preload="metadata"
            className="max-h-80 max-w-md rounded-lg border border-glass-border bg-black"
          />
        ))}

        {attachments.filter(isAudio).map((attachment) => (
          <div
            key={attachment.id}
            className="max-w-md rounded-lg border border-glass-border bg-glass p-2"
          >
            <p className="mb-1 truncate px-1 text-xs text-muted-foreground">
              {attachment.filename}
            </p>
            <audio src={resolveAssetUrl(attachment.url)} controls className="w-full" />
          </div>
        ))}

        {attachments
          .filter((attachment) => !isImage(attachment) && !isVideo(attachment) && !isAudio(attachment))
          .map((attachment) => (
            <FileCard key={attachment.id} attachment={attachment} />
          ))}
      </div>

      {lightboxIndex !== null && (
        <ImageLightbox
          images={images}
          index={lightboxIndex}
          onIndexChange={setLightboxIndex}
          onClose={() => setLightboxIndex(null)}
        />
      )}
    </>
  );
}

function iconFor(contentType: string) {
  if (contentType.startsWith("audio/")) return FileAudio;
  if (contentType.startsWith("video/")) return FileVideo;
  if (contentType.startsWith("text/") || contentType === "application/pdf") return FileText;
  if (/zip|compressed|tar|rar|7z/.test(contentType)) return FileArchive;
  return File;
}

function FileCard({ attachment }: { attachment: Attachment }) {
  const Icon = iconFor(attachment.content_type);

  return (
    <button
      onClick={() => void downloadAttachment(attachment)}
      className="group flex max-w-md items-center gap-3 rounded-lg border border-glass-border bg-glass px-3 py-2.5 text-left transition-colors hover:border-ember-tint-border"
    >
      <Icon className="size-6 shrink-0 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm text-foreground">{attachment.filename}</p>
        <p className="text-xs text-muted-foreground">{formatBytes(attachment.size_bytes)}</p>
      </div>
      <Download className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-foreground" />
    </button>
  );
}
