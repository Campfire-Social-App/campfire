import { Flame } from "lucide-react";

interface AuthShellProps {
  title: string;
  description: string;
  children: React.ReactNode;
}

/** Shared full-bleed starfield backdrop + glowing campfire badge for the
 * connect/login/register screens. */
export function AuthShell({ title, description, children }: AuthShellProps) {
  return (
    <div className="bg-starfield flex h-full w-full items-center justify-center p-4">
      <div className="isolate w-full max-w-sm space-y-6 overflow-hidden rounded-2xl border border-border bg-card/90 p-8 shadow-2xl shadow-black/50 backdrop-blur-sm">
        <div className="flex flex-col items-center gap-3 text-center">
          <div className="flex size-16 items-center justify-center rounded-2xl bg-linear-to-br from-amber-400 via-orange-500 to-red-600 shadow-[0_0_45px_8px_rgba(255,122,61,0.35)]">
            <Flame className="size-8 text-white drop-shadow-sm" />
          </div>
          <h1 className="font-heading text-lg font-semibold text-foreground">{title}</h1>
          <p className="text-sm text-muted-foreground">{description}</p>
        </div>

        {children}
      </div>
    </div>
  );
}
