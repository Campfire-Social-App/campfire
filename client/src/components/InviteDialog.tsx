import { useEffect, useState } from "react";
import { Copy, Loader2 } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createInvite } from "@/api/endpoints";
import { ApiError } from "@/lib/types";
import { toast } from "sonner";

interface InviteDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function InviteDialog({ open, onOpenChange }: InviteDialogProps) {
  const [code, setCode] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open || code) return;
    setLoading(true);
    createInvite()
      .then((invite) => setCode(invite.code))
      .catch((err) => {
        toast.error(err instanceof ApiError ? err.message : "Failed to generate invite.");
        onOpenChange(false);
      })
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const copy = () => {
    if (!code) return;
    void navigator.clipboard.writeText(code);
    toast.success("Code copied.");
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Invite someone</DialogTitle>
        </DialogHeader>
        {loading ? (
          <div className="flex justify-center py-6">
            <Loader2 className="size-5 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <div className="space-y-2">
            <p className="text-sm text-muted-foreground">
              Share this code. Whoever receives it can create an account on this server.
            </p>
            <div className="flex gap-2">
              <Input readOnly value={code ?? ""} className="font-mono" />
              <Button type="button" size="icon" onClick={copy}>
                <Copy className="size-4" />
              </Button>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
