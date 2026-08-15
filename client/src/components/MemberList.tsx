import { useEffect } from "react";
import { UserAvatar } from "@/components/UserAvatar";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import type { User } from "@/lib/types";

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
    <div className="w-60 shrink-0 overflow-y-auto bg-sidebar px-3 py-4">
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
  if (users.length === 0) return null;
  return (
    <div className="mb-4">
      <p className="mb-1 px-1 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
        {title}
      </p>
      <div className="space-y-0.5">
        {users.map((user) => (
          <div
            key={user.id}
            className={`flex items-center gap-2 rounded-md px-1 py-1.5 hover:bg-white/5 ${
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
          </div>
        ))}
      </div>
    </div>
  );
}
