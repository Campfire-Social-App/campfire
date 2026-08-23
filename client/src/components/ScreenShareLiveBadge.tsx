export function ScreenShareLiveBadge() {
  return (
    <span
      aria-label="Sharing screen live"
      className="inline-flex shrink-0 items-center gap-1 text-[10px] font-bold tracking-wider text-red-400 uppercase"
    >
      <span aria-hidden="true" className="size-1.5 rounded-full bg-red-400" />
      Live
    </span>
  );
}
