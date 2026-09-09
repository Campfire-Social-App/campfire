import { useEffect } from "react";
import { UserAvatar } from "@/components/UserAvatar";
import { BotBadge } from "@/components/BotBadge";
import { UserProfileHoverCard } from "@/components/UserProfileHoverCard";
import { UserModerationMenu } from "@/components/UserModerationMenu";
import { DecoratedIdentityPlate } from "@/components/ProfileDecorationLayer";
import { useAuthStore } from "@/state/auth";
import { useDmsStore } from "@/state/dms";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import { ApiError, type User } from "@/lib/types";
import { toast } from "sonner";

export function MemberList() {
  const users = useUsersStore((s) => s.users);
  const fetchUsers = useUsersStore((s) => s.fetch);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);

  useEffect(() => {
    void fetchUsers();
  }, [fetchUsers]);

  const online = users.filter((u) => onlineUserIds[u.id]);
  const offline = users.filter((u) => !onlineUserIds[u.id]);

  return (
    <div className="w-64 shrink-0 overflow-y-auto border-l border-sidebar-border bg-sidebar px-3 py-4">
      <MemberGroup title={`Online — ${online.length}`} users={online} status="online" />
      <MemberGroup title={`Offline — ${offline.length}`} users={offline} status="offline" />
    </div>
  );
}

function MemberGroup({
  title,
  users,
  status,
}: {
  title: string;
  users: User[];
  status: "online" | "offline";
}) {
  const currentUserId = useAuthStore((s) => s.user?.id);
  const openWithUser = useDmsStore((s) => s.openWithUser);

  const startDm = async (user: User) => {
    // Clicking yourself is a no-op rather than an error — the server rejects it.
    // A bot has nobody on the other end to read a DM, so it is the same no-op.
    if (user.id === currentUserId || user.is_bot) return;
    try {
      await openWithUser(user.id);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to open the conversation.");
    }
  };

  if (users.length === 0) return null;
  return (
    <div className="mb-4">
      <p className="mb-1 px-1 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
        {title}
      </p>
      <div className="space-y-0.5">
        {users.map((user) => (
          <UserModerationMenu key={user.id} user={user}>
            <UserProfileHoverCard
              user={user}
              onMessage={
                user.id === currentUserId || user.is_bot ? undefined : () => void startDm(user)
              }
            >
              <button
                type="button"
                title={`View ${user.display_name ?? user.username}'s profile`}
                className={`block h-10 w-full rounded-md text-left hover:bg-white/5 ${
                  status === "offline" ? "opacity-50" : ""
                }`}
              >
                <DecoratedIdentityPlate
                  decoration={user.identity_plate_decoration ?? "none"}
                  customAssets={user.custom_identity_plate ? { "identity-plate": user.custom_identity_plate } : undefined}
                >
                  <UserAvatar username={user.username} avatarUrl={user.avatar_url} size="sm" status={status} />
                  <span className="min-w-0 flex-1 truncate text-sm font-medium text-foreground">
                    {user.display_name ?? user.username}
                  </span>
                  {user.is_bot && <BotBadge className="member-role-tag mr-8 ml-auto shrink-0" />}
                  {user.is_admin && (
                    <span className="member-role-tag mr-8 ml-auto shrink-0 rounded-[4px] px-1 py-px text-[9px] font-semibold tracking-wide text-primary uppercase">
                      Admin
                    </span>
                  )}
                </DecoratedIdentityPlate>
              </button>
            </UserProfileHoverCard>
          </UserModerationMenu>
        ))}
      </div>
    </div>
  );
}
