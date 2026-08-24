import { format } from "date-fns";
import { CalendarDays, ShieldCheck } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { UserAvatar } from "@/components/UserAvatar";
import {
  HoverCard,
  HoverCardContent,
  HoverCardTrigger,
} from "@/components/ui/hover-card";
import { usePresenceStore } from "@/state/presence";
import type { User } from "@/lib/types";

export function UserProfileHoverCard({
  user,
  children,
}: {
  user: User;
  children: React.ReactNode;
}) {
  const isOnline = usePresenceStore((state) => !!state.onlineUserIds[user.id]);

  return (
    <HoverCard openDelay={350} closeDelay={120}>
      <HoverCardTrigger asChild>{children}</HoverCardTrigger>
      <HoverCardContent>
        <div className="relative h-28 overflow-hidden bg-linear-to-br from-amber-400 via-orange-600 to-red-800">
          {user.banner_url && (
            <img src={resolveAssetUrl(user.banner_url)} alt="" className="size-full object-cover" />
          )}
          <div className="absolute inset-0 bg-linear-to-t from-black/35 to-transparent" />
        </div>

        <div className="relative px-4 pb-4 pt-11">
          <div className="absolute -top-10 left-4 rounded-full bg-popover p-1.5 shadow-lg">
            <UserAvatar
              username={user.username}
              avatarUrl={user.avatar_url}
              size="lg"
              status={isOnline ? "online" : "offline"}
              className="size-20 *:text-xl"
            />
          </div>

          <div className="flex items-center gap-2">
            <h3 className="min-w-0 truncate font-heading text-lg font-semibold text-foreground">
              {user.username}
            </h3>
            {user.is_admin && (
              <ShieldCheck aria-label="Administrator" className="size-4 shrink-0 text-primary" />
            )}
          </div>
          <p className="mt-0.5 text-xs font-medium text-muted-foreground">
            {isOnline ? "Online" : "Offline"} · {user.is_admin ? "Administrator" : "Member"}
          </p>
          <div className="mt-4 flex items-center gap-2 border-t border-glass-border pt-3 text-xs text-muted-foreground">
            <CalendarDays className="size-3.5" />
            Member since {format(new Date(user.created_at), "MMM yyyy")}
          </div>
        </div>
      </HoverCardContent>
    </HoverCard>
  );
}
