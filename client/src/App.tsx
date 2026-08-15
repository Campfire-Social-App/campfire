import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { TitleBar } from "@/components/TitleBar";
import { useHydration } from "@/lib/useHydration";
import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { ServerConnectScreen } from "@/screens/ServerConnectScreen";
import { LoginScreen } from "@/screens/LoginScreen";
import { RegisterWithInviteScreen } from "@/screens/RegisterWithInviteScreen";
import { ServerShell } from "@/screens/ServerShell";

function Splash() {
  return (
    <div className="flex h-full w-full items-center justify-center bg-background">
      <Loader2 className="size-6 animate-spin text-muted-foreground" />
    </div>
  );
}

function AuthGate() {
  const [mode, setMode] = useState<"login" | "register">("login");
  return mode === "login" ? (
    <LoginScreen onSwitchToRegister={() => setMode("register")} />
  ) : (
    <RegisterWithInviteScreen onSwitchToLogin={() => setMode("login")} />
  );
}

function App() {
  const hydrated = useHydration();
  const serverUrl = useSettingsStore((s) => s.serverUrl);
  const authStatus = useAuthStore((s) => s.status);
  const restoreSession = useAuthStore((s) => s.restoreSession);

  useEffect(() => {
    if (hydrated && authStatus === "idle") {
      void restoreSession();
    }
  }, [hydrated, authStatus, restoreSession]);

  let content: React.ReactNode;
  if (!hydrated || authStatus === "idle" || authStatus === "restoring") {
    content = <Splash />;
  } else if (!serverUrl) {
    content = <ServerConnectScreen />;
  } else if (authStatus !== "authenticated") {
    content = <AuthGate />;
  } else {
    content = <ServerShell />;
  }

  return (
    <TooltipProvider delayDuration={300}>
      <div className="flex h-screen w-screen flex-col overflow-hidden bg-background">
        <TitleBar />
        <div className="min-h-0 flex-1">{content}</div>
      </div>
      <Toaster theme="dark" position="bottom-right" />
    </TooltipProvider>
  );
}

export default App;
