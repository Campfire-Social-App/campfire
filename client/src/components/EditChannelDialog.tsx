import { useEffect, useState } from "react";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { updateChannel } from "@/api/endpoints";
import { ApiError, type Channel } from "@/lib/types";
import { toast } from "sonner";

interface EditChannelDialogProps {
  channel: Channel;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function EditChannelDialog({ channel, open, onOpenChange }: EditChannelDialogProps) {
  const [name, setName] = useState(channel.name);
  const [loading, setLoading] = useState(false);

  // The dialog outlives a rename (and CHANNEL_UPDATE may rename it from under
  // us), so re-seed the field every time it opens.
  useEffect(() => {
    if (open) setName(channel.name);
  }, [open, channel.name]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed || trimmed === channel.name) {
      onOpenChange(false);
      return;
    }
    setLoading(true);
    try {
      await updateChannel(channel.id, trimmed);
      onOpenChange(false);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to rename channel.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Edit channel</DialogTitle>
          </DialogHeader>

          <div className="space-y-2">
            <Label htmlFor="edit-channel-name">Channel name</Label>
            <Input
              id="edit-channel-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={channel.name}
              autoFocus
            />
          </div>

          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={loading || !name.trim()}>
              Save changes
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
