import { useEffect, useRef, useState } from "react";
import { Camera, Loader2 } from "lucide-react";
import { uploadAttachment, updateMyAvatar } from "@/api/endpoints";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { UserAvatar } from "@/components/UserAvatar";
import { ApiError } from "@/lib/types";
import { useAuthStore } from "@/state/auth";
import { useUsersStore } from "@/state/users";
import { toast } from "sonner";

const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

export function ProfileDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const user = useAuthStore((state) => state.user);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  if (!user) return null;

  const chooseFile = (selected: File | undefined) => {
    if (!selected) return;
    if (!selected.type.startsWith("image/") || selected.type === "image/svg+xml") {
      toast.error("Choose a PNG, JPG, WebP, AVIF or GIF image.");
      return;
    }
    if (selected.size > MAX_AVATAR_BYTES) {
      toast.error("Profile images can be at most 5 MB.");
      return;
    }
    setFile(selected);
  };

  const save = async () => {
    if (!file) return;
    setSaving(true);
    try {
      const attachment = await uploadAttachment(file);
      const updated = await updateMyAvatar(attachment.id);
      useAuthStore.getState().setUser(updated);
      useUsersStore.getState().upsertUser(updated);
      setFile(null);
      onOpenChange(false);
      toast.success("Profile photo updated.");
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't update profile photo.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Profile</DialogTitle>
        </DialogHeader>
        <div className="flex flex-col items-center gap-4 py-2">
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            className="group relative rounded-full"
            aria-label="Change profile photo"
          >
            {previewUrl ? (
              <img
                src={previewUrl}
                alt="New profile preview"
                className="size-24 rounded-full object-cover ring-2 ring-border"
              />
            ) : (
              <UserAvatar username={user.username} size="lg" className="size-24 *:text-2xl" />
            )}
            <span className="absolute inset-0 flex items-center justify-center rounded-full bg-black/55 text-white opacity-0 transition-opacity group-hover:opacity-100">
              <Camera className="size-6" />
            </span>
          </button>
          <div className="text-center">
            <p className="font-heading text-base font-semibold">{user.username}</p>
            <p className="text-xs text-muted-foreground">PNG, JPG, WebP, AVIF or GIF · max 5 MB</p>
          </div>
          <input
            ref={inputRef}
            type="file"
            accept="image/png,image/jpeg,image/gif,image/webp,image/avif"
            className="hidden"
            onChange={(event) => chooseFile(event.target.files?.[0])}
          />
          <div className="flex w-full gap-2">
            <Button type="button" variant="outline" className="flex-1" onClick={() => inputRef.current?.click()}>
              Choose photo
            </Button>
            <Button type="button" className="flex-1" disabled={!file || saving} onClick={() => void save()}>
              {saving && <Loader2 className="size-4 animate-spin" />}
              Save
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
