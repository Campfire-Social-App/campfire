import { useEffect } from "react";
import { Phone, PhoneOff, Video } from "lucide-react";
import { UserAvatar } from "@/components/UserAvatar";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useCallsStore } from "@/state/calls";
import { useDmsStore } from "@/state/dms";
import { acceptCall, declineCall, hangUp } from "@/lib/calls";
import { startIncomingRing, startOutgoingRing, stopRinging } from "@/lib/ringtone";
import { ApiError } from "@/lib/types";
import { toast } from "sonner";

/** How long a call rings before giving up on its own. Without it, an unanswered
 * call rings until someone closes the app. */
const RING_TIMEOUT_MS = 45_000;

/** Everything about a call that has to outlive the conversation being on screen:
 * the ring tones, the give-up timers, and the incoming-call card. Mounted once,
 * app-wide — a call can arrive while you're anywhere. */
export function CallCenter() {
  const incoming = useCallsStore((s) => s.incoming);
  const outgoing = useCallsStore((s) => s.outgoing);
  const incomingId = incoming?.channelId ?? null;

  useEffect(() => {
    if (incomingId) startIncomingRing();
    else if (outgoing) startOutgoingRing();
    else stopRinging();
    return stopRinging;
  }, [incomingId, outgoing]);

  useEffect(() => {
    if (!incomingId) return;
    const timer = window.setTimeout(() => {
      void declineCall(incomingId).catch(() => {});
    }, RING_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, [incomingId]);

  useEffect(() => {
    if (!outgoing) return;
    const timer = window.setTimeout(() => {
      toast("No answer.");
      void hangUp(outgoing).catch(() => {});
    }, RING_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, [outgoing]);

  if (!incoming) return null;

  const handleAccept = async (video: boolean) => {
    try {
      await acceptCall(incoming.channelId, { video });
      // Answering should land you in the conversation — it may be one the callee
      // has never opened, which the ring itself put in their rail.
      useDmsStore.getState().selectDm(incoming.channelId);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Couldn't join the call.");
    }
  };

  return (
    // Deliberately not a modal: an unwanted call shouldn't take the app hostage,
    // so this floats over the corner and leaves everything else usable.
    <div className="fixed right-5 bottom-5 z-50 w-72 rounded-2xl border border-glass-border bg-glass p-4 shadow-2xl backdrop-blur-xl">
      <div className="flex items-center gap-3">
        <UserAvatar username={incoming.from.username} size="lg" className="size-12 *:text-lg" />
        <div className="min-w-0">
          <p className="truncate font-heading text-sm font-semibold text-foreground">
            {incoming.from.username}
          </p>
          <p className="text-xs text-muted-foreground">Incoming call…</p>
        </div>
      </div>

      <div className="mt-4 flex items-center gap-2">
        <Button
          onClick={() => void handleAccept(false)}
          className="flex-1 bg-online text-white hover:bg-online/90"
        >
          <Phone className="size-4" /> Accept
        </Button>

        <Tooltip>
          <TooltipTrigger asChild>
            <button
              onClick={() => void handleAccept(true)}
              className="flex size-9 items-center justify-center rounded-md bg-white/5 text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground"
            >
              <Video className="size-4" />
            </button>
          </TooltipTrigger>
          <TooltipContent>Accept with video</TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <button
              onClick={() => void declineCall(incoming.channelId).catch(() => {})}
              className="flex size-9 items-center justify-center rounded-md bg-destructive/90 text-white transition-colors hover:bg-destructive"
            >
              <PhoneOff className="size-4" />
            </button>
          </TooltipTrigger>
          <TooltipContent>Decline</TooltipContent>
        </Tooltip>
      </div>
    </div>
  );
}
