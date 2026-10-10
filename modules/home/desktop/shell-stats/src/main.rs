//! Prints system statistics for the custom Quickshell shell's performance tab: one JSON
//! object per line, every second (or `--interval <ms>`), until stdout closes. `--once`
//! prints a single line. Missing hardware is reported as absent or null, never an error.

mod cpu;
mod disk;
mod gpu;
mod json;
mod memory;
mod net;

use json::Object;
use std::io::Write;
use std::time::Duration;

fn main() {
    let mut interval = Duration::from_millis(1000);
    let mut once = false;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--once" => once = true,
            "--interval" => {
                let ms = args.next().and_then(|v| v.parse().ok()).unwrap_or(1000u64);
                interval = Duration::from_millis(ms.max(100));
            }
            _ => {
                eprintln!("usage: shell-stats [--interval <ms>] [--once]");
                std::process::exit(2);
            }
        }
    }

    let mut cpu = cpu::Cpu::new();
    let mut net = net::Net::new();
    let mut gpu = gpu::Gpu::new();
    let stdout = std::io::stdout();
    loop {
        // Usage and throughput are differences, so the first line waits one interval.
        std::thread::sleep(interval);
        let line = record(&mut cpu, &mut net, &mut gpu);
        let mut out = stdout.lock();
        if writeln!(out, "{line}").and_then(|_| out.flush()).is_err() || once {
            break;
        }
    }
}

fn record(cpu: &mut cpu::Cpu, net: &mut net::Net, gpu: &mut gpu::Gpu) -> String {
    let c = cpu.sample();
    let cpu_json = Object::new()
        .number("usage", c.usage)
        .raw("cores", &json::numbers(&c.cores))
        .optional("temp", c.temp)
        .finish();

    let m = memory::sample();
    let memory_json = Object::new()
        .number("total", m.total)
        .number("used", m.used)
        .finish();
    let swap_json = Object::new()
        .number("total", m.swap_total)
        .number("used", m.swap_used)
        .finish();

    let gpu_json = match gpu.sample() {
        gpu::GpuSample::Absent => Object::new().text("state", "absent").finish(),
        gpu::GpuSample::Asleep => Object::new().text("state", "asleep").finish(),
        gpu::GpuSample::Unavailable => Object::new().text("state", "unavailable").finish(),
        gpu::GpuSample::Awake {
            name,
            usage,
            memory_used,
            memory_total,
            temp,
            power,
        } => Object::new()
            .text("state", "awake")
            .text("name", &name)
            .number("usage", usage)
            .number("memoryUsed", memory_used)
            .number("memoryTotal", memory_total)
            .optional("temp", temp)
            .optional("power", power)
            .finish(),
    };

    let disks: Vec<String> = disk::sample()
        .into_iter()
        .map(|d| {
            Object::new()
                .text("mount", &d.mount)
                .number("total", d.total)
                .number("used", d.used)
                .finish()
        })
        .collect();

    let n = net.sample();
    let net_json = Object::new().number("rx", n.rx).number("tx", n.tx).finish();

    Object::new()
        .raw("cpu", &cpu_json)
        .raw("memory", &memory_json)
        .raw("swap", &swap_json)
        .raw("gpu", &gpu_json)
        .raw("disks", &json::array(&disks))
        .raw("network", &net_json)
        .finish()
}
