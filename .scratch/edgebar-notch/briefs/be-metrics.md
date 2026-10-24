# Backend: memory history for the performance chart

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `metrics`.

The Performance view gets a history chart (ambxst's ResourceChart: CPU and RAM lines,
newest at the right, zoomable). lib.rs's always-on CPU sampler (`install_cpu_sampler`,
every 2 s) keeps 108 CPU samples for the bar's graph and nothing else.

Build:
- Each sampler tick also reads used memory as a fraction of RAM, computed the way
  `metrics_sample`'s `memUsed` is so the chart and the rows agree, without making the tick
  noticeably dearer (measure it).
- A longer ring: 300 samples (10 min at 2 s) of CPU and memory. `cpu_state` keeps
  returning the last 108 CPU samples, as the bar's graph needs exactly that many.
- `metrics_history` → `MetricsHistory` per ipc.ts; `CpuStat` (the `cpu` event) gains
  `mem`, so the chart appends live without polling.
Keep it in lib.rs next to the sampler, or move the sampler and metrics code into a new
`src-tauri/src/metrics.rs` if that leaves lib.rs simpler; your call, say which.
