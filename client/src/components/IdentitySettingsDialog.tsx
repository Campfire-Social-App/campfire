import { useEffect, useRef, useState } from "react";
import { Camera, ImagePlus, Loader2, Palette, Save, Trash2, Upload } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { deleteMyDecoration, getUserProfile, updateMyAvatar, updateMyBanner, updateMyProfile, uploadAttachment, uploadMyDecoration } from "@/api/endpoints";
import { UserAvatar } from "@/components/UserAvatar";
import { DecoratedAvatar, DecoratedIdentityPlate, ProfileDecorationOrnaments } from "@/components/ProfileDecorationLayer";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { THEMES } from "@/lib/themes";
import { getDecorationAssets, PROFILE_DECORATIONS } from "@/lib/profileDecorations";
import { ApiError, type AvatarDecoration, type CustomDecorationAsset, type CustomDecorationAssets, type DecorationRole, type User, type UserProfileUpdate } from "@/lib/types";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { useUsersStore } from "@/state/users";
import { toast } from "sonner";

const DEFAULTS: UserProfileUpdate = { display_name: null, bio: null, custom_status: null, profile_layout: "standard", accent_color: "#FF6A00", banner_type: "gradient", banner_color: "#FF6A00", banner_secondary_color: "#9A3412", background_type: "solid", avatar_decoration: "none", profile_decoration: "none", avatar_frame_decoration: "none", identity_plate_decoration: "none", profile_effect: "none" };
const DECORATIONS: AvatarDecoration[] = ["none", "admin", "founder", "developer", "bug_hunter", "early_adopter", "event_winner"];
const MAX_PROFILE_IMAGE_BYTES = 8 * 1024 * 1024;
const IMAGE_ACCEPT = "image/png,image/jpeg,image/gif,image/webp,image/avif";
const DECORATION_ACCEPT = "image/png,image/gif,.png,.gif";
const DECORATION_ROLES: readonly { role: DecorationRole; label: string; size: string; limit: string }[] = [
  { role: "card-frame", label: "Card frame", size: "600 × 908", limit: "PNG · 2 MiB" },
  { role: "card-top", label: "Card top", size: "600 × 128", limit: "PNG/GIF · 5 MiB" },
  { role: "avatar-frame", label: "Avatar frame", size: "384 × 384", limit: "PNG/GIF · 3 MiB" },
  { role: "identity-plate", label: "Identity plate", size: "456 × 80", limit: "PNG/GIF · 4 MiB" },
];
const VISUAL_FIELDS = [
  "accent_color",
  "banner_type",
  "banner_color",
  "banner_secondary_color",
  "background_type",
  "avatar_decoration",
  "profile_decoration",
  "avatar_frame_decoration",
  "identity_plate_decoration",
  "profile_effect",
] as const satisfies readonly (keyof UserProfileUpdate)[];

function imageError(file: File): string | null {
  if (!file.type.startsWith("image/") || file.type === "image/svg+xml") return "Choose a PNG, JPG, WebP, AVIF or GIF image.";
  if (file.size > MAX_PROFILE_IMAGE_BYTES) return "Profile images can be at most 8 MB.";
  return null;
}

function useFilePreview(file: File | null): string | null {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!file) { setUrl(null); return; }
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);
  return url;
}

export function IdentitySettingsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const user = useAuthStore((s) => s.user);
  const theme = useSettingsStore((s) => s.theme);
  const setTheme = useSettingsStore((s) => s.setTheme);
  const [draft, setDraft] = useState<UserProfileUpdate>(DEFAULTS);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [removeAvatar, setRemoveAvatar] = useState(false);
  const [removeBanner, setRemoveBanner] = useState(false);
  const [customAssets, setCustomAssets] = useState<CustomDecorationAssets>({});
  const [uploadingRole, setUploadingRole] = useState<DecorationRole | null>(null);
  const avatarInput = useRef<HTMLInputElement>(null);
  const bannerInput = useRef<HTMLInputElement>(null);
  const avatarPreview = useFilePreview(avatarFile);
  const bannerPreview = useFilePreview(bannerFile);
  useEffect(() => {
    if (!open || !user) {
      setAvatarFile(null);
      setBannerFile(null);
      setRemoveAvatar(false);
      setRemoveBanner(false);
      setCustomAssets({});
      return;
    }
    setLoading(true);
    void getUserProfile(user.id).then(({ user: freshUser, badges: _badges, activities: _activities, custom_decoration_assets, ...profile }) => {
      setDraft(profile);
      setCustomAssets(custom_decoration_assets);
      useAuthStore.getState().setUser(freshUser);
      useUsersStore.getState().upsertUser(freshUser);
    }).catch(() => toast.error("Couldn't load your identity.")).finally(() => setLoading(false));
  }, [open, user?.id]);
  if (!user) return null;
  const field = <K extends keyof UserProfileUpdate>(key: K, value: UserProfileUpdate[K]) => setDraft((current) => ({ ...current, [key]: value }));
  const chooseImage = (file: File | undefined, kind: "avatar" | "banner") => {
    if (!file) return;
    const error = imageError(file);
    if (error) { toast.error(error); return; }
    if (kind === "avatar") { setAvatarFile(file); setRemoveAvatar(false); }
    else { setBannerFile(file); setRemoveBanner(false); }
  };
  const uploadDecoration = async (role: DecorationRole, file: File | undefined) => {
    if (!file) return;
    const extension = file.name.split(".").pop()?.toLowerCase();
    if (!(["png", "gif"].includes(extension ?? ""))) {
      toast.error("Custom decorations accept only PNG or GIF files.");
      return;
    }
    setUploadingRole(role);
    try {
      const profile = await uploadMyDecoration(role, file);
      setCustomAssets(profile.custom_decoration_assets);
      if (role === "card-frame" || role === "card-top") field("profile_decoration", "custom");
      else if (role === "avatar-frame") field("avatar_frame_decoration", "custom");
      else field("identity_plate_decoration", "custom");
      useAuthStore.getState().setUser(profile.user);
      useUsersStore.getState().upsertUser(profile.user);
      toast.success(`${role.replace(/-/g, " ")} uploaded and validated.`);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't validate this decoration.");
    } finally {
      setUploadingRole(null);
    }
  };
  const removeDecoration = async (role: DecorationRole) => {
    setUploadingRole(role);
    try {
      const profile = await deleteMyDecoration(role);
      setCustomAssets(profile.custom_decoration_assets);
      setDraft((current) => ({
        ...current,
        profile_decoration: role === "card-frame" || role === "card-top" ? profile.profile_decoration : current.profile_decoration,
        avatar_frame_decoration: role === "avatar-frame" ? profile.avatar_frame_decoration : current.avatar_frame_decoration,
        identity_plate_decoration: role === "identity-plate" ? profile.identity_plate_decoration : current.identity_plate_decoration,
      }));
      useAuthStore.getState().setUser(profile.user);
      useUsersStore.getState().upsertUser(profile.user);
      toast.success("Custom decoration removed.");
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't remove this decoration.");
    } finally {
      setUploadingRole(null);
    }
  };
  const save = async () => {
    setSaving(true);
    try {
      let updatedUser = user;
      const [avatarAttachment, bannerAttachment] = await Promise.all([
        avatarFile ? uploadAttachment(avatarFile) : null,
        bannerFile ? uploadAttachment(bannerFile) : null,
      ]);
      if (avatarAttachment) updatedUser = await updateMyAvatar(avatarAttachment.id);
      else if (removeAvatar) updatedUser = await updateMyAvatar(null);
      if (bannerAttachment) updatedUser = await updateMyBanner(bannerAttachment.id);
      else if (removeBanner) updatedUser = await updateMyBanner(null);
      const updatedProfile = await updateMyProfile(draft);
      const rejectedVisualField = VISUAL_FIELDS.find(
        (key) => updatedProfile[key] !== draft[key],
      );
      if (rejectedVisualField) {
        throw new ApiError(
          409,
          `The server did not persist ${rejectedVisualField.replace(/_/g, " ")}. Apply the latest migrations and restart it.`,
        );
      }
      updatedUser = updatedProfile.user;
      useAuthStore.getState().setUser(updatedUser);
      useUsersStore.getState().upsertUser(updatedUser);
      toast.success("Profile saved.");
      onOpenChange(false);
    }
    catch (error) {
      toast.error(
        error instanceof ApiError
          ? error.message
          : "Couldn't save your identity. Check the selected values.",
      );
    }
    finally { setSaving(false); }
  };
  return <Dialog open={open} onOpenChange={onOpenChange}>
    <DialogContent className="flex max-h-[calc(100vh-2rem)] w-[min(64rem,calc(100vw-2rem))] max-w-none flex-col gap-0 overflow-hidden p-0 sm:max-w-4xl">
      <DialogHeader className="shrink-0 border-b border-glass-border px-6 py-5 pr-14"><DialogTitle className="text-base">Profile</DialogTitle></DialogHeader>
      {loading ? <div className="flex h-64 items-center justify-center"><Loader2 className="size-6 animate-spin" /></div> : <div className="grid min-h-0 flex-1 gap-8 overflow-y-auto px-6 py-5 lg:grid-cols-[minmax(0,1fr)_minmax(17rem,21rem)]">
        <div className="min-w-0 space-y-7">
          <section className="space-y-3"><h3 className="text-sm font-semibold">Profile image</h3>
            <div className="grid gap-3 sm:grid-cols-2">
              <ImageActions label="avatar" hasImage={!!(avatarPreview || (!removeAvatar && user.avatar_url))} onChange={() => avatarInput.current?.click()} onRemove={() => { setAvatarFile(null); setRemoveAvatar(true); }} />
              <ImageActions label="banner" hasImage={!!(bannerPreview || (!removeBanner && user.banner_url))} onChange={() => bannerInput.current?.click()} onRemove={() => { setBannerFile(null); setRemoveBanner(true); }} />
            </div>
            <input ref={avatarInput} type="file" accept={IMAGE_ACCEPT} className="hidden" onChange={(event) => { chooseImage(event.currentTarget.files?.[0], "avatar"); event.currentTarget.value = ""; }} />
            <input ref={bannerInput} type="file" accept={IMAGE_ACCEPT} className="hidden" onChange={(event) => { chooseImage(event.currentTarget.files?.[0], "banner"); event.currentTarget.value = ""; }} />
          </section>
          <section className="space-y-3"><h3 className="text-sm font-semibold">Identity</h3>
            <div className="space-y-1.5"><Label htmlFor="display-name">Display name</Label><Input id="display-name" maxLength={64} value={draft.display_name ?? ""} onChange={(e) => field("display_name", e.target.value || null)} placeholder={user.username} /></div>
            <div className="space-y-1.5"><Label htmlFor="status">Custom status</Label><Input id="status" maxLength={128} value={draft.custom_status ?? ""} onChange={(e) => field("custom_status", e.target.value || null)} placeholder="🔥 Building something warm" /></div>
            <div className="space-y-1.5"><Label htmlFor="bio">Bio</Label><Textarea id="bio" maxLength={500} value={draft.bio ?? ""} onChange={(e) => field("bio", e.target.value || null)} /></div>
          </section>
          <section className="space-y-3"><h3 className="text-sm font-semibold">Card appearance</h3>
            <Select label="Avatar accent (legacy)" value={draft.avatar_decoration} values={DECORATIONS} onChange={(v) => field("avatar_decoration", v as AvatarDecoration)} />
            <div className="grid gap-3 sm:grid-cols-3"><Color label="Accent" value={draft.accent_color} onChange={(v) => field("accent_color", v)} /><Color label="Banner" value={draft.banner_color} onChange={(v) => field("banner_color", v)} /><Color label="Gradient" value={draft.banner_secondary_color} onChange={(v) => field("banner_secondary_color", v)} /></div>
          </section>
          <section className="space-y-3"><div><h3 className="text-sm font-semibold">Card frame</h3><p className="mt-1 text-xs text-muted-foreground">Changes only the outer border of the Profile Card.</p></div><div className="grid gap-2 sm:grid-cols-2">{PROFILE_DECORATIONS.filter((item) => item.id !== "custom" || customAssets["card-frame"] || customAssets["card-top"]).map((item) => <button key={item.id} type="button" onClick={() => field("profile_decoration", item.id)} aria-pressed={draft.profile_decoration === item.id} className={`rounded-xl border p-3 text-left transition-colors ${draft.profile_decoration === item.id ? "border-primary bg-primary/10" : "border-glass-border hover:bg-white/5"}`}><span className="flex items-center justify-between gap-2"><span className="text-sm font-medium">{item.name}</span><span className="text-[9px] font-bold uppercase tracking-wider text-muted-foreground">{item.rarity}</span></span><span className="mt-1 block text-xs text-muted-foreground">{item.description}</span><span className="mt-3 flex gap-1">{item.colors.map((color) => <span key={color} className="h-1.5 flex-1 rounded-full" style={{ background: color }} />)}</span></button>)}</div></section>
          <section className="space-y-3"><div><h3 className="text-sm font-semibold">Independent cosmetics</h3><p className="mt-1 text-xs text-muted-foreground">Mix a Profile Card frame, avatar frame and member-list identity plate independently.</p></div><div className="grid gap-3 sm:grid-cols-2"><Select label="Avatar frame" value={draft.avatar_frame_decoration} values={PROFILE_DECORATIONS.filter((item) => item.id !== "custom" || customAssets["avatar-frame"]).map((item) => item.id)} onChange={(v) => field("avatar_frame_decoration", v as UserProfileUpdate["avatar_frame_decoration"])} /><Select label="Identity plate" value={draft.identity_plate_decoration} values={PROFILE_DECORATIONS.filter((item) => item.id !== "custom" || customAssets["identity-plate"]).map((item) => item.id)} onChange={(v) => field("identity_plate_decoration", v as UserProfileUpdate["identity_plate_decoration"])} /></div></section>
          <section className="space-y-3"><div><h3 className="flex items-center gap-2 text-sm font-semibold"><Upload className="size-4" />Your decoration assets</h3><p className="mt-1 text-xs text-muted-foreground">Upload transparent PNG or GIF files. Campfire validates the real format, dimensions, safe areas and animation before storing them.</p></div><div className="grid gap-2 sm:grid-cols-2">{DECORATION_ROLES.map((item) => <DecorationUpload key={item.role} {...item} asset={customAssets[item.role]} busy={uploadingRole === item.role} disabled={uploadingRole !== null} onUpload={(file) => void uploadDecoration(item.role, file)} onRemove={() => void removeDecoration(item.role)} />)}</div><p className="text-[11px] leading-relaxed text-muted-foreground">GIF: maximum 15 fps, 6 seconds and 90 frames; a reduced-motion poster is created automatically. SVG, HTML, CSS and external URLs are rejected.</p></section>
          <section className="space-y-3"><h3 className="flex items-center gap-2 text-sm font-semibold"><Palette className="size-4" />Application theme</h3><div className="grid grid-cols-[repeat(auto-fit,minmax(7rem,1fr))] gap-2">{THEMES.map((item) => <button key={item.id} type="button" onClick={() => setTheme(item.id)} aria-pressed={theme === item.id} className={`min-w-0 rounded-lg border p-3 text-left transition-colors ${theme === item.id ? "border-primary bg-primary/10" : "border-glass-border hover:bg-white/5"}`}><span className="block truncate text-xs font-medium">{item.name.replace("Campfire ", "")}</span><span className="mt-2 flex gap-1">{item.colors.map((color) => <span key={color} className="size-4 rounded-full border border-white/10" style={{ background: color }} />)}</span></button>)}</div></section>
        </div>
        <aside className="min-w-0 lg:sticky lg:top-0 lg:self-start"><p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Live preview</p><ProfilePreview draft={draft} customAssets={customAssets} user={user} avatarPreview={avatarPreview} bannerPreview={bannerPreview} removeAvatar={removeAvatar} removeBanner={removeBanner} /></aside>
      </div>}
      <div className="flex shrink-0 justify-end gap-2 border-t border-glass-border px-6 py-4"><Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button><Button disabled={loading || saving} onClick={() => void save()}>{saving ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}Save changes</Button></div>
    </DialogContent>
  </Dialog>;
}

function Select({ label, value, values, onChange }: { label: string; value: string; values: readonly string[]; onChange: (value: string) => void }) { return <label className="space-y-1.5 text-xs text-muted-foreground">{label}<select value={value} onChange={(e) => onChange(e.target.value)} className="h-9 w-full rounded-md border border-input bg-background px-2 text-sm text-foreground">{values.map((item) => <option key={item} value={item}>{item.replace(/_/g, " ")}</option>)}</select></label>; }
function Color({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) { return <label className="space-y-1.5 text-xs text-muted-foreground">{label}<input type="color" value={value} onChange={(e) => onChange(e.target.value.toUpperCase())} className="h-9 w-full cursor-pointer rounded-md border border-input bg-background p-1" /></label>; }

function ImageActions({ label, hasImage, onChange, onRemove }: { label: "avatar" | "banner"; hasImage: boolean; onChange: () => void; onRemove: () => void }) {
  const Icon = label === "avatar" ? Camera : ImagePlus;
  return <div className="flex min-w-0 gap-2"><button type="button" onClick={onChange} className="flex min-h-11 min-w-0 flex-1 items-center justify-center gap-2 rounded-lg border border-glass-border px-3 py-2.5 text-sm font-medium transition-colors hover:bg-white/5"><Icon className="size-4 shrink-0" /><span className="truncate">Change {label}</span></button><button type="button" aria-label={`Remove ${label}`} title={`Remove ${label}`} disabled={!hasImage} onClick={onRemove} className="flex size-11 shrink-0 items-center justify-center rounded-lg border border-glass-border text-muted-foreground transition-colors hover:border-destructive/40 hover:bg-destructive/10 hover:text-destructive disabled:pointer-events-none disabled:opacity-35"><Trash2 className="size-4" /></button></div>;
}

function DecorationUpload({ role, label, size, limit, asset, busy, disabled, onUpload, onRemove }: { role: DecorationRole; label: string; size: string; limit: string; asset?: CustomDecorationAsset; busy: boolean; disabled: boolean; onUpload: (file: File | undefined) => void; onRemove: () => void }) {
  return <div className={`rounded-xl border p-3 ${asset ? "border-primary/40 bg-primary/5" : "border-glass-border"}`}>
    <div className="flex items-start justify-between gap-2"><div><p className="text-xs font-semibold text-foreground">{label}</p><p className="mt-0.5 text-[10px] text-muted-foreground">{size} px · {limit}</p></div>{asset && <span className="rounded-full bg-primary/15 px-1.5 py-0.5 text-[9px] font-bold uppercase text-primary">Ready</span>}</div>
    <div className="mt-3 flex gap-2">
      <label className={`flex h-8 min-w-0 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-md border border-input px-2 text-xs font-medium transition-colors hover:bg-white/5 ${disabled ? "pointer-events-none opacity-50" : ""}`}>
        {busy ? <Loader2 className="size-3.5 animate-spin" /> : <Upload className="size-3.5" />}{asset ? "Replace" : "Upload"}
        <input type="file" accept={DECORATION_ACCEPT} className="hidden" disabled={disabled} onChange={(event) => { onUpload(event.currentTarget.files?.[0]); event.currentTarget.value = ""; }} />
      </label>
      <button type="button" title={`Remove ${label}`} aria-label={`Remove ${label}`} disabled={!asset || disabled} onClick={onRemove} className="flex size-8 items-center justify-center rounded-md border border-input text-muted-foreground transition-colors hover:border-destructive/40 hover:bg-destructive/10 hover:text-destructive disabled:pointer-events-none disabled:opacity-35"><Trash2 className="size-3.5" /></button>
    </div>
    <span className="sr-only">Asset role: {role}</span>
  </div>;
}

function ProfilePreview({ draft, customAssets, user, avatarPreview, bannerPreview, removeAvatar, removeBanner }: { draft: UserProfileUpdate; customAssets: CustomDecorationAssets; user: User; avatarPreview: string | null; bannerPreview: string | null; removeAvatar: boolean; removeBanner: boolean }) {
  const imageBanner = !removeBanner && (bannerPreview ?? user.banner_url);
  const avatarUrl = removeAvatar ? null : avatarPreview ?? user.avatar_url;
  const assets = getDecorationAssets(draft.profile_decoration, customAssets);
  const avatarContent = <DecoratedAvatar decoration={draft.avatar_frame_decoration} customAssets={customAssets}>
    <div className={draft.avatar_frame_decoration === "none" && draft.avatar_decoration !== "none" ? "avatar-decoration" : ""} data-decoration={draft.avatar_decoration}>
      {avatarPreview && !removeAvatar
        ? <img src={avatarPreview} alt="Avatar preview" className="size-16 rounded-full object-cover" />
        : <UserAvatar username={user.username} avatarUrl={avatarUrl} size="lg" className="size-16" />}
    </div>
  </DecoratedAvatar>;
  return <div className="space-y-5">
    <div
      className={`profile-decoration-host w-[min(300px,100%)] rounded-lg border border-glass-border bg-popover ${assets?.cardFrame?.layout === "legacy-outset" ? "mt-16" : ""}`}
      data-profile-decoration={draft.profile_decoration}
      style={{ "--profile-accent": draft.accent_color } as React.CSSProperties}
    >
      <ProfileDecorationOrnaments decoration={draft.profile_decoration} customAssets={customAssets} />
      <div className="profile-card-banner h-24 shrink-0 overflow-hidden" style={!imageBanner ? { background: draft.banner_type === "solid" ? draft.banner_color : `linear-gradient(135deg, ${draft.banner_color}, ${draft.banner_secondary_color})` } : undefined}>{imageBanner && <img src={bannerPreview ?? resolveAssetUrl(user.banner_url!)} alt="" className="size-full object-cover" />}</div>
      <div className={`relative px-3 pt-9 ${assets?.cardFrame ? "pb-8" : "pb-3"}`}>
        <div className="absolute -top-8 left-3 rounded-full bg-popover p-1">{avatarContent}</div>
        <h3 className="truncate font-heading text-base font-semibold">{draft.display_name || user.username}</h3>
        {draft.display_name && <p className="truncate text-xs text-muted-foreground">@{user.username}</p>}
        <p className="mt-1 text-xs" style={{ color: draft.accent_color }}>Online</p>
        {draft.custom_status && <p className="mt-3 break-words text-sm">{draft.custom_status}</p>}
        {draft.bio && <p className="mt-2 whitespace-pre-wrap break-words text-sm text-muted-foreground">{draft.bio}</p>}
      </div>
    </div>
    <div>
      <p className="mb-2 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Member-list identity plate · 228 × 40</p>
      <div className="w-64 max-w-full rounded-lg bg-sidebar p-3">
        <DecoratedIdentityPlate decoration={draft.identity_plate_decoration} customAssets={customAssets}>
          <UserAvatar username={user.username} avatarUrl={avatarUrl} size="sm" status="online" />
          <span className="min-w-0 flex-1 truncate text-sm font-medium text-foreground">{draft.display_name || user.username}</span>
          {user.is_admin && <span className="member-role-tag mr-8 ml-auto shrink-0 rounded-[4px] px-1 py-px text-[9px] font-semibold tracking-wide text-primary">ADMIN</span>}
        </DecoratedIdentityPlate>
      </div>
    </div>
  </div>;
}
