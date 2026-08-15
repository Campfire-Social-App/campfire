import { Fragment, useEffect, useLayoutEffect, useRef } from "react";
import { Hash } from "lucide-react";
import { isSameDay } from "date-fns";
import { useMessagesStore } from "@/state/messages";
import { MessageItem } from "@/components/MessageItem";
import { MessageComposer } from "@/components/MessageComposer";
import { TypingIndicator } from "@/components/TypingIndicator";
import { DateSeparator } from "@/components/DateSeparator";
import type { Channel } from "@/lib/types";

const GROUPING_WINDOW_MS = 5 * 60 * 1000;
const LOAD_MORE_THRESHOLD_PX = 150;

interface TextChannelViewProps {
  channel: Channel;
}

export function TextChannelView({ channel }: TextChannelViewProps) {
  const channelData = useMessagesStore((s) => s.byChannel[channel.id]);
  const loadInitial = useMessagesStore((s) => s.loadInitial);
  const loadMore = useMessagesStore((s) => s.loadMore);

  const scrollRef = useRef<HTMLDivElement>(null);
  const prevScrollHeight = useRef(0);
  const prevMessageCount = useRef(0);
  const stickToBottom = useRef(true);

  useEffect(() => {
    void loadInitial(channel.id);
  }, [channel.id, loadInitial]);

  const messages = channelData?.messages ?? [];

  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el) return;

    if (messages.length > prevMessageCount.current && stickToBottom.current) {
      el.scrollTop = el.scrollHeight;
    } else if (el.scrollHeight !== prevScrollHeight.current && !stickToBottom.current) {
      // Older messages were prepended — keep the viewport anchored.
      el.scrollTop += el.scrollHeight - prevScrollHeight.current;
    }

    prevScrollHeight.current = el.scrollHeight;
    prevMessageCount.current = messages.length;
  }, [messages.length]);

  const handleScroll = () => {
    const el = scrollRef.current;
    if (!el) return;

    stickToBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 80;

    if (el.scrollTop < LOAD_MORE_THRESHOLD_PX) {
      void loadMore(channel.id);
    }
  };

  return (
    <div className="flex min-w-0 flex-1 flex-col">
      <header className="flex h-12 shrink-0 items-center gap-2 border-b border-border px-4 shadow-sm">
        <Hash className="size-5 text-muted-foreground" />
        <span className="font-heading text-sm font-semibold text-foreground">{channel.name}</span>
      </header>

      <div
        ref={scrollRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto pb-2"
      >
        {channelData?.loading && messages.length === 0 ? (
          <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
            Loading messages…
          </div>
        ) : messages.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center gap-1 px-8 text-center">
            <Hash className="size-9 text-muted-foreground" />
            <p className="font-heading text-lg font-semibold text-foreground">Welcome to #{channel.name}!</p>
            <p className="text-sm text-muted-foreground">This is the beginning of the channel.</p>
          </div>
        ) : (
          messages.map((message, i) => {
            const prev = messages[i - 1];
            const prevDate = prev ? new Date(prev.created_at) : null;
            const messageDate = new Date(message.created_at);
            const isNewDay = !prevDate || !isSameDay(prevDate, messageDate);
            const showHeader =
              !prev || prev.author.id !== message.author.id || isNewDay ||
              messageDate.getTime() - (prevDate as Date).getTime() > GROUPING_WINDOW_MS;
            return (
              <Fragment key={message.id}>
                {isNewDay && <DateSeparator date={messageDate} />}
                <MessageItem message={message} showHeader={showHeader} />
              </Fragment>
            );
          })
        )}
      </div>

      <TypingIndicator channelId={channel.id} />
      <MessageComposer channel={channel} />
    </div>
  );
}
