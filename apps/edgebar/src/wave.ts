const PHASE_RAD_PER_S = 2.4;
const AMP_EASE_PER_FRAME = 0.15;
const MAX_FRAME_S = 0.05;
const SETTLED_AMP = 0.05;
const SWELL_PX = 8;
const FADE_IN_PX = 3;

export interface Wave {
  amp: number;
  phase: number;
  last: number;
}

export function stepWave(wave: Wave, now: number, moving: boolean, fullAmp: number): void {
  const dt = wave.last ? Math.min(MAX_FRAME_S, (now - wave.last) / 1000) : 0;
  wave.last = now;
  wave.amp += ((moving ? fullAmp : 0) - wave.amp) * AMP_EASE_PER_FRAME;
  if (!moving && wave.amp < SETTLED_AMP) wave.amp = 0;
  if (moving) wave.phase += PHASE_RAD_PER_S * dt;
}

export const swell = (px: number) => Math.min(1, px / SWELL_PX);

export const fadeIn = (px: number) => Math.min(1, px / FADE_IN_PX);
