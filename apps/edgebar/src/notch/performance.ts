import "./performance.css";
import { call } from "../ipc";
import { lucide } from "../icons";
import { resourceChart } from "./resource-chart";
import type { NotchView } from "./view";

const POLL_MS = 2000;
const HEALTH = {
  diskUsedPct: 90,
  // Bytes, not a percentage: macOS grows swap files on demand, so a small file
  // on a healthy machine reads as near-full.
  swapUsedBytes: 2 * 1024 ** 3,
} as const;

const METRICS = [
  {
    key: "cpu",
    label: "CPU",
    shapes:
      '<path d="M12 20v2"/><path d="M12 2v2"/><path d="M17 20v2"/><path d="M17 2v2"/><path d="M2 12h2"/><path d="M2 17h2"/><path d="M2 7h2"/><path d="M20 12h2"/><path d="M20 17h2"/><path d="M20 7h2"/><path d="M7 20v2"/><path d="M7 2v2"/><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="8" y="8" width="8" height="8" rx="1"/>',
  },
  {
    key: "mem",
    label: "Memory",
    shapes:
      '<path d="M12 12v-2"/><path d="M12 18v-2"/><path d="M16 12v-2"/><path d="M16 18v-2"/><path d="M2 11h1.5"/><path d="M20 18v-2"/><path d="M20.5 11H22"/><path d="M4 18v-2"/><path d="M8 12v-2"/><path d="M8 18v-2"/><rect x="2" y="6" width="20" height="10" rx="2"/>',
  },
  {
    key: "disk",
    label: "Disk",
    shapes:
      '<path d="M10 16h.01"/><path d="M2.212 11.577a2 2 0 0 0-.212.896V18a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-5.527a2 2 0 0 0-.212-.896L18.55 5.11A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><path d="M21.946 12.013H2.054"/><path d="M6 16h.01"/>',
  },
  {
    key: "swap",
    label: "Swap",
    shapes:
      '<path d="m3 16 4 4 4-4"/><path d="M7 20V4"/><path d="m21 8-4-4-4 4"/><path d="M17 4v16"/>',
  },
] as const;

type MetricKey = (typeof METRICS)[number]["key"];

const TEMPLATE =
  '<div class="view-head"><span class="view-title">Performance</span></div>' +
  '<div class="perf-chart"></div>' +
  '<div class="metrics">' +
  METRICS.map(
    (m) =>
      `<div class="metric" data-k="${m.key}"><span class="m-icon icon">${lucide(m.shapes)}</span>` +
      `<span class="m-label">${m.label}</span><span class="m-bar"><i></i></span><span class="m-val">—</span></div>`,
  ).join("") +
  "</div>";

const pctOf = (used: number, total: number) => (total > 0 ? (used / total) * 100 : 0);

export const performanceView: NotchView = {
  id: "performance",
  title: "Performance",
  icon: lucide(
    '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/><path d="M3.22 12H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27"/>',
  ),
  size: { w: 380, h: 352 },
  mount(root, ctx) {
    root.innerHTML = TEMPLATE;
    const chart = resourceChart(root.querySelector<HTMLElement>(".perf-chart")!);
    const bars = new Map<MetricKey, HTMLElement>();
    const values = new Map<MetricKey, HTMLElement>();
    for (const { key } of METRICS) {
      const el = root.querySelector<HTMLElement>(`.metric[data-k="${key}"]`)!;
      bars.set(key, el.querySelector<HTMLElement>(".m-bar i")!);
      values.set(key, el.querySelector<HTMLElement>(".m-val")!);
    }

    function setMetric(k: MetricKey, pct: number) {
      const clamped = Math.max(0, Math.min(100, pct));
      bars.get(k)!.style.width = `${clamped}%`;
      values.get(k)!.textContent = `${Math.round(clamped)}%`;
    }

    async function sample() {
      try {
        const m = await call("metrics_sample");
        setMetric("cpu", m.cpu);
        setMetric("mem", pctOf(m.memUsed, m.memTotal));
        setMetric("disk", pctOf(m.diskUsed, m.diskTotal));
        setMetric("swap", pctOf(m.swapUsed, m.swapTotal));
        const reasons: string[] = [];
        if (pctOf(m.diskUsed, m.diskTotal) >= HEALTH.diskUsedPct) {
          reasons.push("disk almost full");
        }
        if (m.swapUsed >= HEALTH.swapUsedBytes) reasons.push("heavy swap use");
        ctx.setAlert(reasons.length ? reasons.join(", ") : null);
      } catch {
      }
    }

    let timer: number | undefined;
    return {
      open: sample,
      show() {
        chart.show();
        if (timer !== undefined) return;
        sample();
        timer = window.setInterval(sample, POLL_MS);
      },
      hide() {
        chart.hide();
        clearInterval(timer);
        timer = undefined;
      },
    };
  },
};
