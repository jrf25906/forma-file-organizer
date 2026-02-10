"use client";

export type SoundType =
  | "organize" // Hero file cards organize -- ascending chime sequence
  | "transition" // Feature transition -- subtle whoosh
  | "snap" // Before/After morph -- satisfying click/snap
  | "reveal" // $29 number arrives -- single clear tone
  | "tick"; // CTA button hover -- micro-tick

class SoundEngine {
  private enabled: boolean = false;
  private audioContext: AudioContext | null = null;
  private volume: number = 0.15;

  constructor() {
    // Load preference from localStorage
    if (typeof window !== "undefined") {
      this.enabled = localStorage.getItem("forma-sound") === "true";
    }
  }

  private getContext(): AudioContext | null {
    if (!this.audioContext && typeof window !== "undefined") {
      try {
        this.audioContext = new AudioContext();
      } catch {
        return null;
      }
    }
    return this.audioContext;
  }

  get isEnabled(): boolean {
    return this.enabled;
  }

  toggle(): boolean {
    this.enabled = !this.enabled;
    if (typeof window !== "undefined") {
      localStorage.setItem("forma-sound", String(this.enabled));
    }
    // Initialize AudioContext on first enable (requires user interaction)
    if (this.enabled) {
      const ctx = this.getContext();
      if (ctx?.state === "suspended") {
        ctx.resume();
      }
    }
    return this.enabled;
  }

  play(sound: SoundType): void {
    if (!this.enabled) return;
    const ctx = this.getContext();
    if (!ctx || ctx.state !== "running") return;

    switch (sound) {
      case "organize":
        this.playOrganize(ctx);
        break;
      case "transition":
        this.playTransition(ctx);
        break;
      case "snap":
        this.playSnap(ctx);
        break;
      case "reveal":
        this.playReveal(ctx);
        break;
      case "tick":
        this.playTick(ctx);
        break;
    }
  }

  private playOrganize(ctx: AudioContext) {
    // Ascending chime sequence -- 3 quick tones (C5, E5, G5)
    const notes = [523.25, 659.25, 783.99];
    const now = ctx.currentTime;

    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(this.volume * 0.6, now + i * 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.1 + 0.3);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + i * 0.1);
      osc.stop(now + i * 0.1 + 0.35);
    });
  }

  private playTransition(ctx: AudioContext) {
    // Subtle whoosh -- filtered noise
    const now = ctx.currentTime;
    const bufferSize = ctx.sampleRate * 0.15;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);
    }
    const source = ctx.createBufferSource();
    source.buffer = buffer;

    const filter = ctx.createBiquadFilter();
    filter.type = "bandpass";
    filter.frequency.value = 2000;
    filter.Q.value = 0.5;

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(this.volume * 0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

    source.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    source.start(now);
  }

  private playSnap(ctx: AudioContext) {
    // Satisfying click -- short sine burst with downward sweep
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(800, now);
    osc.frequency.exponentialRampToValueAtTime(400, now + 0.05);
    gain.gain.setValueAtTime(this.volume * 0.7, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.1);
  }

  private playReveal(ctx: AudioContext) {
    // Single clear tone -- confident bell-like A5
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = 880;
    gain.gain.setValueAtTime(this.volume * 0.5, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.65);
  }

  private playTick(ctx: AudioContext) {
    // Micro-tick -- barely audible click
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = 1200;
    gain.gain.setValueAtTime(this.volume * 0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.03);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.04);
  }
}

// Lazy singleton — avoids instantiation during SSR (no window/localStorage)
let _instance: SoundEngine | null = null;

export function getSoundEngine(): SoundEngine {
  if (!_instance) {
    _instance = new SoundEngine();
  }
  return _instance;
}

// Backwards-compatible named export (getter-based, still lazy)
export const soundEngine: SoundEngine = new Proxy({} as SoundEngine, {
  get(_target, prop) {
    const engine = getSoundEngine();
    const value = (engine as unknown as Record<string | symbol, unknown>)[prop];
    return typeof value === "function" ? value.bind(engine) : value;
  },
});
