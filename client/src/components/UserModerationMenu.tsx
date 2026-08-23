import { useState } from "react";
import { Eye, MicOff, MoreHorizontal } from "lucide-react";
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
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ApiError, type User } from "@/lib/types";
import { useAuthStore } from "@/state/auth";
import { useModerationStore } from "@/state/moderation";
import { useVoiceStore } from "@/state/voice";
import { toast } from "sonner";

export function UserModerationMenu({
  user,
  children,
}: {
  user: User | null;
  children: React.ReactNode;
}) {
  const [pending, setPending] = useState(false);
  const isAdmin = useAuthStore((state) => state.user?.is_admin ?? false);
  const voiceState = useVoiceStore((state) =>
    state.states.find((participant) => participant.user_id === user?.id),
  );
  if (!isAdmin || !user) return <>{children}</>;

  const mute = async () => {
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

  const items = (
    Item: typeof ContextMenuItem | typeof DropdownMenuItem,
    Label: typeof ContextMenuLabel | typeof DropdownMenuLabel,
    Separator: typeof ContextMenuSeparator | typeof DropdownMenuSeparator,
  ) => (
    <>
      <Item onSelect={() => useModerationStore.getState().openUser(user)}>
        <Eye className="size-4" /> View moderation profile
      </Item>
      <Separator />
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

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        <div className="group/user relative">
          {children}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                aria-label={`Moderation options for ${user.username}`}
                className="absolute top-1/2 right-1 flex size-6 -translate-y-1/2 items-center justify-center rounded-md bg-sidebar text-muted-foreground opacity-0 shadow-sm transition-opacity hover:text-foreground focus-visible:opacity-100 group-hover/user:opacity-100 data-open:opacity-100"
              >
                <MoreHorizontal className="size-4" />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-60">
              {items(DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator)}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </ContextMenuTrigger>
      <ContextMenuContent className="w-60">
        {items(ContextMenuItem, ContextMenuLabel, ContextMenuSeparator)}
      </ContextMenuContent>
    </ContextMenu>
  );
}
