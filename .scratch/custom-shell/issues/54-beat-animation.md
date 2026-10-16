# Beat-synced animation on the media card

Status: ready-for-human
Type: HITL (whether the pulse keeps time with real music, and looks right)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Something on the media card that moves in time with the music. Caelestia's bongocat is
an `AnimatedImage` whose speed follows a tempo from aubio
(`plugin/src/Caelestia/Services/beattracker.cpp`, `modules/dashboard/dash/Media.qml`;
ideas only, and its GIF is not ours to use).

It builds on the visualiser (issue 13). `CustomShell.Native`'s `Spectrum` (Rust) reads
the default output's monitor stream from PipeWire. It runs a 2048-sample FFT every 1024
samples (about 47 a second at 48 kHz), only while `active`: the media card shows and its
player plays. Issue 13 measured 3–4 % of one core with the bars showing: 0.4 % for the
spectrum thread, the rest for the shell redrawing about 47 times a second.

## Proposed choices

1. **Our own beat detector, in Rust, in the same `Analyser`.** Spectral flux (the rise
   in each FFT bin's magnitude, low bands weighted) from the FFT it already runs. A beat
   is a flux above the last 1.5 s's mean plus a margin, at least 250 ms after the last.
   The tempo is the median of recent beat gaps. `Spectrum` gains a `beat()` signal and
   a `bpm` property, so one PipeWire stream serves both. Alternative: aubio (0.4.9 in
   nixpkgs, which lists it as GPL-2.0). Reason: no new C library, no licence question
   for this MIT code, and the FFT is already paid for.
2. **What moves: the cover pulses on each beat,** scale 1.0 → 1.04 → 1.0 over 150 ms (an
   effect duration from the PRD). Alternatives: a GIF you choose whose speed follows
   `bpm` (Caelestia's way; it repaints at the GIF's frame rate all the time it plays);
   or the visualiser's bars brighten on the beat.
3. **When: only while `Spectrum` is active,** and never in game mode. Game mode closes
   the dashboard already (`services/GameMode.qml`). `active` also checks
   `!GameMode.on`, in case the dashboard can open during game mode (unchecked). Paused
   or stopped, the capture closes, so no beats come.
4. **With the visualiser off and the pulse on,** `Visualiser.qml` still loads, with its
   bars hidden, for the beats. With both off, nothing loads.
5. **Where: the media card,** on the Overview and in issue 51's Media tab. Not the bar:
   a pulse there would cost frames whenever music plays.
6. **Setting:** `dashboard.beatPulse` (default `true`), on the Dashboard page's
   Overview section, beside the visualiser.
7. **Cost.** With the bars showing, the window already redraws about 47 times a second,
   so the pulse should add few frames. With the bars off, each pulse redraws for 150 ms
   at up to 165 Hz: about 50 frames a second at 120 BPM. Budget: no more than 1 % of one
   core above issue 13's figure. Measure both cases and note them here.

## Acceptance criteria

- [ ] Rust unit tests: a click train at 120 BPM gives beats 500 ms apart (within one
      hop, 21 ms) and `bpm` 120 ± 2; silence and a steady tone give no beats.
- [ ] With the dashboard closed, paused or in game mode, no capture stream exists
      (`pw-dump`) and the cover does not move.
- [ ] CPU and frame counts (Qt's render log, as in issue 11), with the bars on and off,
      are noted here and within the budget.
- [ ] Test audio goes to a null sink, as in issue 13.
- [ ] Left for the user: with real music, the pulse keeps time and looks right.

## Blocked by

- None (issue 13 is done).
