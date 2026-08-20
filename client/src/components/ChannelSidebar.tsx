import { useState } from "react";
import { ChevronDown, Hash, MicOff, Plus, UserPlus, Volume2, VolumeX } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useAuthStore } from "@/state/auth";
import { useChannelsStore } from "@/state/channels";
import { useVoiceStore } from "@/state/voice";
import { usePresenceStore } from "@/state/presence";
import { ChannelMenu } from "@/components/ChannelMenu";
import { CreateChannelDialog } from "@/components/CreateChannelDialog";
import { InviteDialog } from "@/components/InviteDialog";
import { UserAvatar } from "@/components/UserAvatar";
import { UserBar } from "@/components/UserBar";
import { joinVoiceChannel } from "@/livekit/voice";
import { cn } from "@/lib/utils";
import type { Channel } from "@/lib/types";
import { toast } from "sonner";
import { ApiError } from "@/lib/types";

interface ChannelSidebarProps {
  serverName: string;
}

export function ChannelSidebar({ serverName }: ChannelSidebarProps) {
  const channels = useChannelsStore((s) => s.channels);
  const selectedChannelId = useChannelsStore((s) => s.selectedChannelId);
  const selectChannel = useChannelsStore((s) => s.selectChannel);
  const isAdmin = useAuthStore((s) => s.user?.is_admin ?? false);

  const [inviteOpen, setInviteOpen] = useState(false);
  const [createChannelOpen, setCreateChannelOpen] = useState(false);

  const textChannels = channels.filter((c) => c.type === "text");
  const voiceChannels = channels.filter((c) => c.type === "voice");

  const handleSelectVoice = async (channel: Channel) => {
    const { connectedChannelId } = useVoiceStore.getState();
    // Already connected — this click means "show me the voice screen".
    // Otherwise, just join and stay on whatever's currently open; switching
    // to the voice screen is a separate, explicit second click.
    if (connectedChannelId === channel.id) {
      selectChannel(channel.id);
      return;
    }
    try {
      await joinVoiceChannel(channel.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to join the voice channel.");
    }
  };

  return (
    <div className="flex w-68 shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button className="flex h-12 shrink-0 items-center justify-between border-b border-sidebar-border px-4 text-sidebar-foreground shadow-sm hover:bg-white/5">
            <span className="min-w-0 truncate font-heading text-sm font-semibold">{serverName}</span>
            <ChevronDown className="size-4 shrink-0 text-muted-foreground" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent className="w-56">
          <DropdownMenuItem onSelect={() => setInviteOpen(true)}>
            <UserPlus className="size-4" /> Invite people
          </DropdownMenuItem>
          {isAdmin && (
            <DropdownMenuItem onSelect={() => setCreateChannelOpen(true)}>
              <Plus className="size-4" /> Create channel
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <div className="flex-1 overflow-y-auto px-2 py-3">
        <ChannelCategory
          title="Text channels"
          onCreate={isAdmin ? () => setCreateChannelOpen(true) : undefined}
        >
          {textChannels.map((channel) => (
            <ChannelMenu key={channel.id} channel={channel}>
              <ChannelRow
                channel={channel}
                active={selectedChannelId === channel.id}
                onClick={() => selectChannel(channel.id)}
              />
            </ChannelMenu>
          ))}
        </ChannelCategory>

        <ChannelCategory
          title="Voice channels"
          onCreate={isAdmin ? () => setCreateChannelOpen(true) : undefined}
        >
          {voiceChannels.map((channel) => (
            <div key={channel.id}>
              <ChannelMenu channel={channel}>
                <ChannelRow
                  channel={channel}
                  active={selectedChannelId === channel.id}
                  onClick={() => void handleSelectVoice(channel)}
                />
              </ChannelMenu>
              <VoiceParticipants channelId={channel.id} />
            </div>
          ))}
        </ChannelCategory>
      </div>

      <UserBar />

      <InviteDialog open={inviteOpen} onOpenChange={setInviteOpen} />
      <CreateChannelDialog open={createChannelOpen} onOpenChange={setCreateChannelOpen} />
    </div>
  );
}

function ChannelCategory({
  title,
  onCreate,
  children,
}: {
  title: string;
  onCreate?: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="mb-4">
      <div className="mb-1 flex items-center justify-between px-1 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
        <span>{title}</span>
        {onCreate && (
          <button onClick={onCreate} className="hover:text-foreground">
            <Plus className="size-4" />
          </button>
        )}
      </div>
      <div className="space-y-0.5">{children}</div>
    </div>
  );
}

function ChannelRow({
  channel,
  active,
  onClick,
}: {
  channel: Channel;
  active: boolean;
  onClick: () => void;
}) {
  const Icon = channel.type === "text" ? Hash : Volume2;
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex w-full items-center gap-1.5 rounded-lg border border-transparent px-2 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-white/5 hover:text-foreground",
        // Half-strength ember tint — enough to read as selected without
        // competing with the chat pane.
        active && "border-ember-tint-border/75 bg-ember-tint/50 font-semibold text-foreground",
      )}
    >
      <Icon className={cn("size-4 shrink-0", active && "text-primary")} />
      <span className="min-w-0 truncate">{channel.name}</span>
    </button>
  );
}

function VoiceParticipants({ channelId }: { channelId: string }) {
  const participants = useVoiceStore(useShallow((s) => s.participantsInChannel(channelId)));
  const speakingUserIds = useVoiceStore((s) => s.speakingUserIds);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);

  if (participants.length === 0) return null;

  return (
    <div className="ml-4 space-y-1 border-l border-sidebar-border pl-3 py-1">
      {participants.map((p) => (
        <Tooltip key={p.user_id}>
          <TooltipTrigger asChild>
            <div className="flex items-center gap-2 py-0.5">
              <UserAvatar
                username={p.username}
                size="sm"
                status={onlineUserIds[p.user_id] ? "online" : "offline"}
                ring={!!speakingUserIds[p.user_id]}
              />
              <span className="min-w-0 truncate text-sm text-muted-foreground">{p.username}</span>
              {(p.muted || p.deafened) && (
                <div className="ml-auto flex shrink-0 items-center gap-1.5 text-destructive">
                  {p.muted && <MicOff aria-label="Microphone muted" className="size-3.5" />}
                  {p.deafened && <VolumeX aria-label="Audio deafened" className="size-3.5" />}
                </div>
              )}
            </div>
          </TooltipTrigger>
          <TooltipContent side="right">{p.username}</TooltipContent>
        </Tooltip>
      ))}
    </div>
  );
}
