import "./settings.css";
import { call, on, type Config, type SettingsFiles, type SetupItem } from "../../ipc";
import { lucide } from "../../icons";
import { current, errors, onChange, type Settings } from "../../settings";
import { assistantView } from "../assistant";
import { dashboardView } from "../dashboard";
import type { NotchView } from "../view";
import { SCHEMES, wallpapersView } from "../wallpapers";
import {
  button,
  choiceRow,
  el,
  fanOut,
  field,
  folderRow,
  frame,
  group,
  infoRow,
  segmented,
  sliderRow,
  switchRow,
  textRow,
  type Frame,
  type Part,
} from "./rows";
import { rulesPart } from "./rules";
import { alertFor, setupPart } from "./setup";

const ICON = {
  setup: lucide('<path d="m3 17 2 2 4-4"/><path d="m3 7 2 2 4-4"/><path d="M13 6h8"/><path d="M13 12h8"/><path d="M13 18h8"/>'),
  appearance: lucide(
    '<path d="M12 8a2.83 2.83 0 0 0 4 4 4 4 0 1 1-4-4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.9 4.9 1.4 1.4"/><path d="m17.7 17.7 1.4 1.4"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.3 17.7-1.4 1.4"/><path d="m19.1 4.9-1.4 1.4"/>',
  ),
  bar: lucide('<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/>'),
  notch: lucide(
    '<rect width="20" height="12" x="2" y="6" rx="2"/><path d="M12 12h.01"/><path d="M17 12h.01"/><path d="M7 12h.01"/>',
  ),
  about: lucide('<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>'),
  alert: lucide(
    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  ),
  chevron: lucide('<path d="m6 9 6 6 6-6"/>'),
  gear: lucide(
    '<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/><circle cx="12" cy="12" r="3"/>',
  ),
} as const;

const openSettingsFile = () => call("open_settings_file").catch(() => {});

function schemeRow(): Part {
  const box = el("span", "st-select");
  const select = el("select", "");
  for (const s of SCHEMES) {
    const o = el("option", "", s.replace("scheme-", "").replace(/-/g, " "));
    o.value = s;
    select.append(o);
  }
  box.append(select);
  box.insertAdjacentHTML("beforeend", `<span class="icon">${ICON.chevron}</span>`);
  const f = frame("Scheme", "How matugen turns the wallpaper into colours.", box, null);
  const show = (cfg: Config) => {
    if (cfg.scheme) select.value = cfg.scheme;
  };
  select.addEventListener("change", () => {
    call("set_scheme", { scheme: select.value }).catch((e) => f.why(String(e)));
  });
  call("get_config").then(show).catch(() => {});
  on("theme", show);
  return { el: f.el };
}

const IDLE_PRESETS = ["handle", "clock", "userHost"];

function idleRow(): Part {
  let f: Frame;
  let custom = "edgebar";
  const seg = segmented(
    [
      { value: "handle", label: "Handle" },
      { value: "clock", label: "Clock" },
      { value: "userHost", label: "user@host" },
      { value: "custom", label: "Text" },
    ],
    (kind) => void f.commit("notch.idle", kind === "custom" ? custom : kind),
  );
  const text = field({ placeholder: "Shown as it is" }, (t) => void f.commit("notch.idle", t === "" ? null : t));
  const stack = el("div", "st-stack");
  stack.append(seg.el, text.el);
  f = frame("Idle look", "What the notch shows when nothing else has anything to say.", stack, "notch.idle");
  return {
    el: f.el,
    update(s) {
      const idle = s.notch.idle;
      const preset = IDLE_PRESETS.includes(idle);
      if (!preset) custom = idle;
      seg.mark(preset ? idle : "custom");
      text.el.hidden = preset;
      text.show(preset ? "" : idle);
      f.sync();
    },
  };
}

function aboutPart(): Part {
  const box = el("div", "st-section");
  const versionText = el("span", "st-value");
  const version = frame("Version", "", versionText, null);
  const versionCard = el("div", "st-card");
  versionCard.append(version.el);
  const card = el("div", "st-card");
  const open = button("st-btn filled", "Open settings.json");
  open.addEventListener("click", () => void openSettingsFile());
  const foot = el("div", "st-about-foot");
  foot.append(el("p", "st-note", "Each layer overrides the one above it. A row's reset drops your override."), open);
  const layers = el("section", "st-group");
  layers.append(el("h3", "st-group-title", "Settings layers"), card, foot);
  box.append(versionCard, layers);
  let shown = false;

  async function load() {
    const files: SettingsFiles | null = await call("settings_files").catch(() => null);
    if (!files || !shown) return;
    versionText.textContent = files.version;
    card.replaceChildren(
      ...files.layers.map((layer) => {
        const path = el("span", "st-path st-selectable", layer.path);
        const row = frame(layer.name, layer.detail, path, null);
        row.el.classList.add("st-layer");
        return row.el;
      }),
    );
  }
  return {
    el: box,
    update() {
      if (shown) void load();
    },
    show() {
      shown = true;
      void load();
    },
    hide() {
      shown = false;
    },
  };
}

interface Section {
  id: string;
  title: string;
  icon: string;
  build(): Part[];
}

export const settingsView: NotchView = {
  id: "settings",
  title: "Settings",
  icon: ICON.gear,
  rail: "foot",
  size: { w: 640, h: 352 },
  mount(root, ctx) {
    const setAlert = (items: SetupItem[]) => ctx.setAlert(alertFor(items));

    const sections: Section[] = [
      { id: "setup", title: "Setup", icon: ICON.setup, build: () => [setupPart(setAlert)] },
      {
        id: "appearance",
        title: "Appearance",
        icon: ICON.appearance,
        build: () => [
          group("", [
            choiceRow("appearance", "Mode", [
              { value: "light", label: "Light" },
              { value: "dark", label: "Dark" },
              { value: "auto", label: "Auto" },
            ], "Auto follows macOS."),
            schemeRow(),
            switchRow("oled", "OLED", "A pure black surface in dark mode."),
          ]),
          group("Frame", [
            sliderRow("geometry.frameRadius", "Corner radius", { min: 0, max: 32, step: 1, format: (v) => `${v} px` }, "The corners of the hole inside the frame."),
            infoRow(
              "Thickness",
              (s) => `${s.geometry.frameThickness} px`,
              "Set in modules/home/darwin/bar-geometry.nix, because AeroSpace's window gaps are built from it when the system is rebuilt.",
            ),
          ]),
        ],
      },
      {
        id: "bar",
        title: "Bar",
        icon: ICON.bar,
        build: () => [
          group("Clock", [
            switchRow("clock.hour24", "24-hour"),
            switchRow("clock.seconds", "Seconds", "Ticks every second while the bar is on screen."),
            switchRow("clock.date", "Date"),
          ]),
          group("Segments", [
            switchRow("segments.cpu", "CPU", "The load graph and the busiest process. Hidden, it still samples for Performance."),
          ]),
        ],
      },
      {
        id: "notch",
        title: "Notch",
        icon: ICON.notch,
        build: () => [
          group("", [
            idleRow(),
            sliderRow(
              "notch.transientMs",
              "Volume and brightness",
              { min: 500, max: 5000, step: 100, format: (v) => `${(v / 1000).toFixed(1)} s` },
              "How long the notch shows a change.",
            ),
          ]),
          group("Workspace rules", [rulesPart()]),
        ],
      },
      {
        id: "dashboard",
        title: "Dashboard",
        icon: dashboardView.icon,
        build: () => [
          group("Calendar", [
            choiceRow("calendar.weekStart", "Week starts on", [
              { value: "monday", label: "Monday" },
              { value: "sunday", label: "Sunday" },
            ]),
          ]),
          group("Notifications", [
            switchRow(
              "notifications.history",
              "Notification history",
              "Lists macOS's recent notifications here. edgebar reads them from macOS's notification store, which needs Full Disk Access. Off, it never opens the store.",
            ),
          ]),
          group("Quick toggles", [
            textRow("toggles.focusShortcut", "Focus Shortcut", {
              note: "The Shortcut the Focus toggle runs. Empty leaves the toggle read-only.",
              placeholder: "Toggle Focus",
            }),
          ]),
        ],
      },
      {
        id: "wallpapers",
        title: "Wallpapers",
        icon: wallpapersView.icon,
        build: () => [
          group("", [
            folderRow("wallpaper.folder", "Folder", () => call("pick_folder"), "Pictures here and one subfolder down are listed."),
            switchRow("wallpaper.tint", "Tint", "Repaints the desktop picture in the theme's colours. HEIC pictures aren't tinted."),
          ]),
        ],
      },
      {
        id: "assistant",
        title: "Assistant",
        icon: assistantView.icon,
        build: () => [
          group("", [
            choiceRow("assistant.model", "Model", [
              { value: "haiku", label: "Haiku" },
              { value: "sonnet", label: "Sonnet" },
              { value: "opus", label: "Opus" },
            ]),
            textRow("assistant.command", "CLI command", {
              note: "Claude Code. A bare name is looked up on PATH, then in ~/.local/bin.",
              placeholder: "claude",
              mono: true,
              emptyResets: true,
            }),
          ]),
        ],
      },
      { id: "about", title: "About", icon: ICON.about, build: () => [aboutPart()] },
    ];

    root.innerHTML =
      '<nav class="st-nav"></nav>' +
      '<div class="st-main">' +
      `<div class="st-banner" hidden><span class="icon">${ICON.alert}</span><p class="st-banner-text"></p></div>` +
      '<div class="view-head"><span class="view-title"></span></div>' +
      '<div class="st-scroll"></div>' +
      "</div>";
    const nav = root.querySelector<HTMLElement>(".st-nav")!;
    const banner = root.querySelector<HTMLElement>(".st-banner")!;
    const bannerText = banner.querySelector<HTMLElement>(".st-banner-text")!;
    const title = root.querySelector<HTMLElement>(".view-title")!;
    const scroll = root.querySelector<HTMLElement>(".st-scroll")!;
    const fix = button("st-btn filled", "Open settings.json");
    fix.addEventListener("click", () => void openSettingsFile());
    banner.append(fix);
    root.addEventListener("click", (e) => e.stopPropagation());

    const bodies = new Map<string, { el: HTMLElement; part: Part }>();
    const tabs = new Map<string, HTMLButtonElement>();
    for (const section of sections) {
      const body = el("div", "st-section");
      body.hidden = true;
      const parts = section.build();
      body.append(...parts.map((p) => p.el));
      const part = fanOut(body, parts);
      bodies.set(section.id, { el: body, part });
      scroll.append(body);
      const tab = button("st-tab", `<span class="icon">${section.icon}</span><span>${section.title}</span>`);
      tab.addEventListener("click", () => select(section.id));
      tabs.set(section.id, tab);
      nav.append(tab);
    }

    let active = sections[0].id;
    let visible = false;
    function select(id: string) {
      if (visible && id !== active) bodies.get(active)!.part.hide?.();
      active = id;
      for (const [sid, { el: body }] of bodies) body.hidden = sid !== id;
      for (const [sid, tab] of tabs) tab.classList.toggle("active", sid === id);
      title.textContent = sections.find((s) => s.id === id)!.title;
      scroll.scrollTop = 0;
      if (visible) bodies.get(id)!.part.show?.();
    }

    function update(s: Settings) {
      const problems = errors();
      banner.hidden = problems.length === 0;
      bannerText.textContent = problems.join("\n");
      for (const { part } of bodies.values()) part.update?.(s);
    }
    onChange(update);
    update(current());
    select(active);

    return {
      open() {
        call("setup_status").then(setAlert).catch(() => {});
      },
      show() {
        visible = true;
        bodies.get(active)!.part.show?.();
      },
      hide() {
        visible = false;
        bodies.get(active)!.part.hide?.();
      },
    };
  },
};
