/** Call tones, synthesized rather than shipped as audio files: they have to loop
 * for as long as a call rings, and a couple of oscillators do that without
 * pulling another asset (and another decode) into the bundle. */

const RING_VOLUME = 0.18;

type Tone = { freqs: number[]; duration: number; gap: number; cycle: number };

/** Two-tone chime, twice, then a rest — the "someone is calling you" pattern. */
const INCOMING: Tone = { freqs: [660, 880], duration: 0.32, gap: 0.14, cycle: 2.6 };
/** One low tone per cycle — the caller's own ringback, deliberately duller so the
 * two are never mistaken for each other. */
const OUTGOING: Tone = { freqs: [440], duration: 0.9, gap: 0, cycle: 3.2 };

let context: AudioContext | null = null;
let timer: number | null = null;

function beep(ctx: AudioContext, freq: number, at: number, duration: number): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = "sine";
  osc.frequency.value = freq;
  // Ramped rather than switched: an abrupt gain step clicks audibly.
  gain.gain.setValueAtTime(0, at);
  gain.gain.linearRampToValueAtTime(RING_VOLUME, at + 0.04);
  gain.gain.setValueAtTime(RING_VOLUME, at + duration - 0.06);
  gain.gain.linearRampToValueAtTime(0, at + duration);
  osc.connect(gain).connect(ctx.destination);
  osc.start(at);
  osc.stop(at + duration + 0.02);
}

function startTone(tone: Tone): void {
  stopRinging();
  try {
    context = new AudioContext();
  } catch {
    return; // No audio output available — the on-screen call UI still stands alone.
  }
  const ctx = context;
  // Autoplay policy suspends a context created without a user gesture; the
  // resume is best-effort, and a silent ring is better than a thrown error.
  void ctx.resume().catch(() => {});

  const playCycle = () => {
    let at = ctx.currentTime + 0.05;
    for (const freq of tone.freqs) {
      beep(ctx, freq, at, tone.duration);
      at += tone.duration + tone.gap;
    }
  };

  playCycle();
  timer = window.setInterval(playCycle, tone.cycle * 1000);
}

export function startIncomingRing(): void {
  startTone(INCOMING);
}

export function startOutgoingRing(): void {
  startTone(OUTGOING);
}

export function stopRinging(): void {
  if (timer !== null) window.clearInterval(timer);
  timer = null;
  void context?.close().catch(() => {});
  context = null;
}
