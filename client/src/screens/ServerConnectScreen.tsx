import { useState } from "react";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AuthShell } from "@/components/AuthShell";
import { useSettingsStore } from "@/state/settings";
import { toast } from "sonner";

function normalizeServerUrl(url: string): string {
  const trimmed = url.trim().replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(trimmed)) return `https://${trimmed}`;
  return trimmed;
}

export function ServerConnectScreen() {
  const setServerUrl = useSettingsStore((s) => s.setServerUrl);
  const [url, setUrl] = useState("");
  const [checking, setChecking] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!url.trim()) return;
    setChecking(true);
    const normalized = normalizeServerUrl(url);
    try {
      const res = await fetch(`${normalized}/health`);
      if (!res.ok) throw new Error();
      setServerUrl(normalized);
    } catch {
      toast.error("Couldn't connect to that server. Check the address.");
    } finally {
      setChecking(false);
    }
  };

  return (
    <AuthShell
      title="Connect to a server"
      description="Enter the address of the self-hosted Campfire server you want to connect to."
    >
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="server-url">Server address</Label>
          <Input
            id="server-url"
            placeholder="campfire.mydomain.com"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            autoFocus
          />
        </div>

        <Button type="submit" className="w-full" disabled={checking || !url.trim()}>
          {checking && <Loader2 className="size-4 animate-spin" />}
          Connect
        </Button>
      </form>
    </AuthShell>
  );
}
