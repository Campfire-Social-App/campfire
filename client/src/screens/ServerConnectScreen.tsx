import { useState } from "react";
import { Flame, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
      toast.error("Não foi possível conectar a esse servidor. Confira o endereço.");
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="flex h-screen w-screen items-center justify-center bg-background">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-6 rounded-lg border border-border bg-card p-8 shadow-lg">
        <div className="flex flex-col items-center gap-2 text-center">
          <div className="flex size-14 items-center justify-center rounded-2xl bg-primary text-primary-foreground">
            <Flame className="size-7" />
          </div>
          <h1 className="text-xl font-semibold text-foreground">Conectar ao servidor</h1>
          <p className="text-sm text-muted-foreground">
            Digite o endereço do servidor Campfire auto-hospedado ao qual você quer se conectar.
          </p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="server-url">Endereço do servidor</Label>
          <Input
            id="server-url"
            placeholder="campfire.meudominio.com"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            autoFocus
          />
        </div>

        <Button type="submit" className="w-full" disabled={checking || !url.trim()}>
          {checking && <Loader2 className="size-4 animate-spin" />}
          Conectar
        </Button>
      </form>
    </div>
  );
}
