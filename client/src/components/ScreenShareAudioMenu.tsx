import { Volume2, VolumeX } from "lucide-react";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu";
import { setScreenShareMuted, setScreenShareVolume } from "@/livekit/voice";
import { useVoiceStore } from "@/state/voice";

export function ScreenShareAudioMenu({
  userId,
  username,
  disabled,
  children,
}: {
  userId: string;
  username: string;
  disabled?: boolean;
  children: React.ReactElement;
}) {
  const volume = useVoiceStore((state) => state.screenShareVolumes[userId] ?? 1);
  const muted = useVoiceStore((state) => !!state.mutedScreenShares[userId]);

  if (disabled) return children;

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>{children}</ContextMenuTrigger>
      <ContextMenuContent className="w-60">
        <ContextMenuItem onSelect={() => setScreenShareMuted(userId, !muted)}>
          {muted ? <Volume2 className="size-4" /> : <VolumeX className="size-4" />}
          {muted ? "Unmute stream" : "Mute stream"}
        </ContextMenuItem>
        <ContextMenuSeparator />
        <div className="px-2 py-1.5" onKeyDown={(event) => event.stopPropagation()}>
          <div className="mb-1.5 flex items-center justify-between text-xs font-medium text-muted-foreground">
            <span>Stream volume</span>
            <span className="tabular-nums text-foreground">{Math.round(volume * 100)}%</span>
          </div>
          <div className="flex items-center gap-2">
            <VolumeX className="size-3.5 shrink-0 text-muted-foreground" />
            <input
              type="range"
              aria-label={`Stream volume for ${username}`}
              min={0}
              max={200}
              step={1}
              value={Math.round(volume * 100)}
              onChange={(event) =>
                setScreenShareVolume(userId, Number(event.target.value) / 100)
              }
              onDoubleClick={() => setScreenShareVolume(userId, 1)}
              className="h-1.5 w-full cursor-pointer accent-primary"
            />
            <Volume2 className="size-3.5 shrink-0 text-muted-foreground" />
          </div>
        </div>
      </ContextMenuContent>
    </ContextMenu>
  );
}
