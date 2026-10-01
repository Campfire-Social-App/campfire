import { isTauri } from "@tauri-apps/api/core";
import { sendAudioEvents } from "@/api/endpoints";
import type { AudioEventPayload } from "@/lib/types";

/** Reports mic/device lifecycle events to POST /api/diagnostics/audio-events,
 * so production bugs ("mutes itself", device switches) leave a trail in
 * Postgres instead of only in a console nobody is watching. Batched and
 * best-effort: a failed flush is never worth surfacing to the user, and never
 * worth losing — it is retried on the next tick. */

const MAX_QUEUE = 200;
const FLUSH_INTERVAL_MS = 3000;
const FLUSH_AT_SIZE = 20;

let sessionId: string | null = null;
let currentChannelId: string | null = null;
let queue: AudioEventPayload[] = [];
let flushing = false;
let timer: ReturnType<typeof setInterval> | null = null;

function platform(): string {
  return isTauri() ? "tauri" : "web";
}

function ensureTimer(): void {
  if (timer) return;
  timer = setInterval(() => void flush(), FLUSH_INTERVAL_MS);
}

/** Call once per join attempt — every event logged until the matching
 * endAudioDiagnosticsSession() carries this id, so the whole attempt can be
 * pulled with a single WHERE session_id = ... */
export function startAudioDiagnosticsSession(channelId: string): void {
  sessionId = crypto.randomUUID();
  currentChannelId = channelId;
  ensureTimer();
}

export function endAudioDiagnosticsSession(): void {
  void flush();
  sessionId = null;
  currentChannelId = null;
}

export function logAudioEvent(eventType: string, detail: Record<string, unknown> = {}): void {
  queue.push({
    platform: platform(),
    event_type: eventType,
    channel_id: currentChannelId,
    session_id: sessionId,
    client_ts: new Date().toISOString(),
    detail,
  });
  if (queue.length > MAX_QUEUE) queue.splice(0, queue.length - MAX_QUEUE);
  if (queue.length >= FLUSH_AT_SIZE) void flush();
  else ensureTimer();
}

async function flush(): Promise<void> {
  if (flushing || queue.length === 0) return;
  flushing = true;
  const batch = queue;
  queue = [];
  try {
    await sendAudioEvents(batch);
  } catch {
    // The server (or network) is unreachable — keep the batch for the next
    // tick rather than dropping it, capped so an outage can't grow this
    // without bound.
    queue = [...batch, ...queue].slice(-MAX_QUEUE);
  } finally {
    flushing = false;
  }
}
