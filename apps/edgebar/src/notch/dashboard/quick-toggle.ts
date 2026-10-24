import "./quick-toggle.css";
import { call, on, type SettingsPane, type ToggleId, type ToggleState } from "../../ipc";
import { lucide } from "../../icons";

const MOON = lucide(
  '<path d="M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401"/>',
);
const SUNSET = lucide(
  '<path d="M12 10V2"/><path d="m4.93 10.93 1.41 1.41"/><path d="M2 18h2"/><path d="M20 18h2"/><path d="m19.07 10.93-1.41 1.41"/><path d="M22 22H2"/><path d="m16 6-4 4-4-4"/><path d="M16 18a4 4 0 0 0-8 0"/>',
);
const COFFEE = lucide(
  '<path d="M10 2v2"/><path d="M14 2v2"/><path d="M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1"/><path d="M6 2v2"/>',
);

const TOGGLES: Record<ToggleId, { name: string; on: string; off: string; pane: SettingsPane | null }> = {
  wifi: {
    name: "Wi-Fi",
    on: lucide(
      '<path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/>',
    ),
    off: lucide(
      '<path d="M12 20h.01"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><path d="M5 12.859a10 10 0 0 1 5.17-2.69"/><path d="M19 12.859a10 10 0 0 0-2.007-1.523"/><path d="M2 8.82a15 15 0 0 1 4.177-2.643"/><path d="M22 8.82a15 15 0 0 0-11.288-3.764"/><path d="m2 2 20 20"/>',
    ),
    pane: "wifi",
  },
  bluetooth: {
    name: "Bluetooth",
    on: lucide('<path d="m7 7 10 10-5 5V2l5 5L7 17"/>'),
    off: lucide('<path d="m17 17-5 5V12l-5 5"/><path d="m2 2 20 20"/><path d="M14.5 9.5 17 7l-5-5v4.5"/>'),
    pane: "bluetooth",
  },
  focus: {
    name: "Focus",
    on: MOON,
    off: MOON,
    pane: "focus",
  },
  nightShift: {
    name: "Night Shift",
    on: SUNSET,
    off: SUNSET,
    pane: "displays",
  },
  caffeine: {
    name: "Caffeine",
    on: COFFEE,
    off: COFFEE,
    pane: null,
  },
};

export const ORDER: ToggleId[] = ["wifi", "bluetooth", "focus", "nightShift", "caffeine"];

const PANE_NAMES: Record<SettingsPane, string> = {
  wifi: "Wi-Fi settings",
  bluetooth: "Bluetooth settings",
  focus: "Focus settings",
  displays: "Displays settings",
  fullDiskAccess: "Full Disk Access",
  privacyBluetooth: "Bluetooth privacy",
  privacyAutomation: "Automation privacy",
};

const FIXES: [RegExp, SettingsPane][] = [
  [/Full Disk Access/, "fullDiskAccess"],
  [/Bluetooth permission/, "privacyBluetooth"],
];
const paneFor = (s: ToggleState): SettingsPane | null =>
  FIXES.find(([re]) => re.test(s.detail))?.[1] ?? TOGGLES[s.id].pane;

export const openPane = (pane: SettingsPane) => call("open_settings_pane", { pane }).catch(() => {});

const states = new Map<ToggleId, ToggleState>();
const pending = new Set<ToggleId>();
const listeners = new Set<() => void>();

function notify() {
  for (const fn of listeners) fn();
}

function apply(next: ToggleState[]) {
  for (const s of next) if (!pending.has(s.id)) states.set(s.id, s);
  notify();
}

on("toggles", apply);

export function refreshToggles() {
  call("toggles").then(apply).catch(() => {});
}

async function flip(s: ToggleState): Promise<string | null> {
  const want = !s.on;
  pending.add(s.id);
  states.set(s.id, { ...s, on: want });
  notify();
  try {
    const reply = await call("set_toggle", { id: s.id, on: want });
    states.set(s.id, reply);
    return reply.on === want ? null : reply.detail;
  } catch (e) {
    states.set(s.id, s);
    return String(e);
  } finally {
    pending.delete(s.id);
    notify();
  }
}

export interface Note {
  show(anchor: HTMLElement, text: string, pane: SettingsPane | null): void;
  hide(): void;
}

export function note(host: HTMLElement): Note {
  const el = document.createElement("div");
  el.className = "tg-note";
  el.hidden = true;
  el.innerHTML = '<p class="tg-note-text"></p><button class="tg-note-open" type="button"></button>';
  host.append(el);
  const text = el.querySelector<HTMLElement>(".tg-note-text")!;
  const open = el.querySelector<HTMLButtonElement>(".tg-note-open")!;
  let shownFor: HTMLElement | null = null;
  let pane: SettingsPane | null = null;

  const outside = (e: PointerEvent) => {
    const t = e.target as Node;
    if (!el.contains(t) && !shownFor?.contains(t)) hide();
  };
  function hide() {
    if (!shownFor) return;
    shownFor = null;
    el.hidden = true;
    document.removeEventListener("pointerdown", outside, true);
  }
  open.addEventListener("click", () => {
    if (pane) void openPane(pane);
    hide();
  });

  return {
    show(anchor, why, fix) {
      if (shownFor === anchor && text.textContent === why) return hide();
      text.textContent = why;
      pane = fix;
      open.hidden = !fix;
      open.textContent = fix ? `Open ${PANE_NAMES[fix]}` : "";
      el.style.top = `${anchor.getBoundingClientRect().bottom - host.getBoundingClientRect().top + 4}px`;
      el.hidden = false;
      if (!shownFor) document.addEventListener("pointerdown", outside, true);
      shownFor = anchor;
    },
    hide,
  };
}

export function toggleButton(
  id: ToggleId,
  hint: Note,
  glyphs: { on: string; off: string } = TOGGLES[id],
): HTMLButtonElement {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "qt";
  btn.innerHTML = '<span class="icon"></span>';
  const icon = btn.firstElementChild as HTMLElement;
  const { name } = TOGGLES[id];
  let drawn = "";

  function draw() {
    const s = states.get(id);
    const busy = pending.has(id);
    const key = s ? `${s.on}|${s.available}|${s.detail}|${busy}` : "";
    if (key === drawn) return;
    drawn = key;
    const on = !!s?.on;
    icon.innerHTML = on ? glyphs.on : glyphs.off;
    btn.classList.toggle("on", on);
    btn.classList.toggle("unavailable", !!s && !s.available);
    btn.classList.toggle("busy", busy);
    btn.setAttribute("aria-pressed", String(on));
    btn.title = s ? `${name}: ${s.detail}` : name;
  }
  listeners.add(draw);
  draw();

  btn.addEventListener("click", async () => {
    const s = states.get(id);
    if (!s || pending.has(id)) return;
    if (!s.available) return hint.show(btn, s.detail, paneFor(s));
    hint.hide();
    const failed = await flip(s);
    const now = states.get(id);
    if (failed && now) hint.show(btn, failed, paneFor({ ...now, detail: failed }));
  });
  btn.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    const pane = TOGGLES[id].pane;
    if (pane) void openPane(pane);
  });
  return btn;
}
