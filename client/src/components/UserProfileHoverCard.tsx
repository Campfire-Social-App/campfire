import { format } from "date-fns";
import { CalendarDays, MessageCircle, ShieldCheck } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { UserAvatar } from "@/components/UserAvatar";
import { BotBadge } from "@/components/BotBadge";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { usePresenceStore } from "@/state/presence";
import type { User } from "@/lib/types";

export function UserProfileHoverCard({
  user,
  children,
  onMessage,
}: {
  user: User;
  children: React.ReactNode;
  onMessage?: () => void;
}) {
  const isOnline = usePresenceStore((state) => !!state.onlineUserIds[user.id]);

  return (
    <Popover>
      <PopoverTrigger asChild>{children}</PopoverTrigger>
      <PopoverContent className="w-72">
        <div className="relative h-20 overflow-hidden bg-linear-to-br from-amber-400 via-orange-600 to-red-800">
          {user.banner_url && (
            <img src={resolveAssetUrl(user.banner_url)} alt="" className="size-full object-cover" />
          )}
          <div className="absolute inset-0 bg-linear-to-t from-black/35 to-transparent" />
        </div>

        <div className="relative px-3 pb-3 pt-9">
          <div className="absolute -top-8 left-3 rounded-full bg-popover p-1 shadow-lg">
            <UserAvatar
              username={user.username}
              avatarUrl={user.avatar_url}
              size="lg"
              status={isOnline ? "online" : "offline"}
              className="size-16 *:text-lg"
            />
          </div>

          <div className="flex items-center gap-2">
            <h3 className="min-w-0 truncate font-heading text-base font-semibold text-foreground">
              {user.username}
            </h3>
            {user.is_bot && <BotBadge className="shrink-0" />}
            {user.is_admin && (
              <ShieldCheck aria-label="Administrator" className="size-4 shrink-0 text-primary" />
            )}
          </div>
          <p className="mt-0.5 text-xs font-medium text-muted-foreground">
            {isOnline ? "Online" : "Offline"} ·{" "}
            {user.is_bot ? "Bot" : user.is_admin ? "Administrator" : "Member"}
          </p>
          <div className="mt-3 flex items-center gap-2 border-t border-glass-border pt-2.5 text-xs text-muted-foreground">
            <CalendarDays className="size-3.5" />
            Member since {format(new Date(user.created_at), "MMM yyyy")}
          </div>
          {onMessage && (
            <button
              type="button"
              onClick={onMessage}
              className="mt-2.5 flex h-7 w-full items-center justify-center gap-1.5 rounded-md bg-primary/15 text-xs font-medium text-primary hover:bg-primary/25"
            >
              <MessageCircle className="size-3.5" />
              Message
            </button>
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}
