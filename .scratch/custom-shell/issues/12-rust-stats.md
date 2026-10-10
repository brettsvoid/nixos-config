# Rust stats program feeding a dashboard performance tab

Status: done
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

## Comments

**2026-10-10:** Done and tested on brett-desktop, except the laptop's sleeping GPU.
- `modules/home/desktop/shell-stats`: Rust, one crate (`libc`, for `statvfs`, `dlopen`).
  A JSON object per line every second (`--interval <ms>`, `--once`), exits when stdout
  closes. CPU from /proc/stat deltas (total and per core) and hwmon (coretemp "Package
  id 0", k10temp "Tctl"/"Tdie"); memory and swap from /proc/meminfo (used = total −
  available, as `free`); disks via statvfs, one mount per block device (shortest path,
  so btrfs subvolumes count once), /boot and /efi left out; network from /proc/net/dev
  over the real interfaces.
- GPU: the NVIDIA display device is found in /sys/bus/pci; NVML is dlopen'd at run time
  (also from /run/opengl-driver/lib, where NixOS keeps it) through a small FFI of the
  calls used, written from nvml.h. It is only queried while the device's
  `power/runtime_status` is "active", and where runtime PM is on (`power/control` is
  "auto", as on the laptop) NVML is shut down after each sample, so the device is never
  held open. Memory uses `nvmlDeviceGetMemoryInfo_v2` (v1 counts the driver's reserve:
  1732 MiB against nvidia-smi's 1367). States: awake, asleep, absent, unavailable.
- Checked against the tools: memory used 5.65 GB vs `free` 5.64; swap identical; CPU
  5.8% vs `top` 5.5%, 42 °C vs hwmon 42; VRAM 1356 vs nvidia-smi 1357 MiB, 49 °C both;
  disks byte-for-byte as `df`. With /sys/bus/pci/devices and /sys/class/hwmon hidden
  (user and mount namespaces) it reports the GPU absent and the temperature null; with
  /run/opengl-driver hidden, the GPU unavailable; exit 0 both times.
- Nix: `rustPlatform.buildRustPackage` with `cargoLock.lockFile`; built from the flake.
- Tab: Performance in the dashboard runs `shell-stats` through a Process with a line
  parser. Quickshell kills a running Process when it is destroyed: checked, the program
  ran only while the tab showed, and was gone after switching back and after closing
  the dashboard. CPU and GPU graphs (a minute) are QtQuick Shapes rebuilt per sample.
- Not tested: on the laptop, that an idle discrete GPU stays asleep with the tab open
  (the desktop's GPU has no runtime PM: `control` is "on"). Note that querying an awake
  GPU every second may keep its idle timer from running out; measure on the laptop.
