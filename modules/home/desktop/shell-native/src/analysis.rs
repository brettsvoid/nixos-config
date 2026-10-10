//! Turns audio samples into bar heights: a Hann-windowed FFT over the latest samples,
//! folded into bands spaced evenly on a log frequency scale, in decibels scaled to 0..1,
//! rising at once and falling back gently.

use rustfft::{num_complex::Complex, Fft, FftPlanner};
use std::sync::Arc;

/// Samples per FFT.
pub const WINDOW: usize = 2048;
/// New samples between FFTs (about 21 ms at 48 kHz).
pub const HOP: usize = 1024;

const LOWEST_HZ: f64 = 40.0;
const HIGHEST_HZ: f64 = 16_000.0;
/// The decibel range drawn, from an empty bar to a full one.
const FLOOR_DB: f64 = -70.0;
const CEILING_DB: f64 = -12.0;
/// How much of its height a bar keeps from one frame to the next as it falls.
const FALL: f64 = 0.82;

pub struct Analyser {
    fft: Arc<dyn Fft<f64>>,
    hann: Vec<f64>,
    /// The latest WINDOW mono samples, as a ring: the oldest is at `next`.
    history: Vec<f64>,
    next: usize,
    fresh: usize,
    bars: Vec<f64>,
    /// For each bar, the FFT bins it covers.
    bands: Vec<std::ops::Range<usize>>,
}

impl Analyser {
    pub fn new(count: usize, rate: u32) -> Self {
        let fft = FftPlanner::new().plan_fft_forward(WINDOW);
        let hann = (0..WINDOW)
            .map(|i| {
                0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / (WINDOW - 1) as f64).cos()
            })
            .collect();
        Analyser {
            fft,
            hann,
            history: vec![0.0; WINDOW],
            next: 0,
            fresh: 0,
            bars: vec![0.0; count],
            bands: bands(count, rate),
        }
    }

    pub fn bars(&self) -> &[f64] {
        &self.bars
    }

    /// Adds interleaved samples; returns true each time new bar heights are ready.
    pub fn push(&mut self, interleaved: &[f32], channels: usize) -> bool {
        let channels = channels.max(1);
        let mut ready = false;
        for frame in interleaved.chunks_exact(channels) {
            let mono = frame.iter().map(|&s| s as f64).sum::<f64>() / channels as f64;
            self.history[self.next] = mono;
            self.next = (self.next + 1) % WINDOW;
            self.fresh += 1;
            if self.fresh >= HOP {
                self.fresh = 0;
                self.analyse();
                ready = true;
            }
        }
        ready
    }

    /// No audio arrived for a while (the output is idle): let the bars fall.
    pub fn decay(&mut self) {
        for bar in &mut self.bars {
            *bar *= FALL;
            if *bar < 0.005 {
                *bar = 0.0;
            }
        }
    }

    fn analyse(&mut self) {
        let (newest, oldest) = self.history.split_at(self.next);
        let mut buffer: Vec<Complex<f64>> = oldest
            .iter()
            .chain(newest)
            .zip(&self.hann)
            .map(|(s, w)| Complex::new(s * w, 0.0))
            .collect();
        self.fft.process(&mut buffer);
        // Amplitude of a full-scale sine is about WINDOW / 4 with a Hann window.
        let scale = 4.0 / WINDOW as f64;
        for (bar, band) in self.bars.iter_mut().zip(&self.bands) {
            let peak = buffer[band.clone()]
                .iter()
                .map(|c| c.norm())
                .fold(0.0, f64::max)
                * scale;
            let db = 20.0 * peak.max(1e-9).log10();
            let level = ((db - FLOOR_DB) / (CEILING_DB - FLOOR_DB)).clamp(0.0, 1.0);
            *bar = level.max(*bar * FALL);
        }
    }
}

/// Bin ranges for `count` bands spaced evenly in log frequency, each at least one bin.
fn bands(count: usize, rate: u32) -> Vec<std::ops::Range<usize>> {
    let hz_per_bin = rate.max(1) as f64 / WINDOW as f64;
    let top = HIGHEST_HZ.min(rate as f64 / 2.0);
    let edge = |i: usize| LOWEST_HZ * (top / LOWEST_HZ).powf(i as f64 / count.max(1) as f64);
    (0..count)
        .map(|i| {
            let start = ((edge(i) / hz_per_bin) as usize).clamp(1, WINDOW / 2 - 1);
            let end = ((edge(i + 1) / hz_per_bin) as usize).clamp(start + 1, WINDOW / 2);
            start..end
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_tone_lights_its_own_band() {
        let rate = 48_000;
        let mut analyser = Analyser::new(32, rate);
        let tone: Vec<f32> = (0..WINDOW * 2)
            .map(|i| {
                (2.0 * std::f64::consts::PI * 1000.0 * i as f64 / rate as f64).sin() as f32 * 0.5
            })
            .collect();
        assert!(analyser.push(&tone, 1));
        let bars = analyser.bars();
        let loudest = (0..bars.len())
            .max_by(|&a, &b| bars[a].total_cmp(&bars[b]))
            .unwrap();
        let band = &analyser.bands[loudest];
        let hz = |bin: usize| bin as f64 * rate as f64 / WINDOW as f64;
        assert!(
            hz(band.start) <= 1000.0 && 1000.0 <= hz(band.end),
            "1 kHz in {band:?}"
        );
        assert!(bars[loudest] > 0.9);
    }

    #[test]
    fn silence_stays_empty_and_decay_falls() {
        let mut analyser = Analyser::new(16, 48_000);
        analyser.push(&vec![0.0; WINDOW * 2], 2);
        assert!(analyser.bars().iter().all(|&b| b == 0.0));
        analyser.bars = vec![1.0; 16];
        for _ in 0..40 {
            analyser.decay();
        }
        assert!(analyser.bars().iter().all(|&b| b == 0.0));
    }
}
