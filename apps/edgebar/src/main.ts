import "./styles.css";
import { animate, stagger } from "motion";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

interface Workspace {
  name: string;
  focused: boolean;
  has_windows: boolean;
  app: string; // app name for the dot's tooltip ("" if empty)
  icon: string; // PNG data URL, or "" when the workspace is empty
}

interface Config {
  colors: Record<string, string>;
  geometry: {
    innerRadius: number;
    lineThickness: number;
    pillHeight: number;
    pillRadius: number;
    concave: number;
    windowHeight: number;
  };
  appearance: string; // "light" | "dark" | "auto"
  scheme: string; // active matugen scheme (e.g. "scheme-tonal-spot")
  ink: InkInfo;
  notchIdle: string; // "handle" | "clock" | literal text
}

// How the on-pill ink (colors.base) was chosen — see ThemeState::resolve in lib.rs.
interface InkInfo {
  source: "config" | "contrast" | "override";
  ratio: number; // contrast of the ink in effect against the pill
  configured: string; // the role map's ink, before any correction
  configuredRatio: number;
  mode: "light" | "dark"; // the scheme it belongs to; an override edits this one
}

// One line of collapsed-notch content. Rust picks the winner (an OSD flash
// beats workspace context beats whatever is playing); null means the idle look.
interface NotchItem {
  tier: "transient" | "workspace" | "media";
  glyph: string; // icon name, used when `icon` is empty
  icon: string; // app icon PNG data URL, or ""
  art: string; // album art data URL, or "" — the media pill's backdrop
  primary: string;
  secondary: string;
  progress: number | null; // 0..1 hairline fill
  duration: number; // track length in seconds, 0 when unknown
  controls: boolean; // transport commands reach this source
  active: boolean; // false dims it (paused player)
}

interface ThemePayload {
  colors: Record<string, string>;
  appearance: string;
  scheme: string;
  ink: InkInfo;
}

interface Battery {
  present: boolean; // false on desktops — the readout is hidden entirely
  percent: number;
  state: string;
  time: string | null;
}

interface Metrics {
  cpu: number;
  memUsed: number;
  memTotal: number;
  swapUsed: number;
  swapTotal: number;
  diskUsed: number;
  diskTotal: number;
}

// One point on the CPU graph: fractions of total capacity, 0..1.
interface CpuSample {
  sys: number;
  user: number;
}

interface CpuStat extends CpuSample {
  total: number;
  topProc: string;
  topProcPct: number; // percent of one core, so >100 for a threaded process
  topPid: number; // 0 before the first process walk lands
}

interface CpuSnapshot {
  history: CpuSample[];
  latest: CpuStat;
}

interface Volume {
  output: number;
  input: number;
}

interface Network {
  state: string; // "wifi" | "vpn" | "off"
  label: string;
  rssi: number | null; // Wi-Fi signal in dBm when connected, else null
  online: boolean; // false = connected but no internet (only meaningful for "wifi")
}

// ---- tuned constants (named so each value lives in one place) ----
const SPRING = {
  panelOpen: { type: "spring", stiffness: 280, damping: 26 },
  panelClose: { type: "spring", stiffness: 320, damping: 30 },
  reveal: { type: "spring", stiffness: 420, damping: 26 },
  hide: { type: "spring", stiffness: 520, damping: 34 },
  popup: { type: "spring", stiffness: 300, damping: 26 },
} as const;
const FADE = { in: 0.25, inDelay: 0.08, out: 0.12 } as const; // seconds
const STAGGER = { reveal: 0.05, hide: 0.03 } as const; // seconds between pills
const POLL = {
  metrics: 2000,
  battery: 60000,
} as const; // ms (network is event-driven, so it has no poll)
const DEBOUNCE = { volume: 60, mic: 60, brightness: 40 } as const; // ms
// Thresholds for the performance tab's alert dot. Only disk and swap: CPU and
// memory swing too fast for a dot to mean anything.
const HEALTH = {
  diskUsedPct: 90,
  // Bytes, not a percentage: macOS grows swap files on demand, so a small file
  // on a healthy machine reads as near-full.
  swapUsedBytes: 2 * 1024 ** 3,
} as const;
// CPU histogram. `samples` must match CPU_HISTORY in lib.rs and equal `w`, so
// each column is exactly 1px (otherwise they blur); at CPU_POLL's 2s that's
// 3.6 min of history. `w`/`h` must match .cpu-graph in styles.css.
const CPU_GRAPH = {
  w: 108,
  h: 14,
  samples: 108,
  // Load ladder from the sketchybar helper; the colors live in styles.css.
  thresholds: { hot: 0.7, warm: 0.3, mild: 0.1 },
} as const;
const LAYOUT = {
  hiddenY: -48, // px above the top edge (clipped by the window)
  windowExpandedH: 280, // bar-window height while a panel is open
  popupTuck: -8, // px a dropdown starts tucked up (hidden) before sliding in
  settleDelay: 600, // ms to let the reveal spring settle before hit-testing
} as const;
// Collapsed notch sizing: one width per state, not sized to content, so the
// bar doesn't twitch on every track change. Long text marquees instead.
const NOTCH = {
  idleW: 200, // the bare handle
  itemW: 320, // any published item
  marquee: { pxPerSec: 26, minSec: 4, pause: 0.18 }, // scroll speed / dwell at each end
} as const;
// The media playhead, after Android's lock-screen player: a travelling sine
// over the played part, a rounded thumb, a flat rule for the rest. The sine
// flattens when paused. `wavelength` is in px so the pitch is width-independent;
// `ease` is the per-frame approach to the target amplitude; `speed` is rad/sec.
const WAVE = {
  amp: 2.2,
  wavelength: 22,
  speed: 2.4,
  ease: 0.15,
  line: 2,
  thumb: { w: 4, h: 12, gap: 2.5 }, // px; `gap` clears it either side
  rampPx: 8, // px of played track over which the wave swells to full amplitude
  fadeInPx: 3, // px over which it fades up from nothing — see the round-cap note
} as const;
const FALLBACK = { pillHeight: 32, windowHeight: 64 } as const; // if get_config fails; matches config.default.json
// Interactive-rect sentinel: the whole window is hit-testable while a panel is open.
const RECT_WHOLE_WINDOW: number[] = [0, 0, 1e5, 1e5];

// Apply the shared config (also read by the native frame) as CSS variables,
// then start the bar. styles.css holds fallback values.
invoke<Config>("get_config")
  .then((cfg) => {
    applyConfig(cfg);
    initBar(
      cfg.geometry.pillHeight,
      cfg.geometry.windowHeight,
      cfg.appearance,
      cfg.notchIdle,
      cfg.ink,
      cfg.colors.base,
    );
  })
  .catch(() =>
    initBar(FALLBACK.pillHeight, FALLBACK.windowHeight, "auto", "handle", null, ""),
  );

// Colour vars only; re-applied live on theme changes.
function applyColors(c: Record<string, string>) {
  const s = document.documentElement.style;
  s.setProperty("--base", c.base);
  s.setProperty("--pill-bg", c.pillBg);
  s.setProperty("--text", c.text);
  s.setProperty("--subtext", c.subtext);
  s.setProperty("--accent", c.accent);
  s.setProperty("--occupied", c.occupied);
  s.setProperty("--empty", c.empty);
  s.setProperty("--battery-charging", c.batteryCharging);
  s.setProperty("--battery-low", c.batteryLow);
  s.setProperty("--vpn", c.vpn);
  s.setProperty("--cpu-sys", c.cpuSys);
  s.setProperty("--cpu-user", c.cpuUser);
}

function applyConfig(cfg: Config) {
  const s = document.documentElement.style;
  const g = cfg.geometry;
  applyColors(cfg.colors);
  s.setProperty("--bezel-line-thickness", `${g.lineThickness}px`);
  s.setProperty("--pill-h", `${g.pillHeight}px`);
  s.setProperty("--pill-radius", `${g.pillRadius}px`);
  s.setProperty("--concave", `${g.concave}px`);
  s.setProperty("--window-h", `${g.windowHeight}px`);
}

// Coalesces slider drags into fewer IPC calls.
function debounce<A extends unknown[]>(fn: (...a: A) => void, ms: number) {
  let t: number | undefined;
  return (...a: A) => {
    window.clearTimeout(t);
    t = window.setTimeout(() => fn(...a), ms);
  };
}

interface Wallpaper {
  name: string;
  path: string;
  thumb: string; // data:image/png;base64,…
}

// Per-view panel geometry. All views share a height, so switching only moves
// the width. `win` is the bar-window height needed (overshoot included), 7×64.
// The default view's width is its column grid plus PANEL_CHROME.
const VIEW = {
  default: { w: 680, h: 400, win: 448 },
  theme: { w: 704, h: 400, win: 448 },
  metrics: { w: 460, h: 400, win: 448 }, // 56 of it is the rail
} as const;
// Panel width outside the tab body: side padding (2 × --space-6), the rail
// (48px) and its gap (--space-4). Keep in step with .notch-panel / .rail-tab.
const PANEL_CHROME = 12 * 2 + 48 + 8;
type ViewName = keyof typeof VIEW;

// matugen scheme types, in select-scheme.sh's order.
const SCHEMES = [
  "scheme-tonal-spot",
  "scheme-vibrant",
  "scheme-expressive",
  "scheme-content",
  "scheme-fidelity",
  "scheme-neutral",
  "scheme-monochrome",
  "scheme-rainbow",
  "scheme-fruit-salad",
] as const;

function initBar(
  pillHeight: number,
  windowHeight: number,
  appearance: string,
  notchIdle: string,
  ink: InkInfo | null,
  inkColour: string,
) {
  const pills = [...document.querySelectorAll<HTMLElement>(".pill")];

  let shown = false;
  let hovering = false;

  // Hover auto-hide, off because it fought the auto-hidden macOS menu bar.
  const AUTO_HIDE = false;

  // ---- expandable-panel window sizing ------------------------------------
  // Open panels need a taller (transparent) bar window. It's shared, so it's
  // tall while any panel is open and back to base once all are closed. Base is
  // geometry.windowHeight, the size lib.rs creates the window at.
  const WINDOW_BASE_H = windowHeight;
  const COLLAPSED_H = pillHeight;
  const openPanels = new Set<string>();
  // Bar-window height while a panel is open: the popup height by default,
  // raised by the notch's views (showView) and reset when the notch closes.
  let expandedWindowH: number = LAYOUT.windowExpandedH;
  let lastWindowH = -1;

  async function syncWindowHeight() {
    const target = openPanels.size > 0 ? expandedWindowH : WINDOW_BASE_H;
    if (target === lastWindowH) return;
    lastWindowH = target;
    await invoke("set_bar_size", {
      width: window.innerWidth,
      height: target,
    });
    reportInteractiveRects();
  }

  // True while the playhead is dragged. Like an open panel, it makes the whole
  // window interactive, or a scrub that strays off the pill would go
  // click-through and stop receiving pointer events.
  let scrubbing = false;
  let rectsScheduled = false;
  // Tell lib.rs's click-through tracker which regions stay interactive: the
  // pills, or the whole window while a popup is open (so an outside click
  // reaches the bar and closes it). Coalesced to one IPC per frame.
  function reportInteractiveRects() {
    if (rectsScheduled) return;
    rectsScheduled = true;
    requestAnimationFrame(() => {
      rectsScheduled = false;
      const rects =
        openPanels.size > 0 || scrubbing
          ? [RECT_WHOLE_WINDOW]
          : pills
              .map((p) => {
                const r = p.getBoundingClientRect();
                return [r.left, r.top, r.width, r.height];
              })
              .filter((r) => r[2] > 0 && r[3] > 0);
      invoke("set_interactive_rects", { rects }).catch(() => {});
    });
  }
  window.addEventListener("resize", reportInteractiveRects);

  interface PanelOpts {
    id: string;
    pill: HTMLElement;
    header: HTMLElement; // the always-visible strip that toggles expansion
    panel: HTMLElement; // the content faded in on expand
    width: number;
    height: number;
    onOpen?: () => void;
    onClose?: () => void;
    /// Width to collapse back to. Omit it to reuse the width captured on
    /// expand; the notch can't, as its collapsed width changes while open.
    collapsedWidth?: () => number;
  }

  interface Panel {
    pill: HTMLElement;
    isOpen: () => boolean;
    collapse: () => void;
  }

  function makePanel(o: PanelOpts): Panel {
    let open = false;
    let collapsedW = 0;

    async function expand() {
      if (open) return;
      open = true;
      collapsedW = o.pill.offsetWidth;
      o.onOpen?.();
      openPanels.add(o.id);
      await syncWindowHeight();
      animate(o.pill, { width: o.width, height: o.height }, SPRING.panelOpen);
      animate(o.panel, { opacity: 1 }, { duration: FADE.in, delay: FADE.inDelay });
    }

    async function collapse() {
      if (!open) return;
      open = false;
      o.onClose?.();
      animate(o.panel, { opacity: 0 }, { duration: FADE.out });
      const target = o.collapsedWidth?.() ?? collapsedW;
      await animate(
        o.pill,
        { width: target, height: COLLAPSED_H },
        SPRING.panelClose,
      ).finished;
      // Hand the width back to CSS, unless it comes from `collapsedWidth`,
      // which CSS knows nothing about.
      if (!o.collapsedWidth) o.pill.style.width = "";
      o.pill.style.height = "";
      openPanels.delete(o.id);
      await syncWindowHeight();
      if (AUTO_HIDE && !hovering) hideBar();
    }

    // Only the header toggles, so clicks on panel content don't collapse it.
    o.header.addEventListener("click", (e) => {
      e.stopPropagation();
      open ? collapse() : expand();
    });

    return { pill: o.pill, isOpen: () => open, collapse };
  }

  // ---- show / hide --------------------------------------------------------
  function showBar() {
    if (shown) return;
    shown = true;
    animate(
      pills,
      { y: 0, opacity: 1 },
      { ...SPRING.reveal, delay: stagger(STAGGER.reveal) },
    );
  }
  function hideBar() {
    if (!AUTO_HIDE) return;
    if (!shown || openPanels.size > 0) return;
    shown = false;
    animate(
      pills,
      { y: LAYOUT.hiddenY, opacity: 0 },
      { ...SPRING.hide, delay: stagger(STAGGER.hide) },
    );
  }

  document.addEventListener("mouseenter", () => {
    hovering = true;
    showBar();
  });
  document.addEventListener("mouseleave", () => {
    hovering = false;
    for (const p of panels) p.collapse();
    hideBar();
  });

  // ---- clock --------------------------------------------------------------
  // HH:MM, so it updates once a minute on the minute boundary.
  const timeEl = document.querySelector<HTMLElement>("#clock .time")!;
  const dateEl = document.querySelector<HTMLElement>("#clock .date")!;

  function updateCompactClock() {
    const now = new Date();
    timeEl.textContent = now.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
    dateEl.textContent = now.toLocaleDateString([], {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
  }
  function tickMinute() {
    updateCompactClock();
    // The notch's idle clock too, while no provider owns the slot.
    if (notchIdle === "clock" && !notchLive) renderNotch(null);
    // reschedule for the next minute boundary (no drift)
    window.setTimeout(tickMinute, 60000 - (Date.now() % 60000));
  }

  // ---- metrics (lazy: only sampled while the performance view is open) ----
  const metricBars = new Map<string, HTMLElement>();
  const metricVals = new Map<string, HTMLElement>();
  for (const el of document.querySelectorAll<HTMLElement>("#notch .metric")) {
    const k = el.dataset.k!;
    metricBars.set(k, el.querySelector<HTMLElement>(".m-bar i")!);
    metricVals.set(k, el.querySelector<HTMLElement>(".m-val")!);
  }
  function setMetric(k: string, pct: number) {
    const clamped = Math.max(0, Math.min(100, pct));
    metricBars.get(k)!.style.width = `${clamped}%`;
    metricVals.get(k)!.textContent = `${Math.round(clamped)}%`;
  }
  const pctOf = (used: number, total: number) =>
    total > 0 ? (used / total) * 100 : 0;
  function startMetrics() {
    if (metricsTimer !== undefined) return;
    sampleMetrics();
    metricsTimer = window.setInterval(sampleMetrics, POLL.metrics);
  }
  function stopMetrics() {
    clearInterval(metricsTimer);
    metricsTimer = undefined;
  }
  async function sampleMetrics() {
    try {
      const m = await invoke<Metrics>("metrics_sample");
      setMetric("cpu", m.cpu);
      setMetric("mem", pctOf(m.memUsed, m.memTotal));
      setMetric("disk", pctOf(m.diskUsed, m.diskTotal));
      setMetric("swap", pctOf(m.swapUsed, m.swapTotal));
      setHealth(m);
    } catch {
      /* sampling can fail mid-teardown; ignore */
    }
  }

  // Alert dot on the performance tab. The rail is only visible while the notch
  // is open, so there's no background poll: one sample on open, then the
  // metrics view's own cadence.
  const perfTab = document.querySelector<HTMLElement>('.rail-tab[data-to="metrics"]')!;
  const perfDot = document.querySelector<HTMLElement>("#perf-dot")!;
  function setHealth(m: Metrics) {
    const reasons: string[] = [];
    if (pctOf(m.diskUsed, m.diskTotal) >= HEALTH.diskUsedPct) {
      reasons.push("disk almost full");
    }
    if (m.swapUsed >= HEALTH.swapUsedBytes) reasons.push("heavy swap use");
    perfDot.hidden = reasons.length === 0;
    perfTab.title = reasons.length
      ? `Performance — ${reasons.join(", ")}`
      : "Performance";
  }

  // ---- centre notch: the dashboard / wallpapers / performance hub ---------
  let metricsTimer: number | undefined;
  const notchEl = document.querySelector<HTMLElement>("#notch")!;
  // Collapsed notch width, updated by renderNotch. Read on collapse so the pill
  // returns to the width for its *current* content, not the one it had on open.
  let notchCollapsedW: number = NOTCH.idleW;
  const notchPanel = makePanel({
    id: "notch",
    pill: notchEl,
    header: notchEl.querySelector<HTMLElement>(".notch-row")!,
    panel: notchEl.querySelector<HTMLElement>(".notch-panel")!,
    width: VIEW.default.w,
    height: VIEW.default.h,
    collapsedWidth: () => notchCollapsedW,
    onOpen: () => {
      showView("default"); // always open on the dashboard, as ambxst does
      sampleMetrics(); // one read, so the rail's alert dot is right on arrival
    },
    onClose: () => {
      stopMetrics();
      // Back to the popup height, so the controls/launcher popups don't
      // inherit the notch's taller window.
      expandedWindowH = LAYOUT.windowExpandedH;
    },
  });

  // ---- controls: volume / mic / brightness sliders -----------------------
  const controlsEl = document.querySelector<HTMLElement>("#controls")!;
  const volRange = controlsEl.querySelector<HTMLInputElement>(
    '.slider-row[data-k="volume"] .s-range',
  )!;
  const micRange = controlsEl.querySelector<HTMLInputElement>(
    '.slider-row[data-k="mic"] .s-range',
  )!;
  const briRange = controlsEl.querySelector<HTMLInputElement>(
    '.slider-row[data-k="brightness"] .s-range',
  )!;

  async function loadControls() {
    try {
      const v = await invoke<Volume>("get_volume");
      volRange.value = String(v.output);
      micRange.value = String(v.input);
      const br = await invoke<number>("get_brightness"); // 0..1
      briRange.value = String(Math.round(br * 100));
    } catch {
      /* ignore */
    }
  }
  volRange.addEventListener(
    "input",
    debounce(() => invoke("set_volume", { output: +volRange.value }), DEBOUNCE.volume),
  );
  micRange.addEventListener(
    "input",
    debounce(() => invoke("set_input_volume", { input: +micRange.value }), DEBOUNCE.mic),
  );
  briRange.addEventListener(
    "input",
    debounce(
      () => invoke("set_brightness", { value: +briRange.value / 100 }),
      DEBOUNCE.brightness,
    ),
  );

  // A floating dropdown with its own width, so the pill stays a small cog
  // button. Mirrors the launcher menu.
  const ctlBtn = document.querySelector<HTMLElement>("#ctl-btn")!;
  const ctlPanelEl = controlsEl.querySelector<HTMLElement>(".ctl-panel")!;
  let controlsOpen = false;
  animate(ctlPanelEl, { y: LAYOUT.popupTuck }, { duration: 0 }); // start tucked up (hidden)

  async function openControls() {
    if (controlsOpen) return;
    controlsOpen = true;
    openPanels.add("controls");
    await syncWindowHeight();
    await loadControls();
    ctlPanelEl.style.pointerEvents = "auto";
    animate(
      ctlPanelEl,
      { opacity: 1, y: 0 },
      SPRING.popup,
    );
  }
  async function closeControls() {
    if (!controlsOpen) return;
    controlsOpen = false;
    ctlPanelEl.style.pointerEvents = "none";
    await animate(
      ctlPanelEl,
      { opacity: 0, y: LAYOUT.popupTuck },
      { duration: FADE.out },
    ).finished;
    openPanels.delete("controls");
    await syncWindowHeight();
  }
  ctlBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    controlsOpen ? closeControls() : openControls();
  });
  // Same shape as makePanel() so outside-click / mouse-leave close it.
  const controlsPanel = {
    pill: controlsEl,
    isOpen: () => controlsOpen,
    collapse: closeControls,
  };

  // ---- launcher: ⌘ quick-actions menu (drops down from the workspaces pill)
  const wsPill = document.querySelector<HTMLElement>("#workspaces")!;
  const launcherBtn = document.querySelector<HTMLElement>("#launcher-btn")!;
  const menuPanel = wsPill.querySelector<HTMLElement>(".menu-panel")!;
  let launcherOpen = false;
  animate(menuPanel, { y: LAYOUT.popupTuck }, { duration: 0 }); // start tucked up (hidden)

  async function openLauncher() {
    if (launcherOpen) return;
    launcherOpen = true;
    openPanels.add("launcher");
    await syncWindowHeight();
    menuPanel.style.pointerEvents = "auto";
    animate(
      menuPanel,
      { opacity: 1, y: 0 },
      SPRING.popup,
    );
  }
  async function closeLauncher() {
    if (!launcherOpen) return;
    launcherOpen = false;
    menuPanel.style.pointerEvents = "none";
    await animate(
      menuPanel,
      { opacity: 0, y: LAYOUT.popupTuck },
      { duration: FADE.out },
    ).finished;
    openPanels.delete("launcher");
    await syncWindowHeight();
  }
  launcherBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    launcherOpen ? closeLauncher() : openLauncher();
  });
  for (const btn of menuPanel.querySelectorAll<HTMLElement>(".menu-item")) {
    btn.addEventListener("click", () => {
      invoke("launcher_action", { action: btn.dataset.action });
      closeLauncher();
    });
  }
  // Same shape as makePanel() so outside-click / mouse-leave close it.
  const launcherPanel = {
    pill: wsPill,
    isOpen: () => launcherOpen,
    collapse: closeLauncher,
  };

  const panels = [notchPanel, controlsPanel, launcherPanel];

  // Click outside an open panel collapses it.
  document.addEventListener("click", (e) => {
    const t = e.target as Node;
    for (const p of panels) {
      if (p.isOpen() && !p.pill.contains(t)) p.collapse();
    }
  });

  // ---- battery (polled; changes slowly) ----------------------------------
  // Inline Lucide battery SVGs, swapped by charge level / charging state. The
  // exact percentage is shown as text, so discrete level icons are enough.
  const lucide = (paths: string) =>
    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
  const BAT_SVG = {
    charging: lucide(
      '<path d="m11 7-3 5h4l-3 5"/><path d="M14.856 6H16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.935"/><path d="M22 14v-4"/><path d="M5.14 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2.936"/>',
    ),
    low: lucide('<path d="M22 14v-4"/><path d="M6 14v-4"/><rect x="2" y="6" width="16" height="12" rx="2"/>'),
    medium: lucide('<path d="M10 14v-4"/><path d="M22 14v-4"/><path d="M6 14v-4"/><rect x="2" y="6" width="16" height="12" rx="2"/>'),
    full: lucide('<path d="M10 10v4"/><path d="M14 10v4"/><path d="M22 14v-4"/><path d="M6 10v4"/><rect x="2" y="6" width="16" height="12" rx="2"/>'),
  };
  const batPill = document.querySelector<HTMLElement>("#battery")!;
  const batIcon = batPill.querySelector<HTMLElement>(".bat-icon")!;
  const batPct = batPill.querySelector<HTMLElement>(".bat-pct")!;
  let batTimer = 0;
  async function updateBattery() {
    try {
      const b = await invoke<Battery>("battery");
      // No battery (e.g. Mac mini): hide the group and stop polling.
      if (!b.present) {
        batPill.hidden = true;
        window.clearInterval(batTimer);
        return;
      }
      const charging = b.state !== "discharging";
      batIcon.innerHTML = charging
        ? BAT_SVG.charging
        : b.percent <= 20
          ? BAT_SVG.low
          : b.percent <= 60
            ? BAT_SVG.medium
            : BAT_SVG.full;
      batPct.textContent = `${b.percent}%`;
      batPill.classList.toggle("charging", charging && b.state !== "charged");
      batPill.classList.toggle("low", !charging && b.percent <= 20);
    } catch {
      /* ignore */
    }
  }
  updateBattery();
  batTimer = window.setInterval(updateBattery, POLL.battery);

  // ---- Wi-Fi / network (event-driven) -----------------------------------
  // The connected glyph is Lucide's wifi (dot + 3 arcs) with per-arc opacity,
  // macOS-style: dim arcs, with those up to the signal level solid. VPN and off
  // are static glyphs.
  const WIFI_PARTS = {
    dot: "M12 20h.01",
    arc1: "M8.5 16.429a5 5 0 0 1 7 0", // innermost (weakest signal)
    arc2: "M5 12.859a10 10 0 0 1 14 0",
    arc3: "M2 8.82a15 15 0 0 1 20 0", // outermost (strongest signal)
  };
  const WIFI_DIM = 0.25; // opacity of the inactive "grey base" arcs
  const WIFI_SVG_OPEN =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">';
  // level 0..3 = how many arcs are lit (the dot is always lit when connected).
  function wifiSignalSvg(level: number): string {
    const arc = (d: string, on: boolean) => `<path d="${d}" stroke-opacity="${on ? 1 : WIFI_DIM}"/>`;
    return (
      WIFI_SVG_OPEN +
      arc(WIFI_PARTS.dot, true) +
      arc(WIFI_PARTS.arc1, level >= 1) +
      arc(WIFI_PARTS.arc2, level >= 2) +
      arc(WIFI_PARTS.arc3, level >= 3) +
      "</svg>"
    );
  }
  // Connected but no internet: dim arcs over a solid exclamation (coloured by
  // .warn). The arcs are context only, not signal strength.
  const WIFI_WARN_SVG =
    WIFI_SVG_OPEN +
    `<path d="${WIFI_PARTS.arc3}" stroke-opacity="${WIFI_DIM}"/>` +
    `<path d="${WIFI_PARTS.arc2}" stroke-opacity="${WIFI_DIM}"/>` +
    '<path d="M12 12v4"/>' +
    '<path d="M12 20h.01"/>' +
    "</svg>";

  // dBm -> level, with hysteresis: a boundary must be crossed by WIFI_HYST dBm
  // before the level changes, so signal jitter near a threshold doesn't flicker
  // the icon. WIFI_BOUNDS are the dBm needed to *reach* levels 1, 2, 3.
  const WIFI_BOUNDS = [-82, -72, -60];
  const WIFI_HYST = 3; // dBm deadband on each side of a boundary
  function rssiToLevel(rssi: number | null, prev: number): number {
    if (rssi == null) return 3;
    let level = 0;
    for (let i = 0; i < WIFI_BOUNDS.length; i++) {
      // Already at/above this level? Demand a deeper drop before leaving it.
      const threshold = prev >= i + 1 ? WIFI_BOUNDS[i] - WIFI_HYST : WIFI_BOUNDS[i] + WIFI_HYST;
      if (rssi >= threshold) level = i + 1;
    }
    return level;
  }

  // Inline Lucide SVGs for the VPN and off states.
  const WIFI_SVG: Record<string, string> = {
    vpn: lucide(
      '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    ),
    off: lucide(
      '<path d="M12 20h.01"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><path d="M5 12.859a10 10 0 0 1 5.17-2.69"/><path d="M19 12.859a10 10 0 0 0-2.007-1.523"/><path d="M2 8.82a15 15 0 0 1 4.177-2.643"/><path d="M22 8.82a15 15 0 0 0-11.288-3.764"/><path d="m2 2 20 20"/>',
    ),
  };
  const wifiPill = document.querySelector<HTMLElement>("#wifi")!;
  const wifiIcon = wifiPill.querySelector<HTMLElement>(".wifi-icon")!;
  const wifiLabel = wifiPill.querySelector<HTMLElement>(".wifi-label")!;
  let wifiLevel = 3; // last committed signal level, kept for hysteresis
  function renderNetwork(n: Network) {
    const noNet = n.state === "wifi" && !n.online;
    if (n.state === "wifi" && n.online) {
      wifiLevel = rssiToLevel(n.rssi, wifiLevel);
      wifiIcon.innerHTML = wifiSignalSvg(wifiLevel);
      wifiIcon.title = n.rssi != null ? `${n.rssi} dBm` : "";
    } else {
      wifiIcon.innerHTML = noNet ? WIFI_WARN_SVG : (WIFI_SVG[n.state] ?? WIFI_SVG.off);
      wifiIcon.title = noNet ? "No internet" : "";
    }
    wifiLabel.textContent = n.label;
    wifiPill.classList.toggle("vpn", n.state === "vpn");
    wifiPill.classList.toggle("off", n.state === "off");
    wifiPill.classList.toggle("warn", noNet);
  }
  // Rust's reachability watcher pushes on every route change (connect,
  // disconnect, IP, VPN), re-checking online state each time. The initial fetch
  // covers a listener that attaches after Rust's startup push.
  invoke<Network>("network").then(renderNetwork).catch(() => {});
  listen<Network>("network", (e) => renderNetwork(e.payload));

  // ---- CPU pill: load graph + hungriest process (always on) --------------
  // Rust pushes a "cpu" event every CPU_POLL whether or not a panel is open.
  // It keeps the history too, so a bar rebuilt by a display change seeds itself
  // from cpu_state.
  const cpuPill = document.querySelector<HTMLElement>("#cpu")!;
  const cpuTopEl = cpuPill.querySelector<HTMLElement>(".cpu-top")!;
  const cpuNameEl = cpuPill.querySelector<HTMLElement>(".cpu-name")!;
  const cpuPidEl = cpuPill.querySelector<HTMLElement>(".cpu-pid")!;
  const cpuPctEl = cpuPill.querySelector<HTMLElement>(".cpu-pct")!;
  const cpuCanvas = cpuPill.querySelector<HTMLCanvasElement>(".cpu-graph")!;
  const cpuCtx = cpuCanvas.getContext("2d");
  const cpuHistory: CpuSample[] = [];

  const cssVar = (name: string) =>
    getComputedStyle(document.documentElement).getPropertyValue(name).trim();

  function drawCpuGraph() {
    if (!cpuCtx) return;
    const ctx = cpuCtx;
    const { w, h } = CPU_GRAPH;
    // Re-size the backing store when the DPR changes: the bar window can be
    // rebuilt onto a display with a different scale factor.
    const dpr = window.devicePixelRatio || 1;
    if (cpuCanvas.width !== Math.round(w * dpr)) {
      cpuCanvas.width = Math.round(w * dpr);
      cpuCanvas.height = Math.round(h * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    if (cpuHistory.length === 0) return;

    // One stacked column per sample: system from the baseline, user above it,
    // so a column's full height is total load.
    const colW = w / CPU_GRAPH.samples; // 1px, butted up with no gap
    const sysColor = cssVar("--cpu-sys");
    const userColor = cssVar("--cpu-user");

    cpuHistory.forEach((s, i) => {
      // Newest column flush right; a part-filled buffer leaves the left blank.
      const x = w - (cpuHistory.length - i) * colW;
      // Clamp the stack, not each part: a rounding overshoot past 100% should
      // cost the upper segment rather than draw outside the box.
      const sysH = Math.max(0, Math.min(1, s.sys)) * h;
      const userH = Math.max(0, Math.min(1 - s.sys, s.user)) * h;
      ctx.fillStyle = sysColor;
      ctx.fillRect(x, h - sysH, colW, sysH);
      ctx.fillStyle = userColor;
      ctx.fillRect(x, h - sysH - userH, colW, userH);
    });
  }

  function renderCpu(stat: CpuStat) {
    cpuNameEl.textContent = stat.topProc || "—";
    cpuPidEl.textContent = stat.topPid ? String(stat.topPid) : "";
    cpuTopEl.title = stat.topProc
      ? `${stat.topProc} (pid ${stat.topPid}) — ${Math.round(stat.topProcPct)}% of one core`
      : "";
    cpuPctEl.textContent = `${Math.round(stat.total * 100)}%`;
    const t = CPU_GRAPH.thresholds;
    cpuPill.classList.toggle("hot", stat.total >= t.hot);
    cpuPill.classList.toggle("warm", stat.total >= t.warm && stat.total < t.hot);
    cpuPill.classList.toggle("mild", stat.total >= t.mild && stat.total < t.warm);
  }

  listen<CpuStat>("cpu", (e) => {
    cpuHistory.push({ sys: e.payload.sys, user: e.payload.user });
    if (cpuHistory.length > CPU_GRAPH.samples) cpuHistory.shift();
    renderCpu(e.payload);
    drawCpuGraph();
  });
  invoke<CpuSnapshot>("cpu_state")
    .then((s) => {
      // Skip if the sampler's first push beat this reply; the event is newer.
      if (cpuHistory.length > 0 || s.history.length === 0) return;
      cpuHistory.push(...s.history.slice(-CPU_GRAPH.samples));
      renderCpu(s.latest);
      drawCpuGraph();
    })
    .catch(() => {});

  // ---- workspaces: event-driven (Rust pushes on AeroSpace changes) -------
  const wsContainer = document.querySelector<HTMLElement>("#workspaces .ws-dots")!;
  const wsEls = new Map<string, HTMLElement>();

  function renderWorkspaces(list: Workspace[]) {
    for (const [name, el] of wsEls) {
      if (!list.some((w) => w.name === name)) {
        el.remove();
        wsEls.delete(name);
      }
    }
    for (const w of list) {
      let el = wsEls.get(w.name);
      if (!el) {
        el = document.createElement("div");
        el.className = "ws";
        const img = document.createElement("img");
        img.className = "ws-icon";
        img.alt = "";
        el.appendChild(img);
        el.addEventListener("click", () =>
          invoke("aerospace_focus", { name: w.name }),
        );
        wsEls.set(w.name, el);
        wsContainer.appendChild(el);
      }
      // Occupied workspaces show the app icon; empty ones stay as small dots.
      const img = el.querySelector<HTMLImageElement>(".ws-icon")!;
      const hasIcon = !!w.icon;
      if (hasIcon) img.src = w.icon;
      else img.removeAttribute("src");
      el.classList.toggle("has-icon", hasIcon);
      el.classList.toggle("active", w.focused);
      el.classList.toggle("occupied", w.has_windows && !w.focused);
      el.title = w.app ? `${w.app} — workspace ${w.name}` : `workspace ${w.name}`;
    }
    for (const w of list) wsContainer.appendChild(wsEls.get(w.name)!);
    reportInteractiveRects(); // dot count/width changes the workspaces pill
  }

  listen<Workspace[]>("workspaces", (e) => renderWorkspaces(e.payload));
  invoke<Workspace[]>("aerospace_workspaces") // initial state
    .then(renderWorkspaces)
    .catch(() => {});

  // ---- notch content: whatever the winning provider published ------------
  // Rust picks what the notch says (see notch.rs) and pushes one item, or null;
  // only the idle look is decided here.
  const NOTCH_GLYPH: Record<string, string> = {
    music: lucide(
      '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
    ),
    volume: lucide(
      '<path d="M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"/><path d="M16 9a5 5 0 0 1 0 6"/><path d="M19.364 18.364a9 9 0 0 0 0-12.728"/>',
    ),
    mic: lucide(
      '<path d="M12 19v3"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><rect x="9" y="2" width="6" height="13" rx="3"/>',
    ),
    brightness: lucide(
      '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    ),
    window: lucide(
      '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/>',
    ),
    terminal: lucide('<path d="m4 17 6-6-6-6"/><path d="M12 19h8"/>'),
    clock: lucide('<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>'),
  };

  const notchRow = notchEl.querySelector<HTMLElement>(".notch-row")!;
  const notchHandle = notchRow.querySelector<HTMLElement>(".notch-handle")!;
  const notchItem = notchRow.querySelector<HTMLElement>(".notch-item")!;
  const niIcon = notchItem.querySelector<HTMLElement>(".ni-icon")!;
  const niPrimary = notchItem.querySelector<HTMLElement>(".ni-primary")!;
  const niSecondary = notchItem.querySelector<HTMLElement>(".ni-secondary")!;
  const niProgress = notchItem.querySelector<HTMLElement>(".ni-progress i")!;

  // Set a line's text and marquee it if it overflows the fixed box; an
  // ellipsis would hide the half of a title that tells tracks apart.
  function setLine(box: HTMLElement, text: string) {
    const inner = box.firstElementChild as HTMLElement;
    if (inner.textContent !== text) inner.textContent = text;
    box.classList.remove("scroll");
    box.style.removeProperty("--ni-shift");
    box.style.removeProperty("--ni-dur");
    // Measured after the text lands; scrollWidth is the unclipped content.
    const overflow = inner.scrollWidth - box.clientWidth;
    if (overflow <= 1) return;
    const travel = Math.max(
      NOTCH.marquee.minSec,
      overflow / NOTCH.marquee.pxPerSec,
    );
    box.style.setProperty("--ni-shift", `${overflow}px`);
    // Two passes plus a dwell at each end, so one cycle is there-and-back.
    box.style.setProperty(
      "--ni-dur",
      `${(travel + NOTCH.marquee.pause * travel) * 2}s`,
    );
    box.classList.add("scroll");
  }

  // The idle look is a synthetic item, so one renderer covers both cases.
  function idleItem(): NotchItem | null {
    if (notchIdle === "handle") return null;
    const now = new Date();
    const clock = notchIdle === "clock";
    return {
      tier: "media",
      glyph: clock ? "clock" : "",
      icon: "",
      art: "",
      primary: clock
        ? now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
        : notchIdle,
      secondary: clock
        ? now.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" })
        : "",
      progress: null,
      duration: 0,
      controls: false,
      active: true,
    };
  }

  // ---- media pill: art backdrop, wavy playhead, working transport ---------
  const niMedia = notchRow.querySelector<HTMLElement>(".ni-media")!;
  const nmArt = niMedia.querySelector<HTMLElement>(".nm-art")!;
  const nmPlay = niMedia.querySelector<HTMLButtonElement>(".nm-play")!;
  const nmWave = niMedia.querySelector<HTMLCanvasElement>(".nm-wave")!;
  const nmSource = niMedia.querySelector<HTMLElement>(".nm-source")!;
  const waveCtx = nmWave.getContext("2d");
  // Playhead colours are set on .nm-wave, not :root, so read them from there.
  const mediaVar = (name: string) =>
    getComputedStyle(nmWave).getPropertyValue(name).trim();
  // Solid glyphs: Lucide's outlines read as hollow at this size.
  const TRANSPORT_SVG = {
    play: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M8 5.14v13.72a1 1 0 0 0 1.54.84l10.1-6.86a1 1 0 0 0 0-1.68L9.54 4.3A1 1 0 0 0 8 5.14z"/></svg>',
    pause:
      '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M7 4h3.2v16H7zm6.8 0H17v16h-3.2z"/></svg>',
  };

  // Playhead state. `progress` is the last position Rust published and `t0`
  // when it arrived, so the head advances between the 2s polls. `amp`/`phase`
  // drive the wave.
  const media = { progress: 0, duration: 0, playing: false, t0: 0, amp: 0, phase: 0, last: 0 };

  function playedFraction(): number {
    const p =
      media.playing && media.duration > 0
        ? media.progress + (performance.now() - media.t0) / 1000 / media.duration
        : media.progress;
    return Math.max(0, Math.min(1, p));
  }

  function paintWave() {
    if (!waveCtx) return;
    const w = nmWave.clientWidth;
    const h = nmWave.clientHeight;
    if (!w || !h) return;
    // Re-size the backing store when the DPR changes, as the CPU graph does.
    const dpr = window.devicePixelRatio || 1;
    if (nmWave.width !== Math.round(w * dpr)) {
      nmWave.width = Math.round(w * dpr);
      nmWave.height = Math.round(h * dpr);
    }
    waveCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    waveCtx.clearRect(0, 0, w, h);

    const y = h / 2;
    // Inset by a full stroke width, not half: at half, the round cap's outer
    // edge sits exactly on x=0, where antialiasing shaves it flat.
    const pad = WAVE.line;
    const t = WAVE.thumb;
    // The thumb also needs its half-width, or it clips at 0% and 100%.
    const lo = pad + t.w / 2;
    const hi = w - pad - t.w / 2;
    // Map across the thumb's usable travel. Mapping across the full width and
    // clamping would park the thumb at `lo` for the first seconds of a track.
    const head = lo + (hi - lo) * playedFraction();
    waveCtx.lineWidth = WAVE.line;
    // Round caps for domed ends; round joins so the sine's crests don't mitre.
    waveCtx.lineCap = "round";
    waveCtx.lineJoin = "round";

    // Remainder: a flat rule in the muted tone, starting clear of the thumb.
    waveCtx.strokeStyle = mediaVar("--nm-remaining");
    const restFrom = head + t.w / 2 + t.gap;
    if (restFrom < w - pad) {
      waveCtx.beginPath();
      waveCtx.moveTo(restFrom, y);
      waveCtx.lineTo(w - pad, y);
      waveCtx.stroke();
    }

    // Played: the wave. Amplitude eases to 0 on pause, so this also draws the
    // flat paused line.
    waveCtx.strokeStyle = mediaVar("--nm-played");
    const waveTo = head - t.w / 2 - t.gap;
    if (waveTo > pad) {
      const len = waveTo - pad;
      // Swell the amplitude over the first stretch, so the squiggle grows out
      // of the left edge.
      const grow = Math.min(1, len / WAVE.rampPx);
      // Fade it in over a shorter run: round caps paint even a hairline-long
      // stroke as a line-width blob, which would otherwise pop in.
      const fade = Math.min(1, len / WAVE.fadeInPx);
      const waveY = (x: number) =>
        y + media.amp * grow * Math.sin((2 * Math.PI * x) / WAVE.wavelength + media.phase);
      waveCtx.globalAlpha = fade;
      waveCtx.beginPath();
      waveCtx.moveTo(pad, waveY(pad));
      for (let x = pad + 1; x < waveTo; x += 1) waveCtx.lineTo(x, waveY(x));
      // Finish exactly at waveTo, not the last whole pixel, or the gap to the
      // moving thumb jitters by a pixel.
      waveCtx.lineTo(waveTo, waveY(waveTo));
      waveCtx.stroke();
      waveCtx.globalAlpha = 1;
    }

    // Thumb: the rounded upright between the two, marking the position.
    waveCtx.lineWidth = t.w;
    waveCtx.beginPath();
    waveCtx.moveTo(head, y - t.h / 2 + t.w / 2);
    waveCtx.lineTo(head, y + t.h / 2 - t.w / 2);
    waveCtx.stroke();
  }

  let waveRaf = 0;
  function waveFrame(now: number) {
    waveRaf = 0;
    const dt = media.last ? Math.min(0.05, (now - media.last) / 1000) : 0;
    media.last = now;
    media.amp += ((media.playing ? WAVE.amp : 0) - media.amp) * WAVE.ease;
    if (!media.playing && media.amp < 0.05) media.amp = 0; // settle, don't wobble
    if (media.playing) media.phase += WAVE.speed * dt;
    paintWave();
    // Loop only while something moves: playing, or flattening after a pause.
    if (!niMedia.hidden && (media.playing || media.amp > 0)) {
      waveRaf = requestAnimationFrame(waveFrame);
    }
  }
  function startWave() {
    if (waveRaf) return;
    media.last = 0;
    waveRaf = requestAnimationFrame(waveFrame);
  }

  function setMedia(item: NotchItem) {
    nmArt.style.backgroundImage = item.art ? `url("${item.art}")` : "";
    niMedia.classList.toggle("has-art", !!item.art);
    nmSource.innerHTML = item.icon ? `<img src="${item.icon}" alt="">` : "";
    niMedia.title = item.secondary ? `${item.primary} — ${item.secondary}` : item.primary;
    syncPlayhead(item);
  }

  // Re-anchor the playhead to a freshly published position. Also sets the
  // transport glyph, since play/pause doesn't trigger a re-render (see identity).
  function syncPlayhead(item: NotchItem) {
    // Mid-drag the cursor owns the position — a poll landing now would yank the
    // head back to where the player still thinks it is.
    if (!scrubbing) media.progress = item.progress ?? 0;
    media.duration = item.duration;
    media.playing = item.active;
    media.t0 = performance.now();
    nmPlay.innerHTML = item.active ? TRANSPORT_SVG.pause : TRANSPORT_SVG.play;
    startWave();
  }

  nmPlay.addEventListener("click", (e) => {
    e.stopPropagation(); // the row is the panel's toggle; the button isn't
    // Flip optimistically so the glyph and wave respond at once; Rust
    // re-publishes the real state a moment later.
    media.progress = playedFraction();
    media.playing = !media.playing;
    media.t0 = performance.now();
    nmPlay.innerHTML = media.playing ? TRANSPORT_SVG.pause : TRANSPORT_SVG.play;
    startWave();
    invoke("media_toggle").catch(() => {});
  });

  // Scrubbing: map the pointer through the same inset travel paintWave draws
  // the thumb along, so the head stays under the cursor at the ends.
  function fractionAt(clientX: number): number {
    const r = nmWave.getBoundingClientRect();
    const lo = WAVE.line + WAVE.thumb.w / 2;
    const hi = r.width - WAVE.line - WAVE.thumb.w / 2;
    return Math.max(0, Math.min(1, (clientX - r.left - lo) / (hi - lo)));
  }

  // Move the playhead now; seek the player only on release.
  function scrubTo(clientX: number, commit: boolean) {
    media.progress = fractionAt(clientX);
    media.t0 = performance.now();
    // A paused player has no animation loop, so paint by hand.
    paintWave();
    if (commit) invoke("media_seek", { fraction: media.progress }).catch(() => {});
  }

  nmWave.addEventListener("pointerdown", (e) => {
    e.stopPropagation();
    scrubbing = true;
    // Capture keeps move/up events coming even when the cursor leaves the bar.
    nmWave.setPointerCapture(e.pointerId);
    reportInteractiveRects();
    scrubTo(e.clientX, false);
  });
  nmWave.addEventListener("pointermove", (e) => {
    if (!scrubbing) return;
    scrubTo(e.clientX, false);
  });
  for (const type of ["pointerup", "pointercancel"] as const) {
    nmWave.addEventListener(type, (e) => {
      if (!scrubbing) return;
      scrubbing = false;
      nmWave.releasePointerCapture(e.pointerId);
      scrubTo(e.clientX, true);
      reportInteractiveRects();
    });
  }
  // The row is the panel's toggle, and a scrub ends in a click on it.
  nmWave.addEventListener("click", (e) => e.stopPropagation());

  // What makes an item visually *different*. Excludes `progress`, which every
  // 2s media poll advances; position moves in place without a crossfade.
  function identity(i: NotchItem | null): string {
    if (!i) return "";
    const parts: unknown[] = [
      i.tier,
      i.primary,
      i.secondary,
      i.glyph,
      i.icon.length,
      i.art.length,
      i.controls,
    ];
    // Play/pause isn't part of a media pill's identity: the wave already
    // animates it, and a crossfade would flash the art. The text layout has no
    // such animation, so there it counts.
    if (!wantsMediaPill(i)) parts.push(i.active);
    return parts.join("|");
  }

  // A driveable player gets the media pill; anything else, including an
  // audible app we can only name, gets the icon and text line.
  const wantsMediaPill = (i: NotchItem | null) => !!i && i.tier === "media" && i.controls;

  function setProgress(item: NotchItem) {
    niProgress.style.width = `${(item.progress ?? 0) * 100}%`;
    notchItem.classList.toggle("has-progress", item.progress != null);
  }

  let notchLive: NotchItem | null = null; // the item Rust last pushed (null = idle)
  function renderNotch(item: NotchItem | null) {
    notchLive = item;
    const shown = item ?? idleItem();
    const asMedia = wantsMediaPill(shown);
    notchItem.hidden = !shown || asMedia;
    niMedia.hidden = !asMedia;
    notchHandle.hidden = !!shown;
    notchRow.classList.toggle("media", asMedia);
    if (asMedia) {
      setMedia(shown!);
    } else if (shown) {
      const hasIcon = !!shown.icon;
      niIcon.innerHTML = hasIcon
        ? `<img src="${shown.icon}" alt="">`
        : (NOTCH_GLYPH[shown.glyph] ?? "");
      niIcon.hidden = !hasIcon && !NOTCH_GLYPH[shown.glyph];
      niSecondary.hidden = !shown.secondary;
      setLine(niPrimary, shown.primary);
      setLine(niSecondary, shown.secondary);
      setProgress(shown);
      notchItem.classList.toggle("dim", !shown.active);
      notchItem.title = shown.secondary
        ? `${shown.primary} — ${shown.secondary}`
        : shown.primary;
    }

    const width = shown ? NOTCH.itemW : NOTCH.idleW;
    if (width === notchCollapsedW) return;
    notchCollapsedW = width;
    // While a panel is open the view owns the width; collapse picks the new
    // value up via `collapsedWidth`. Report rects once the spring settles, not
    // mid-flight.
    if (!notchPanel.isOpen()) {
      animate(notchEl, { width }, SPRING.panelOpen)
        .finished.then(reportInteractiveRects)
        .catch(() => {}); // superseded by a newer item; that one reports instead
    }
  }

  function pushNotch(item: NotchItem | null) {
    // Same content, new position: update only the playhead or hairline.
    if (item && identity(item) === identity(notchLive)) {
      notchLive = item;
      if (wantsMediaPill(item)) syncPlayhead(item);
      else setProgress(item);
      return;
    }
    notchLive = item;
    // New content: crossfade. The row holds two layouts (text and media pill),
    // so fade out whichever is visible now and fade in whichever is visible
    // after the render; fading a fixed one would strand the other at opacity 0.
    const outgoing = niMedia.hidden ? notchItem : niMedia;
    animate(outgoing, { opacity: 0 }, { duration: FADE.out })
      .finished.then(() => {
        renderNotch(item);
        const incoming = niMedia.hidden ? notchItem : niMedia;
        if (outgoing !== incoming) outgoing.style.opacity = "1"; // it's hidden now
        incoming.style.opacity = "0"; // start the fade from a known state
        animate(incoming, { opacity: 1 }, { duration: FADE.in });
      })
      .catch(() => {});
  }

  listen<NotchItem | null>("notch", (e) => pushNotch(e.payload));
  invoke<NotchItem | null>("notch_state") // whatever was already winning
    .then((item) => renderNotch(item))
    .catch(() => renderNotch(null));

  // ---- notch views: switching, appearance, wallpaper picker, scheme -------
  const notchPanelEl = notchEl.querySelector<HTMLElement>(".notch-panel")!;
  // One element per VIEW key. A new view needs an entry here, a `.view-<name>`
  // div, a VIEW size and a rail tab.
  const viewEls: Record<ViewName, HTMLElement> = {
    default: notchPanelEl.querySelector<HTMLElement>(".view-default")!,
    theme: notchPanelEl.querySelector<HTMLElement>(".view-theme")!,
    metrics: notchPanelEl.querySelector<HTMLElement>(".view-metrics")!,
  };
  const tabBody = notchPanelEl.querySelector<HTMLElement>(".tab-body")!;
  const railTabs = [
    ...notchPanelEl.querySelectorAll<HTMLElement>(".rail-tab[data-to]"),
  ];
  const filmstrip = document.querySelector<HTMLElement>("#filmstrip")!;
  const schemeSelect = document.querySelector<HTMLSelectElement>("#scheme-select")!;
  let currentView: ViewName = "default";
  let themeLoaded = false;

  function showView(view: ViewName) {
    currentView = view;
    // Pin the body to the view's final width before the pill springs, or fluid
    // layouts inside (the wallpaper grid's auto-fill) reflow every frame.
    // .notch-panel-clip crops it while the pill catches up.
    tabBody.style.width = `${VIEW[view].w - PANEL_CHROME}px`;
    for (const name of Object.keys(viewEls) as ViewName[]) {
      viewEls[name].hidden = name !== view;
    }
    // The rail survives the view swap, so move its highlight.
    for (const tab of railTabs) {
      tab.classList.toggle("active", tab.dataset.to === view);
    }
    expandedWindowH = VIEW[view].win;
    // Sampling follows the view, not the panel: ambxst polls SystemResources
    // only while its metrics tab is the open one.
    if (view === "metrics") startMetrics();
    else stopMetrics();
  }

  async function switchView(view: ViewName) {
    if (currentView === view) return;
    showView(view);
    animate(notchEl, { width: VIEW[view].w, height: VIEW[view].h }, SPRING.panelOpen);
    await syncWindowHeight();
    if (view === "theme") loadThemeView();
  }

  for (const btn of notchPanelEl.querySelectorAll<HTMLElement>(".view-switch")) {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      switchView(btn.dataset.to as ViewName);
    });
  }

  // Appearance: set_appearance persists the choice, re-resolves colours and
  // emits "theme". Auto follows the macOS setting (Rust observes it).
  const themeOpts = [...document.querySelectorAll<HTMLElement>(".theme-opt")];
  function setActiveMode(mode: string) {
    for (const b of themeOpts)
      b.classList.toggle("active", b.dataset.mode === mode);
  }
  setActiveMode(appearance);
  for (const b of themeOpts) {
    b.addEventListener("click", (e) => {
      e.stopPropagation();
      const mode = b.dataset.mode!;
      setActiveMode(mode);
      invoke("set_appearance", { mode });
    });
  }

  // Ink: the colour drawn on the pills. Auto is Rust's contrast-checked pick;
  // the swatch opens the system colour picker and pins an ink for the current
  // light/dark scheme. Both report back through the "theme" event.
  const inkAuto = document.querySelector<HTMLElement>("#ink-auto")!;
  const inkCustom = document.querySelector<HTMLElement>("#ink-custom")!;
  const inkSwatch = inkCustom.querySelector<HTMLElement>(".ink-swatch")!;
  function renderInk(info: InkInfo, colour: string) {
    inkColour = colour;
    const pinned = info.source === "override";
    inkAuto.classList.toggle("active", !pinned);
    inkCustom.classList.toggle("active", pinned);
    inkSwatch.style.background = colour;
    const ratio = (r: number) => `${r.toFixed(1)}:1`;
    inkAuto.title = pinned
      ? "Back to auto (contrast-checked)"
      : info.source === "contrast"
        ? `Auto: ${colour}, ${ratio(info.ratio)} on the pill ` +
          `(the scheme's ${info.configured} was only ${ratio(info.configuredRatio)})`
        : `Auto: ${colour}, ${ratio(info.ratio)} on the pill`;
    inkCustom.title = pinned
      ? `Custom ${info.mode} ink: ${colour}, ${ratio(info.ratio)} on the pill`
      : `Pick a ${info.mode} ink…`;
  }
  if (ink) renderInk(ink, inkColour);
  inkAuto.addEventListener("click", (e) => {
    e.stopPropagation();
    invoke("set_ink", { colour: null });
  });
  inkCustom.addEventListener("click", (e) => {
    e.stopPropagation();
    invoke<string | null>("pick_colour", { initial: inkColour }).then((colour) => {
      if (colour) invoke("set_ink", { colour });
    });
  });

  // Wallpaper grid: a thumb sets the desktop and re-themes the bar (Rust runs
  // desktoppr and generate-edgebar-theme).
  function renderFilmstrip(wallpapers: Wallpaper[], current: string) {
    filmstrip.replaceChildren();
    for (const w of wallpapers) {
      const b = document.createElement("button");
      b.className = "thumb";
      b.classList.toggle("active", w.path === current);
      b.title = w.name;
      const img = document.createElement("img");
      img.src = w.thumb;
      img.alt = w.name;
      b.appendChild(img);
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        invoke("set_wallpaper", { path: w.path });
        for (const t of filmstrip.children) t.classList.remove("active");
        b.classList.add("active");
      });
      filmstrip.appendChild(b);
    }
  }

  let schemesBuilt = false;
  function renderSchemes(active: string) {
    if (!schemesBuilt) {
      for (const s of SCHEMES) {
        const o = document.createElement("option");
        o.value = s;
        o.textContent = s.replace("scheme-", "").replace(/-/g, " ");
        schemeSelect.appendChild(o);
      }
      schemeSelect.addEventListener("change", (e) => {
        e.stopPropagation();
        invoke("set_scheme", { scheme: schemeSelect.value });
      });
      schemesBuilt = true;
    }
    schemeSelect.value = active;
  }

  async function loadThemeView() {
    const [wallpapers, current, cfg] = await Promise.all([
      invoke<Wallpaper[]>("list_wallpapers"),
      invoke<string>("current_wallpaper"),
      invoke<Config>("get_config"),
    ]);
    renderFilmstrip(wallpapers, current);
    renderSchemes(cfg.scheme);
    setActiveMode(cfg.appearance);
    renderInk(cfg.ink, cfg.colors.base);
    themeLoaded = true;
    // warm the per-wallpaper palette caches so thumbnail clicks are instant
    invoke("precompute_palettes").catch(() => {});
  }

  // Browse… → native Finder picker → set + theme the chosen file in place.
  document
    .querySelector<HTMLElement>("#browse-btn")!
    .addEventListener("click", (e) => {
      e.stopPropagation();
      invoke<string | null>("pick_wallpaper_file").then((path) => {
        if (!path) return;
        invoke("set_wallpaper", { path });
        for (const t of filmstrip.children) t.classList.remove("active");
      });
    });

  // Live theme pushes (day/night flip, wallpaper or scheme change from anywhere).
  listen<ThemePayload>("theme", (e) => {
    applyColors(e.payload.colors);
    setActiveMode(e.payload.appearance);
    renderInk(e.payload.ink, e.payload.colors.base);
    if (themeLoaded && e.payload.scheme) renderSchemes(e.payload.scheme);
    // Canvas pixels don't follow CSS vars — repaint them by hand.
    drawCpuGraph();
    paintWave();
  });

  // ---- init ---------------------------------------------------------------
  tickMinute(); // start the per-minute clock (updates immediately)
  animate(pills, { y: LAYOUT.hiddenY, opacity: 0 }, { duration: 0 });
  requestAnimationFrame(showBar);
  // Seed the click-through rects once the reveal spring has settled (pill
  // transforms skew getBoundingClientRect mid-animation).
  setTimeout(reportInteractiveRects, LAYOUT.settleDelay);
}
