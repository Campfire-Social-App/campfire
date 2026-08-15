import { useState } from "react";
import { Flame, Plus } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { UserAvatar } from "@/components/UserAvatar";
import { NewDirectMessageDialog } from "@/components/NewDirectMessageDialog";
import { useDmsStore } from "@/state/dms";
import { usePresenceStore } from "@/state/presence";
import { cn } from "@/lib/utils";
import type { DMConversation } from "@/lib/types";

interface ServerRailProps {
  serverName: string;
}

/** Leftmost bar: the one server this client talks to, then the open direct
 * message conversations below it — the same shape as Discord's, minus the
 * multi-server part (Campfire is single-server by design). */
export function ServerRail({ serverName }: ServerRailProps) {
  const conversations = useDmsStore((s) => s.conversations);
  const activeDmId = useDmsStore((s) => s.activeDmId);
  const selectDm = useDmsStore((s) => s.selectDm);
  const [newDmOpen, setNewDmOpen] = useState(false);

  return (
    <div className="flex w-18 shrink-0 flex-col items-center gap-2 overflow-y-auto border-r border-sidebar-border bg-rail py-3">
      <RailItem active={activeDmId === null} label={serverName} onClick={() => selectDm(null)}>
        <div
          className={cn(
            "flex size-12 items-center justify-center rounded-2xl bg-linear-to-br from-amber-400 via-orange-500 to-red-600 text-white",
            "shadow-[0_0_18px_1px_rgba(255,122,61,0.35)] transition-all hover:rounded-xl hover:shadow-[0_0_26px_3px_rgba(255,122,61,0.5)]",
          )}
        >
          <Flame className="size-6" />
        </div>
      </RailItem>

      <div className="my-1 h-px w-8 shrink-0 rounded-full bg-sidebar-border" />

      {conversations.map((conversation) => (
        <DirectMessageRailItem
          key={conversation.id}
          conversation={conversation}
          active={activeDmId === conversation.id}
          onClick={() => selectDm(conversation.id)}
        />
      ))}

      <RailItem active={false} label="New direct message" onClick={() => setNewDmOpen(true)}>
        <div className="flex size-12 items-center justify-center rounded-2xl border border-dashed border-sidebar-border text-muted-foreground transition-all hover:rounded-xl hover:border-primary hover:text-primary">
          <Plus className="size-5" />
        </div>
      </RailItem>

      <NewDirectMessageDialog open={newDmOpen} onOpenChange={setNewDmOpen} />
    </div>
  );
}

function DirectMessageRailItem({
  conversation,
  active,
  onClick,
}: {
  conversation: DMConversation;
  active: boolean;
  onClick: () => void;
}) {
  const isOnline = usePresenceStore((s) => !!s.onlineUserIds[conversation.recipient.id]);

  return (
    <RailItem active={active} label={conversation.recipient.username} onClick={onClick}>
      <div className="relative">
        {/* Sized to match the server button above it, so the rail reads as one
            column. Circular (not the server button's squircle) — that's the
            visual cue for "person" vs "place". */}
        <UserAvatar
          username={conversation.recipient.username}
          size="lg"
          status={isOnline ? "online" : "offline"}
          className={cn("size-12! transition-all", active && "ring-2 ring-primary/70")}
        />
        {conversation.unread_count > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-bold text-white ring-2 ring-rail">
            {conversation.unread_count > 99 ? "99+" : conversation.unread_count}
          </span>
        )}
      </div>
    </RailItem>
  );
}

/** Rail button with the selected-state pill on the left edge. */
function RailItem({
  active,
  label,
  onClick,
  children,
}: {
  active: boolean;
  label: string;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="relative shrink-0">
      <span
        className={cn(
          "absolute top-1/2 -left-3 h-5 w-1 -translate-y-1/2 rounded-r-full bg-foreground transition-all",
          active ? "opacity-100" : "opacity-0",
        )}
      />
      <Tooltip>
        <TooltipTrigger asChild>
          <button onClick={onClick}>{children}</button>
        </TooltipTrigger>
        <TooltipContent side="right">{label}</TooltipContent>
      </Tooltip>
    </div>
  );
}
