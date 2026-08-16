import { useEffect } from "react";
import { ChevronLeft, ChevronRight, Download, X } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { downloadAttachment } from "@/lib/files";
import type { Attachment } from "@/lib/types";

interface ImageLightboxProps {
  images: Attachment[];
  index: number;
  onIndexChange: (index: number) => void;
  onClose: () => void;
}

/** Full-window viewer for the images of one message. Not a modal dialog: it owns
 * the whole surface, and every way out (escape, backdrop, the X) is one action. */
export function ImageLightbox({ images, index, onIndexChange, onClose }: ImageLightboxProps) {
  const image = images[index];

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
      if (event.key === "ArrowRight") onIndexChange((index + 1) % images.length);
      if (event.key === "ArrowLeft") onIndexChange((index - 1 + images.length) % images.length);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [index, images.length, onClose, onIndexChange]);

  if (!image) return null;

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 bg-black/85 p-8 backdrop-blur-sm"
    >
      <img
        src={resolveAssetUrl(image.url)}
        alt={image.filename}
        onClick={(event) => event.stopPropagation()}
        className="max-h-[80vh] max-w-full rounded-lg object-contain shadow-2xl"
      />

      <div
        onClick={(event) => event.stopPropagation()}
        className="flex items-center gap-3 text-sm text-white/80"
      >
        <span className="max-w-md truncate">{image.filename}</span>
        <button
          onClick={() => void downloadAttachment(image)}
          className="flex items-center gap-1.5 rounded-md border border-white/15 px-2.5 py-1 transition-colors hover:bg-white/10 hover:text-white"
        >
          <Download className="size-3.5" /> Download
        </button>
      </div>

      {images.length > 1 && (
        <>
          <NavButton side="left" onClick={() => onIndexChange((index - 1 + images.length) % images.length)}>
            <ChevronLeft className="size-6" />
          </NavButton>
          <NavButton side="right" onClick={() => onIndexChange((index + 1) % images.length)}>
            <ChevronRight className="size-6" />
          </NavButton>
        </>
      )}

      <button
        onClick={onClose}
        className="absolute top-6 right-6 flex size-9 items-center justify-center rounded-full border border-white/15 text-white/80 transition-colors hover:bg-white/10 hover:text-white"
      >
        <X className="size-5" />
      </button>
    </div>
  );
}

function NavButton({
  side,
  onClick,
  children,
}: {
  side: "left" | "right";
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={(event) => {
        event.stopPropagation();
        onClick();
      }}
      className={`absolute top-1/2 flex size-10 -translate-y-1/2 items-center justify-center rounded-full border border-white/15 text-white/80 transition-colors hover:bg-white/10 hover:text-white ${
        side === "left" ? "left-6" : "right-6"
      }`}
    >
      {children}
    </button>
  );
}
