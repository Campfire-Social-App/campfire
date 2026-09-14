import { Volume2 } from "lucide-react";
import { CallStage } from "@/components/CallStage";
import type { Channel } from "@/lib/types";

export function VoiceChannelView({ channel }: { channel: Channel }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col">
      <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
        <Volume2 className="size-5 text-muted-foreground" />
        <span className="font-heading text-sm font-semibold text-foreground">{channel.name}</span>
      </header>
      <CallStage channelId={channel.id} />
    </div>
  );
}
