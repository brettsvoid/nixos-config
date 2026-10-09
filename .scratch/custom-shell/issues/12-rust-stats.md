# Rust stats program feeding a dashboard performance tab

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A small Rust program that samples system statistics and prints one JSON object per
line on stdout. A new performance tab in the dashboard starts it while the tab is
visible, reads the lines (Quickshell's Process with a line parser), and stops it when
the tab hides. Quickshell has no statistics of its own.

Samples, about once a second:

- CPU: total and per-core usage, temperature.
- Memory and swap.
- GPU through NVML (no `nvidia-smi` per tick): usage, VRAM, temperature, power.
- Disk usage for the main filesystems, and network throughput.

The tab shows current values and a short history graph for CPU and GPU. Draw the graphs
without a per-frame repaint; they only change when a sample arrives.

On the laptop (NVIDIA Optimus) the discrete GPU sleeps when idle. Querying NVML wakes
it, which Caelestia users reported against `nvidia-smi` (their #1797). Only query the
GPU when it is already awake (its runtime power status in sysfs), and show "asleep"
otherwise.

Package it with the Nix Rust tooling next to the shell, so a rebuild installs it.

## Acceptance criteria

- [ ] The program runs standalone and prints valid JSON lines; values match `top`,
      `free` and `nvidia-smi` within reason.
- [ ] Opening the performance tab starts it; closing the tab or the dashboard stops it
      (no stray process left).
- [ ] The tab shows CPU, memory, GPU, disk and network, with history graphs for CPU and
      GPU.
- [ ] On the laptop, an idle discrete GPU stays asleep while the tab is open.
- [ ] Missing hardware (no NVIDIA GPU, no sensor) is reported as absent, not as a crash.
- [ ] The program builds from the flake with no network access at build time.

## Blocked by

- .scratch/custom-shell/issues/11-dashboard-drawer.md
