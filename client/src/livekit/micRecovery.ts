/** Brings an involuntarily lost microphone back without the user's help.
 *
 * A loose connector makes the OS drop and re-enumerate the device. LiveKit
 * answers the resulting `ended` event with a single restart on the default
 * device and, if that fails (the device is momentarily gone), mutes the track
 * for good — the user sounds muted to everyone until they notice and click.
 *
 * This retries on a backoff while the user still wants to be heard, and
 * `nudge()` retries immediately when the OS reports a device change, which is
 * usually the moment the connector makes contact again. Polling stops after
 * `pollWindowMs`, but nudges keep working until the mic is back or `cancel()`. */
export interface MicRecoveryDeps {
  /** False once the user muted, left, or switched rooms. */
  shouldRecover(): boolean;
  /** One reacquire attempt; resolves true once the mic is live again. */
  attempt(): Promise<boolean>;
  onRecovered(attempts: number): void;
  onPollingExhausted(): void;
}

export interface MicRecovery {
  readonly active: boolean;
  trigger(): void;
  nudge(): void;
  cancel(): void;
}

export function microphoneRecovery(
  deps: MicRecoveryDeps,
  delays: readonly number[] = [250, 750, 1500, 3000],
  pollWindowMs = 120_000,
): MicRecovery {
  let active = false;
  let running = false;
  let rerun = false;
  let attempts = 0;
  let startedAt = 0;
  let exhausted = false;
  let timer: ReturnType<typeof setTimeout> | null = null;

  const clearTimer = () => {
    if (timer) clearTimeout(timer);
    timer = null;
  };

  const stop = () => {
    active = false;
    rerun = false;
    clearTimer();
  };

  const schedule = () => {
    clearTimer();
    if (!active) return;
    const elapsed = Date.now() - startedAt;
    if (elapsed >= pollWindowMs) {
      if (!exhausted) {
        exhausted = true;
        deps.onPollingExhausted();
      }
      return;
    }
    const delay = delays[Math.min(attempts, delays.length - 1)] ?? 3000;
    timer = setTimeout(run, delay);
  };

  const run = async () => {
    timer = null;
    if (!active) return;
    if (!deps.shouldRecover()) return stop();
    if (running) {
      rerun = true;
      return;
    }
    running = true;
    attempts++;
    let recovered = false;
    try {
      recovered = await deps.attempt();
    } catch {
      recovered = false;
    } finally {
      running = false;
    }
    if (!active) return;
    if (recovered) {
      const total = attempts;
      stop();
      deps.onRecovered(total);
      return;
    }
    if (rerun) {
      rerun = false;
      void run();
      return;
    }
    schedule();
  };

  return {
    get active() {
      return active;
    },
    trigger() {
      if (active) return;
      active = true;
      attempts = 0;
      exhausted = false;
      startedAt = Date.now();
      schedule();
    },
    nudge() {
      if (!active) return;
      clearTimer();
      void run();
    },
    cancel: stop,
  };
}
