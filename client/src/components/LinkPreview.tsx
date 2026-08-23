import { useMemo, useState } from "react";
import { ExternalLink, Play, Video } from "lucide-react";
import { VideoPlayer } from "@/components/MediaPlayer";
import { previewsFromContent, type EmbeddedVideoPreview } from "@/lib/links";

export function LinkPreviewList({ content }: { content: string }) {
  const previews = useMemo(
    () => previewsFromContent(content).filter((preview) => preview.kind !== "link"),
    [content],
  );
  if (previews.length === 0) return null;

  return (
    <div className="mt-2 flex max-w-lg flex-col gap-2">
      {previews.map((preview) => {
        if (preview.kind === "embed") {
          return <EmbeddedVideoCard key={preview.url} preview={preview} />;
        }
        return <VideoPlayer key={preview.url} src={preview.url} className="max-w-lg!" />;
      })}
    </div>
  );
}

function EmbeddedVideoCard({ preview }: { preview: EmbeddedVideoPreview }) {
  const [playing, setPlaying] = useState(false);

  return (
    <section className="overflow-hidden rounded-xl border border-glass-border bg-black shadow-sm">
      <div className="relative aspect-video">
        {playing ? (
          <iframe
            src={preview.embedUrl}
            title={`${preview.provider} video`}
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowFullScreen
            referrerPolicy="strict-origin-when-cross-origin"
            sandbox="allow-scripts allow-same-origin allow-presentation allow-popups"
            className="absolute inset-0 size-full border-0"
          />
        ) : (
          <button
            type="button"
            aria-label={`Reproduzir vídeo do ${preview.provider}`}
            onClick={() => setPlaying(true)}
            className="group absolute inset-0 flex size-full items-center justify-center overflow-hidden bg-zinc-950"
          >
            {preview.thumbnailUrl ? (
              <img
                src={preview.thumbnailUrl}
                alt=""
                loading="lazy"
                referrerPolicy="no-referrer"
                className="absolute inset-0 size-full object-cover opacity-80 transition group-hover:scale-[1.02] group-hover:opacity-90"
              />
            ) : (
              <Video className="size-16 text-zinc-700" />
            )}
            <span className="relative flex size-14 items-center justify-center rounded-full bg-zinc-100/90 text-zinc-950 shadow-xl transition-transform group-hover:scale-105">
              <Play className="ml-0.5 size-6 fill-current" />
            </span>
          </button>
        )}
      </div>
      <div className="flex items-center justify-between gap-3 border-t border-white/10 bg-zinc-950 px-3 py-2">
        <span className="text-xs font-medium text-zinc-300">{preview.provider}</span>
        <a
          href={preview.url}
          target="_blank"
          rel="noopener noreferrer"
          className="flex min-w-0 items-center gap-1.5 text-xs text-zinc-500 hover:text-zinc-200"
        >
          <span className="truncate">Abrir link original</span>
          <ExternalLink className="size-3.5 shrink-0" />
        </a>
      </div>
    </section>
  );
}
