import { Avatar, AvatarBadge, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { resolveAssetUrl } from "@/api/client";
import { cn } from "@/lib/utils";
import { useAuthStore } from "@/state/auth";
import { useUsersStore } from "@/state/users";

// Fire embers mixed with night-sky tones, so avatars stay distinguishable
// without clashing with the primary campfire-orange accent used for UI chrome.
// TEXT_PALETTE is the same hues as text-* classes, index-paired with PALETTE,
// so a username in the message list matches that user's avatar color.
const PALETTE = [
  "bg-[#f0463f]",
  "bg-[#fbbf24]",
  "bg-[#ff9d42]",
  "bg-[#4ade80]",
  "bg-[#38bdf8]",
  "bg-[#9c84ef]",
  "bg-[#f472b6]",
  "bg-[#2dd4bf]",
];

const TEXT_PALETTE = [
  "text-[#f0463f]",
  "text-[#fbbf24]",
  "text-[#ff9d42]",
  "text-[#4ade80]",
  "text-[#38bdf8]",
  "text-[#9c84ef]",
  "text-[#f472b6]",
  "text-[#2dd4bf]",
];

function paletteIndex(username: string): number {
  let hash = 0;
  for (let i = 0; i < username.length; i++) hash = (hash << 5) - hash + username.charCodeAt(i);
  return Math.abs(hash) % PALETTE.length;
}

function colorFor(username: string): string {
  return PALETTE[paletteIndex(username)];
}

export function usernameColorFor(username: string): string {
  return TEXT_PALETTE[paletteIndex(username)];
}

function initialsFor(username: string): string {
  return username.slice(0, 2).toUpperCase();
}

interface UserAvatarProps {
  username: string;
  size?: "default" | "sm" | "lg";
  status?: "online" | "offline";
  ring?: boolean;
  className?: string;
}

export function UserAvatar({ username, size = "default", status, ring, className }: UserAvatarProps) {
  const knownAvatar = useUsersStore((state) => state.users.find((user) => user.username === username)?.avatar_url);
  const ownAvatar = useAuthStore((state) => state.user?.username === username ? state.user.avatar_url : null);
  const avatarUrl = knownAvatar ?? ownAvatar;
  return (
    <Avatar
      size={size}
      className={cn(
        ring && "ring-2 ring-primary shadow-[0_0_12px_1px_var(--primary)] ring-offset-2 ring-offset-background",
        className,
      )}
    >
      {avatarUrl && <AvatarImage src={resolveAssetUrl(avatarUrl)} alt={username} />}
      <AvatarFallback className={cn(colorFor(username), "font-semibold text-white")}>
        {initialsFor(username)}
      </AvatarFallback>
      {status && (
        <AvatarBadge className={cn("size-2.5!", status === "online" ? "bg-online" : "bg-offline")} />
      )}
    </Avatar>
  );
}
