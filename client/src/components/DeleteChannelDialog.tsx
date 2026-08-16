import { useState } from "react";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { deleteChannel } from "@/api/endpoints";
import { ApiError, type Channel } from "@/lib/types";
import { toast } from "sonner";

interface DeleteChannelDialogProps {
  channel: Channel;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function DeleteChannelDialog({ channel, open, onOpenChange }: DeleteChannelDialogProps) {
  const [loading, setLoading] = useState(false);

  const handleDelete = async () => {
    setLoading(true);
    try {
      await deleteChannel(channel.id);
      onOpenChange(false);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to delete channel.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete channel</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-muted-foreground">
          <span className="font-semibold text-foreground">#{channel.name}</span> and every message
          in it will be gone for everyone. This can't be undone.
        </p>
        <DialogFooter>
          <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button type="button" variant="destructive" disabled={loading} onClick={() => void handleDelete()}>
            Delete channel
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
