//! Memory and swap from /proc/meminfo, in bytes.

use std::fs;

pub struct MemorySample {
    pub total: f64,
    pub used: f64,
    pub swap_total: f64,
    pub swap_used: f64,
}

pub fn sample() -> MemorySample {
    let info = fs::read_to_string("/proc/meminfo").unwrap_or_default();
    let field = |name: &str| -> f64 {
        info.lines()
            .find(|l| l.starts_with(name) && l[name.len()..].starts_with(':'))
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|kib| kib.parse::<f64>().ok())
            .map(|kib| kib * 1024.0)
            .unwrap_or(0.0)
    };
    let total = field("MemTotal");
    let swap_total = field("SwapTotal");
    MemorySample {
        total,
        // What `free` calls used: everything the kernel could not hand out now.
        used: total - field("MemAvailable"),
        swap_total,
        swap_used: swap_total - field("SwapFree"),
    }
}
