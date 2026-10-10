//! Network throughput from /proc/net/dev, in bytes per second over the real interfaces
//! (not loopback, containers, bridges, VMs or tunnels).

use std::fs;
use std::time::Instant;

pub struct Net {
    previous: (u64, u64),
    at: Instant,
}

pub struct NetSample {
    pub rx: f64,
    pub tx: f64,
}

impl Net {
    pub fn new() -> Self {
        Net {
            previous: totals(),
            at: Instant::now(),
        }
    }

    pub fn sample(&mut self) -> NetSample {
        let now = totals();
        let seconds = self.at.elapsed().as_secs_f64().max(1e-3);
        let sample = NetSample {
            rx: now.0.saturating_sub(self.previous.0) as f64 / seconds,
            tx: now.1.saturating_sub(self.previous.1) as f64 / seconds,
        };
        self.previous = now;
        self.at = Instant::now();
        sample
    }
}

fn totals() -> (u64, u64) {
    let dev = fs::read_to_string("/proc/net/dev").unwrap_or_default();
    let mut rx = 0;
    let mut tx = 0;
    for line in dev.lines().skip(2) {
        let Some((name, rest)) = line.split_once(':') else {
            continue;
        };
        let name = name.trim();
        if name == "lo"
            || ["docker", "veth", "br-", "virbr", "vnet", "tun", "tap"]
                .iter()
                .any(|p| name.starts_with(p))
        {
            continue;
        }
        let fields: Vec<u64> = rest
            .split_whitespace()
            .filter_map(|f| f.parse().ok())
            .collect();
        rx += fields.first().copied().unwrap_or(0);
        tx += fields.get(8).copied().unwrap_or(0);
    }
    (rx, tx)
}
