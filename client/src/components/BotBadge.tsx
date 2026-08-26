import { cn } from "@/lib/utils";

/** Marks an account driven by the bots service rather than by a person.
 * Same shape as the Admin pill in the member list, so a row reads consistently
 * whichever label it carries. */
export function BotBadge({ className }: { className?: string }) {
  return (
    <span
      title="Conta de bot"
      className={cn(
        "rounded-[4px] bg-primary/15 px-1 py-px text-[9px] font-semibold tracking-wide text-primary uppercase",
        className,
      )}
    >
      Bot
    </span>
  );
}
