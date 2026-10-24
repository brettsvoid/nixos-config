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
fn cpu_percent(app: &tauri::AppHandle) -> f32 {
    app.state::<MetricsState>().latest.lock().unwrap().total * 100.0
}

/// `host_statistics` is macOS-only, so the sampler never runs elsewhere — fall
/// back to sysinfo's own aggregate there.
#[cfg(not(target_os = "macos"))]
fn cpu_percent(app: &tauri::AppHandle) -> f32 {
    let state = app.state::<AppState>();
    let mut sys = state.sys.lock().unwrap();
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
        let cpu = cpu_percent(&app);
        let state = app.state::<AppState>();
        let mut sys = state.sys.lock().unwrap();
        sample_metrics(&mut sys, cpu)
    })
    .await
    .unwrap_or_default()
}

const SAMPLE_PERIOD: Duration = Duration::from_secs(2);
/// Columns in the bar's CPU graph.
const CPU_HISTORY: usize = 108;
/// How far back the Performance view's chart can reach.
const HISTORY_SPAN: Duration = Duration::from_secs(10 * 60);
const HISTORY_LEN: usize = (HISTORY_SPAN.as_secs() / SAMPLE_PERIOD.as_secs()) as usize;
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
    mem_used_fraction: f32,
    top_proc: String,
    top_proc_pct: f32,
    /// None until the first process walk.
    top_pid: Option<u32>,
}

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuSnapshot {
    /// How many samples `history` holds once full: the bar graph's columns.
    capacity: usize,
    history: Vec<CpuSample>,
    latest: CpuStat,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetricsHistory {
    interval_ms: u64,
    /// How many seconds the history holds once full.
    capacity_secs: u64,
    cpu: Vec<CpuSample>,
    mem_used_fraction: Vec<f32>,
}

#[derive(Clone, Copy, Default)]
struct Point {
    cpu: CpuSample,
    mem_used_fraction: f32,
}

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
            capacity_secs: HISTORY_SPAN.as_secs(),
            cpu: self.0.iter().map(|p| p.cpu).collect(),
            mem_used_fraction: self.0.iter().map(|p| p.mem_used_fraction).collect(),
        }
    }
}

/// Managed from the builder, so a bar that loads before setup finishes can
/// still ask for it.
#[derive(Default)]
pub struct MetricsState {
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
        CpuSnapshot {
            capacity: CPU_HISTORY,
            history,
            latest,
        }
    }
}

#[tauri::command]
pub fn cpu_state(app: tauri::AppHandle) -> CpuSnapshot {
    app.state::<MetricsState>().snapshot()
}

#[tauri::command]
pub fn metrics_history(app: tauri::AppHandle) -> MetricsHistory {
    app.state::<MetricsState>().history.lock().unwrap().series()
}

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

#[derive(Default)]
struct TopProcess {
    name: String,
    cpu_pct: f32,
    pid: Option<u32>,
}

#[cfg(target_os = "macos")]
struct Sampler {
    host: libc::host_t,
    /// Its own `System`, not AppState's: sysinfo's CPU figures are deltas since
    /// that instance's last refresh, so a second refresher would shrink the
    /// window to milliseconds and skew the readings.
    sys: sysinfo::System,
    proc_cpu: sysinfo::ProcessRefreshKind,
    prev: Option<[u32; libc::CPU_STATE_MAX as usize]>,
    top: TopProcess,
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

    fn read_mem(&mut self) -> f32 {
        use sysinfo::MemoryRefreshKind;

        self.sys
            .refresh_memory_specifics(MemoryRefreshKind::nothing().with_ram());
        mem_fraction(self.sys.used_memory(), self.sys.total_memory())
    }

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
                .map(|p| TopProcess {
                    name: trim_proc_name(&p.name().to_string_lossy()).to_string(),
                    cpu_pct: p.cpu_usage(),
                    pid: Some(p.pid().as_u32()),
                })
                .unwrap_or_default();
        }
        self.tick = self.tick.wrapping_add(1);

        let mem_used_fraction = self.read_mem();
        let stat = CpuStat {
            sys: cpu.sys,
            user: cpu.user,
            total: cpu.sys + cpu.user,
            mem_used_fraction,
            top_proc: self.top.name.clone(),
            top_proc_pct: self.top.cpu_pct,
            top_pid: self.top.pid,
        };
        Some((
            Point {
                cpu,
                mem_used_fraction,
            },
            stat,
        ))
    }
}

pub fn install(app: tauri::AppHandle) {
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
            mem_used_fraction: i as f32,
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
        assert_eq!(series.mem_used_fraction.len(), 300);
        assert_eq!(series.cpu[0].sys, 5.0);
        assert_eq!(series.mem_used_fraction[0], 5.0);
        assert_eq!(series.cpu[299].sys, 304.0);
        assert_eq!(series.mem_used_fraction[299], 304.0);
    }

    #[test]
    fn snapshot_still_hands_the_bar_its_108_newest_cpu_samples() {
        let state = MetricsState::default();
        for i in 0..305 {
            let stat = CpuStat {
                mem_used_fraction: i as f32,
                ..CpuStat::default()
            };
            state.record(point(i), stat);
        }
        let snapshot = state.snapshot();
        assert_eq!(snapshot.history.len(), 108);
        assert_eq!(snapshot.history[0].sys, 197.0);
        assert_eq!(snapshot.history[107].sys, 304.0);
        assert_eq!(snapshot.latest.mem_used_fraction, 304.0);
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
            mem_used_fraction: 0.5,
        });
        history.push(Point {
            cpu: CpuSample {
                sys: 0.125,
                user: 0.25,
            },
            mem_used_fraction: 0.75,
        });
        assert_eq!(
            serde_json::to_value(history.series()).unwrap(),
            json!({
                "intervalMs": 2000,
                "capacitySecs": 600,
                "cpu": [{"sys": 0.25, "user": 0.5}, {"sys": 0.125, "user": 0.25}],
                "memUsedFraction": [0.5, 0.75],
            })
        );
    }

    #[test]
    fn cpu_event_carries_mem_beside_the_pill_readout() {
        let stat = CpuStat {
            sys: 0.25,
            user: 0.5,
            total: 0.75,
            mem_used_fraction: 0.5,
            top_proc: "kernel_task".into(),
            top_proc_pct: 12.5,
            top_pid: Some(0),
        };
        assert_eq!(
            serde_json::to_value(stat).unwrap(),
            json!({
                "sys": 0.25,
                "user": 0.5,
                "total": 0.75,
                "memUsedFraction": 0.5,
                "topProc": "kernel_task",
                "topProcPct": 12.5,
                "topPid": 0,
            })
        );
        assert_eq!(
            serde_json::to_value(CpuStat::default()).unwrap()["topPid"],
            serde_json::Value::Null
        );
    }

    #[test]
    fn the_bar_snapshot_says_how_many_columns_it_holds() {
        let snapshot = serde_json::to_value(MetricsState::default().snapshot()).unwrap();
        assert_eq!(snapshot["capacity"], json!(108));
    }

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
            .mem_used_fraction
            .iter()
            .fold((f32::MAX, f32::MIN), |(lo, hi), m| (lo.min(*m), hi.max(*m)));
        println!(
            "history: {} cpu / {} mem entries, intervalMs {}, bar snapshot {} columns",
            series.cpu.len(),
            series.mem_used_fraction.len(),
            series.interval_ms,
            snapshot.history.len()
        );
        println!(
            "mem fraction over the run: {mem_min:.4}..{mem_max:.4}; latest event mem {:.4}, cpu total {:.3}, top {} (pid {:?})",
            snapshot.latest.mem_used_fraction, snapshot.latest.total, snapshot.latest.top_proc, snapshot.latest.top_pid
        );
        assert!(series
            .mem_used_fraction
            .iter()
            .all(|m| *m > 0.0 && *m < 1.0));
        assert_eq!(series.cpu.len(), 12);

        let chart = sampler.read_mem();
        let rows = sample_metrics(&mut sysinfo::System::new(), 0.0);
        let rows_frac = rows.mem_used as f64 / rows.mem_total as f64;
        println!(
            "chart mem {chart:.5} vs rows memUsed/memTotal {rows_frac:.5} ({} of {} bytes)",
            rows.mem_used, rows.mem_total
        );
        assert!((chart as f64 - rows_frac).abs() < 0.02);

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
