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
  };
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

const HIDDEN_Y = -48; // px above the top edge (clipped by the window)

// Pull the shared config (same one the native frame uses) and apply it as CSS
// variables, then start the bar. styles.css keeps matching defaults as fallback.
invoke<Config>("get_config")
  .then((cfg) => {
    applyConfig(cfg);
    initBar(cfg.geometry.pillHeight);
  })
  .catch(() => initBar(30));

function applyConfig(cfg: Config) {
  const s = document.documentElement.style;
  const c = cfg.colors;
  const g = cfg.geometry;
  s.setProperty("--base", c.base);
  s.setProperty("--pill-bg", c.pillBg);
  s.setProperty("--text", c.text);
  s.setProperty("--subtext", c.subtext);
  s.setProperty("--accent", c.accent);
  s.setProperty("--occupied", c.occupied);
  s.setProperty("--empty", c.empty);
  s.setProperty("--bezel-line-thickness", `${g.lineThickness}px`);
  s.setProperty("--pill-h", `${g.pillHeight}px`);
  s.setProperty("--pill-radius", `${g.pillRadius}px`);
  s.setProperty("--concave", `${g.concave}px`);
}

// Debounce a function — used to coalesce slider drags into fewer IPC calls.
function debounce<A extends unknown[]>(fn: (...a: A) => void, ms: number) {
  let t: number | undefined;
  return (...a: A) => {
    window.clearTimeout(t);
    t = window.setTimeout(() => fn(...a), ms);
  };
}

function initBar(pillHeight: number) {
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
  const WINDOW_BASE_H = 64; // matches BAR_HEIGHT in lib.rs
  const WINDOW_EXPANDED_H = 280;
  const COLLAPSED_H = pillHeight;
  const openPanels = new Set<string>();
  let windowTall = false;

  async function syncWindowHeight() {
    const tall = openPanels.size > 0;
    if (tall === windowTall) return;
    windowTall = tall;
    await invoke("set_bar_size", {
      width: window.innerWidth,
      height: tall ? WINDOW_EXPANDED_H : WINDOW_BASE_H,
    });
  }

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
      animate(
        o.pill,
        { width: o.width, height: o.height },
        { type: "spring", stiffness: 280, damping: 26 },
      );
      animate(o.panel, { opacity: 1 }, { duration: 0.25, delay: 0.08 });
    }

    async function collapse() {
      if (!open) return;
      open = false;
      o.onClose?.();
      animate(o.panel, { opacity: 0 }, { duration: 0.12 });
      await animate(
        o.pill,
        { width: collapsedW, height: COLLAPSED_H },
        { type: "spring", stiffness: 320, damping: 30 },
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
      { type: "spring", stiffness: 420, damping: 26, delay: stagger(0.05) },
    );
  }
  function hideBar() {
    if (!AUTO_HIDE) return;
    if (!shown || openPanels.size > 0) return;
    shown = false;
    animate(
      pills,
      { y: HIDDEN_Y, opacity: 0 },
      { type: "spring", stiffness: 520, damping: 34, delay: stagger(0.03) },
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
    height: 210,
    onOpen: () => {
      updateNotchClock();
      secondTimer = window.setInterval(updateNotchClock, 1000);
      sampleMetrics();
      metricsTimer = window.setInterval(sampleMetrics, 2000);
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
    debounce(() => invoke("set_volume", { output: +volRange.value }), 60),
  );
  micRange.addEventListener(
    "input",
    debounce(() => invoke("set_input_volume", { input: +micRange.value }), 60),
  );
  briRange.addEventListener(
    "input",
    debounce(() => invoke("set_brightness", { value: +briRange.value / 100 }), 40),
  );

  // The popup is a floating dropdown (own width), so the collapsed pill stays a
  // small cog button — the panel doesn't widen it. Mirrors the launcher menu.
  const ctlBtn = document.querySelector<HTMLElement>("#ctl-btn")!;
  const ctlPanelEl = controlsEl.querySelector<HTMLElement>(".ctl-panel")!;
  let controlsOpen = false;
  animate(ctlPanelEl, { y: -8 }, { duration: 0 }); // start tucked up (hidden)

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
      { type: "spring", stiffness: 300, damping: 26 },
    );
  }
  async function closeControls() {
    if (!controlsOpen) return;
    controlsOpen = false;
    ctlPanelEl.style.pointerEvents = "none";
    await animate(ctlPanelEl, { opacity: 0, y: -8 }, { duration: 0.12 }).finished;
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
  animate(menuPanel, { y: -8 }, { duration: 0 }); // start tucked up (hidden)

  async function openLauncher() {
    if (launcherOpen) return;
    launcherOpen = true;
    openPanels.add("launcher");
    await syncWindowHeight();
    menuPanel.style.pointerEvents = "auto";
    animate(
      menuPanel,
      { opacity: 1, y: 0 },
      { type: "spring", stiffness: 300, damping: 26 },
    );
  }
  async function closeLauncher() {
    if (!launcherOpen) return;
    launcherOpen = false;
    menuPanel.style.pointerEvents = "none";
    await animate(menuPanel, { opacity: 0, y: -8 }, { duration: 0.12 }).finished;
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
  // Nerd Font (Material Design) battery glyphs, 0%..100% in 10% steps.
  const BAT = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
  const BAT_CHG = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
  const batPill = document.querySelector<HTMLElement>("#battery")!;
  const batIcon = batPill.querySelector<HTMLElement>(".bat-icon")!;
  const batPct = batPill.querySelector<HTMLElement>(".bat-pct")!;
  async function updateBattery() {
    try {
      const b = await invoke<Battery>("battery");
      const charging = b.state !== "discharging";
      const i = Math.max(0, Math.min(10, Math.round(b.percent / 10)));
      batIcon.textContent = (charging ? BAT_CHG : BAT)[i];
      batPct.textContent = `${b.percent}%`;
      batPill.classList.toggle("charging", charging && b.state !== "charged");
      batPill.classList.toggle("low", !charging && b.percent <= 20);
    } catch {
      /* ignore */
    }
  }
  updateBattery();
  window.setInterval(updateBattery, 60000);

  // ---- Wi-Fi / network (polled; changes slowly) --------------------------
  // Nerd Font glyphs: connected / VPN / off (reused from sketchybar icons.sh).
  const WIFI_ICON: Record<string, string> = {
    wifi: "󰖩",
    vpn: "󰦝",
    off: "󰖪",
  };
  const wifiPill = document.querySelector<HTMLElement>("#wifi")!;
  const wifiIcon = wifiPill.querySelector<HTMLElement>(".wifi-icon")!;
  const wifiLabel = wifiPill.querySelector<HTMLElement>(".wifi-label")!;
  async function updateNetwork() {
    try {
      const n = await invoke<Network>("network");
      wifiIcon.textContent = WIFI_ICON[n.state] ?? WIFI_ICON.off;
      wifiLabel.textContent = n.label;
      wifiPill.classList.toggle("vpn", n.state === "vpn");
      wifiPill.classList.toggle("off", n.state === "off");
    } catch {
      /* ignore */
    }
  }
  updateNetwork();
  window.setInterval(updateNetwork, 15000);

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
  }

  listen<Workspace[]>("workspaces", (e) => renderWorkspaces(e.payload));
  invoke<Workspace[]>("aerospace_workspaces") // initial state
    .then(renderWorkspaces)
    .catch(() => {});

  // ---- init ---------------------------------------------------------------
  tickMinute(); // start the per-minute clock (updates immediately)
  animate(pills, { y: HIDDEN_Y, opacity: 0 }, { duration: 0 });
  requestAnimationFrame(showBar);
}
