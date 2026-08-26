import {
  Track,
  type AudioProcessorOptions,
  type TrackProcessor,
} from "livekit-client";

export type NoiseGateMode = "off" | "standard" | "strong";

interface NoiseGatePreset {
  openDb: number;
  closeDb: number;
  noiseMarginDb: number;
  calibrationMs: number;
  immediateOpenDb: number;
  highpassHz: number;
  lowpassHz: number;
  holdMs: number;
  attackSeconds: number;
  releaseSeconds: number;
}

const PRESETS: Record<Exclude<NoiseGateMode, "off">, NoiseGatePreset> = {
  standard: {
    openDb: -48,
    closeDb: -54,
    noiseMarginDb: 10,
    calibrationMs: 0,
    immediateOpenDb: -24,
    highpassHz: 80,
    lowpassHz: 9000,
    holdMs: 180,
    attackSeconds: 0.004,
    releaseSeconds: 0.12,
  },
  strong: {
    // With AGC disabled (see voice.ts), a close microphone normally clears
    // this threshold while a TV or another speaker across the room does not.
    openDb: -34,
    closeDb: -42,
    noiseMarginDb: 12,
    calibrationMs: 350,
    immediateOpenDb: -25,
    highpassHz: 120,
    lowpassHz: 7500,
    holdMs: 140,
    attackSeconds: 0.003,
    releaseSeconds: 0.08,
  },
};

/**
 * Low-latency adaptive microphone gate for LiveKit.
 *
 * The analyser follows the room noise while the gate is closed. Speech must
 * clear both the preset threshold and that moving floor plus a safety margin.
 * A short delay preserves the first consonant while the detector opens, and
 * hysteresis/hold keep natural pauses from chopping the end of words.
 */
export class NoiseGateProcessor
  implements TrackProcessor<Track.Kind.Audio, AudioProcessorOptions>
{
  readonly name: string;
  readonly mode: Exclude<NoiseGateMode, "off">;
  processedTrack?: MediaStreamTrack;

  private source?: MediaStreamAudioSourceNode;
  private highpass?: BiquadFilterNode;
  private lowpass?: BiquadFilterNode;
  private analyser?: AnalyserNode;
  private delay?: DelayNode;
  private gain?: GainNode;
  private destination?: MediaStreamAudioDestinationNode;
  private timer?: number;
  private samples?: Float32Array<ArrayBuffer>;
  private noiseFloorDb = -70;
  private calibrationUntil = 0;
  private open = false;
  private lastVoiceAt = 0;

  constructor(mode: Exclude<NoiseGateMode, "off">) {
    this.mode = mode;
    this.name = `campfire-noise-gate-${mode}`;
  }

  async init(options: AudioProcessorOptions): Promise<void> {
    this.setup(options);
  }

  async restart(options: AudioProcessorOptions): Promise<void> {
    this.teardown(true);
    this.setup(options);
  }

  async destroy(): Promise<void> {
    this.teardown(false);
  }

  private setup({ audioContext, track }: AudioProcessorOptions): void {
    const preset = PRESETS[this.mode];
    const source = audioContext.createMediaStreamSource(new MediaStream([track]));
    const highpass = audioContext.createBiquadFilter();
    const lowpass = audioContext.createBiquadFilter();
    const analyser = audioContext.createAnalyser();
    const delay = audioContext.createDelay(0.05);
    const gain = audioContext.createGain();
    const destination = audioContext.createMediaStreamDestination();

    highpass.type = "highpass";
    highpass.frequency.value = preset.highpassHz;
    highpass.Q.value = 0.7;
    lowpass.type = "lowpass";
    lowpass.frequency.value = preset.lowpassHz;
    lowpass.Q.value = 0.7;
    analyser.fftSize = 1024;
    analyser.smoothingTimeConstant = 0.15;
    // The detector checks one render quantum before the delayed signal reaches
    // the gain node, preserving sharp consonants without perceptible latency.
    delay.delayTime.value = 0.012;
    gain.gain.value = 0;

    source.connect(highpass);
    highpass.connect(lowpass);
    lowpass.connect(analyser);
    analyser.connect(delay);
    delay.connect(gain);
    gain.connect(destination);

    this.source = source;
    this.highpass = highpass;
    this.lowpass = lowpass;
    this.analyser = analyser;
    this.delay = delay;
    this.gain = gain;
    this.destination = destination;
    this.processedTrack = destination.stream.getAudioTracks()[0];
    this.samples = new Float32Array(analyser.fftSize);
    this.noiseFloorDb = -70;
    this.calibrationUntil = performance.now() + preset.calibrationMs;
    this.open = false;
    this.lastVoiceAt = performance.now();

    this.timer = window.setInterval(() => this.measure(audioContext, preset), 8);
  }

  private measure(audioContext: AudioContext, preset: NoiseGatePreset): void {
    if (!this.analyser || !this.gain || !this.samples) return;

    this.analyser.getFloatTimeDomainData(this.samples);
    let energy = 0;
    for (const sample of this.samples) energy += sample * sample;
    const rms = Math.sqrt(energy / this.samples.length);
    const levelDb = 20 * Math.log10(Math.max(rms, 1e-7));
    const now = performance.now();

    // Strong mode first samples the room with the output closed. Without this,
    // a television already playing when capture starts immediately opens the
    // gate and is then mistaken for foreground speech indefinitely.
    if (now < this.calibrationUntil) {
      // Do not sacrifice the first word: a close voice is considerably louder
      // than the background levels this calibration is intended to learn.
      if (levelDb >= preset.immediateOpenDb) {
        this.calibrationUntil = 0;
        this.open = true;
        this.lastVoiceAt = now;
        this.setGain(audioContext, 1, preset.attackSeconds);
        return;
      }
      this.noiseFloorDb =
        this.noiseFloorDb === -70
          ? levelDb
          : this.noiseFloorDb * 0.85 + levelDb * 0.15;
      return;
    }

    if (!this.open) {
      // Learn slowly only from levels that still resemble background noise.
      // This prevents a keyboard burst from becoming the new baseline.
      if (levelDb < this.noiseFloorDb + preset.noiseMarginDb + 3) {
        this.noiseFloorDb = this.noiseFloorDb * 0.97 + levelDb * 0.03;
      }
      const adaptiveOpenDb = Math.max(
        preset.openDb,
        this.noiseFloorDb + preset.noiseMarginDb,
      );
      if (levelDb >= adaptiveOpenDb) {
        this.open = true;
        this.lastVoiceAt = now;
        this.setGain(audioContext, 1, preset.attackSeconds);
      }
      return;
    }

    const adaptiveCloseDb = Math.max(
      preset.closeDb,
      this.noiseFloorDb + preset.noiseMarginDb - 6,
    );
    if (levelDb >= adaptiveCloseDb) {
      this.lastVoiceAt = now;
    } else if (now - this.lastVoiceAt >= preset.holdMs) {
      this.open = false;
      this.setGain(audioContext, 0, preset.releaseSeconds);
    }
  }

  private setGain(audioContext: AudioContext, value: number, time: number): void {
    if (!this.gain) return;
    const parameter = this.gain.gain;
    const now = audioContext.currentTime;
    parameter.cancelAndHoldAtTime(now);
    parameter.linearRampToValueAtTime(value, now + time);
  }

  private teardown(stopTrack: boolean): void {
    if (this.timer !== undefined) window.clearInterval(this.timer);
    if (stopTrack) this.processedTrack?.stop();
    this.source?.disconnect();
    this.highpass?.disconnect();
    this.lowpass?.disconnect();
    this.analyser?.disconnect();
    this.delay?.disconnect();
    this.gain?.disconnect();
    this.destination?.disconnect();
    this.source = undefined;
    this.highpass = undefined;
    this.lowpass = undefined;
    this.analyser = undefined;
    this.delay = undefined;
    this.gain = undefined;
    this.destination = undefined;
    this.processedTrack = undefined;
    this.samples = undefined;
    this.timer = undefined;
  }
}
