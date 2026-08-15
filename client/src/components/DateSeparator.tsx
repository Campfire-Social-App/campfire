import { format, isSameDay, isYesterday } from "date-fns";

interface DateSeparatorProps {
  date: Date;
}

export function DateSeparator({ date }: DateSeparatorProps) {
  const label = isSameDay(date, new Date())
    ? "Today"
    : isYesterday(date)
      ? "Yesterday"
      : `${format(date, "MMMM d")} · ${format(date, "EEEE")}`;

  return (
    <div className="my-4 flex items-center justify-center">
      <span className="isolate overflow-hidden rounded-full bg-glass px-3 py-1 text-xs font-medium text-muted-foreground backdrop-blur-sm">
        {label}
      </span>
    </div>
  );
}
