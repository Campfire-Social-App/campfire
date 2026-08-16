import { openUrl } from "@tauri-apps/plugin-opener";
import { resolveAssetUrl } from "@/api/client";
import type { Attachment } from "@/lib/types";

const isTauri = "__TAURI_INTERNALS__" in window;

/** SVG is intentionally not previewable: the server sends it as a download
 * rather than an image, since it can carry script. */
const PREVIEWABLE_IMAGES = new Set([
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
  "image/avif",
]);

export const isImage = (attachment: Attachment): boolean =>
  PREVIEWABLE_IMAGES.has(attachment.content_type);

export const isVideo = (attachment: Attachment): boolean =>
  attachment.content_type.startsWith("video/");

export const isAudio = (attachment: Attachment): boolean =>
  attachment.content_type.startsWith("audio/");

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB"];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value < 10 ? value.toFixed(1) : Math.round(value)} ${units[unit]}`;
}

/** Hands the file to the OS. A plain `<a download>` is inert inside the Tauri
 * webview, so there the URL goes to the default browser, which honours the
 * Content-Disposition the server sets and saves it under its real name. */
export async function downloadAttachment(attachment: Attachment): Promise<void> {
  const url = resolveAssetUrl(attachment.url);
  if (isTauri) {
    await openUrl(url);
    return;
  }
  const link = document.createElement("a");
  link.href = url;
  link.download = attachment.filename;
  link.rel = "noreferrer";
  link.click();
}
