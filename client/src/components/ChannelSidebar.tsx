import { useState } from "react";
import { ChevronDown, Hash, MicOff, Plus, UserPlus, Volume2, VolumeX } from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuthStore } from "@/state/auth";
import { useChannelsStore } from "@/state/channels";
import { useVoiceStore } from "@/state/voice";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import { ChannelMenu } from "@/components/ChannelMenu";
import { CreateChannelDialog } from "@/components/CreateChannelDialog";
import { InviteDialog } from "@/components/InviteDialog";
import { UserAvatar } from "@/components/UserAvatar";
import { UserProfileHoverCard } from "@/components/UserProfileHoverCard";
import { BotBadge } from "@/components/BotBadge";
import { UserModerationMenu } from "@/components/UserModerationMenu";
import { UserBar } from "@/components/UserBar";
import { ScreenShareLiveBadge } from "@/components/ScreenShareLiveBadge";
import { joinVoiceChannel } from "@/livekit/voice";
import { moveVoiceParticipant } from "@/api/endpoints";
import { cn } from "@/lib/utils";
import type { Channel } from "@/lib/types";
import { toast } from "sonner";
import { ApiError } from "@/lib/types";

interface ChannelSidebarProps {
  serverName: string;
}

const VOICE_PARTICIPANT_DRAG_TYPE = "application/x-campfire-voice-participant";

export function ChannelSidebar({ serverName }: ChannelSidebarProps) {
  const channels = useChannelsStore((s) => s.channels);
  const selectedChannelId = useChannelsStore((s) => s.selectedChannelId);
  const unreadChannelIds = useChannelsStore((s) => s.unreadChannelIds);
  const mentionCounts = useChannelsStore((s) => s.mentionCounts);
  const selectChannel = useChannelsStore((s) => s.selectChannel);
  const isAdmin = useAuthStore((s) => s.user?.is_admin ?? false);

  const [inviteOpen, setInviteOpen] = useState(false);
  const [createChannelOpen, setCreateChannelOpen] = useState(false);

  const textChannels = channels.filter((c) => c.type === "text");
  const voiceChannels = channels.filter((c) => c.type === "voice");

  const handleSelectVoice = async (channel: Channel) => {
    const { connectedChannelId } = useVoiceStore.getState();
    // Entering voice always opens its participant stage. If already connected,
    // this is only navigation; otherwise select it after the join succeeds so
    // a failed connection does not leave the user on a misleading call screen.
    if (connectedChannelId === channel.id) {
      selectChannel(channel.id);
      return;
    }
    try {
      await joinVoiceChannel(channel.id);
      selectChannel(channel.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to join the voice channel.");
    }
  };

  const handleMoveParticipant = async (userId: string, destination: Channel) => {
    const voiceState = useVoiceStore.getState().states.find((state) => state.user_id === userId);
    if (!voiceState || voiceState.channel_id === destination.id) return;
    const username = useUsersStore.getState().byId[userId]?.username ?? "Participant";
    try {
      await moveVoiceParticipant(userId, destination.id);
      toast.success(`${username} is being moved to ${destination.name}.`);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't move the participant.");
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
                unread={!!unreadChannelIds[channel.id]}
                mentionCount={mentionCounts[channel.id] ?? 0}
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
                  onParticipantDrop={
                    isAdmin
                      ? (userId) => void handleMoveParticipant(userId, channel)
                      : undefined
                  }
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
  unread = false,
  mentionCount = 0,
  onClick,
  onParticipantDrop,
}: {
  channel: Channel;
  active: boolean;
  unread?: boolean;
  mentionCount?: number;
  onClick: () => void;
  onParticipantDrop?: (userId: string) => void;
}) {
  const [dropActive, setDropActive] = useState(false);
  const Icon = channel.type === "text" ? Hash : Volume2;
  return (
    <button
      onClick={onClick}
      onDragOver={(event) => {
        if (!onParticipantDrop || !event.dataTransfer.types.includes(VOICE_PARTICIPANT_DRAG_TYPE)) {
          return;
        }
        event.preventDefault();
        event.dataTransfer.dropEffect = "move";
        setDropActive(true);
      }}
      onDragLeave={(event) => {
        if (event.relatedTarget instanceof Node && event.currentTarget.contains(event.relatedTarget)) {
          return;
        }
        setDropActive(false);
      }}
      onDrop={(event) => {
        if (!onParticipantDrop) return;
        event.preventDefault();
        setDropActive(false);
        const userId = event.dataTransfer.getData(VOICE_PARTICIPANT_DRAG_TYPE);
        if (userId) onParticipantDrop(userId);
      }}
      className={cn(
        "flex w-full items-center gap-1.5 rounded-lg border border-transparent px-2 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-white/5 hover:text-foreground",
        // Half-strength ember tint — enough to read as selected without
        // competing with the chat pane.
        active && "border-ember-tint-border/75 bg-ember-tint/50 font-semibold text-foreground",
        dropActive && "border-primary bg-primary/15 text-foreground ring-2 ring-primary/35",
      )}
    >
      <Icon className={cn("size-4 shrink-0", active && "text-primary")} />
      <span
        className={cn(
          "min-w-0 truncate",
          !active && unread && "font-semibold text-foreground",
        )}
      >
        {channel.name}
      </span>
      {mentionCount > 0 && (
        <span className="ml-auto flex h-4.5 min-w-4.5 shrink-0 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold text-white">
          {mentionCount > 99 ? "99+" : mentionCount}
        </span>
      )}
    </button>
  );
}

function VoiceParticipants({ channelId }: { channelId: string }) {
  const participants = useVoiceStore(useShallow((s) => s.participantsInChannel(channelId)));
  const speakingUserIds = useVoiceStore((s) => s.speakingUserIds);
  const availableScreenShares = useVoiceStore((s) => s.availableScreenShares);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);
  const isAdmin = useAuthStore((s) => s.user?.is_admin ?? false);
  const usersById = useUsersStore((s) => s.byId);

  if (participants.length === 0) return null;

  return (
    <div className="ml-4 space-y-1 border-l border-sidebar-border pl-3 py-1">
      {participants.map((p) => {
        const user = usersById[p.user_id] ?? null;
        const row = (
          <button
            type="button"
            draggable={isAdmin && !!user}
            onDragStart={(event) => {
              event.dataTransfer.effectAllowed = "move";
              event.dataTransfer.setData(VOICE_PARTICIPANT_DRAG_TYPE, p.user_id);
              event.dataTransfer.setData("text/plain", p.username);
            }}
            title={
              isAdmin && user
                ? `View ${p.username}'s profile or drag to another voice channel`
                : `View ${p.username}'s profile`
            }
            className={cn(
              "flex w-full items-center gap-2 rounded-md py-0.5 pr-8 text-left hover:bg-white/5",
              isAdmin && user && "cursor-grab active:cursor-grabbing",
            )}
          >
            <UserAvatar
              username={p.username}
              avatarUrl={user?.avatar_url}
              size="sm"
              status={onlineUserIds[p.user_id] ? "online" : "offline"}
              ring={!!speakingUserIds[p.user_id]}
            />
            <span className="min-w-0 truncate text-sm text-muted-foreground">{p.username}</span>
            {user?.is_bot && <BotBadge className="shrink-0" />}
            {(p.screen_sharing || availableScreenShares[p.user_id] || p.muted || p.deafened) && (
              <div className="ml-auto flex shrink-0 items-center gap-1.5">
                {p.muted && (
                  <MicOff aria-label="Microphone muted" className="size-3.5 text-destructive" />
                )}
                {p.deafened && (
                  <VolumeX aria-label="Audio deafened" className="size-3.5 text-destructive" />
                )}
                {(p.screen_sharing || availableScreenShares[p.user_id]) && (
                  <ScreenShareLiveBadge />
                )}
              </div>
            )}
          </button>
        );

        return (
          <UserModerationMenu
            key={p.user_id}
            user={user}
            voiceParticipant={{ userId: p.user_id, username: p.username }}
          >
            {user ? <UserProfileHoverCard user={user}>{row}</UserProfileHoverCard> : row}
          </UserModerationMenu>
        );
      })}
    </div>
  );
}
