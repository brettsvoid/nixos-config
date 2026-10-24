import "./resource-chart.css";
import { call, on, type MetricsHistory } from "../ipc";
import { lucide } from "../icons";
import { fingersUp, wheelStepper } from "../wheel";
import type { Widget } from "./view";

const SPANS_S = [30, 60, 120, 300, 600] as const;
const START_SPAN = 2;
const WHEEL_PX = 60;
const LINE = 2;
const FILL_ALPHA = 0.3;
const GRID = [0.25, 0.5, 0.75];

type Rgb = [number, number, number];

const SERIES = [
  { key: "mem", label: "Memory" },
  { key: "cpu", label: "CPU" },
] as const;
type SeriesKey = (typeof SERIES)[number]["key"];

const MINUS = lucide('<path d="M5 12h14"/>');
const PLUS = lucide('<path d="M5 12h14"/><path d="M12 5v14"/>');

const spanLabel = (s: number) => (s < 60 ? `${s} s` : `${s / 60} min`);
const clamp01 = (v: number) => Math.max(0, Math.min(1, v));

const probe = Object.assign(document.createElement("canvas"), { width: 1, height: 1 }).getContext("2d", {
  willReadFrequently: true,
});
function rgbOf(css: string): Rgb {
  if (!probe) return [128, 128, 128];
  probe.clearRect(0, 0, 1, 1);
  probe.fillStyle = css;
  probe.fillRect(0, 0, 1, 1);
  const [r, g, b] = probe.getImageData(0, 0, 1, 1).data;
  return [r, g, b];
}
const rgba = ([r, g, b]: Rgb, a: number) => `rgba(${r}, ${g}, ${b}, ${a})`;

export const resourceChart: Widget = (root) => {
  root.classList.add("rc");
  root.innerHTML =
    '<div class="rc-head"><div class="rc-legend">' +
    SERIES.slice()
      .reverse()
      .map(
        (s) =>
          `<span class="rc-key" data-k="${s.key}"><i class="rc-swatch"></i>` +
          `<span class="rc-name">${s.label}</span><span class="rc-val">—</span></span>`,
      )
      .join("") +
    "</div>" +
    '<div class="rc-zoom">' +
    `<button class="rc-step" type="button" data-step="1" aria-label="Show more time">${MINUS}</button>` +
    '<span class="rc-span"></span>' +
    `<button class="rc-step" type="button" data-step="-1" aria-label="Show less time">${PLUS}</button>` +
    "</div></div>" +
    '<canvas class="rc-canvas"></canvas>';

  const canvas = root.querySelector<HTMLCanvasElement>(".rc-canvas")!;
  const ctx = canvas.getContext("2d");
  const spanEl = root.querySelector<HTMLElement>(".rc-span")!;
  const [zoomOut, zoomIn] = [...root.querySelectorAll<HTMLButtonElement>(".rc-step")];
  const keys = new Map(
    SERIES.map(({ key }) => {
      const el = root.querySelector<HTMLElement>(`.rc-key[data-k="${key}"]`)!;
      return [key, { swatch: el.querySelector<HTMLElement>(".rc-swatch")!, value: el.querySelector<HTMLElement>(".rc-val")! }];
    }),
  );

  const series: Record<SeriesKey, number[]> = { cpu: [], mem: [] };
  let intervalMs = 2000;
  let zoom: number = START_SPAN;
  let visible = false;

  const capacity = () => Math.round((SPANS_S[SPANS_S.length - 1] * 1000) / intervalMs);
  const shown = () => Math.max(2, Math.round((SPANS_S[zoom] * 1000) / intervalMs));

  function showLatest() {
    for (const { key } of SERIES) {
      const values = series[key];
      keys.get(key)!.value.textContent = values.length
        ? `${Math.round(values[values.length - 1] * 100)}%`
        : "—";
    }
  }

  function showZoom() {
    spanEl.textContent = spanLabel(SPANS_S[zoom]);
    zoomOut.disabled = zoom === SPANS_S.length - 1;
    zoomIn.disabled = zoom === 0;
  }

  function seed(h: MetricsHistory) {
    intervalMs = h.intervalMs || intervalMs;
    series.cpu = h.cpu.map((s) => clamp01(s.sys + s.user)).slice(-capacity());
    series.mem = h.memUsedFraction.map(clamp01).slice(-capacity());
  }

  function push(cpu: number, mem: number) {
    series.cpu.push(clamp01(cpu));
    series.mem.push(clamp01(mem));
    for (const values of Object.values(series)) if (values.length > capacity()) values.shift();
  }

  function paint() {
    if (!visible || !ctx) return;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (!w || !h) return;
    const dpr = window.devicePixelRatio || 1;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const top = LINE;
    const bottom = h - LINE;
    const y = (v: number) => bottom - v * (bottom - top);

    ctx.lineWidth = 1 / dpr;
    ctx.strokeStyle = getComputedStyle(root).getPropertyValue("--rc-grid").trim() || "rgba(128, 128, 128, 0.3)";
    for (const f of GRID) {
      const gy = (Math.round(y(f) * dpr) + 0.5) / dpr;
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(w, gy);
      ctx.stroke();
    }

    const n = shown();
    const step = w / (n - 1);
    for (const { key } of SERIES) {
      const values = series[key].slice(-n);
      if (values.length < 2) continue;
      const colour = rgbOf(getComputedStyle(keys.get(key)!.swatch).backgroundColor);
      const pts = values.map((v, i) => [w - (values.length - 1 - i) * step, y(v)] as const);
      const trace = () => {
        ctx.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length - 1; i++) {
          const [x, py] = pts[i];
          ctx.quadraticCurveTo(x, py, (x + pts[i + 1][0]) / 2, (py + pts[i + 1][1]) / 2);
        }
        ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
      };

      const peak = Math.min(...pts.map(([, py]) => py));
      const fill = ctx.createLinearGradient(0, peak, 0, bottom);
      fill.addColorStop(0, rgba(colour, FILL_ALPHA));
      fill.addColorStop(1, rgba(colour, 0));
      ctx.beginPath();
      trace();
      ctx.lineTo(pts[pts.length - 1][0], bottom);
      ctx.lineTo(pts[0][0], bottom);
      ctx.closePath();
      ctx.fillStyle = fill;
      ctx.fill();

      ctx.beginPath();
      trace();
      ctx.lineWidth = LINE;
      ctx.lineJoin = "round";
      ctx.lineCap = "round";
      ctx.strokeStyle = rgba(colour, 1);
      ctx.stroke();
    }
  }

  function setZoom(next: number) {
    const z = Math.max(0, Math.min(SPANS_S.length - 1, next));
    if (z === zoom) return;
    zoom = z;
    showZoom();
    paint();
  }

  for (const btn of [zoomOut, zoomIn]) {
    btn.addEventListener("click", () => setZoom(zoom + Number(btn.dataset.step)));
  }
  const steps = wheelStepper(WHEEL_PX, fingersUp);
  root.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const n = steps(e);
      if (n) setZoom(zoom - n);
    },
    { passive: false },
  );
  on("theme", () => requestAnimationFrame(paint));

  showZoom();

  let session = 0;
  let unlisten: (() => void) | null = null;

  return {
    show() {
      visible = true;
      const s = ++session;
      void (async () => {
        try {
          const history = await call("metrics_history");
          if (s !== session) return;
          seed(history);
        } catch {
        }
        showLatest();
        paint();
        const un = await on("cpu", (stat) => {
          push(stat.total, stat.memUsedFraction);
          showLatest();
          paint();
        });
        if (s === session) unlisten = un;
        else un();
      })();
    },
    hide() {
      visible = false;
      session++;
      unlisten?.();
      unlisten = null;
    },
  };
};
