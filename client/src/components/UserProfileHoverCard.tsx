import { useState } from "react";
import { format } from "date-fns";
import { CalendarDays, Code2, Gamepad2, Loader2, MessageCircle, ShieldCheck } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { getUserProfile } from "@/api/endpoints";
import { BotBadge } from "@/components/BotBadge";
import { DecoratedAvatar, ProfileDecorationOrnaments } from "@/components/ProfileDecorationLayer";
import { UserAvatar } from "@/components/UserAvatar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { getDecorationAssets } from "@/lib/profileDecorations";
import type { User, UserProfile } from "@/lib/types";
import { usePresenceStore } from "@/state/presence";

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
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(false);

  const load = (open: boolean) => {
    if (!open || loading) return;
    setLoading(true);
    void getUserProfile(user.id).then(setProfile).finally(() => setLoading(false));
  };

  const identity = profile ?? {
    user,
    display_name: user.display_name ?? null,
    bio: null,
    custom_status: null,
    profile_layout: "standard",
    accent_color: "#FF6A00",
    banner_type: "gradient",
    banner_color: "#FF6A00",
    banner_secondary_color: "#9A3412",
    background_type: "solid",
    avatar_decoration: "none",
    profile_decoration: "none",
    avatar_frame_decoration: "none",
    identity_plate_decoration: "none",
    profile_effect: "none",
    custom_decoration_assets: {},
    badges: user.is_admin ? ["admin"] : [],
    activities: [],
  } satisfies UserProfile;
  const decorationAssets = getDecorationAssets(
    identity.profile_decoration,
    identity.custom_decoration_assets,
  );

  const bannerStyle = !user.banner_url
    ? {
        background:
          identity.banner_type === "solid"
            ? identity.banner_color
            : `linear-gradient(135deg, ${identity.banner_color}, ${identity.banner_secondary_color})`,
      }
    : undefined;
  return (
    <Popover onOpenChange={load}>
      <PopoverTrigger asChild>{children}</PopoverTrigger>
      <PopoverContent
        className={`profile-decoration-host w-[min(300px,calc(100vw-1rem))] ${identity.profile_effect === "glow" ? "profile-effect-glow" : ""}`}
        data-profile-decoration={identity.profile_decoration}
        sideOffset={decorationAssets?.cardFrame?.layout === "legacy-outset" ? 64 : 6}
        style={{ "--profile-accent": identity.accent_color } as React.CSSProperties}
      >
        <ProfileDecorationOrnaments decoration={identity.profile_decoration} customAssets={identity.custom_decoration_assets} />

        <div
          className="profile-card-banner relative h-24 shrink-0 overflow-hidden bg-linear-to-br from-amber-400 via-orange-600 to-red-800"
          style={bannerStyle}
        >
          {user.banner_url && (
            <img src={resolveAssetUrl(user.banner_url)} alt="" className="size-full object-cover" />
          )}
          <div className="absolute inset-0 bg-linear-to-t from-black/35 to-transparent" />
        </div>

        <div
          className={`profile-card-body relative px-3 pt-9 ${decorationAssets?.cardFrame ? "pb-8" : "pb-3"}`}
        >
          <div className="absolute -top-8 left-3 rounded-full bg-popover p-1 shadow-lg">
            <DecoratedAvatar decoration={identity.avatar_frame_decoration} customAssets={identity.custom_decoration_assets}>
              <div
                className={identity.avatar_frame_decoration === "none" && identity.avatar_decoration !== "none" ? "avatar-decoration" : ""}
                data-decoration={identity.avatar_decoration}
              >
                <UserAvatar username={user.username} avatarUrl={user.avatar_url} size="lg" status={isOnline ? "online" : "offline"} className="size-16 *:text-lg" />
              </div>
            </DecoratedAvatar>
          </div>

          {loading && (
            <Loader2 className="absolute top-3 right-3 size-4 animate-spin text-muted-foreground" />
          )}

          <div className="flex items-center gap-2">
            <h3 className="min-w-0 truncate font-heading text-base font-semibold text-foreground">
              {identity.display_name ?? user.username}
            </h3>
            {user.is_bot && <BotBadge className="shrink-0" />}
            {user.is_admin && (
              <ShieldCheck aria-label="Administrator" className="size-4 shrink-0 text-primary" />
            )}
          </div>
          {identity.display_name && (
            <p className="text-xs text-muted-foreground">@{user.username}</p>
          )}
          <p className="mt-0.5 text-xs font-medium text-muted-foreground">
            {isOnline ? "Online" : "Offline"} ·{" "}
            {user.is_bot ? "Bot" : user.is_admin ? "Administrator" : "Member"}
          </p>

          {identity.custom_status && <p className="mt-3 text-sm">{identity.custom_status}</p>}
          {identity.bio && (
            <p className="mt-2 whitespace-pre-wrap text-sm text-muted-foreground">{identity.bio}</p>
          )}
          {identity.activities.map((activity) => (
            <div
              key={`${activity.type}-${activity.name}`}
              className="mt-3 rounded-lg border border-glass-border bg-white/4 p-3"
            >
              <p
                className="flex items-center gap-1.5 text-[10px] font-bold uppercase"
                style={{ color: identity.accent_color }}
              >
                {activity.type === "game" ? (
                  <Gamepad2 className="size-3" />
                ) : (
                  <Code2 className="size-3" />
                )}
                {activity.type}
              </p>
              <p className="mt-1 text-sm font-semibold">{activity.name}</p>
              {activity.details && (
                <p className="text-xs text-muted-foreground">{activity.details}</p>
              )}
            </div>
          ))}
          {identity.badges.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-1">
              {identity.badges.map((badge) => (
                <span
                  key={badge}
                  className="rounded-full border border-glass-border bg-white/5 px-2 py-0.5 text-[10px] font-semibold uppercase"
                >
                  {badge}
                </span>
              ))}
            </div>
          )}

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
