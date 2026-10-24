import "./wallpapers.css";
import { call, on, type Config, type InkInfo, type Wallpaper } from "../ipc";
import { lucide } from "../icons";
import type { NotchView } from "./view";

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

const TEMPLATE =
  '<div class="view-head"><span class="view-title">Wallpapers</span>' +
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
  // ambxst's WallpapersTab puts search, OLED mode, tint and the scheme picker
  // in one 48px row above the grid.
  '<div class="theme-bar">' +
  `<div class="ph ph-inline" data-for="SearchBar"><span class="ph-icon icon">${lucide(
    '<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>',
  )}</span><span class="ph-name">Search</span></div>` +
  '<select class="scheme-select" id="scheme-select" title="matugen scheme"></select>' +
  '<div class="theme-toggle ink-toggle" role="group" aria-label="Pill ink">' +
  '<span class="ink-label">Ink</span>' +
  '<button class="ink-opt" id="ink-auto">Auto</button>' +
  '<button class="ink-opt" id="ink-custom"><span class="ink-swatch"></span></button>' +
  "</div>" +
  `<button class="chip wip" title="OLED mode — not implemented"><span class="icon">${lucide(
    '<circle cx="12" cy="12" r="10"/><path d="M12 18a6 6 0 0 0 0-12v12z"/>',
  )}</span><span>OLED</span></button>` +
  // A droplet, not a palette: the rail's wallpapers tab already uses that icon.
  `<button class="chip wip" title="Tint — not implemented"><span class="icon">${lucide(
    '<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>',
  )}</span><span>Tint</span></button>` +
  `<button class="browse-btn" id="browse-btn"><span class="icon">${lucide(
    '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  )}</span><span>Browse…</span></button>` +
  "</div>" +
  // FilterBar: file-type chips and the subfolder crumbs that narrow the grid.
  `<div class="ph ph-inline" data-for="FilterBar"><span class="ph-icon icon">${lucide(
    '<path d="M10 5H3"/><path d="M12 19H3"/><path d="M14 3v4"/><path d="M16 17v4"/><path d="M21 12h-9"/><path d="M21 19h-5"/><path d="M21 5h-7"/><path d="M8 10v4"/><path d="M8 12H3"/>',
  )}</span><span class="ph-name">FilterBar</span><span class="ph-note">type chips · subfolders</span></div>` +
  '<div class="filmstrip" id="filmstrip"></div>';

export const wallpapersView: NotchView = {
  id: "wallpapers",
  title: "Wallpapers",
  icon: lucide(
    '<path d="M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z"/><circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/>',
  ),
  size: { w: 704, h: 400 },
  mount(root) {
    root.innerHTML = TEMPLATE;
    const filmstrip = root.querySelector<HTMLElement>("#filmstrip")!;
    const schemeSelect = root.querySelector<HTMLSelectElement>("#scheme-select")!;
    const modeButtons = [...root.querySelectorAll<HTMLElement>(".theme-opt")];
    const inkAuto = root.querySelector<HTMLElement>("#ink-auto")!;
    const inkCustom = root.querySelector<HTMLElement>("#ink-custom")!;
    const inkSwatch = inkCustom.querySelector<HTMLElement>(".ink-swatch")!;
    let inkColour = "";

    // Appearance: set_appearance persists the choice, re-resolves colours and
    // emits "theme". Auto follows the macOS setting (Rust observes it).
    function setActiveMode(mode: string) {
      for (const b of modeButtons) b.classList.toggle("active", b.dataset.mode === mode);
    }
    for (const b of modeButtons) {
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        const mode = b.dataset.mode!;
        setActiveMode(mode);
        call("set_appearance", { mode });
      });
    }

    // Ink: the colour drawn on the pills. Auto is Rust's contrast-checked pick;
    // the swatch opens the system colour picker and pins an ink for the current
    // light/dark scheme. Both report back through the "theme" event.
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
    inkAuto.addEventListener("click", (e) => {
      e.stopPropagation();
      call("set_ink", { colour: null });
    });
    inkCustom.addEventListener("click", (e) => {
      e.stopPropagation();
      call("pick_colour", { initial: inkColour }).then((colour) => {
        if (colour) call("set_ink", { colour });
      });
    });

    // A thumb sets the desktop and re-themes the bar (Rust runs desktoppr and
    // generate-edgebar-theme).
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
          call("set_wallpaper", { path: w.path });
          for (const t of filmstrip.children) t.classList.remove("active");
          b.classList.add("active");
        });
        filmstrip.appendChild(b);
      }
    }

    for (const s of SCHEMES) {
      const o = document.createElement("option");
      o.value = s;
      o.textContent = s.replace("scheme-", "").replace(/-/g, " ");
      schemeSelect.appendChild(o);
    }
    schemeSelect.addEventListener("change", (e) => {
      e.stopPropagation();
      call("set_scheme", { scheme: schemeSelect.value });
    });

    function showConfig(cfg: Config) {
      schemeSelect.value = cfg.scheme;
      setActiveMode(cfg.appearance);
      renderInk(cfg.ink, cfg.colors.base);
    }

    async function load() {
      const [wallpapers, current, cfg] = await Promise.all([
        call("list_wallpapers"),
        call("current_wallpaper"),
        call("get_config"),
      ]);
      renderFilmstrip(wallpapers, current);
      showConfig(cfg);
      // warm the per-wallpaper palette caches so thumbnail clicks are instant
      call("precompute_palettes").catch(() => {});
    }

    // Browse… → native Finder picker → set + theme the chosen file in place.
    root.querySelector<HTMLElement>("#browse-btn")!.addEventListener("click", (e) => {
      e.stopPropagation();
      call("pick_wallpaper_file").then((path) => {
        if (!path) return;
        call("set_wallpaper", { path });
        for (const t of filmstrip.children) t.classList.remove("active");
      });
    });

    // Live theme pushes (day/night flip, wallpaper or scheme change from anywhere).
    on("theme", (theme) => {
      setActiveMode(theme.appearance);
      renderInk(theme.ink, theme.colors.base);
      if (theme.scheme) schemeSelect.value = theme.scheme;
    });

    // Seeds the toggles and the ink swatch, so they are right before the first
    // load lands.
    call("get_config").then(showConfig).catch(() => {});

    return {
      show() {
        void load();
      },
    };
  },
};
