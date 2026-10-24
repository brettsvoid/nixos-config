import "./controls.css";
import { call } from "../../ipc";
import { lucide } from "../../icons";
import { fingersUp, wheelStepper } from "../../wheel";
import type { Widget } from "../view";

const STEP = 5;
const DRAG_PX = 100;
const CLICK_SLOP_PX = 3;
const WHEEL_PX = 30;
const DIAL = { size: 48, r: 16, startDeg: 135, sweepDeg: 270, clearPx: 6, tick: { in: 2, out: 4 } } as const;

const ICON = {
  sun: lucide(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
  ),
  volume: lucide(
    '<path d="M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"/><path d="M16 9a5 5 0 0 1 0 6"/><path d="M19.364 18.364a9 9 0 0 0 0-12.728"/>',
  ),
  volumeMuted: lucide(
    '<path d="M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"/><path d="m22 9-6 6"/><path d="m16 9 6 6"/>',
  ),
  mic: lucide(
    '<path d="M12 19v3"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><rect x="9" y="2" width="6" height="13" rx="3"/>',
  ),
  micMuted: lucide(
    '<path d="m2 2 20 20"/><path d="M18.89 13.23A7.12 7.12 0 0 0 19 12v-2"/><path d="M5 10v2a7 7 0 0 0 12 5"/><path d="M15 9.34V5a3 3 0 0 0-5.68-1.33"/><path d="M9 9v3a3 3 0 0 0 5.12 2.12"/><path d="M12 19v3"/>',
  ),
} as const;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

function latest<T>(send: (value: T) => Promise<unknown>): (value: T) => void {
  let pending: { value: T } | null = null;
  let busy = false;
  return (value) => {
    pending = { value };
    if (busy) return;
    busy = true;
    void (async () => {
      while (pending) {
        const next: T = pending.value;
        pending = null;
        await send(next).catch(() => {});
      }
      busy = false;
    })();
  };
}

interface Level {
  value: number;
  muted: boolean;
}

interface DialSpec {
  name: string;
  icon: string;
  mutedIcon: string;
  setLevel: (value: number) => Promise<void>;
  setMuted: (muted: boolean) => Promise<void>;
}

const pt = (deg: number, r: number) => {
  const a = (deg * Math.PI) / 180;
  const c = DIAL.size / 2;
  return `${(c + r * Math.cos(a)).toFixed(2)} ${(c + r * Math.sin(a)).toFixed(2)}`;
};
const arc = (from: number, to: number) =>
  to > from
    ? `M${pt(from, DIAL.r)}A${DIAL.r} ${DIAL.r} 0 ${to - from > 180 ? 1 : 0} 1 ${pt(to, DIAL.r)}`
    : "";

function dial(root: HTMLElement, spec: DialSpec) {
  const el = document.createElement("div");
  el.className = "ctl-dial";
  el.innerHTML =
    `<svg viewBox="0 0 ${DIAL.size} ${DIAL.size}" aria-hidden="true">` +
    '<path class="dial-rest"/><path class="dial-fill"/><path class="dial-tick"/></svg>' +
    '<span class="dial-icon icon"></span>';
  root.append(el);
  const [rest, fill, tick] = [...el.querySelectorAll<SVGPathElement>("path")];
  const iconEl = el.querySelector<HTMLElement>(".dial-icon")!;
  const send = latest(spec.setLevel);
  const steps = wheelStepper(WHEEL_PX, fingersUp);
  let level: Level = { value: 0, muted: false };
  let drag: { y: number; from: number; moved: boolean } | null = null;

  function draw() {
    const end = DIAL.startDeg + DIAL.sweepDeg;
    const at = DIAL.startDeg + (DIAL.sweepDeg * level.value) / 100;
    const clear = ((DIAL.clearPx / DIAL.r) * 180) / Math.PI;
    fill.setAttribute("d", arc(DIAL.startDeg, at - clear));
    rest.setAttribute("d", arc(at + clear, end));
    tick.setAttribute("d", `M${pt(at, DIAL.r - DIAL.tick.in)}L${pt(at, DIAL.r + DIAL.tick.out)}`);
    el.classList.toggle("muted", level.muted);
    iconEl.innerHTML = level.muted ? spec.mutedIcon : spec.icon;
    el.title = level.muted ? `${spec.name} muted` : `${spec.name} ${level.value}%`;
  }

  function setLevel(value: number) {
    const v = Math.round(clamp(value, 0, 100));
    if (v === level.value && !level.muted) return;
    level = { value: v, muted: false };
    draw();
    send(v);
  }

  el.addEventListener("pointerdown", (e) => {
    el.setPointerCapture(e.pointerId);
    drag = { y: e.clientY, from: level.value, moved: false };
  });
  el.addEventListener("pointermove", (e) => {
    if (!drag) return;
    const dy = drag.y - e.clientY;
    if (!drag.moved && Math.abs(dy) < CLICK_SLOP_PX) return;
    drag.moved = true;
    setLevel(drag.from + (dy / DRAG_PX) * 100);
  });
  el.addEventListener("pointerup", () => {
    if (drag && !drag.moved) {
      level = { ...level, muted: !level.muted };
      draw();
      spec.setMuted(level.muted).catch(() => {});
    }
    drag = null;
  });
  el.addEventListener("pointercancel", () => (drag = null));
  el.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const n = steps(e);
      if (n) setLevel(level.value + n * STEP);
    },
    { passive: false },
  );

  return {
    set(next: Level) {
      if (drag) return;
      level = next;
      draw();
    },
  };
}

type Brightness = { ok: true; value: number } | { ok: false; reason: string };

function brightnessSlider(root: HTMLElement) {
  const el = document.createElement("div");
  el.className = "ctl-bri";
  el.innerHTML =
    '<div class="bri-track"><i class="bri-rest"></i><i class="bri-fill"></i><i class="bri-handle"></i>' +
    '<span class="bri-label"></span></div>' +
    `<span class="bri-icon icon">${ICON.sun}</span>`;
  root.append(el);
  const track = el.querySelector<HTMLElement>(".bri-track")!;
  const label = el.querySelector<HTMLElement>(".bri-label")!;
  const send = latest((value: number) => call("set_brightness", { value }));
  const steps = wheelStepper(WHEEL_PX, fingersUp);
  let state: Brightness = { ok: false, reason: "not read yet" };
  let dragging = false;

  function draw() {
    el.classList.toggle("disabled", !state.ok);
    if (!state.ok) {
      el.title = `Brightness unavailable: ${state.reason}`;
      track.style.setProperty("--v", "0");
      return;
    }
    const pct = Math.round(state.value * 100);
    track.style.setProperty("--v", String(state.value));
    label.textContent = `${pct}%`;
    el.title = `Brightness ${pct}%`;
  }

  function setValue(value: number) {
    if (!state.ok) return;
    state = { ok: true, value: clamp(value, 0, 1) };
    draw();
    send(state.value);
  }

  const valueAt = (e: PointerEvent) => {
    const r = track.getBoundingClientRect();
    return (r.bottom - e.clientY) / r.height;
  };
  el.addEventListener("pointerdown", (e) => {
    if (!state.ok) return;
    el.setPointerCapture(e.pointerId);
    dragging = true;
    el.classList.add("dragging");
    setValue(valueAt(e));
  });
  el.addEventListener("pointermove", (e) => {
    if (dragging) setValue(valueAt(e));
  });
  for (const type of ["pointerup", "pointercancel"] as const) {
    el.addEventListener(type, () => {
      dragging = false;
      el.classList.remove("dragging");
    });
  }
  el.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const n = steps(e);
      if (n && state.ok) setValue(state.value + (n * STEP) / 100);
    },
    { passive: false },
  );

  return {
    set(next: Brightness) {
      if (dragging) return;
      state = next;
      draw();
    },
  };
}

export const controls: Widget = (root) => {
  const brightness = brightnessSlider(root);
  const volume = dial(root, {
    name: "Volume",
    icon: ICON.volume,
    mutedIcon: ICON.volumeMuted,
    setLevel: (output) => call("set_volume", { output }),
    setMuted: (muted) => call("set_output_muted", { muted }),
  });
  const mic = dial(root, {
    name: "Mic",
    icon: ICON.mic,
    mutedIcon: ICON.micMuted,
    setLevel: (input) => call("set_input_volume", { input }),
    setMuted: (muted) => call("set_input_muted", { muted }),
  });

  async function read() {
    const [levels, bright] = await Promise.allSettled([
      call("get_volume"),
      call("get_brightness"),
    ]);
    if (levels.status === "fulfilled") {
      volume.set({ value: levels.value.output, muted: levels.value.outputMuted });
      const { input, inputRestore } = levels.value;
      mic.set({ value: inputRestore ?? input, muted: inputRestore !== null });
    }
    brightness.set(
      bright.status === "fulfilled"
        ? { ok: true, value: bright.value }
        : { ok: false, reason: String(bright.reason) },
    );
  }

  return { show: () => void read() };
};
