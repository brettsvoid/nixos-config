// System metrics: the notch's memory, swap and disk rows, the always-on sampler
// behind the bar's CPU pill, and the history the performance chart plots.

use serde::Serialize;
use std::collections::VecDeque;
use std::sync::Mutex;
use std::time::Duration;
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
    app.state::<MetricsState>().latest.lock().unwrap().total * 100.0
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
        // Lock order: AppState.sys then MetricsState. The sampler thread never takes
        // AppState.sys, so the two can't invert on each other.
        let cpu = cpu_percent(&app, &mut sys);
        sample_metrics(&mut sys, cpu)
    })
    .await
    .unwrap_or_default()
}

// ───────────────────────── sampler and history ──────────────────────────
// Always on, unlike the metrics view: the bar's CPU pill draws a rolling CPU
// history and the performance chart plots CPU and RAM over ten minutes. One
// tick of one sampler feeds both. Ported from the sketchybar mach helper: the
// same system/user split from `host_statistics(HOST_CPU_LOAD_INFO)` and the same
// top-process readout.

/// Sampling period, matching the notch metrics' cadence. The bar's graph spans
/// CPU_HISTORY × SAMPLE_PERIOD, the performance chart HISTORY_LEN × SAMPLE_PERIOD.
const SAMPLE_PERIOD: Duration = Duration::from_secs(2);
/// Columns of the bar's CPU graph, one entry each, each 1px wide. Must match
/// CPU_GRAPH.samples in main.ts, which is in turn pinned to the graph's pixel
/// width so columns land on whole pixels.
const CPU_HISTORY: usize = 108;
/// Ticks kept for the performance chart: ten minutes at SAMPLE_PERIOD.
const HISTORY_LEN: usize = 300;
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
/// `mem` is the used fraction of RAM (0..1) read with the same tick.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuStat {
    sys: f32,
    user: f32,
    total: f32,
    mem: f32,
    top_proc: String,
    top_proc_pct: f32,
    /// 0 when no process has been sampled yet — the bar hides the pid then.
    top_pid: u32,
}

/// Seed for a bar that just loaded: the graph's columns plus the latest
/// readout. Bars are rebuilt on every display change, and without this a new
/// one would start with an empty graph.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuSnapshot {
    history: Vec<CpuSample>,
    latest: CpuStat,
}

/// The performance chart's series, oldest first, one entry per tick.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetricsHistory {
    interval_ms: u64,
    cpu: Vec<CpuSample>,
    /// Used fraction of RAM, 0..1: the same figure as `Metrics`' `mem_used` over
    /// `mem_total`.
    mem: Vec<f32>,
}

/// One tick as the chart plots it: the CPU split and the RAM fraction read
/// together.
#[derive(Clone, Copy, Default)]
struct Point {
    cpu: CpuSample,
    mem: f32,
}

/// The last HISTORY_LEN ticks, newest last. The bar's graph reads the
/// CPU_HISTORY newest, the chart reads all of them.
#[derive(Default)]
struct History(VecDeque<Point>);

impl History {
    fn push(&mut self, point: Point) {
        if self.0.len() == HISTORY_LEN {
            self.0.pop_front();
        }
        self.0.push_back(point);
    }

    fn cpu_tail(&self, n: usize) -> Vec<CpuSample> {
        let skip = self.0.len().saturating_sub(n);
        self.0.iter().skip(skip).map(|p| p.cpu).collect()
    }

    fn series(&self) -> MetricsHistory {
        MetricsHistory {
            interval_ms: SAMPLE_PERIOD.as_millis() as u64,
            cpu: self.0.iter().map(|p| p.cpu).collect(),
            mem: self.0.iter().map(|p| p.mem).collect(),
        }
    }
}

#[derive(Default)]
struct MetricsState {
    history: Mutex<History>,
    latest: Mutex<CpuStat>,
}

impl MetricsState {
    fn record(&self, point: Point, stat: CpuStat) {
        self.history.lock().unwrap().push(point);
        *self.latest.lock().unwrap() = stat;
    }

    fn snapshot(&self) -> CpuSnapshot {
        let history = self.history.lock().unwrap().cpu_tail(CPU_HISTORY);
        let latest = self.latest.lock().unwrap().clone();
        CpuSnapshot { history, latest }
    }
}

#[tauri::command]
pub fn cpu_state(app: tauri::AppHandle) -> CpuSnapshot {
    app.state::<MetricsState>().snapshot()
}

/// The chart's seed. Live points arrive on the `cpu` event, which carries `mem`.
#[tauri::command]
pub fn metrics_history(app: tauri::AppHandle) -> MetricsHistory {
    app.state::<MetricsState>().history.lock().unwrap().series()
}

/// Used RAM over total, 0..1. A failed total read (0) gives 0 rather than NaN,
/// which JSON would turn into null.
fn mem_fraction(used: u64, total: u64) -> f32 {
    if total == 0 {
        return 0.0;
    }
    (used as f64 / total as f64).min(1.0) as f32
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

/// What one sampler thread carries between ticks.
#[cfg(target_os = "macos")]
struct Sampler {
    host: libc::host_t,
    /// Its own `System`, not AppState's: sysinfo's CPU figures are deltas since
    /// that instance's last refresh, so a second refresher would shrink the
    /// window to milliseconds and skew the readings.
    sys: sysinfo::System,
    proc_cpu: sysinfo::ProcessRefreshKind,
    prev: Option<[u32; libc::CPU_STATE_MAX as usize]>,
    /// Last known hungriest process (name, percent, pid), carried across the
    /// ticks that skip the walk so every emitted stat still names one.
    top: (String, f32, u32),
    tick: u32,
}

#[cfg(target_os = "macos")]
impl Sampler {
    fn new() -> Self {
        use sysinfo::{ProcessRefreshKind, ProcessesToUpdate};

        // `mach_host_self` adds a send right per call, so take the port once and
        // reuse it for the sampler's lifetime rather than leaking one per tick.
        #[allow(deprecated)]
        let host = unsafe { libc::mach_host_self() };

        let mut sys = sysinfo::System::new();
        let proc_cpu = ProcessRefreshKind::nothing().with_cpu();
        // Prime both baselines — the first delta of either is meaningless.
        sys.refresh_processes_specifics(ProcessesToUpdate::All, true, proc_cpu);
        Sampler {
            host,
            sys,
            proc_cpu,
            prev: read_cpu_ticks(host),
            top: Default::default(),
            tick: 0,
        }
    }

    /// Used fraction of RAM now. Reads RAM only (no swap sysctl) but through the
    /// same sysinfo fields as `sample_metrics`, so the chart and the rows agree.
    fn read_mem(&mut self) -> f32 {
        use sysinfo::MemoryRefreshKind;

        self.sys
            .refresh_memory_specifics(MemoryRefreshKind::nothing().with_ram());
        mem_fraction(self.sys.used_memory(), self.sys.total_memory())
    }

    /// One tick: the CPU split since the previous call, RAM now, and the pill's
    /// readout. `None` when there is nothing to plot (a failed read, the first
    /// call, or no elapsed ticks).
    fn step(&mut self) -> Option<(Point, CpuStat)> {
        use sysinfo::ProcessesToUpdate;

        let now = read_cpu_ticks(self.host)?;
        let before = self.prev.replace(now)?;

        // Ticks are monotonic but wrap at u32; wrapping_sub keeps the delta
        // right across the rollover instead of yielding a huge bogus jump.
        let delta = |i: libc::c_int| now[i as usize].wrapping_sub(before[i as usize]) as f64;
        let user = delta(libc::CPU_STATE_USER);
        let system = delta(libc::CPU_STATE_SYSTEM);
        let idle = delta(libc::CPU_STATE_IDLE);
        // NICE is counted (the sketchybar helper left it out) so the
        // fractions still total 1 under re-niced load; it's nearly always 0
        // on macOS.
        let nice = delta(libc::CPU_STATE_NICE);
        let busy_total = user + system + idle + nice;
        if busy_total <= 0.0 {
            return None; // no elapsed ticks (clock skew / suspend) — nothing to plot
        }
        let cpu = CpuSample {
            sys: (system / busy_total) as f32,
            // NICE is user-space work, so it counts as user load.
            user: ((user + nice) / busy_total) as f32,
        };

        // `tick` starts at 0, so the first pass names a process straight
        // away. Skipped ticks just widen the window each process's usage
        // averages over.
        if self.tick % CPU_TOP_PROC_EVERY == 0 {
            self.sys
                .refresh_processes_specifics(ProcessesToUpdate::All, true, self.proc_cpu);
            self.top = self
                .sys
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
        self.tick = self.tick.wrapping_add(1);

        let mem = self.read_mem();
        let stat = CpuStat {
            sys: cpu.sys,
            user: cpu.user,
            total: cpu.sys + cpu.user,
            mem,
            top_proc: self.top.0.clone(),
            top_proc_pct: self.top.1,
            top_pid: self.top.2,
        };
        Some((Point { cpu, mem }, stat))
    }
}

/// Manages the state, then starts the sampler on its own thread. Call it before
/// the bar windows are built, so `cpu_state` and `metrics_history` can answer a
/// bar that asks before the first tick. A display-config rebuild replaces the
/// bar windows but leaves the sampler and its history untouched.
pub fn install(app: tauri::AppHandle) {
    app.manage(MetricsState::default());

    #[cfg(target_os = "macos")]
    std::thread::spawn(move || {
        let mut sampler = Sampler::new();
        loop {
            std::thread::sleep(SAMPLE_PERIOD);
            let Some((point, stat)) = sampler.step() else {
                continue;
            };
            app.state::<MetricsState>().record(point, stat.clone());
            let _ = app.emit("cpu", &stat);
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn point(i: usize) -> Point {
        Point {
            cpu: CpuSample {
                sys: i as f32,
                user: 0.0,
            },
            mem: i as f32,
        }
    }

    #[test]
    fn mem_fraction_is_used_over_total() {
        assert_eq!(mem_fraction(4 << 30, 16 << 30), 0.25);
        assert_eq!(mem_fraction(12 << 30, 16 << 30), 0.75);
    }

    #[test]
    fn mem_fraction_is_zero_when_the_total_read_failed() {
        assert_eq!(mem_fraction(123, 0), 0.0);
    }

    #[test]
    fn mem_fraction_never_exceeds_one() {
        assert_eq!(mem_fraction(20, 10), 1.0);
    }

    #[test]
    fn history_keeps_the_newest_300_ticks_oldest_first() {
        let state = MetricsState::default();
        for i in 0..305 {
            state.record(point(i), CpuStat::default());
        }
        let series = state.history.lock().unwrap().series();
        assert_eq!(series.cpu.len(), 300);
        assert_eq!(series.mem.len(), 300);
        assert_eq!(series.cpu[0].sys, 5.0);
        assert_eq!(series.mem[0], 5.0);
        assert_eq!(series.cpu[299].sys, 304.0);
        assert_eq!(series.mem[299], 304.0);
    }

    #[test]
    fn snapshot_still_hands_the_bar_its_108_newest_cpu_samples() {
        let state = MetricsState::default();
        for i in 0..305 {
            let stat = CpuStat {
                mem: i as f32,
                ..CpuStat::default()
            };
            state.record(point(i), stat);
        }
        let snapshot = state.snapshot();
        assert_eq!(snapshot.history.len(), 108);
        assert_eq!(snapshot.history[0].sys, 197.0);
        assert_eq!(snapshot.history[107].sys, 304.0);
        assert_eq!(snapshot.latest.mem, 304.0);
    }

    #[test]
    fn snapshot_of_a_short_history_is_all_of_it() {
        let state = MetricsState::default();
        for i in 0..3 {
            state.record(point(i), CpuStat::default());
        }
        let sys: Vec<f32> = state.snapshot().history.iter().map(|s| s.sys).collect();
        assert_eq!(sys, [0.0, 1.0, 2.0]);
    }

    #[test]
    fn series_serialises_as_ipc_ts_declares_it() {
        let mut history = History::default();
        history.push(Point {
            cpu: CpuSample {
                sys: 0.25,
                user: 0.5,
            },
            mem: 0.5,
        });
        history.push(Point {
            cpu: CpuSample {
                sys: 0.125,
                user: 0.25,
            },
            mem: 0.75,
        });
        assert_eq!(
            serde_json::to_value(history.series()).unwrap(),
            json!({
                "intervalMs": 2000,
                "cpu": [{"sys": 0.25, "user": 0.5}, {"sys": 0.125, "user": 0.25}],
                "mem": [0.5, 0.75],
            })
        );
    }

    #[test]
    fn cpu_event_carries_mem_beside_the_pill_readout() {
        let stat = CpuStat {
            sys: 0.25,
            user: 0.5,
            total: 0.75,
            mem: 0.5,
            top_proc: "kernel_task".into(),
            top_proc_pct: 12.5,
            top_pid: 0,
        };
        assert_eq!(
            serde_json::to_value(stat).unwrap(),
            json!({
                "sys": 0.25,
                "user": 0.5,
                "total": 0.75,
                "mem": 0.5,
                "topProc": "kernel_task",
                "topProcPct": 12.5,
                "topPid": 0,
            })
        );
    }

    /// Microseconds per call over `n` calls: (min, median, p99).
    #[cfg(target_os = "macos")]
    fn time_us(n: usize, mut f: impl FnMut()) -> (f64, f64, f64) {
        let mut us: Vec<f64> = (0..n)
            .map(|_| {
                let start = std::time::Instant::now();
                f();
                start.elapsed().as_secs_f64() * 1e6
            })
            .collect();
        us.sort_by(f64::total_cmp);
        (us[0], us[n / 2], us[n * 99 / 100])
    }

    /// Runs the real sampler against this Mac: `cargo test metrics -- --ignored
    /// --nocapture`.
    #[cfg(target_os = "macos")]
    #[test]
    #[ignore = "reads the live machine"]
    fn live_sampler() {
        let mut sampler = Sampler::new();
        let state = MetricsState::default();

        let mut step_walk_us = Vec::new();
        let mut step_plain_us = Vec::new();
        for i in 0..12 {
            std::thread::sleep(SAMPLE_PERIOD);
            let walks = sampler.tick % CPU_TOP_PROC_EVERY == 0;
            let start = std::time::Instant::now();
            let (point, stat) = sampler
                .step()
                .unwrap_or_else(|| panic!("tick {i} gave nothing to plot"));
            let us = start.elapsed().as_secs_f64() * 1e6;
            let bucket = if walks {
                &mut step_walk_us
            } else {
                &mut step_plain_us
            };
            bucket.push(us);
            state.record(point, stat);
        }

        let series = state.history.lock().unwrap().series();
        let snapshot = state.snapshot();
        let (mem_min, mem_max) = series
            .mem
            .iter()
            .fold((f32::MAX, f32::MIN), |(lo, hi), m| (lo.min(*m), hi.max(*m)));
        println!(
            "history: {} cpu / {} mem entries, intervalMs {}, bar snapshot {} columns",
            series.cpu.len(),
            series.mem.len(),
            series.interval_ms,
            snapshot.history.len()
        );
        println!(
            "mem fraction over the run: {mem_min:.4}..{mem_max:.4}; latest event mem {:.4}, cpu total {:.3}, top {} (pid {})",
            snapshot.latest.mem, snapshot.latest.total, snapshot.latest.top_proc, snapshot.latest.top_pid
        );
        assert!(series.mem.iter().all(|m| *m > 0.0 && *m < 1.0));
        assert_eq!(series.cpu.len(), 12);

        // The chart's figure against the rows' figure, read back to back.
        let chart = sampler.read_mem();
        let rows = sample_metrics(&mut sysinfo::System::new(), 0.0);
        let rows_frac = rows.mem_used as f64 / rows.mem_total as f64;
        println!(
            "chart mem {chart:.5} vs rows memUsed/memTotal {rows_frac:.5} ({} of {} bytes)",
            rows.mem_used, rows.mem_total
        );
        assert!((chart as f64 - rows_frac).abs() < 0.02);

        // What the memory read adds to a tick.
        let (lo, med, p99) = time_us(2000, || {
            sampler.read_mem();
        });
        println!("read_mem (ram only):      min {lo:.1} med {med:.1} p99 {p99:.1} µs");
        let mut full = sysinfo::System::new();
        let (lo, med, p99) = time_us(2000, || full.refresh_memory());
        println!("refresh_memory (+ swap):  min {lo:.1} med {med:.1} p99 {p99:.1} µs");
        let (lo, med, p99) = time_us(2000, || {
            read_cpu_ticks(sampler.host);
        });
        println!("read_cpu_ticks:           min {lo:.1} med {med:.1} p99 {p99:.1} µs");
        let (lo, med, p99) = time_us(30, || {
            sampler.sys.refresh_processes_specifics(
                sysinfo::ProcessesToUpdate::All,
                true,
                sampler.proc_cpu,
            );
        });
        println!("process walk:             min {lo:.1} med {med:.1} p99 {p99:.1} µs");
        step_walk_us.sort_by(f64::total_cmp);
        step_plain_us.sort_by(f64::total_cmp);
        println!(
            "whole step, with walk:    median {:.1} µs over {}; without walk: median {:.1} µs over {}",
            step_walk_us[step_walk_us.len() / 2],
            step_walk_us.len(),
            step_plain_us[step_plain_us.len() / 2],
            step_plain_us.len()
        );
    }
}
