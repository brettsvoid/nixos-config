import "./styles.css";
import { animate, stagger } from "motion";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

interface Workspace {
  name: string;
  focused: boolean;
  has_windows: boolean;
  app: string; // app name shown on the dot ("" if empty)
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
}

interface ThemePayload {
  colors: Record<string, string>;
  appearance: string;
}

interface Battery {
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

interface Volume {
  output: number;
  input: number;
}

interface Network {
  state: string; // "wifi" | "vpn" | "off"
  label: string;
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
  clockSecond: 1000,
  metrics: 2000,
  network: 15000,
  battery: 60000,
} as const; // ms
const DEBOUNCE = { volume: 60, mic: 60, brightness: 40 } as const; // ms
const LAYOUT = {
  hiddenY: -48, // px above the top edge (clipped by the window)
  windowExpandedH: 280, // bar-window height while a panel is open
  popupTuck: -8, // px a dropdown starts tucked up (hidden) before sliding in
  settleDelay: 600, // ms to let the reveal spring settle before hit-testing
} as const;
const FALLBACK = { pillHeight: 30, windowHeight: 64 } as const; // if get_config fails

// Pull the shared config (same one the native frame uses) and apply it as CSS
// variables, then start the bar. styles.css keeps matching defaults as fallback.
invoke<Config>("get_config")
  .then((cfg) => {
    applyConfig(cfg);
    initBar(cfg.geometry.pillHeight, cfg.geometry.windowHeight, cfg.appearance);
  })
  .catch(() => initBar(FALLBACK.pillHeight, FALLBACK.windowHeight, "auto"));

// Color vars only — re-applied live on day/night or wallpaper changes.
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

// Debounce a function — used to coalesce slider drags into fewer IPC calls.
function debounce<A extends unknown[]>(fn: (...a: A) => void, ms: number) {
  let t: number | undefined;
  return (...a: A) => {
    window.clearTimeout(t);
    t = window.setTimeout(() => fn(...a), ms);
  };
}

function initBar(pillHeight: number, windowHeight: number, appearance: string) {
  const pills = [...document.querySelectorAll<HTMLElement>(".pill")];

  let shown = false;
  let hovering = false;

  // Auto-hide disabled: the bar stays visible (hover-reveal fought the
  // auto-hidden macOS menu bar). Flip to true to re-enable hover auto-hide.
  const AUTO_HIDE = false;

  // ---- expandable-panel window sizing ------------------------------------
  // Both the notch and the controls popup grow the (transparent) bar window so
  // their panels have room. The window is shared, so size to "tall" whenever any
  // panel is open and back to "base" once all are closed.
  // Collapsed bar-window height. Matches the height lib.rs sizes the window to
  // at startup (config.geometry.windowHeight) — taller than the bar band so the
  // pills' shadows and the corner fillets hanging below the band aren't clipped
  // by the window bounds. Single-sourced via config so it can't drift from the
  // native side again. (The extra height is transparent and passes clicks
  // through, so it doesn't cover the windows below.)
  const WINDOW_BASE_H = windowHeight;
  const COLLAPSED_H = pillHeight;
  const openPanels = new Set<string>();
  let windowTall = false;

  async function syncWindowHeight() {
    const tall = openPanels.size > 0;
    if (tall === windowTall) return;
    windowTall = tall;
    await invoke("set_bar_size", {
      width: window.innerWidth,
      height: tall ? LAYOUT.windowExpandedH : WINDOW_BASE_H,
    });
    reportInteractiveRects();
  }

  // Feed the native click-through hitTest (lib.rs) the regions that should stay
  // interactive: the pills when idle, or one full-window rect while a popup is
  // open (so clicks outside the popup still land on the bar and close it).
  // Everywhere else the bar passes clicks through to the windows below. Coalesced
  // to one IPC per frame; called whenever the bar's layout changes.
  let rectsScheduled = false;
  function reportInteractiveRects() {
    if (rectsScheduled) return;
    rectsScheduled = true;
    requestAnimationFrame(() => {
      rectsScheduled = false;
      const rects =
        openPanels.size > 0
          ? [[0, 0, 1e5, 1e5]]
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
      await animate(
        o.pill,
        { width: collapsedW, height: COLLAPSED_H },
        SPRING.panelClose,
      ).finished;
      o.pill.style.width = "";
      o.pill.style.height = "";
      openPanels.delete(o.id);
      await syncWindowHeight();
      if (AUTO_HIDE && !hovering) hideBar();
    }

    // Only the header toggles — so clicks on panel content (e.g. dragging a
    // slider) don't collapse the popup.
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
  // The compact clock shows HH:MM, so it only updates once a minute, aligned to
  // the minute boundary. The notch's HH:MM:SS only ticks while the notch is open.
  const timeEl = document.querySelector<HTMLElement>("#clock .time")!;
  const dateEl = document.querySelector<HTMLElement>("#clock .date")!;
  const bigTimeEl = document.querySelector<HTMLElement>("#notch .big-time")!;
  const fullDateEl = document.querySelector<HTMLElement>("#notch .full-date")!;

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
    // self-reschedule to the next minute boundary (no drift, one wake/min)
    window.setTimeout(tickMinute, 60000 - (Date.now() % 60000));
  }

  function updateNotchClock() {
    const now = new Date();
    bigTimeEl.textContent = now.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });
    fullDateEl.textContent = now.toLocaleDateString([], {
      weekday: "long",
      month: "long",
      day: "numeric",
      year: "numeric",
    });
  }

  // ---- metrics (lazy: only sampled while the notch is open) ---------------
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
  async function sampleMetrics() {
    try {
      const m = await invoke<Metrics>("metrics_sample");
      setMetric("cpu", m.cpu);
      setMetric("mem", pctOf(m.memUsed, m.memTotal));
      setMetric("disk", pctOf(m.diskUsed, m.diskTotal));
      setMetric("swap", pctOf(m.swapUsed, m.swapTotal));
    } catch {
      /* sampling can fail mid-teardown; ignore */
    }
  }

  // ---- center notch: clock + metrics hub ---------------------------------
  let secondTimer: number | undefined;
  let metricsTimer: number | undefined;
  const notchEl = document.querySelector<HTMLElement>("#notch")!;
  const notchPanel = makePanel({
    id: "notch",
    pill: notchEl,
    header: notchEl.querySelector<HTMLElement>(".notch-row")!,
    panel: notchEl.querySelector<HTMLElement>(".notch-panel")!,
    width: 250,
    height: 250,
    onOpen: () => {
      updateNotchClock();
      secondTimer = window.setInterval(updateNotchClock, POLL.clockSecond);
      sampleMetrics();
      metricsTimer = window.setInterval(sampleMetrics, POLL.metrics);
    },
    onClose: () => {
      clearInterval(secondTimer);
      clearInterval(metricsTimer);
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

  // The popup is a floating dropdown (own width), so the collapsed pill stays a
  // small cog button — the panel doesn't widen it. Mirrors the launcher menu.
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
  // Expose the same shape as makePanel() so outside-click / mouse-leave close it.
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
  async function updateBattery() {
    try {
      const b = await invoke<Battery>("battery");
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
  window.setInterval(updateBattery, POLL.battery);

  // ---- Wi-Fi / network (polled; changes slowly) --------------------------
  // Inline Lucide SVGs: connected / VPN (shield) / off.
  const WIFI_SVG: Record<string, string> = {
    wifi: lucide(
      '<path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/>',
    ),
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
  async function updateNetwork() {
    try {
      const n = await invoke<Network>("network");
      wifiIcon.innerHTML = WIFI_SVG[n.state] ?? WIFI_SVG.off;
      wifiLabel.textContent = n.label;
      wifiPill.classList.toggle("vpn", n.state === "vpn");
      wifiPill.classList.toggle("off", n.state === "off");
    } catch {
      /* ignore */
    }
  }
  updateNetwork();
  window.setInterval(updateNetwork, POLL.network);

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

  // ---- appearance toggle (light / dark / auto) ---------------------------
  // The bar pushes the choice to Rust (set_appearance), which persists it,
  // re-resolves colors for the new scheme, and emits "theme"; the native frame
  // recolors in place. Auto follows the macOS system setting (Rust observes it).
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
  listen<ThemePayload>("theme", (e) => {
    applyColors(e.payload.colors);
    setActiveMode(e.payload.appearance);
  });

  // ---- init ---------------------------------------------------------------
  tickMinute(); // start the per-minute clock (updates immediately)
  animate(pills, { y: LAYOUT.hiddenY, opacity: 0 }, { duration: 0 });
  requestAnimationFrame(showBar);
  // Seed the click-through hitTest once the reveal spring has settled (pill
  // transforms change getBoundingClientRect mid-animation). Workspace renders,
  // panel toggles, and resizes report again from then on.
  setTimeout(reportInteractiveRects, LAYOUT.settleDelay);
}
