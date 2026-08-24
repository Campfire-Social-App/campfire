import { useEffect, useRef, useState } from "react";
import { Camera, ImagePlus, Loader2 } from "lucide-react";
import { resolveAssetUrl } from "@/api/client";
import { updateMyProfileImages, uploadAttachment } from "@/api/endpoints";
import { UserAvatar } from "@/components/UserAvatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { ApiError } from "@/lib/types";
import { useAuthStore } from "@/state/auth";
import { useUsersStore } from "@/state/users";
import { toast } from "sonner";

const MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_ACCEPT = "image/png,image/jpeg,image/gif,image/webp,image/avif";

function useFilePreview(file: File | null): string | null {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!file) {
      setUrl(null);
      return;
    }
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);
  return url;
}

export function ProfileDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const user = useAuthStore((state) => state.user);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const avatarPreviewUrl = useFilePreview(avatarFile);
  const bannerPreviewUrl = useFilePreview(bannerFile);
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const bannerInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!open) {
      setAvatarFile(null);
      setBannerFile(null);
    }
  }, [open]);

  if (!user) return null;

  const chooseFile = (selected: File | undefined, kind: "avatar" | "banner") => {
    if (!selected) return;
    if (!selected.type.startsWith("image/") || selected.type === "image/svg+xml") {
      toast.error("Choose a PNG, JPG, WebP, AVIF or GIF image.");
      return;
    }
    if (selected.size > MAX_PROFILE_IMAGE_BYTES) {
      toast.error("Profile images can be at most 5 MB.");
      return;
    }
    if (kind === "avatar") setAvatarFile(selected);
    else setBannerFile(selected);
  };

  const save = async () => {
    if (!avatarFile && !bannerFile) return;
    setSaving(true);
    try {
      const [avatarAttachment, bannerAttachment] = await Promise.all([
        avatarFile ? uploadAttachment(avatarFile) : null,
        bannerFile ? uploadAttachment(bannerFile) : null,
      ]);
      const updated = await updateMyProfileImages(
        avatarAttachment?.id,
        bannerAttachment?.id,
      );
      useAuthStore.getState().setUser(updated);
      useUsersStore.getState().upsertUser(updated);
      onOpenChange(false);
      toast.success("Profile updated.");
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't update the profile.");
    } finally {
      setSaving(false);
    }
  };

  const bannerUrl = bannerPreviewUrl ?? (user.banner_url ? resolveAssetUrl(user.banner_url) : null);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="overflow-hidden p-0">
        <DialogHeader className="sr-only">
          <DialogTitle>Profile</DialogTitle>
        </DialogHeader>

        <div className="relative h-40 overflow-hidden bg-linear-to-br from-amber-400 via-orange-600 to-red-800">
          {bannerUrl && (
            <img src={bannerUrl} alt="Profile background" className="size-full object-cover" />
          )}
          <div className="absolute inset-0 bg-linear-to-t from-black/40 to-transparent" />
          <button
            type="button"
            onClick={() => bannerInputRef.current?.click()}
            className="absolute top-3 right-3 flex items-center gap-2 rounded-full border border-white/15 bg-black/55 px-3 py-1.5 text-xs font-medium text-white backdrop-blur-sm transition-colors hover:bg-black/70"
          >
            <ImagePlus className="size-4" /> Change background
          </button>
        </div>

        <div className="relative px-6 pb-6 pt-14">
          <button
            type="button"
            onClick={() => avatarInputRef.current?.click()}
            className="group absolute -top-12 left-6 rounded-full bg-popover p-1.5 shadow-xl"
            aria-label="Change profile photo"
          >
            {avatarPreviewUrl ? (
              <img
                src={avatarPreviewUrl}
                alt="New profile preview"
                className="size-24 rounded-full object-cover"
              />
            ) : (
              <UserAvatar
                username={user.username}
                avatarUrl={user.avatar_url}
                size="lg"
                className="size-24 *:text-2xl"
              />
            )}
            <span className="absolute inset-1.5 flex items-center justify-center rounded-full bg-black/55 text-white opacity-0 transition-opacity group-hover:opacity-100">
              <Camera className="size-6" />
            </span>
          </button>

          <p className="font-heading text-xl font-semibold text-foreground">{user.username}</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Avatar and background · PNG, JPG, WebP, AVIF or GIF · max 5 MB each
          </p>

          <input
            ref={avatarInputRef}
            type="file"
            accept={IMAGE_ACCEPT}
            className="hidden"
            onChange={(event) => chooseFile(event.target.files?.[0], "avatar")}
          />
          <input
            ref={bannerInputRef}
            type="file"
            accept={IMAGE_ACCEPT}
            className="hidden"
            onChange={(event) => chooseFile(event.target.files?.[0], "banner")}
          />

          <div className="mt-6 flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button
              type="button"
              disabled={(!avatarFile && !bannerFile) || saving}
              onClick={() => void save()}
            >
              {saving && <Loader2 className="size-4 animate-spin" />}
              Save changes
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
