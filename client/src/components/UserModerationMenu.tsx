import { useState } from "react";
import { MicOff, MoreHorizontal, Shield, Volume2, VolumeX } from "lucide-react";
import { muteVoiceParticipant } from "@/api/endpoints";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuLabel,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ApiError, type User } from "@/lib/types";
import { useAuthStore } from "@/state/auth";
import { useModerationStore } from "@/state/moderation";
import { useVoiceStore } from "@/state/voice";
import { toast } from "sonner";
import { setParticipantVolume } from "@/livekit/voice";

export function UserModerationMenu({
  user,
  children,
  voiceParticipant,
}: {
  user: User | null;
  children: React.ReactNode;
  voiceParticipant?: { userId: string; username: string };
}) {
  const [pending, setPending] = useState(false);
  const currentUser = useAuthStore((state) => state.user);
  const isAdmin = currentUser?.is_admin ?? false;
  const targetId = voiceParticipant?.userId ?? user?.id;
  const targetUsername = voiceParticipant?.username ?? user?.username ?? "participant";
  const volume = useVoiceStore((state) =>
    targetId ? (state.participantVolumes[targetId] ?? 1) : 1,
  );
  const voiceState = useVoiceStore((state) =>
    state.states.find((participant) => participant.user_id === user?.id),
  );
  const canAdjustVolume = !!voiceParticipant && targetId !== currentUser?.id;
  const canModerate = isAdmin && !!user;
  if (!canModerate && !canAdjustVolume) return <>{children}</>;

  const mute = async () => {
    if (!user) return;
    setPending(true);
    try {
      await muteVoiceParticipant(user.id);
      useVoiceStore.getState().setParticipantMuted(user.id, true);
      toast.success(`${user.username}'s microphone was muted.`);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't mute the participant.");
    } finally {
      setPending(false);
    }
  };

  const moderationItems = (
    Item: typeof ContextMenuItem | typeof DropdownMenuItem,
    Label: typeof ContextMenuLabel | typeof DropdownMenuLabel,
  ) => user && (
    <>
      <Item onSelect={() => useModerationStore.getState().openUser(user)}>
        <Shield className="size-4" />
        Open moderator view
      </Item>
      <Item
        disabled={!voiceState || voiceState.muted || pending}
        variant="destructive"
        onSelect={() => void mute()}
      >
        <MicOff className="size-4" />
        {voiceState?.muted ? "Microphone muted" : "Mute microphone"}
      </Item>
      {!voiceState && <Label>User is not connected to voice</Label>}
    </>
  );

  const volumeControl = canAdjustVolume && (
    <div
      className="px-2 py-1.5"
      onKeyDown={(event) => event.stopPropagation()}
    >
      <div className="mb-1.5 flex items-center justify-between text-xs font-medium text-muted-foreground">
        <span>User volume</span>
        <span className="tabular-nums text-foreground">{Math.round(volume * 100)}%</span>
      </div>
      <div className="flex items-center gap-2">
        <VolumeX className="size-3.5 shrink-0 text-muted-foreground" />
        <input
          type="range"
          aria-label={`Volume for ${targetUsername}`}
          min={0}
          max={200}
          step={1}
          value={Math.round(volume * 100)}
          onChange={(event) => {
            if (targetId) setParticipantVolume(targetId, Number(event.target.value) / 100);
          }}
          onDoubleClick={() => {
            if (targetId) setParticipantVolume(targetId, 1);
          }}
          className="h-1.5 w-full cursor-pointer accent-primary"
        />
        <Volume2 className="size-3.5 shrink-0 text-muted-foreground" />
      </div>
    </div>
  );

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        <div className="group/user relative">
          {children}
          {canModerate && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  type="button"
                  aria-label={`Moderation options for ${targetUsername}`}
                  className="absolute top-1/2 right-1 flex size-6 -translate-y-1/2 items-center justify-center rounded-md bg-sidebar text-muted-foreground opacity-0 shadow-sm transition-opacity hover:text-foreground focus-visible:opacity-100 group-hover/user:opacity-100 data-open:opacity-100"
                >
                  <MoreHorizontal className="size-4" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-60">
                {moderationItems(DropdownMenuItem, DropdownMenuLabel)}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </ContextMenuTrigger>
      <ContextMenuContent className="w-60">
        {volumeControl}
        {canAdjustVolume && canModerate && <ContextMenuSeparator />}
        {canModerate && moderationItems(ContextMenuItem, ContextMenuLabel)}
      </ContextMenuContent>
    </ContextMenu>
  );
}
