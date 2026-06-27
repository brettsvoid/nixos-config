import "./styles.css";
import { animate, stagger } from "motion";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

interface Workspace {
  name: string;
  focused: boolean;
  has_windows: boolean;
}

const HIDDEN_Y = -48; // px above the top edge (clipped by the window)

initBar();

function initBar() {
  const pills = [...document.querySelectorAll<HTMLElement>(".pill")];

  let shown = false;
  let hovering = false;
  let notchExpanded = false;

  // Auto-hide disabled: the bar stays visible (hover-reveal fought the
  // auto-hidden macOS menu bar). Flip to true to re-enable hover auto-hide.
  const AUTO_HIDE = false;

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
    if (!shown || notchExpanded) return;
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
    if (notchExpanded) collapseNotch();
    else hideBar();
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

  // ---- center notch: expand into a hub -----------------------------------
  // Grows the (transparent) bar window so the panel has room, then springs the
  // pill open. The resize is invisible since the window is transparent.
  const notchEl = document.querySelector<HTMLElement>("#notch")!;
  const notchPanel = document.querySelector<HTMLElement>("#notch .notch-panel")!;
  const COLLAPSED_H = 30; // matches --pill-h
  const EXPANDED_H = 104;
  const EXPANDED_W = 240;
  const WINDOW_BASE_H = 64;
  const WINDOW_EXPANDED_H = 180;
  let collapsedW = 0;
  let secondTimer: number | undefined;

  async function expandNotch() {
    if (notchExpanded) return;
    notchExpanded = true;
    collapsedW = notchEl.offsetWidth;
    updateNotchClock(); // fill before reveal
    secondTimer = window.setInterval(updateNotchClock, 1000); // only while open
    await invoke("set_bar_size", {
      width: window.innerWidth,
      height: WINDOW_EXPANDED_H,
    });
    animate(
      notchEl,
      { width: EXPANDED_W, height: EXPANDED_H },
      { type: "spring", stiffness: 280, damping: 24 },
    );
    animate(notchPanel, { opacity: 1 }, { duration: 0.25, delay: 0.08 });
  }

  async function collapseNotch() {
    if (!notchExpanded) return;
    notchExpanded = false;
    clearInterval(secondTimer);
    animate(notchPanel, { opacity: 0 }, { duration: 0.12 });
    await animate(
      notchEl,
      { width: collapsedW, height: COLLAPSED_H },
      { type: "spring", stiffness: 320, damping: 30 },
    ).finished;
    notchEl.style.width = "";
    notchEl.style.height = "";
    await invoke("set_bar_size", {
      width: window.innerWidth,
      height: WINDOW_BASE_H,
    });
    if (!hovering) hideBar();
  }

  notchEl.addEventListener("click", () =>
    notchExpanded ? collapseNotch() : expandNotch(),
  );
  document.addEventListener("click", (e) => {
    if (notchExpanded && !notchEl.contains(e.target as Node)) collapseNotch();
  });

  // ---- workspaces: event-driven (Rust pushes on AeroSpace changes) -------
  const wsContainer = document.querySelector<HTMLElement>("#workspaces")!;
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
        el.title = `workspace ${w.name}`;
        el.addEventListener("click", () =>
          invoke("aerospace_focus", { name: w.name }),
        );
        wsEls.set(w.name, el);
        wsContainer.appendChild(el);
      }
      el.classList.toggle("active", w.focused);
      el.classList.toggle("occupied", w.has_windows && !w.focused);
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
