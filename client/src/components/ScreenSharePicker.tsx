import { useEffect, useState } from "react";
import { AppWindow, Loader2, Monitor, RefreshCw } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useVoiceStore } from "@/state/voice";
import { startNativeScreenShare } from "@/livekit/voice";
import { listCaptureSources, type CaptureQuality, type CaptureSource } from "@/lib/screenCapture";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

const QUALITIES: { value: CaptureQuality; label: string }[] = [
  { value: "720p", label: "720p" },
  { value: "1080p", label: "1080p" },
  { value: "native", label: "Native" },
];

const FRAME_RATES = [15, 30, 60];

type Tab = "window" | "screen";

/** Our own source picker, in place of the WebView's: it can show what the
 * WebView's can't be asked for — thumbnails, quality and frame rate — because
 * the capture behind it is ours (see lib/screenCapture.ts). */
export function ScreenSharePicker() {
  const open = useVoiceStore((s) => s.screenPickerOpen);
  const setOpen = useVoiceStore((s) => s.setScreenPickerOpen);

  const [sources, setSources] = useState<CaptureSource[]>([]);
  const [loading, setLoading] = useState(false);
  const [tab, setTab] = useState<Tab>("window");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [quality, setQuality] = useState<CaptureQuality>("1080p");
  const [fps, setFps] = useState(30);
  const [sharing, setSharing] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      setSources(await listCaptureSources());
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't list what's on screen.");
      setOpen(false);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!open) return;
    setSelectedId(null);
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const visible = sources.filter((source) => source.kind === tab);
  const selected = sources.find((source) => source.id === selectedId) ?? null;

  const handleShare = async () => {
    if (!selected) return;
    setSharing(true);
    try {
      await startNativeScreenShare(selected.id, quality, fps);
      setOpen(false);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't start sharing.");
    } finally {
      setSharing(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>Share your screen</DialogTitle>
        </DialogHeader>

        <div className="flex items-center gap-1 rounded-lg bg-white/5 p-1">
          <TabButton active={tab === "window"} onClick={() => setTab("window")}>
            <AppWindow className="size-4" /> Applications
          </TabButton>
          <TabButton active={tab === "screen"} onClick={() => setTab("screen")}>
            <Monitor className="size-4" /> Entire screen
          </TabButton>
          <button
            onClick={() => void load()}
            title="Refresh"
            className="ml-auto flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground"
          >
            <RefreshCw className={cn("size-4", loading && "animate-spin")} />
          </button>
        </div>

        <div className="max-h-96 min-h-56 overflow-y-auto">
          {loading && sources.length === 0 ? (
            <div className="flex h-56 items-center justify-center">
              <Loader2 className="size-6 animate-spin text-muted-foreground" />
            </div>
          ) : visible.length === 0 ? (
            <p className="flex h-56 items-center justify-center text-sm text-muted-foreground">
              Nothing to share here.
            </p>
          ) : (
            <div className="grid grid-cols-2 gap-3 p-0.5">
              {visible.map((source) => (
                <button
                  key={source.id}
                  onClick={() => setSelectedId(source.id)}
                  onDoubleClick={() => void handleShare()}
                  className={cn(
                    "group overflow-hidden rounded-xl border bg-glass text-left transition-all",
                    source.id === selectedId
                      ? "border-primary ring-2 ring-primary/60"
                      : "border-glass-border hover:border-ember-tint-border/60",
                  )}
                >
                  <img
                    src={source.thumbnail}
                    alt=""
                    className="aspect-video w-full bg-black object-contain"
                  />
                  <div className="flex items-center gap-1.5 px-2.5 py-2">
                    {source.kind === "screen" ? (
                      <Monitor className="size-3.5 shrink-0 text-muted-foreground" />
                    ) : (
                      <AppWindow className="size-3.5 shrink-0 text-muted-foreground" />
                    )}
                    <span className="truncate text-sm text-foreground">{source.title}</span>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-4 border-t border-glass-border pt-4">
          <Segmented
            label="Quality"
            options={QUALITIES.map((q) => ({ value: q.value, label: q.label }))}
            value={quality}
            onChange={setQuality}
          />
          <Segmented
            label="Frame rate"
            options={FRAME_RATES.map((rate) => ({ value: rate, label: `${rate}fps` }))}
            value={fps}
            onChange={setFps}
          />

          <div className="ml-auto flex items-center gap-2">
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleShare()} disabled={!selected || sharing}>
              {sharing && <Loader2 className="size-4 animate-spin" />}
              Share
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
        active
          ? "bg-white/10 text-foreground"
          : "text-muted-foreground hover:bg-white/5 hover:text-foreground",
      )}
    >
      {children}
    </button>
  );
}

function Segmented<T extends string | number>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <div className="space-y-1">
      <p className="text-xs text-muted-foreground">{label}</p>
      <div className="flex items-center gap-1 rounded-lg bg-white/5 p-1">
        {options.map((option) => (
          <button
            key={String(option.value)}
            onClick={() => onChange(option.value)}
            className={cn(
              "rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
              option.value === value
                ? "bg-primary/20 text-primary"
                : "text-muted-foreground hover:bg-white/5 hover:text-foreground",
            )}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
