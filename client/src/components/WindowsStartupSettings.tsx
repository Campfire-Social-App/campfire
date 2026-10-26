import { useEffect, useRef, useState } from "react";
import { invoke, isTauri } from "@tauri-apps/api/core";
import { toast } from "sonner";

export function WindowsStartupSettings({ open }: { open: boolean }) {
  const supported = isTauri() && navigator.userAgent.includes("Windows");
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [readError, setReadError] = useState(false);
  const pending = useRef(false);
  const writeInFlight = useRef<Promise<boolean> | null>(null);
  const generation = useRef(0);

  useEffect(() => {
    if (!open || !supported) return;
    const current = ++generation.current;
    const refresh = async () => {
      if (pending.current) return;
      pending.current = true;
      setBusy(true);
      try {
        // A write can outlive closing the dialog. Read after it completes so
        // reopening never displays the registration from before that write.
        await writeInFlight.current?.catch(() => {});
        const value = await invoke<boolean>("get_startup_enabled");
        if (generation.current === current) {
          setEnabled(value);
          setReadError(false);
        }
      } catch {
        if (generation.current === current) {
          setEnabled(null);
          setReadError(true);
          toast.error("Couldn't read Windows startup settings.");
        }
      } finally {
        if (generation.current === current) {
          pending.current = false;
          setBusy(false);
        }
      }
    };
    void refresh();
    window.addEventListener("focus", refresh);
    return () => {
      generation.current++;
      pending.current = false;
      window.removeEventListener("focus", refresh);
    };
  }, [open, supported]);

  const toggle = async () => {
    if (pending.current || enabled === null) return;
    const current = generation.current;
    pending.current = true;
    setBusy(true);
    const write = invoke<boolean>("set_startup_enabled", { enabled: !enabled });
    writeInFlight.current = write;
    try {
      const value = await write;
      if (generation.current === current) setEnabled(value);
    } catch {
      if (generation.current === current) toast.error("Couldn't change Windows startup settings.");
    } finally {
      if (writeInFlight.current === write) writeInFlight.current = null;
      if (generation.current === current) {
        pending.current = false;
        setBusy(false);
      }
    }
  };

  if (!supported) return null;
  return <section className="space-y-3">
    <h3 className="text-sm font-semibold">Windows</h3>
    <div className="flex items-start justify-between gap-4">
      <div className="space-y-1">
        <label htmlFor="windows-startup" className="text-sm font-medium">Start Campfire with Windows</label>
        <p id="windows-startup-help" className="text-xs text-muted-foreground">Open the Campfire window when you sign in to Windows. Changes apply immediately.</p>
      </div>
      <button id="windows-startup" type="button" role="switch" aria-checked={enabled ?? false}
        aria-describedby="windows-startup-help windows-startup-note" aria-busy={busy}
        disabled={busy || enabled === null} onClick={() => void toggle()}
        className={`inline-flex h-6 w-11 shrink-0 items-center rounded-full p-0.5 transition-colors focus-visible:outline-2 focus-visible:outline-ring disabled:opacity-50 ${enabled ? "bg-primary" : "bg-muted"}`}>
        <span className={`size-5 rounded-full bg-white shadow transition-transform ${enabled ? "translate-x-5" : "translate-x-0"}`} />
      </button>
    </div>
    {readError && <p role="alert" className="text-xs text-destructive">Startup settings are unavailable. Reopen settings or return to this window to retry.</p>}
    <p id="windows-startup-note" className="text-xs text-muted-foreground">This switch controls Campfire’s startup registration for your Windows user. Windows can still block startup in Settings → Apps → Startup.</p>
  </section>;
}
