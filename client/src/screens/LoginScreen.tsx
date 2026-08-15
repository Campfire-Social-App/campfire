import { useState } from "react";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AuthShell } from "@/components/AuthShell";
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
      const message = err instanceof ApiError ? err.message : "Failed to sign in.";
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell title="Welcome back" description={serverUrl ?? ""}>
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="username">Username</Label>
          <Input id="username" value={username} onChange={(e) => setUsername(e.target.value)} autoFocus />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>

        <Button type="submit" className="w-full" disabled={loading || !username || !password}>
          {loading && <Loader2 className="size-4 animate-spin" />}
          Sign in
        </Button>

        <div className="flex flex-col items-center gap-1 text-sm">
          <button type="button" onClick={onSwitchToRegister} className="text-primary hover:underline">
            I have an invite — create an account
          </button>
          <button type="button" onClick={clearServerUrl} className="text-muted-foreground hover:underline">
            Switch server
          </button>
        </div>
      </form>
    </AuthShell>
  );
}
