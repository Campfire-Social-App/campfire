import { Hash } from "lucide-react";
import { ChatPane } from "@/components/ChatPane";
import type { Channel } from "@/lib/types";

interface TextChannelViewProps {
  channel: Channel;
}

export function TextChannelView({ channel }: TextChannelViewProps) {
  return (
    <ChatPane
      channelId={channel.id}
      composerPlaceholder={`Message #${channel.name}`}
      header={
        <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
          <Hash className="size-5 text-muted-foreground" />
          <span className="font-heading text-sm font-semibold text-foreground">{channel.name}</span>
        </header>
      }
      empty={
        <div className="flex h-full flex-col items-center justify-center gap-1 px-8 text-center">
          <Hash className="size-9 text-muted-foreground" />
          <p className="font-heading text-lg font-semibold text-foreground">
            Welcome to #{channel.name}!
          </p>
          <p className="text-sm text-muted-foreground">This is the beginning of the channel.</p>
        </div>
      }
    />
  );
}
