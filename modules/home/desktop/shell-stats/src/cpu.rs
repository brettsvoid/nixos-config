//! CPU usage from /proc/stat, temperature from hwmon.

use std::fs;

#[derive(Clone, Copy, Default)]
struct Times {
    busy: u64,
    total: u64,
}

pub struct Cpu {
    previous: Vec<Times>,
    temp_path: Option<String>,
}

pub struct CpuSample {
    /// Percent, all cores together.
    pub usage: f64,
    /// Percent per core.
    pub cores: Vec<f64>,
    /// Degrees Celsius, if a sensor was found.
    pub temp: Option<f64>,
}

impl Cpu {
    pub fn new() -> Self {
        Cpu {
            previous: read_times(),
            temp_path: find_temp_sensor(),
        }
    }

    pub fn sample(&mut self) -> CpuSample {
        let now = read_times();
        let usage: Vec<f64> = now
            .iter()
            .zip(
                self.previous
                    .iter()
                    .chain(std::iter::repeat(&Times::default())),
            )
            .map(|(n, p)| {
                let total = n.total.saturating_sub(p.total);
                let busy = n.busy.saturating_sub(p.busy);
                if total == 0 {
                    0.0
                } else {
                    100.0 * busy as f64 / total as f64
                }
            })
            .collect();
        self.previous = now;
        let temp = self
            .temp_path
            .as_ref()
            .and_then(|p| fs::read_to_string(p).ok())
            .and_then(|s| s.trim().parse::<f64>().ok())
            .map(|millidegrees| millidegrees / 1000.0);
        CpuSample {
            usage: usage.first().copied().unwrap_or(0.0),
            cores: usage.get(1..).map(|c| c.to_vec()).unwrap_or_default(),
            temp,
        }
    }
}

/// The "cpu" line, then one per core. Busy is everything but idle and iowait.
fn read_times() -> Vec<Times> {
    let Ok(stat) = fs::read_to_string("/proc/stat") else {
        return Vec::new();
    };
    stat.lines()
        .filter(|l| l.starts_with("cpu"))
        .map(|l| {
            let fields: Vec<u64> = l
                .split_whitespace()
                .skip(1)
                .filter_map(|f| f.parse().ok())
                .collect();
            let total: u64 = fields.iter().take(8).sum();
            let idle = fields.get(3).copied().unwrap_or(0) + fields.get(4).copied().unwrap_or(0);
            Times {
                busy: total.saturating_sub(idle),
                total,
            }
        })
        .collect()
}

/// The package sensor: Intel's coretemp "Package id 0", AMD's k10temp "Tctl", else the
/// first input of either driver.
fn find_temp_sensor() -> Option<String> {
    let mut fallback = None;
    for entry in fs::read_dir("/sys/class/hwmon").ok()?.flatten() {
        let dir = entry.path();
        let name = fs::read_to_string(dir.join("name")).unwrap_or_default();
        if !matches!(name.trim(), "coretemp" | "k10temp" | "zenpower") {
            continue;
        }
        for i in 1..=32 {
            let label = fs::read_to_string(dir.join(format!("temp{i}_label"))).unwrap_or_default();
            let input = dir.join(format!("temp{i}_input"));
            if !input.exists() {
                continue;
            }
            if matches!(label.trim(), "Package id 0" | "Tctl" | "Tdie") {
                return Some(input.to_string_lossy().into_owned());
            }
            fallback.get_or_insert_with(|| input.to_string_lossy().into_owned());
        }
    }
    fallback
}
