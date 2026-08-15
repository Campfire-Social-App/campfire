import { Avatar, AvatarBadge, AvatarFallback } from "@/components/ui/avatar";
import { cn } from "@/lib/utils";

const PALETTE = [
  "bg-[#f23f43]",
  "bg-[#f0b232]",
  "bg-[#23a55a]",
  "bg-[#3ba55c]",
  "bg-[#5865f2]",
  "bg-[#eb459e]",
  "bg-[#9c84ef]",
  "bg-[#00a8fc]",
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
    <Avatar size={size} className={cn(ring && "ring-2 ring-online ring-offset-2 ring-offset-background", className)}>
      <AvatarFallback className={cn(colorFor(username), "font-semibold text-white")}>
        {initialsFor(username)}
      </AvatarFallback>
      {status && (
        <AvatarBadge className={cn("size-2.5!", status === "online" ? "bg-online" : "bg-offline")} />
      )}
    </Avatar>
  );
}
