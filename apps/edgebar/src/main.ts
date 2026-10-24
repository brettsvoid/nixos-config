import "./styles.css";
import { animate, motionValue } from "motion";
import defaults from "../src-tauri/config.default.json";
import {
  call,
  on,
  type Colours,
  type Config,
  type CpuSample,
  type CpuStat,
  type Network,
  type NotchItem,
  type Workspace,
} from "./ipc";
import { lucide, TRANSPORT } from "./icons";
import { releaseKeyboard } from "./keyboard";
import { setLine } from "./marquee";
import { SPRING } from "./motion";
import { current, onChange } from "./settings";
import type { NotchView, ViewHandle } from "./notch/view";
import { home, views } from "./notch/views";

// ---- tuned constants (named so each value lives in one place) ----
const POLL = {
  battery: 60000,
} as const; // ms (network is event-driven, so it has no poll)
const DEBOUNCE = { volume: 60, mic: 60, brightness: 40 } as const; // ms
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
  drawerRoom: 32,
  settleDelay: 600,
} as const;
// Collapsed notch sizing: one width per state, not sized to content, so the
// bar doesn't twitch on every track change. Long text marquees instead.
const NOTCH = {
  idleW: 200, // the bare handle
  itemW: 320, // any published item
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
const RECT_WHOLE_WINDOW: number[] = [0, 0, 1e5, 1e5];

// Apply the shared config (also read by the native frame) as CSS variables,
// then start the bar. styles.css holds fallback values.
call("get_config")
  .then((cfg) => {
    applyConfig(cfg);
    initBar(cfg.geometry.barHeight, cfg.geometry.windowHeight, cfg.notchIdle);
  })
  .catch(() =>
    initBar(defaults.geometry.barHeight, defaults.geometry.windowHeight, defaults.notch.idle),
  );

function applyColours(c: Colours) {
  const s = document.documentElement.style;
  s.setProperty("--surface", c.surface);
  s.setProperty("--on-surface", c.text);
  s.setProperty("--on-surface-variant", c.subtext);
  s.setProperty("--primary", c.accent);
  s.setProperty("--battery-charging", c.batteryCharging);
  s.setProperty("--battery-low", c.batteryLow);
  s.setProperty("--vpn", c.vpn);
  s.setProperty("--cpu-sys", c.cpuSys);
  s.setProperty("--cpu-user", c.cpuUser);
}

function applyConfig(cfg: Config) {
  const s = document.documentElement.style;
  applyColours(cfg.colors);
  s.setProperty("--bar-h", `${cfg.geometry.barHeight}px`);
  s.setProperty("--frame-t", `${cfg.geometry.frameThickness}px`);
}

// Coalesces slider drags into fewer IPC calls.
function debounce<A extends unknown[]>(fn: (...a: A) => void, ms: number) {
  let t: number | undefined;
  return (...a: A) => {
    window.clearTimeout(t);
    t = window.setTimeout(() => fn(...a), ms);
  };
}

function initBar(barHeight: number, windowHeight: number, notchIdle: string) {
  const segments = [...document.querySelectorAll<HTMLElement>(".seg")];

  const drawerHeights = new Map<string, number>();
  let lastWindowH = -1;

  async function syncWindowHeight() {
    const tallest = Math.max(0, ...drawerHeights.values());
    const target =
      drawerHeights.size > 0 ? barHeight + tallest + LAYOUT.drawerRoom : windowHeight;
    if (target === lastWindowH) return;
    lastWindowH = target;
    await call("set_bar_size", {
      width: window.innerWidth,
      height: target,
    });
    reportInteractiveRects();
  }

  let scrubbing = false;
  let rectsScheduled = false;
  function reportInteractiveRects() {
    if (rectsScheduled) return;
    rectsScheduled = true;
    requestAnimationFrame(() => {
      rectsScheduled = false;
      const rects =
        drawerHeights.size > 0 || scrubbing
          ? [RECT_WHOLE_WINDOW]
          : segments
              .map((p) => {
                const r = p.getBoundingClientRect();
                return [r.left, r.top, r.width, r.height];
              })
              .filter((r) => r[2] > 0 && r[3] > 0);
      call("set_interactive_rects", { rects }).catch(() => {});
    });
  }
  window.addEventListener("resize", reportInteractiveRects);

  interface DrawerOpts {
    id: string;
    root: HTMLElement;
    toggle: HTMLElement;
    box: HTMLElement;
    body: HTMLElement;
    onOpen?: () => void | Promise<void>;
    onClose?: () => void;
  }

  interface Drawer {
    root: HTMLElement;
    isOpen: () => boolean;
    close: () => Promise<void>;
    resize: () => void;
  }

  function makeDrawer(o: DrawerOpts): Drawer {
    let open = false;
    const reach = motionValue(0);
    reach.on("change", (v) => o.box.style.setProperty("--reach", `${Math.max(0, v)}px`));
    const setState = (state: "opening" | "open" | "closing" | "closed") => {
      o.box.dataset.state = state;
    };
    setState("closed");

    async function show() {
      if (open) return;
      open = true;
      await o.onOpen?.();
      if (!open) return;
      drawerHeights.set(o.id, o.body.offsetHeight);
      await syncWindowHeight();
      setState("opening");
      await animate(reach, o.body.offsetHeight, SPRING.drawer).finished;
      if (open) setState("open");
    }

    async function close() {
      if (!open) return;
      open = false;
      o.onClose?.();
      setState("closing");
      await animate(reach, 0, SPRING.drawer).finished;
      if (open) return;
      setState("closed");
      drawerHeights.delete(o.id);
      await syncWindowHeight();
    }

    function resize() {
      if (!open) return;
      drawerHeights.set(o.id, o.body.offsetHeight);
      void syncWindowHeight();
      animate(reach, o.body.offsetHeight, SPRING.drawer);
    }

    o.toggle.addEventListener("click", (e) => {
      e.stopPropagation();
      void (open ? close() : show());
    });

    return { root: o.root, isOpen: () => open, close, resize };
  }

  document.addEventListener("mouseleave", () => {
    for (const d of drawers) void d.close();
  });

  // ---- clock --------------------------------------------------------------
  const timeEl = document.querySelector<HTMLElement>("#clock .time")!;
  const sepEl = document.querySelector<HTMLElement>("#clock .sep")!;
  const dateEl = document.querySelector<HTMLElement>("#clock .date")!;

  const timeText = (now: Date, seconds: boolean) =>
    now.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: seconds ? "2-digit" : undefined,
      hour12: !current().clock.hour24,
    });

  function updateCompactClock(now: Date) {
    const c = current().clock;
    timeEl.textContent = timeText(now, c.seconds);
    sepEl.hidden = dateEl.hidden = !c.date;
    dateEl.textContent = now.toLocaleDateString([], {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
  }
  let clockTimer = 0;
  let clockMinute = -1;
  function tick({ force = false } = {}) {
    const now = new Date();
    updateCompactClock(now);
    const minute = Math.floor(now.getTime() / 60000);
    if ((force || minute !== clockMinute) && notchIdle === "clock" && !notchLive) renderNotch(null);
    clockMinute = minute;
    const step = current().clock.seconds && !document.hidden ? 1000 : 60000;
    window.clearTimeout(clockTimer);
    clockTimer = window.setTimeout(() => tick(), step - (Date.now() % step));
  }
  document.addEventListener("visibilitychange", () => tick());

  // ---- centre notch: the dashboard / wallpapers / performance hub ---------
  const notchEl = document.querySelector<HTMLElement>("#notch")!;
  const notchBox = notchEl.querySelector<HTMLElement>(".notch-drawer")!;
  const notchBody = notchBox.querySelector<HTMLElement>(".notch-panel")!;
  let notchW: number = NOTCH.idleW;
  const notchDrawer = makeDrawer({
    id: "notch",
    root: notchEl,
    toggle: notchEl.querySelector<HTMLElement>(".notch-row")!,
    box: notchBox,
    body: notchBody,
    onOpen: openViews,
    onClose: closeViews,
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
  const ranges = [volRange, micRange, briRange];

  const paintRange = (r: HTMLInputElement) => r.style.setProperty("--fill", `${r.value}%`);
  for (const r of ranges) r.addEventListener("input", () => paintRange(r));

  async function loadControls() {
    try {
      const v = await call("get_volume");
      volRange.value = String(v.output);
      micRange.value = String(v.inputRestore ?? v.input);
      const br = await call("get_brightness");
      briRange.value = String(Math.round(br * 100));
    } catch {
      /* ignore */
    }
    ranges.forEach(paintRange);
  }
  volRange.addEventListener(
    "input",
    debounce(() => call("set_volume", { output: +volRange.value }), DEBOUNCE.volume),
  );
  micRange.addEventListener(
    "input",
    debounce(() => call("set_input_volume", { input: +micRange.value }), DEBOUNCE.mic),
  );
  briRange.addEventListener(
    "input",
    debounce(
      () => call("set_brightness", { value: +briRange.value / 100 }),
      DEBOUNCE.brightness,
    ),
  );

  const ctlBox = controlsEl.querySelector<HTMLElement>(".ctl-panel")!;
  const controlsDrawer = makeDrawer({
    id: "controls",
    root: controlsEl,
    toggle: document.querySelector<HTMLElement>("#ctl-btn")!,
    box: ctlBox,
    body: ctlBox.querySelector<HTMLElement>(".drawer-body")!,
    onOpen: loadControls,
  });

  const wsEl = document.querySelector<HTMLElement>("#workspaces")!;
  const menuBox = wsEl.querySelector<HTMLElement>(".menu-panel")!;
  const launcherDrawer = makeDrawer({
    id: "launcher",
    root: wsEl,
    toggle: document.querySelector<HTMLElement>("#launcher-btn")!,
    box: menuBox,
    body: menuBox.querySelector<HTMLElement>(".drawer-body")!,
  });
  for (const btn of menuBox.querySelectorAll<HTMLElement>(".menu-item")) {
    btn.addEventListener("click", () => {
      call("launcher_action", { action: btn.dataset.action! });
      void launcherDrawer.close();
    });
  }

  const drawers = [notchDrawer, controlsDrawer, launcherDrawer];

  document.addEventListener("click", (e) => {
    const path = e.composedPath();
    for (const d of drawers) {
      if (d.isOpen() && !path.includes(d.root)) void d.close();
    }
  });

  // ---- battery (polled; changes slowly) ----------------------------------
  // Inline Lucide battery SVGs, swapped by charge level / charging state. The
  // exact percentage is shown as text, so discrete level icons are enough.
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
      const b = await call("battery");
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
  call("network").then(renderNetwork).catch(() => {});
  on("network", renderNetwork);

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
    cpuPidEl.textContent = stat.topPid === null ? "" : String(stat.topPid);
    cpuTopEl.title = stat.topProc
      ? `${stat.topProc} (pid ${stat.topPid}) — ${Math.round(stat.topProcPct)}% of one core`
      : "";
    cpuPctEl.textContent = `${Math.round(stat.total * 100)}%`;
    const t = CPU_GRAPH.thresholds;
    cpuPill.classList.toggle("hot", stat.total >= t.hot);
    cpuPill.classList.toggle("warm", stat.total >= t.warm && stat.total < t.hot);
    cpuPill.classList.toggle("mild", stat.total >= t.mild && stat.total < t.warm);
  }

  on("cpu", (stat) => {
    if (cpuPill.hidden) return;
    cpuHistory.push({ sys: stat.sys, user: stat.user });
    if (cpuHistory.length > CPU_GRAPH.samples) cpuHistory.shift();
    renderCpu(stat);
    drawCpuGraph();
  });
  function seedCpu() {
    call("cpu_state")
      .then((s) => {
        if (s.history.length === 0) return;
        cpuHistory.splice(0, cpuHistory.length, ...s.history.slice(-CPU_GRAPH.samples));
        renderCpu(s.latest);
        drawCpuGraph();
      })
      .catch(() => {});
  }
  seedCpu();
  function showCpuSegment(shown: boolean) {
    if (shown === !cpuPill.hidden) return;
    cpuPill.hidden = !shown;
    if (shown) seedCpu();
  }

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
          call("aerospace_focus", { name: w.name }),
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

  on("workspaces", renderWorkspaces);
  call("aerospace_workspaces")
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
      primary: clock ? timeText(now, false) : notchIdle,
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
    nmPlay.innerHTML = item.active ? TRANSPORT.pause : TRANSPORT.play;
    startWave();
  }

  nmPlay.addEventListener("click", (e) => {
    e.stopPropagation(); // the row is the panel's toggle; the button isn't
    // Flip optimistically so the glyph and wave respond at once; Rust
    // re-publishes the real state a moment later.
    media.progress = playedFraction();
    media.playing = !media.playing;
    media.t0 = performance.now();
    nmPlay.innerHTML = media.playing ? TRANSPORT.pause : TRANSPORT.play;
    startWave();
    call("media_toggle").catch(() => {});
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
    if (commit) call("media_seek", { fraction: media.progress }).catch(() => {});
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
    if (width === notchW) return;
    notchW = width;
    animate(notchEl, { width }, SPRING.move)
      .finished.then(reportInteractiveRects)
      .catch(() => {});
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
    animate(outgoing, { opacity: 0 }, SPRING.fade)
      .finished.then(() => {
        renderNotch(item);
        const incoming = niMedia.hidden ? notchItem : niMedia;
        if (outgoing !== incoming) outgoing.style.opacity = "1"; // it's hidden now
        incoming.style.opacity = "0"; // start the fade from a known state
        animate(incoming, { opacity: 1 }, SPRING.fade);
      })
      .catch(() => {});
  }

  on("notch", pushNotch);
  call("notch_state")
    .then((item) => renderNotch(item))
    .catch(() => renderNotch(null));

  const tabBody = notchBody.querySelector<HTMLElement>(".tab-body")!;
  const railEl = notchBody.querySelector<HTMLElement>(".dash-rail")!;
  const railTabs = new Map<string, HTMLElement>();
  const viewEls = new Map<string, HTMLElement>();
  const handles = new Map<string, ViewHandle>();
  let shownView: string | null = null;

  function railTab(view: NotchView): HTMLElement {
    const tab = document.createElement("button");
    tab.className = "rail-tab";
    tab.classList.toggle("rail-foot", view.rail === "foot");
    tab.innerHTML = `<span class="icon">${view.icon}</span>`;
    tab.title = view.title;
    tab.dataset.to = view.id;
    tab.addEventListener("click", (e) => {
      e.stopPropagation();
      switchView(view.id);
    });
    return tab;
  }
  for (const view of views) {
    const tab = railTab(view);
    railTabs.set(view.id, tab);
    railEl.append(tab);
  }

  const panelStyle = getComputedStyle(notchBody);
  const px = (...props: string[]) =>
    props.reduce((sum, p) => sum + parseFloat(panelStyle.getPropertyValue(p)), 0);
  const notchChrome = {
    w: px("padding-left", "padding-right", "column-gap") + railEl.offsetWidth,
    h: px("padding-top", "padding-bottom"),
  };

  function setAlert(view: NotchView, reason: string | null) {
    const tab = railTabs.get(view.id)!;
    let dot = tab.querySelector<HTMLElement>(".rail-dot");
    if (!dot) {
      dot = document.createElement("span");
      dot.className = "rail-dot";
      tab.append(dot);
    }
    dot.hidden = reason === null;
    tab.title = reason === null ? view.title : `${view.title} — ${reason}`;
  }

  function mountViews() {
    if (handles.size > 0) return;
    for (const view of views) {
      const el = document.createElement("div");
      el.className = `view view-${view.id}`;
      el.hidden = true;
      tabBody.append(el);
      viewEls.set(view.id, el);
      handles.set(view.id, view.mount(el, { setAlert: (reason) => setAlert(view, reason) }));
    }
  }

  function showView(view: NotchView) {
    if (shownView && shownView !== view.id) handles.get(shownView)?.hide?.();
    shownView = view.id;
    tabBody.style.width = `${view.size.w}px`;
    notchBody.style.height = `${view.size.h + notchChrome.h}px`;
    for (const [id, el] of viewEls) el.hidden = id !== view.id;
    for (const [id, tab] of railTabs) tab.classList.toggle("active", id === view.id);
    handles.get(view.id)?.show?.();
  }

  function switchView(id: string) {
    const view = views.find((v) => v.id === id);
    if (!view || shownView === id) return;
    showView(view);
    // From the width on screen: openViews sets it without Motion, which would
    // otherwise start from the last switch's target and, back on that view,
    // leave the box at the dashboard's width.
    animate(
      notchBox,
      { width: [notchBox.offsetWidth, view.size.w + notchChrome.w] },
      SPRING.drawer,
    );
    notchDrawer.resize();
  }

  function openViews() {
    mountViews();
    showView(home);
    notchBox.style.width = `${home.size.w + notchChrome.w}px`;
    for (const handle of handles.values()) handle.open?.();
  }

  function closeViews() {
    if (shownView) handles.get(shownView)?.hide?.();
    shownView = null;
    releaseKeyboard();
  }

  // Live theme pushes (day/night flip, wallpaper or scheme change from anywhere).
  on("theme", (theme) => {
    applyConfig(theme);
    for (const handle of handles.values()) handle.theme?.();
    drawCpuGraph();
    paintWave();
    if (theme.notchIdle !== notchIdle) {
      notchIdle = theme.notchIdle;
      if (!notchLive) renderNotch(null);
    }
  });

  function applyBarSettings() {
    showCpuSegment(current().segments.cpu);
    tick({ force: true });
    reportInteractiveRects();
  }
  onChange(applyBarSettings);

  function resetNativeAfterReload() {
    releaseKeyboard();
    void syncWindowHeight();
  }

  // ---- init ---------------------------------------------------------------
  resetNativeAfterReload();
  applyBarSettings();
  reportInteractiveRects();
  setTimeout(reportInteractiveRects, LAYOUT.settleDelay);
}
