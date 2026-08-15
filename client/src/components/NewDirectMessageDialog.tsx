import { useEffect, useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { UserAvatar, usernameColorFor } from "@/components/UserAvatar";
import { useAuthStore } from "@/state/auth";
import { useDmsStore } from "@/state/dms";
import { usePresenceStore } from "@/state/presence";
import { useUsersStore } from "@/state/users";
import { ApiError } from "@/lib/types";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface NewDirectMessageDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function NewDirectMessageDialog({ open, onOpenChange }: NewDirectMessageDialogProps) {
  const users = useUsersStore((s) => s.users);
  const currentUserId = useAuthStore((s) => s.user?.id);
  const onlineUserIds = usePresenceStore((s) => s.onlineUserIds);
  const openWithUser = useDmsStore((s) => s.openWithUser);
  const [query, setQuery] = useState("");

  useEffect(() => {
    if (open) setQuery("");
  }, [open]);

  const matches = useMemo(() => {
    const lower = query.trim().toLowerCase();
    return users.filter(
      (u) => u.id !== currentUserId && u.username.toLowerCase().includes(lower),
    );
  }, [users, currentUserId, query]);

  const handleSelect = async (userId: string) => {
    try {
      await openWithUser(userId);
      onOpenChange(false);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to open the conversation.");
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New direct message</DialogTitle>
        </DialogHeader>

        <div className="relative">
          <Search className="absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Find a member"
            className="pl-9"
            autoFocus
          />
        </div>

        <div className="max-h-72 space-y-0.5 overflow-y-auto">
          {matches.length === 0 ? (
            <p className="px-1 py-6 text-center text-sm text-muted-foreground">
              No members match “{query}”.
            </p>
          ) : (
            matches.map((user) => (
              <button
                key={user.id}
                onClick={() => void handleSelect(user.id)}
                className="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left hover:bg-white/5"
              >
                <UserAvatar
                  username={user.username}
                  size="sm"
                  status={onlineUserIds[user.id] ? "online" : "offline"}
                />
                <span className={cn("truncate text-sm", usernameColorFor(user.username))}>
                  {user.username}
                </span>
              </button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
