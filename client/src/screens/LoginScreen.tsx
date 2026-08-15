import { useState } from "react";
import { Flame, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { ApiError } from "@/lib/types";
import { toast } from "sonner";

interface LoginScreenProps {
  onSwitchToRegister: () => void;
}

export function LoginScreen({ onSwitchToRegister }: LoginScreenProps) {
  const login = useAuthStore((s) => s.login);
  const serverUrl = useSettingsStore((s) => s.serverUrl);
  const clearServerUrl = useSettingsStore((s) => s.clearServerUrl);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(username, password);
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "Falha ao entrar.";
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex h-screen w-screen items-center justify-center bg-background">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-6 rounded-lg border border-border bg-card p-8 shadow-lg">
        <div className="flex flex-col items-center gap-2 text-center">
          <div className="flex size-14 items-center justify-center rounded-2xl bg-primary text-primary-foreground">
            <Flame className="size-7" />
          </div>
          <h1 className="text-xl font-semibold text-foreground">Bem-vindo de volta</h1>
          <p className="text-sm text-muted-foreground break-all">{serverUrl}</p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="username">Usuário</Label>
          <Input id="username" value={username} onChange={(e) => setUsername(e.target.value)} autoFocus />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Senha</Label>
          <Input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>

        <Button type="submit" className="w-full" disabled={loading || !username || !password}>
          {loading && <Loader2 className="size-4 animate-spin" />}
          Entrar
        </Button>

        <div className="flex flex-col items-center gap-1 text-sm">
          <button
            type="button"
            onClick={onSwitchToRegister}
            className="text-primary hover:underline"
          >
            Tenho um convite — criar conta
          </button>
          <button
            type="button"
            onClick={clearServerUrl}
            className="text-muted-foreground hover:underline"
          >
            Trocar de servidor
          </button>
        </div>
      </form>
    </div>
  );
}
