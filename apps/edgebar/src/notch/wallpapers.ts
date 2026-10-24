import "./wallpapers.css";
import { call, on, type Config, type InkInfo, type Wallpaper } from "../ipc";
import { lucide } from "../icons";
import { keyboardField } from "../keyboard";
import { current, onChange, set as setSetting } from "../settings";
import type { NotchView } from "./view";

export const SCHEMES = [
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

const TINT_PATIENCE_MS = 20000;

const ICON = {
  search: lucide('<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>'),
  clear: lucide('<path d="M18 6 6 18"/><path d="m6 6 12 12"/>'),
  chevron: lucide('<path d="m6 9 6 6 6-6"/>'),
  check: lucide('<path d="M20 6 9 17l-5-5"/>'),
  oled: lucide('<circle cx="12" cy="12" r="10"/><path d="M12 18a6 6 0 0 0 0-12v12z"/>'),
  tint: lucide(
    '<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>',
  ),
  folder: lucide(
    '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  ),
  empty: lucide(
    '<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>',
  ),
} as const;

const TEMPLATE =
  '<div class="view-head"><span class="view-title">Wallpapers</span>' +
  '<div class="wp-switches">' +
  `<button class="wp-switch" type="button" data-k="oled" aria-pressed="false"><span class="icon">${ICON.oled}</span><span>OLED</span></button>` +
  `<button class="wp-switch" type="button" data-k="tint" aria-pressed="false"><span class="icon wp-tint-icon">${ICON.tint}</span><span>Tint</span></button>` +
  "</div>" +
  '<div class="theme-toggle" role="group" aria-label="Appearance">' +
  `<button class="theme-opt" data-mode="light" title="Light"><span class="icon">${lucide(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
  )}</span></button>` +
  `<button class="theme-opt" data-mode="dark" title="Dark"><span class="icon">${lucide(
    '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
  )}</span></button>` +
  `<button class="theme-opt" data-mode="auto" title="Auto (system)"><span class="icon">${lucide(
    '<rect width="20" height="14" x="2" y="3" rx="2"/><line x1="8" x2="16" y1="21" y2="21"/><line x1="12" x2="12" y1="17" y2="21"/>',
  )}</span></button>` +
  "</div></div>" +
  '<div class="theme-bar">' +
  `<label class="wp-search"><span class="icon">${ICON.search}</span>` +
  '<input class="wp-query" type="text" placeholder="Search wallpapers…" spellcheck="false" autocomplete="off">' +
  `<button class="wp-clear" type="button" aria-label="Clear the search" hidden>${ICON.clear}</button></label>` +
  '<span class="wp-select"><select class="scheme-select" id="scheme-select" title="matugen scheme"></select>' +
  `<span class="icon">${ICON.chevron}</span></span>` +
  '<div class="theme-toggle ink-toggle" role="group" aria-label="Ink">' +
  '<span class="ink-label">Ink</span>' +
  '<button class="ink-opt" id="ink-auto">Auto</button>' +
  '<button class="ink-opt" id="ink-custom"><span class="ink-swatch"></span></button>' +
  "</div>" +
  `<button class="browse-btn" id="browse-btn"><span class="icon">${ICON.folder}</span><span>Browse…</span></button>` +
  "</div>" +
  '<div class="wp-filters" hidden></div>' +
  '<div class="filmstrip" id="filmstrip"></div>' +
  `<div class="wp-empty" hidden><span class="icon">${ICON.empty}</span><span class="wp-empty-text"></span></div>`;

interface Chip {
  key: string;
  label: string;
  matches: (w: Wallpaper) => boolean;
}

function chipsFor(list: Wallpaper[]): Chip[] {
  const kinds = [...new Set(list.map((w) => w.kind))].sort();
  const folders = [...new Set(list.map((w) => w.folder).filter(Boolean))].sort();
  if (kinds.length <= 1 && folders.length === 0) return [];
  return [
    ...kinds.map((k) => ({ key: `kind:${k}`, label: k.toUpperCase(), matches: (w: Wallpaper) => w.kind === k })),
    ...folders.map((f) => ({ key: `folder:${f}`, label: f, matches: (w: Wallpaper) => w.folder === f })),
  ];
}

type TintWait = { until: "pick"; path: string } | { until: "pass" } | null;

export const wallpapersView: NotchView = {
  id: "wallpapers",
  title: "Wallpapers",
  icon: lucide(
    '<path d="M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z"/><circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/>',
  ),
  size: { w: 624, h: 352 },
  mount(root) {
    root.innerHTML = TEMPLATE;
    const filmstrip = root.querySelector<HTMLElement>("#filmstrip")!;
    const filtersEl = root.querySelector<HTMLElement>(".wp-filters")!;
    const emptyEl = root.querySelector<HTMLElement>(".wp-empty")!;
    const emptyText = emptyEl.querySelector<HTMLElement>(".wp-empty-text")!;
    const query = root.querySelector<HTMLInputElement>(".wp-query")!;
    const clear = root.querySelector<HTMLButtonElement>(".wp-clear")!;
    const oledBtn = root.querySelector<HTMLButtonElement>('.wp-switch[data-k="oled"]')!;
    const tintBtn = root.querySelector<HTMLButtonElement>('.wp-switch[data-k="tint"]')!;
    const schemeSelect = root.querySelector<HTMLSelectElement>("#scheme-select")!;
    const modeButtons = [...root.querySelectorAll<HTMLElement>(".theme-opt")];
    const inkAuto = root.querySelector<HTMLElement>("#ink-auto")!;
    const inkCustom = root.querySelector<HTMLElement>("#ink-custom")!;
    const inkSwatch = inkCustom.querySelector<HTMLElement>(".ink-swatch")!;
    let inkColour = "";

    let all: Wallpaper[] = [];
    let chips: Chip[] = [];
    const selected = new Set<string>();
    const thumbs = new Map<string, HTMLButtonElement>();
    let tintWait: TintWait = null;

    function visible(w: Wallpaper): boolean {
      const q = query.value.trim().toLowerCase();
      if (q && !w.name.toLowerCase().includes(q)) return false;
      return selected.size === 0 || chips.some((c) => selected.has(c.key) && c.matches(w));
    }

    function applyFilter() {
      let shown = 0;
      for (const w of all) {
        const ok = visible(w);
        thumbs.get(w.path)!.hidden = !ok;
        if (ok) shown++;
      }
      clear.hidden = !query.value;
      const q = query.value.trim();
      filmstrip.hidden = shown === 0;
      emptyEl.hidden = shown > 0;
      emptyText.textContent =
        all.length === 0
          ? `No pictures in ${current().wallpaper.folder}. Browse… picks one from anywhere.`
          : q
            ? `Nothing matches “${q}”.`
            : "Nothing matches these filters.";
    }

    function setActive(path: string) {
      for (const [p, t] of thumbs) t.classList.toggle("active", p === path);
    }

    function renderChips() {
      for (const key of [...selected]) if (!chips.some((c) => c.key === key)) selected.delete(key);
      filtersEl.hidden = chips.length === 0;
      filtersEl.replaceChildren(
        ...chips.map((c) => {
          const b = document.createElement("button");
          b.type = "button";
          b.className = "wp-chip";
          b.classList.toggle("active", selected.has(c.key));
          b.setAttribute("aria-pressed", String(selected.has(c.key)));
          b.innerHTML = `<span class="wp-check">${ICON.check}</span><span></span>`;
          b.lastElementChild!.textContent = c.label;
          b.addEventListener("click", () => {
            if (selected.has(c.key)) selected.delete(c.key);
            else selected.add(c.key);
            b.classList.toggle("active", selected.has(c.key));
            b.setAttribute("aria-pressed", String(selected.has(c.key)));
            applyFilter();
          });
          return b;
        }),
      );
    }

    function renderGrid(list: Wallpaper[], desktop: string) {
      all = list;
      chips = chipsFor(list);
      thumbs.clear();
      filmstrip.replaceChildren(
        ...list.map((w) => {
          const b = document.createElement("button");
          b.className = "thumb";
          b.title = w.name;
          const img = document.createElement("img");
          img.src = w.thumb;
          img.alt = w.name;
          b.appendChild(img);
          b.addEventListener("click", () => {
            setActive(w.path);
            if (current().wallpaper.tint) waitForTint({ until: "pick", path: w.path });
            call("set_wallpaper", { path: w.path });
          });
          thumbs.set(w.path, b);
          return b;
        }),
      );
      renderChips();
      setActive(tintWait?.until === "pick" ? tintWait.path : desktop);
      applyFilter();
    }

    keyboardField(root.querySelector<HTMLElement>(".wp-search")!);
    query.addEventListener("input", applyFilter);
    query.addEventListener("keydown", (e) => {
      if (e.key !== "Escape" || !query.value) return;
      e.preventDefault();
      query.value = "";
      applyFilter();
    });
    clear.addEventListener("click", (e) => {
      e.preventDefault();
      query.value = "";
      applyFilter();
    });

    let tintTimer = 0;
    let mode: InkInfo["mode"] = "dark";

    function showSwitches() {
      const s = current();
      const tintBusy = tintWait !== null;
      oledBtn.classList.toggle("active", s.oled);
      oledBtn.setAttribute("aria-pressed", String(s.oled));
      oledBtn.disabled = mode === "light";
      oledBtn.title =
        mode === "light" ? "OLED: a black surface in dark mode (off while light)" : "OLED: a black surface";
      tintBtn.classList.toggle("active", s.wallpaper.tint);
      tintBtn.setAttribute("aria-pressed", String(s.wallpaper.tint));
      tintBtn.classList.toggle("busy", tintBusy);
      tintBtn.title = tintBusy ? "Tint: repainting the desktop…" : "Tint: repaint the desktop in the theme's colours";
    }

    function waitForTint(wait: TintWait) {
      tintWait = wait;
      clearTimeout(tintTimer);
      if (wait) tintTimer = window.setTimeout(() => waitForTint(null), TINT_PATIENCE_MS);
      showSwitches();
    }

    const retint = () => {
      if (current().wallpaper.tint) waitForTint({ until: "pass" });
    };

    async function flip(key: "oled" | "wallpaper.tint", on: boolean) {
      try {
        await setSetting(key, on);
      } catch {
        waitForTint(null);
      }
      showSwitches();
    }
    oledBtn.addEventListener("click", () => {
      retint();
      void flip("oled", !current().oled);
    });
    tintBtn.addEventListener("click", () => {
      waitForTint({ until: "pass" });
      void flip("wallpaper.tint", !current().wallpaper.tint);
    });

    on("desktop", (shown) => {
      if (tintWait?.until === "pick" && shown !== tintWait.path) return;
      if (shown) setActive(shown);
      if (tintWait) waitForTint(null);
    });

    function setActiveMode(m: string) {
      for (const b of modeButtons) b.classList.toggle("active", b.dataset.mode === m);
    }
    for (const b of modeButtons) {
      b.addEventListener("click", () => {
        const m = b.dataset.mode!;
        setActiveMode(m);
        retint();
        void setSetting("appearance", m);
      });
    }

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
          ? `Auto: ${colour}, ${ratio(info.ratio)} on the surface ` +
            `(the scheme's ${info.configured} was only ${ratio(info.configuredRatio)})`
          : `Auto: ${colour}, ${ratio(info.ratio)} on the surface`;
      inkCustom.title = pinned
        ? `Custom ${info.mode} ink: ${colour}, ${ratio(info.ratio)} on the surface`
        : `Pick a ${info.mode} ink…`;
    }
    inkAuto.addEventListener("click", () => {
      call("set_ink", { colour: null });
    });
    inkCustom.addEventListener("click", () => {
      call("pick_colour", { initial: inkColour }).then((colour) => {
        if (colour) call("set_ink", { colour });
      });
    });

    for (const s of SCHEMES) {
      const o = document.createElement("option");
      o.value = s;
      o.textContent = s.replace("scheme-", "").replace(/-/g, " ");
      schemeSelect.appendChild(o);
    }
    schemeSelect.addEventListener("change", () => {
      retint();
      call("set_scheme", { scheme: schemeSelect.value });
    });

    function showConfig(cfg: Config) {
      if (cfg.scheme) schemeSelect.value = cfg.scheme;
      setActiveMode(cfg.appearance);
      renderInk(cfg.ink, cfg.colors.text);
      mode = cfg.ink.mode;
      showSwitches();
    }

    async function load() {
      const [wallpapers, desktop, cfg] = await Promise.all([
        call("list_wallpapers"),
        call("current_wallpaper"),
        call("get_config"),
      ]);
      renderGrid(wallpapers, desktop);
      showConfig(cfg);
      call("precompute_palettes").catch(() => {});
    }

    root.querySelector<HTMLElement>("#browse-btn")!.addEventListener("click", () => {
      call("pick_wallpaper_file").then((path) => {
        if (!path) return;
        setActive(path);
        if (current().wallpaper.tint) waitForTint({ until: "pick", path });
        call("set_wallpaper", { path });
      });
    });

    on("theme", showConfig);

    let shown = false;
    let folder = current().wallpaper.folder;
    onChange((s) => {
      showSwitches();
      if (s.wallpaper.folder === folder) return;
      folder = s.wallpaper.folder;
      if (shown) void load();
    });

    call("get_config").then(showConfig).catch(() => {});

    return {
      show() {
        shown = true;
        void load();
      },
      hide() {
        shown = false;
      },
    };
  },
};
