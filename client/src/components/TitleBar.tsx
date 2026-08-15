import { useEffect, useState } from "react";
import { Copy, Minus, Square, X } from "lucide-react";
import { isTauri } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { cn } from "@/lib/utils";

/**
 * Replaces the OS title bar — disabled via `decorations: false` in
 * tauri.conf.json — with an in-app drag region and window controls. Renders
 * nothing outside the Tauri shell, since `npm run dev` in a plain browser has
 * no native chrome to stand in for.
 */
export function TitleBar() {
  const [maximized, setMaximized] = useState(false);

  useEffect(() => {
    if (!isTauri()) return;
    const win = getCurrentWindow();
    let unlisten: (() => void) | undefined;

    void win.isMaximized().then(setMaximized);
    void win.onResized(() => void win.isMaximized().then(setMaximized)).then((fn) => {
      unlisten = fn;
    });

    return () => unlisten?.();
  }, []);

  if (!isTauri()) return null;

  const win = getCurrentWindow();

  return (
    <div
      data-tauri-drag-region
      className="flex h-9 shrink-0 items-center justify-between border-b border-sidebar-border bg-rail pl-3 select-none"
    >
      <span className="pointer-events-none text-xs font-medium text-muted-foreground">Campfire</span>
      <div className="flex h-full">
        <TitleBarButton onClick={() => void win.minimize()} label="Minimize">
          <Minus className="size-3.5" />
        </TitleBarButton>
        <TitleBarButton onClick={() => void win.toggleMaximize()} label={maximized ? "Restore" : "Maximize"}>
          {maximized ? <Copy className="size-3" /> : <Square className="size-3" />}
        </TitleBarButton>
        <TitleBarButton onClick={() => void win.close()} label="Close" danger>
          <X className="size-3.5" />
        </TitleBarButton>
      </div>
    </div>
  );
}

function TitleBarButton({
  children,
  onClick,
  label,
  danger,
}: {
  children: React.ReactNode;
  onClick: () => void;
  label: string;
  danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      className={cn(
        "flex h-full w-11 items-center justify-center text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground",
        danger && "hover:bg-destructive hover:text-white",
      )}
    >
      {children}
    </button>
  );
}
