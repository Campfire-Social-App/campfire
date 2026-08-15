import { Avatar, AvatarBadge, AvatarFallback } from "@/components/ui/avatar";
import { cn } from "@/lib/utils";

// Fire embers mixed with night-sky tones, so avatars stay distinguishable
// without clashing with the primary campfire-orange accent used for UI chrome.
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

function colorFor(username: string): string {
  let hash = 0;
  for (let i = 0; i < username.length; i++) hash = (hash << 5) - hash + username.charCodeAt(i);
  return PALETTE[Math.abs(hash) % PALETTE.length];
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
  return (
    <Avatar
      size={size}
      className={cn(
        ring && "ring-2 ring-primary shadow-[0_0_12px_1px_var(--primary)] ring-offset-2 ring-offset-background",
        className,
      )}
    >
      <AvatarFallback className={cn(colorFor(username), "font-semibold text-white")}>
        {initialsFor(username)}
      </AvatarFallback>
      {status && (
        <AvatarBadge className={cn("size-2.5!", status === "online" ? "bg-online" : "bg-offline")} />
      )}
    </Avatar>
  );
}
