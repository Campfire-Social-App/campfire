import { Flame } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

interface ServerRailProps {
  serverName: string;
}

export function ServerRail({ serverName }: ServerRailProps) {
  return (
    <div className="flex w-18 shrink-0 flex-col items-center gap-2 border-r border-sidebar-border bg-rail py-3">
      <Tooltip>
        <TooltipTrigger asChild>
          <button
            className={cn(
              "flex size-12 items-center justify-center rounded-2xl bg-linear-to-br from-amber-400 via-orange-500 to-red-600 text-white",
              "shadow-[0_0_18px_1px_rgba(255,122,61,0.35)] transition-all hover:rounded-xl hover:shadow-[0_0_26px_3px_rgba(255,122,61,0.5)]",
            )}
          >
            <Flame className="size-6" />
          </button>
        </TooltipTrigger>
        <TooltipContent side="right">{serverName}</TooltipContent>
      </Tooltip>
    </div>
  );
}
