// System metrics: the notch's memory, swap and disk rows, and the always-on
// sampler behind the bar's CPU pill.

use serde::Serialize;
use std::sync::Mutex;
use tauri::{Emitter, Manager};

use crate::AppState;

// ───────────────────────── system metrics (sysinfo) ─────────────────
// Memory, swap and disk are sampled only while the notch's metrics view is open
// (as ambxst does). CPU comes from the bar's always-on sampler (see
// `cpu_percent`).
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Metrics {
    cpu: f32, // percent 0..100
    mem_used: u64,
    mem_total: u64,
    swap_used: u64,
    swap_total: u64,
    disk_used: u64,
    disk_total: u64,
}

/// Read from the bar's always-on sampler rather than refreshing sysinfo here:
/// sysinfo's figure is the delta since its last refresh, so the first reading
/// after the notch had been shut for an hour would be that hour's average, and
/// a second sampler wouldn't agree with the bar's pill anyway.
#[cfg(target_os = "macos")]
fn cpu_percent(app: &tauri::AppHandle, _sys: &mut sysinfo::System) -> f32 {
    app.state::<CpuState>().latest.lock().unwrap().total * 100.0
}

/// `host_statistics` is macOS-only, so the sampler never runs elsewhere — fall
/// back to sysinfo's own aggregate there.
#[cfg(not(target_os = "macos"))]
fn cpu_percent(_app: &tauri::AppHandle, sys: &mut sysinfo::System) -> f32 {
    sys.refresh_cpu_usage();
    sys.global_cpu_usage()
}

fn sample_metrics(sys: &mut sysinfo::System, cpu: f32) -> Metrics {
    sys.refresh_memory();

    // Root volume (the boot disk). Fall back to the largest disk if "/" isn't
    // listed (on macOS the data volume is mounted under /System/Volumes/Data).
    let disks = sysinfo::Disks::new_with_refreshed_list();
    let root = disks
        .list()
        .iter()
        .find(|d| d.mount_point() == std::path::Path::new("/"))
        .or_else(|| disks.list().iter().max_by_key(|d| d.total_space()));
    let (disk_total, disk_avail) = root.map_or((0, 0), |d| (d.total_space(), d.available_space()));

    Metrics {
        cpu,
        mem_used: sys.used_memory(),
        mem_total: sys.total_memory(),
        swap_used: sys.used_swap(),
        swap_total: sys.total_swap(),
        disk_used: disk_total.saturating_sub(disk_avail),
        disk_total,
    }
}

// Off the main thread: `Disks::new_with_refreshed_list()` rescans every mount,
// every 2s while the metrics view is open.
#[tauri::command]
pub async fn metrics_sample(app: tauri::AppHandle) -> Metrics {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<AppState>();
        let mut sys = state.sys.lock().unwrap();
        // Lock order: AppState.sys then CpuState. The sampler thread never takes
        // AppState.sys, so the two can't invert on each other.
        let cpu = cpu_percent(&app, &mut sys);
        sample_metrics(&mut sys, cpu)
    })
    .await
    .unwrap_or_default()
}

// ───────────────────────── cpu load graph ───────────────────────────
// Always on, unlike the metrics view: the bar's CPU pill draws a rolling
// history. Ported from the sketchybar mach helper: the same system/user split
// from `host_statistics(HOST_CPU_LOAD_INFO)` and the same top-process readout.

/// Sampling period, matching the notch metrics' cadence. The graph spans
/// CPU_HISTORY × CPU_POLL.
const CPU_POLL: std::time::Duration = std::time::Duration::from_secs(2);
/// Ring-buffer depth — one entry per histogram column, each 1px wide. Must match
/// CPU_GRAPH.samples in main.ts, which is in turn pinned to the graph's pixel
/// width so columns land on whole pixels.
const CPU_HISTORY: usize = 108;
/// Ticks between top-process lookups. A tick's `host_statistics` read is ~11µs,
/// but naming the hungriest process walks every PID (~13ms with 600
/// processes), and the name changes far more slowly than the graph.
const CPU_TOP_PROC_EVERY: u32 = 3;

/// One graph column: system and user load as fractions (0..1) of total CPU
/// capacity, kept apart so the graph can stack user on top of system.
#[derive(Clone, Copy, Default, Serialize)]
pub struct CpuSample {
    sys: f32,
    user: f32,
}

/// The pill's current readout. `top_proc_pct` is percent of a single core (so it
/// can exceed 100 on a threaded process) — the same convention `ps pcpu` used.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuStat {
    sys: f32,
    user: f32,
    total: f32,
    top_proc: String,
    top_proc_pct: f32,
    /// 0 when no process has been sampled yet — the bar hides the pid then.
    top_pid: u32,
}

/// Seed for a bar that just loaded: the full history plus the latest readout.
/// Bars are rebuilt on every display change, and without this a new one would
/// start with an empty graph.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuSnapshot {
    history: Vec<CpuSample>,
    latest: CpuStat,
}

#[derive(Default)]
pub struct CpuState {
    history: Mutex<std::collections::VecDeque<CpuSample>>,
    latest: Mutex<CpuStat>,
}

#[tauri::command]
pub fn cpu_state(app: tauri::AppHandle) -> CpuSnapshot {
    let state = app.state::<CpuState>();
    let history = state.history.lock().unwrap().iter().copied().collect();
    let latest = state.latest.lock().unwrap().clone();
    CpuSnapshot { history, latest }
}

/// Cumulative CPU ticks since boot, indexed by `CPU_STATE_*`. Percentages come
/// from the delta between two reads, so a single sample means nothing on its own.
#[cfg(target_os = "macos")]
fn read_cpu_ticks(host: libc::host_t) -> Option<[u32; libc::CPU_STATE_MAX as usize]> {
    let mut info: libc::host_cpu_load_info = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_CPU_LOAD_INFO_COUNT;
    // SAFETY: `info` is the layout HOST_CPU_LOAD_INFO writes, and `count` tells
    // the kernel how many words it may write (the matching _COUNT constant).
    let err = unsafe {
        libc::host_statistics(
            host,
            libc::HOST_CPU_LOAD_INFO,
            &mut info as *mut _ as libc::host_info_t,
            &mut count,
        )
    };
    (err == libc::KERN_SUCCESS).then_some(info.cpu_ticks)
}

/// Drop the `com.apple.` prefix from reverse-DNS process names
/// (`com.apple.WebKit.WebContent`): noise in a pill this narrow. Same filter as
/// the sketchybar helper's FILTER_PATTERN.
fn trim_proc_name(name: &str) -> &str {
    name.strip_prefix("com.apple.").unwrap_or(name)
}

/// Background sampler: reads the tick split, finds the hungriest process, pushes
/// both to every bar. Runs on its own thread — a display-config rebuild replaces
/// the bar windows but leaves this and its history untouched.
#[cfg(target_os = "macos")]
pub fn install_cpu_sampler(app: tauri::AppHandle) {
    use sysinfo::{ProcessRefreshKind, ProcessesToUpdate};

    std::thread::spawn(move || {
        // `mach_host_self` adds a send right per call, so take the port once and
        // reuse it for the process's lifetime rather than leaking one per tick.
        #[allow(deprecated)]
        let host = unsafe { libc::mach_host_self() };

        // Its own `System`, not AppState's: sysinfo's CPU figures are deltas
        // since that instance's last refresh, so a second refresher would
        // shrink the window to milliseconds and skew the readings.
        let mut sys = sysinfo::System::new();
        let proc_cpu = ProcessRefreshKind::nothing().with_cpu();
        // Prime both baselines — the first delta of either is meaningless.
        sys.refresh_processes_specifics(ProcessesToUpdate::All, true, proc_cpu);
        let mut prev = read_cpu_ticks(host);
        // Last known hungriest process (name, percent, pid), carried across the
        // ticks that skip the walk so every emitted stat still names one.
        let mut top: (String, f32, u32) = Default::default();
        let mut tick: u32 = 0;

        loop {
            std::thread::sleep(CPU_POLL);

            let Some(now) = read_cpu_ticks(host) else {
                continue;
            };
            let Some(before) = prev else {
                prev = Some(now);
                continue;
            };
            prev = Some(now);

            // Ticks are monotonic but wrap at u32; wrapping_sub keeps the delta
            // right across the rollover instead of yielding a huge bogus jump.
            let delta = |i: libc::c_int| {
                now[i as usize].wrapping_sub(before[i as usize]) as f64
            };
            let user = delta(libc::CPU_STATE_USER);
            let system = delta(libc::CPU_STATE_SYSTEM);
            let idle = delta(libc::CPU_STATE_IDLE);
            // NICE is counted (the sketchybar helper left it out) so the
            // fractions still total 1 under re-niced load; it's nearly always 0
            // on macOS.
            let nice = delta(libc::CPU_STATE_NICE);
            let busy_total = user + system + idle + nice;
            if busy_total <= 0.0 {
                continue; // no elapsed ticks (clock skew / suspend) — nothing to plot
            }
            let sample = CpuSample {
                sys: (system / busy_total) as f32,
                // NICE is user-space work, so it counts as user load.
                user: ((user + nice) / busy_total) as f32,
            };

            // `tick` starts at 0, so the first pass names a process straight
            // away. Skipped ticks just widen the window each process's usage
            // averages over.
            if tick % CPU_TOP_PROC_EVERY == 0 {
                sys.refresh_processes_specifics(ProcessesToUpdate::All, true, proc_cpu);
                top = sys
                    .processes()
                    .values()
                    .max_by(|a, b| a.cpu_usage().total_cmp(&b.cpu_usage()))
                    .map(|p| {
                        let name = p.name().to_string_lossy();
                        (
                            trim_proc_name(&name).to_string(),
                            p.cpu_usage(),
                            p.pid().as_u32(),
                        )
                    })
                    .unwrap_or_default();
            }
            tick = tick.wrapping_add(1);

            let stat = CpuStat {
                sys: sample.sys,
                user: sample.user,
                total: sample.sys + sample.user,
                top_proc: top.0.clone(),
                top_proc_pct: top.1,
                top_pid: top.2,
            };

            {
                let state = app.state::<CpuState>();
                let mut history = state.history.lock().unwrap();
                if history.len() == CPU_HISTORY {
                    history.pop_front();
                }
                history.push_back(sample);
                *state.latest.lock().unwrap() = stat.clone();
            }
            let _ = app.emit("cpu", &stat);
        }
    });
}
