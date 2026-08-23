import { useEffect } from "react";
import { UserAvatar } from "@/components/UserAvatar";
import { UserModerationMenu } from "@/components/UserModerationMenu";
import { useAuthStore } from "@/state/auth";
import { useDmsStore } from "@/state/dms";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import { useModerationStore } from "@/state/moderation";
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
  const isAdmin = useAuthStore((s) => s.user?.is_admin ?? false);
  const openWithUser = useDmsStore((s) => s.openWithUser);

  const startDm = async (user: User) => {
    if (isAdmin) {
      useModerationStore.getState().openUser(user);
      return;
    }
    // Clicking yourself is a no-op rather than an error — the server rejects it.
    if (user.id === currentUserId) return;
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
            <button
              onClick={() => void startDm(user)}
              title={isAdmin ? `Moderate ${user.username}` : user.id === currentUserId ? undefined : `Message ${user.username}`}
              className={`flex w-full items-center gap-2 rounded-md px-1 py-1.5 pr-8 text-left hover:bg-white/5 ${
                status === "offline" ? "opacity-50" : ""
              }`}
            >
              <UserAvatar username={user.username} size="sm" status={status} />
              <span className="truncate text-sm text-foreground">{user.username}</span>
              {user.is_admin && (
                <span className="ml-auto text-[10px] font-semibold tracking-wide text-primary uppercase">
                  Admin
                </span>
              )}
            </button>
          </UserModerationMenu>
        ))}
      </div>
    </div>
  );
}
