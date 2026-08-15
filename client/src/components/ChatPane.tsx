import { Fragment, useEffect, useLayoutEffect, useRef, useState } from "react";
import { isSameDay } from "date-fns";
import { useMessagesStore } from "@/state/messages";
import { MessageItem } from "@/components/MessageItem";
import { MessageComposer } from "@/components/MessageComposer";
import { TypingIndicator } from "@/components/TypingIndicator";
import { DateSeparator } from "@/components/DateSeparator";
import type { Message } from "@/lib/types";

const GROUPING_WINDOW_MS = 5 * 60 * 1000;
const LOAD_MORE_THRESHOLD_PX = 150;

interface ChatPaneProps {
  /** Channel id to read and post in — a text channel or a DM conversation. */
  channelId: string;
  header: React.ReactNode;
  /** Optional strip between the header and the history — the DM call stage. */
  banner?: React.ReactNode;
  /** Shown in place of the message list before anything has been said. */
  empty: React.ReactNode;
  composerPlaceholder: string;
}

/** The conversation surface itself: history, pagination, scroll anchoring,
 * reply state and the composer. Text channels and DMs differ only in their
 * header and empty state, so both drive this. */
export function ChatPane({
  channelId,
  header,
  banner,
  empty,
  composerPlaceholder,
}: ChatPaneProps) {
  const channelData = useMessagesStore((s) => s.byChannel[channelId]);
  const loadInitial = useMessagesStore((s) => s.loadInitial);
  const loadMore = useMessagesStore((s) => s.loadMore);

  const scrollRef = useRef<HTMLDivElement>(null);
  const prevScrollHeight = useRef(0);
  const prevMessageCount = useRef(0);
  const stickToBottom = useRef(true);
  const [replyingTo, setReplyingTo] = useState<Message | null>(null);

  useEffect(() => {
    void loadInitial(channelId);
  }, [channelId, loadInitial]);

  useEffect(() => {
    setReplyingTo(null);
  }, [channelId]);

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
      void loadMore(channelId);
    }
  };

  return (
    <div className="flex min-w-0 flex-1 flex-col">
      {header}
      {banner}

      <div ref={scrollRef} onScroll={handleScroll} className="flex-1 overflow-y-auto pb-2">
        {channelData?.loading && messages.length === 0 ? (
          <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
            Loading messages…
          </div>
        ) : messages.length === 0 ? (
          empty
        ) : (
          messages.map((message, i) => {
            const prev = messages[i - 1];
            const prevDate = prev ? new Date(prev.created_at) : null;
            const messageDate = new Date(message.created_at);
            const isNewDay = !prevDate || !isSameDay(prevDate, messageDate);
            const showHeader =
              !prev || prev.author.id !== message.author.id || isNewDay ||
              messageDate.getTime() - (prevDate as Date).getTime() > GROUPING_WINDOW_MS ||
              // A reply always gets its own header — the quoted line needs
              // an avatar to anchor to, even mid-run from the same author.
              !!message.reply_to;
            return (
              <Fragment key={message.id}>
                {isNewDay && <DateSeparator date={messageDate} />}
                <MessageItem message={message} showHeader={showHeader} onReply={setReplyingTo} />
              </Fragment>
            );
          })
        )}
      </div>

      <TypingIndicator channelId={channelId} />
      <MessageComposer
        channelId={channelId}
        placeholder={composerPlaceholder}
        replyingTo={replyingTo}
        onCancelReply={() => setReplyingTo(null)}
        onSent={() => {
          // Sending your own message is a deliberate action — pull the view
          // back to the bottom even if you'd scrolled up (e.g. to find a
          // message to reply to), rather than leaving it to arrive off-screen
          // the way an incoming message from someone else would.
          stickToBottom.current = true;
        }}
      />
    </div>
  );
}
