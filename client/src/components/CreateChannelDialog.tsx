import { useState } from "react";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createChannel } from "@/api/endpoints";
import { useChannelsStore } from "@/state/channels";
import { ApiError, type ChannelType } from "@/lib/types";
import { toast } from "sonner";
import { Hash, Volume2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface CreateChannelDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CreateChannelDialog({ open, onOpenChange }: CreateChannelDialogProps) {
  const [name, setName] = useState("");
  const [type, setType] = useState<ChannelType>("text");
  const [loading, setLoading] = useState(false);
  const selectChannel = useChannelsStore((s) => s.selectChannel);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const channel = await createChannel(name.trim(), type);
      selectChannel(channel.id);
      setName("");
      onOpenChange(false);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Failed to create channel.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Create channel</DialogTitle>
          </DialogHeader>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setType("text")}
              className={cn(
                "flex flex-1 items-center gap-2 rounded-md border border-border p-3 text-sm",
                type === "text" && "border-primary bg-primary/10",
              )}
            >
              <Hash className="size-4" /> Text
            </button>
            <button
              type="button"
              onClick={() => setType("voice")}
              className={cn(
                "flex flex-1 items-center gap-2 rounded-md border border-border p-3 text-sm",
                type === "voice" && "border-primary bg-primary/10",
              )}
            >
              <Volume2 className="size-4" /> Voice
            </button>
          </div>

          <div className="space-y-2">
            <Label htmlFor="channel-name">Channel name</Label>
            <Input
              id="channel-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="new-channel"
              autoFocus
            />
          </div>

          <DialogFooter>
            <Button type="submit" disabled={loading || !name.trim()}>
              Create channel
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
