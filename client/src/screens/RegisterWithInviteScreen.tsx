import { useState } from "react";
import { Flame, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuthStore } from "@/state/auth";
import { ApiError } from "@/lib/types";
import { toast } from "sonner";

interface RegisterWithInviteScreenProps {
  onSwitchToLogin: () => void;
}

export function RegisterWithInviteScreen({ onSwitchToLogin }: RegisterWithInviteScreenProps) {
  const register = useAuthStore((s) => s.register);
  const [inviteCode, setInviteCode] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await register(inviteCode, username, password);
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "Falha ao criar conta.";
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
          <h1 className="text-xl font-semibold text-foreground">Criar conta</h1>
          <p className="text-sm text-muted-foreground">Você precisa de um convite para entrar.</p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="invite-code">Código de convite</Label>
          <Input
            id="invite-code"
            value={inviteCode}
            onChange={(e) => setInviteCode(e.target.value)}
            autoFocus
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="username">Usuário</Label>
          <Input id="username" value={username} onChange={(e) => setUsername(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Senha</Label>
          <Input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <p className="text-xs text-muted-foreground">Mínimo de 8 caracteres.</p>
        </div>

        <Button
          type="submit"
          className="w-full"
          disabled={loading || !inviteCode || !username || password.length < 8}
        >
          {loading && <Loader2 className="size-4 animate-spin" />}
          Criar conta
        </Button>

        <div className="flex justify-center text-sm">
          <button type="button" onClick={onSwitchToLogin} className="text-primary hover:underline">
            Já tenho uma conta
          </button>
        </div>
      </form>
    </div>
  );
}
