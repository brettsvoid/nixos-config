// edgebar spike — ambxst-style top bar on macOS.
//
// Click-through is solved with window *geometry*, not by toggling
// ignore_cursor_events from a hot loop (that deadlocks on macOS: the runtime's
// getters block on the main event loop, which stops servicing them while the
// cursor is being tracked over a window). Two windows instead:
//
//   * "frame" — full-screen, transparent, permanently click-through. The bezel.
//   * "bar"   — a thin interactive strip pinned to the top. The pills.
//
// Anything outside the top strip lands on the click-through frame and passes to
// the app underneath. The bar webview gets native mouse events, so hover/click
// and reveal/hide need no polling.

use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{Emitter, LogicalPosition, LogicalSize, Manager};

/// Appearance preference. `Auto` follows the macOS system light/dark setting;
/// `Light`/`Dark` pin it. Lives in config.json and is overridable at runtime
/// (persisted to `~/.config/edgebar/appearance`).
#[derive(Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
enum Appearance {
    Light,
    Dark,
    Auto,
}

fn default_appearance() -> Appearance {
    Appearance::Auto
}

/// The concrete scheme in effect once `Auto` is resolved against the system.
/// Selects which palette (light/dark) the color roles resolve against.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Scheme {
    Light,
    Dark,
}

/// Per-scheme color-role maps. Catppuccin inverts its neutral ramp between
/// flavors, so day and night need distinct role→palette-key mappings (e.g. the
/// on-pill ink is `base` at night but `text` by day). Each value is a palette
/// key (resolved against the active scheme's palette) or a literal `#hex`.
#[derive(Clone, Deserialize, Serialize)]
struct Themes {
    dark: Colors,
    light: Colors,
}

impl Themes {
    fn for_scheme(&self, s: Scheme) -> &Colors {
        match s {
            Scheme::Light => &self.light,
            Scheme::Dark => &self.dark,
        }
    }
}

/// Light + dark palettes (palette-key → hex). Loaded from
/// `~/.config/edgebar/palette.json` (matugen-generated) if present, else the
/// bundled default (Catppuccin Latte / Mocha).
#[derive(Clone, Deserialize)]
struct Palettes {
    light: std::collections::HashMap<String, String>,
    dark: std::collections::HashMap<String, String>,
}

impl Palettes {
    fn for_scheme(&self, s: Scheme) -> &std::collections::HashMap<String, String> {
        match s {
            Scheme::Light => &self.light,
            Scheme::Dark => &self.dark,
        }
    }
}

/// Single source of truth for colors + geometry, read by both the native frame
/// (Rust) and the bar WebView (applied as CSS custom properties). Loaded from
/// `~/.config/edgebar/config.json` if present, else the bundled default.
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Config {
    #[serde(default = "default_appearance")]
    appearance: Appearance,
    colors: Themes,
    geometry: Geometry,
    /// Binaries the bar shells out to for the in-app wallpaper/scheme picker.
    /// Nix injects absolute store paths; absent (bundled default / dev), they
    /// fall back to a bare name resolved on PATH.
    #[serde(default)]
    theme_command: Option<String>,
    #[serde(default)]
    wallpaper_command: Option<String>,
}

/// What `get_config` and the `theme` event hand the WebView: colors already
/// resolved to hex for the active scheme, plus geometry, appearance, and the
/// active matugen scheme (so the theme view can mark current selections).
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ResolvedConfig {
    colors: Colors,
    geometry: Geometry,
    appearance: Appearance,
    scheme: String,
}

/// Resolve a role map against a palette: palette name → hex (literal `#hex`
/// passes through; an unknown name passes through unchanged).
fn resolve_colors(
    colors: &Colors,
    palette: &std::collections::HashMap<String, String>,
) -> Colors {
    let r = |v: &str| -> String {
        if v.starts_with('#') {
            v.to_string()
        } else {
            palette.get(v).cloned().unwrap_or_else(|| v.to_string())
        }
    };
    Colors {
        base: r(&colors.base),
        pill_bg: r(&colors.pill_bg),
        text: r(&colors.text),
        subtext: r(&colors.subtext),
        accent: r(&colors.accent),
        occupied: r(&colors.occupied),
        empty: r(&colors.empty),
        battery_charging: r(&colors.battery_charging),
        battery_low: r(&colors.battery_low),
        vpn: r(&colors.vpn),
        cpu_sys: r(&colors.cpu_sys),
        cpu_user: r(&colors.cpu_user),
        frame_line: r(&colors.frame_line),
        frame_corner: r(&colors.frame_corner),
    }
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Colors {
    base: String,
    pill_bg: String,
    text: String,
    subtext: String,
    accent: String,
    occupied: String,
    empty: String,
    /// Battery-state accents. Serde defaults keep an older config.json (rendered
    /// before these existed) parsing instead of dropping to the bundled default.
    #[serde(default = "default_battery_charging")]
    battery_charging: String,
    #[serde(default = "default_battery_low")]
    battery_low: String,
    #[serde(default = "default_vpn")]
    vpn: String,
    /// The CPU graph's two traces (filled system load, stroked user load).
    #[serde(default = "default_cpu_sys")]
    cpu_sys: String,
    #[serde(default = "default_cpu_user")]
    cpu_user: String,
    frame_line: String,
    frame_corner: String,
}

fn default_battery_charging() -> String {
    "#40a02b".to_string()
}
fn default_battery_low() -> String {
    "#d20f39".to_string()
}
fn default_vpn() -> String {
    "#179299".to_string()
}
fn default_cpu_sys() -> String {
    "#d20f39".to_string()
}
fn default_cpu_user() -> String {
    "#1e66f5".to_string()
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Geometry {
    inner_radius: f64,
    line_thickness: f64,
    pill_height: f64,
    pill_radius: f64,
    concave: f64,
    /// Height (logical px) of the bar window itself. Taller than the bar band
    /// AeroSpace reserves (config's `barHeight`, consumed only on the Nix side)
    /// so the pills' shadows and the corner fillets that hang below the band
    /// aren't clipped by the window bounds. The extra height is transparent and
    /// passes clicks through, so it doesn't cover the windows below.
    #[serde(default = "default_window_height")]
    window_height: f64,
    /// Top offset in DEVICE pixels. This display does not show its topmost
    /// physical row (see the inset in `create_native_frame`), so both the native
    /// frame and the bar window are pushed down by this many device pixels to
    /// keep their top edge on the first visible row. Device px, not points, so it
    /// is one dead row regardless of the backing scale.
    #[serde(default = "default_top_offset_px")]
    top_offset_px: f64,
}

/// Fallback when an older config.json (rendered before `windowHeight` existed)
/// omits the field — keeps such a config parsing instead of dropping to the
/// fully-bundled default.
fn default_window_height() -> f64 {
    64.0
}

/// Fallback for configs rendered before `topOffsetPx` existed.
fn default_top_offset_px() -> f64 {
    1.0
}

fn load_config() -> Config {
    const DEFAULT: &str = include_str!("../config.default.json");
    std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/config.json"))
        .and_then(|path| std::fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| {
            serde_json::from_str(DEFAULT).expect("bundled config.default.json is valid")
        })
}

fn load_palettes() -> Palettes {
    const DEFAULT: &str = include_str!("../palette.default.json");
    std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/palette.json"))
        .and_then(|path| std::fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| {
            serde_json::from_str(DEFAULT).expect("bundled palette.default.json is valid")
        })
}

/// Runtime appearance override (a 3-way light/dark/auto toggle from the bar),
/// persisted next to the nix-rendered config.json (which is a read-only symlink
/// into the Nix store, so it can't hold this mutable preference).
fn appearance_state_path() -> Option<std::path::PathBuf> {
    std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/appearance"))
}

fn appearance_label(a: Appearance) -> &'static str {
    match a {
        Appearance::Light => "light",
        Appearance::Dark => "dark",
        Appearance::Auto => "auto",
    }
}

fn persist_appearance(a: Appearance) {
    if let Some(path) = appearance_state_path() {
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::write(path, appearance_label(a));
    }
}

fn load_persisted_appearance() -> Option<Appearance> {
    let text = std::fs::read_to_string(appearance_state_path()?).ok()?;
    match text.trim() {
        "light" => Some(Appearance::Light),
        "dark" => Some(Appearance::Dark),
        "auto" => Some(Appearance::Auto),
        _ => None,
    }
}

const DEFAULT_MATUGEN_SCHEME: &str = "scheme-tonal-spot";

/// matugen scheme persisted by `select-scheme` / the theme view, read by
/// `generate-edgebar-theme`. Lives next to the appearance file.
fn scheme_state_path() -> Option<std::path::PathBuf> {
    std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/scheme"))
}

fn persisted_scheme() -> String {
    scheme_state_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| DEFAULT_MATUGEN_SCHEME.to_string())
}

fn persist_scheme(scheme: &str) {
    if let Some(path) = scheme_state_path() {
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::write(path, scheme);
    }
}

/// Shared, mutable theme state behind a `Mutex` (managed by Tauri). Holds the
/// raw per-scheme role maps + both palettes; `get_config`/`apply_theme` resolve
/// to hex on demand for whichever scheme is active.
struct ThemeState {
    colors: Themes,
    geometry: Geometry,
    palettes: Palettes,
    appearance: Appearance,
    scheme: Scheme,
    /// Binaries for the picker (resolved from config, else a bare PATH name).
    theme_command: String,
    wallpaper_command: String,
}

/// Resolve `Auto` against the macOS system setting. `AppleInterfaceStyle` is
/// "Dark" in dark mode and absent in light mode (NSUserDefaults is thread-safe,
/// so this needs no main-thread hop).
#[cfg(target_os = "macos")]
fn system_scheme() -> Scheme {
    use objc2_foundation::{NSString, NSUserDefaults};
    let defaults = NSUserDefaults::standardUserDefaults();
    let key = NSString::from_str("AppleInterfaceStyle");
    let dark = defaults
        .stringForKey(&key)
        .map(|s| s.to_string().eq_ignore_ascii_case("dark"))
        .unwrap_or(false);
    if dark {
        Scheme::Dark
    } else {
        Scheme::Light
    }
}

#[cfg(not(target_os = "macos"))]
fn system_scheme() -> Scheme {
    Scheme::Dark
}

fn resolve_scheme(appearance: Appearance) -> Scheme {
    match appearance {
        Appearance::Light => Scheme::Light,
        Appearance::Dark => Scheme::Dark,
        Appearance::Auto => system_scheme(),
    }
}

/// Switch the active appearance: re-resolve colors for the new scheme, push them
/// to the WebView (one repaint) and recolor the native frame's layers in place.
fn apply_theme(app: &tauri::AppHandle, appearance: Appearance) {
    let resolved: ResolvedConfig = {
        let state = app.state::<Mutex<ThemeState>>();
        let mut ts = state.lock().unwrap();
        ts.appearance = appearance;
        ts.scheme = resolve_scheme(appearance);
        ResolvedConfig {
            colors: resolve_colors(ts.colors.for_scheme(ts.scheme), ts.palettes.for_scheme(ts.scheme)),
            geometry: ts.geometry.clone(),
            appearance,
            scheme: persisted_scheme(),
        }
    };
    let _ = app.emit("theme", &resolved);
    #[cfg(target_os = "macos")]
    {
        let line = resolved.colors.frame_line.clone();
        let corner = resolved.colors.frame_corner.clone();
        let _ = app.run_on_main_thread(move || recolor_native_frame(&line, &corner));
    }
}

/// Reload palettes + role maps from disk (after matugen rewrites palette.json,
/// or a config.json edit) and re-apply the current appearance. Triggered by a
/// ping on `theme.sock`. Geometry changes still need a relaunch.
fn reload_theme(app: &tauri::AppHandle) {
    let palettes = load_palettes();
    let config = load_config();
    let appearance = {
        let state = app.state::<Mutex<ThemeState>>();
        let mut ts = state.lock().unwrap();
        ts.palettes = palettes;
        ts.colors = config.colors;
        ts.geometry = config.geometry;
        ts.appearance
    };
    apply_theme(app, appearance);
}

/// "#rrggbb" or "#rrggbbaa" -> [r, g, b, a] in 0..1 (defaults to opaque black).
fn hex_to_rgba(hex: &str) -> [f64; 4] {
    // Operate on bytes: a multi-byte char in a hand-edited config.json color
    // would panic a str byte-slice on a non-char-boundary.
    let h = hex.trim().trim_start_matches('#').as_bytes();
    let byte = |i: usize| -> Option<f64> {
        let pair = std::str::from_utf8(h.get(i..i + 2)?).ok()?;
        u8::from_str_radix(pair, 16).ok().map(|v| v as f64 / 255.0)
    };
    if h.len() >= 6 {
        let a = if h.len() >= 8 { byte(6).unwrap_or(1.0) } else { 1.0 };
        [
            byte(0).unwrap_or(0.0),
            byte(2).unwrap_or(0.0),
            byte(4).unwrap_or(0.0),
            a,
        ]
    } else {
        [0.0, 0.0, 0.0, 1.0]
    }
}

#[tauri::command]
fn get_config(state: tauri::State<Mutex<ThemeState>>) -> ResolvedConfig {
    let ts = state.lock().unwrap();
    ResolvedConfig {
        colors: resolve_colors(ts.colors.for_scheme(ts.scheme), ts.palettes.for_scheme(ts.scheme)),
        geometry: ts.geometry.clone(),
        appearance: ts.appearance,
        scheme: persisted_scheme(),
    }
}

/// 3-way appearance toggle from the bar (light / dark / auto). Persists the
/// choice and re-themes live.
#[tauri::command]
fn set_appearance(app: tauri::AppHandle, mode: String) {
    let appearance = match mode.as_str() {
        "light" => Appearance::Light,
        "dark" => Appearance::Dark,
        _ => Appearance::Auto,
    };
    persist_appearance(appearance);
    apply_theme(&app, appearance);
}

#[derive(Clone, Serialize)]
struct Workspace {
    name: String,
    focused: bool,
    has_windows: bool,
    /// App name of the icon shown on this workspace's dot ("" if empty).
    app: String,
    /// Bundle id used to resolve `icon` (not sent to the WebView).
    #[serde(skip)]
    bundle_id: String,
    /// "data:image/png;base64,…" app icon, or "" when the workspace is empty.
    icon: String,
}

/// One window's identifying app info, parsed from `aerospace list-windows`.
struct WinRef {
    app: String,
    bundle_id: String,
}

/// Parse a `workspace|app-name|app-bundle-id` row.
fn parse_win(line: &str) -> Option<(String, WinRef)> {
    let mut p = line.splitn(3, '|');
    let ws = p.next()?.to_string();
    let app = p.next()?.to_string();
    let bundle_id = p.next().unwrap_or("").to_string();
    Some((ws, WinRef { app, bundle_id }))
}

/// Run the AeroSpace CLI and return non-empty, trimmed stdout lines. Capped at
/// 5s: a wedged server otherwise blocks the caller forever (observed in the
/// wild — a hung `list-workspaces` froze the ws.sock loop for days and piled
/// its pending pings into the listen backlog). On timeout the child is killed
/// and the query degrades to "no output".
fn aerospace(args: &[&str]) -> Vec<String> {
    use std::io::Read;
    use std::process::{Command, Stdio};
    let Ok(mut child) = Command::new("aerospace")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
    else {
        return Vec::new();
    };
    // Drain stdout on a side thread so a full pipe can't wedge the child, and
    // so the deadline can be enforced from here. kill() forces the pipe to EOF,
    // which unblocks the reader; the second recv then returns what was read.
    let mut stdout = child.stdout.take();
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut text = String::new();
        if let Some(out) = stdout.as_mut() {
            let _ = out.read_to_string(&mut text);
        }
        let _ = tx.send(text);
    });
    let text = match rx.recv_timeout(std::time::Duration::from_secs(5)) {
        Ok(text) => text,
        Err(_) => {
            let _ = child.kill();
            rx.recv().unwrap_or_default()
        }
    };
    let _ = child.wait();
    text.lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect()
}

/// Query AeroSpace for all workspaces with focused + occupied state.
/// Two CLI calls: focused flag via --format, occupied set via --empty no.
/// Canonical dot order: 1-9 then 0. AeroSpace lists `0` first and may surface
/// stray on-demand workspaces (e.g. `11`, where Spotify lives); we render only
/// these ten, with `alt-0` shown last to match the keyboard row.
const WS_ORDER: [&str; 10] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];

fn query_workspaces() -> Vec<Workspace> {
    let rows = aerospace(&[
        "list-workspaces",
        "--all",
        "--format",
        "%{workspace}|%{workspace-is-focused}",
    ]);
    let non_empty = aerospace(&["list-workspaces", "--monitor", "all", "--empty", "no"]);

    // One icon per workspace: the first window AeroSpace lists for it (stable
    // order), overridden by the globally-focused window for the active workspace
    // so its dot tracks whatever app you're actually looking at.
    let win_rows = aerospace(&[
        "list-windows",
        "--all",
        "--format",
        "%{workspace}|%{app-name}|%{app-bundle-id}",
    ]);
    let mut ws_app: std::collections::HashMap<String, WinRef> = std::collections::HashMap::new();
    for line in &win_rows {
        if let Some((ws, win)) = parse_win(line) {
            ws_app.entry(ws).or_insert(win);
        }
    }
    if let Some((ws, win)) = aerospace(&[
        "list-windows",
        "--focused",
        "--format",
        "%{workspace}|%{app-name}|%{app-bundle-id}",
    ])
    .first()
    .and_then(|l| parse_win(l))
    {
        ws_app.insert(ws, win);
    }

    let mut workspaces: Vec<Workspace> = rows
        .into_iter()
        .filter_map(|row| {
            let mut parts = row.splitn(2, '|');
            let name = parts.next()?.to_string();
            let focused = parts.next() == Some("true");
            WS_ORDER.contains(&name.as_str()).then(|| {
                let win = ws_app.get(&name);
                Workspace {
                    has_windows: non_empty.contains(&name),
                    focused,
                    app: win.map(|w| w.app.clone()).unwrap_or_default(),
                    bundle_id: win.map(|w| w.bundle_id.clone()).unwrap_or_default(),
                    icon: String::new(),
                    name,
                }
            })
        })
        .collect();

    workspaces.sort_by_key(|w| {
        WS_ORDER
            .iter()
            .position(|n| *n == w.name)
            .unwrap_or(usize::MAX)
    });
    workspaces
}

/// Mark a window as a stationary, all-spaces overlay so Mission Control /
/// Exposé leave it in place instead of sweeping it into the overview. tao only
/// sets CanJoinAllSpaces via set_visible_on_all_workspaces; Stationary is the
/// bit that keeps HUD windows put during Exposé.
#[cfg(target_os = "macos")]
fn make_overlay(window: &tauri::WebviewWindow) {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;

    // NSWindowCollectionBehavior bits
    const CAN_JOIN_ALL_SPACES: usize = 1 << 0;
    const STATIONARY: usize = 1 << 4;
    const IGNORES_CYCLE: usize = 1 << 6;
    const FULLSCREEN_AUXILIARY: usize = 1 << 8;

    if let Ok(ptr) = window.ns_window() {
        let ns_window = ptr as *mut AnyObject;
        let behavior =
            CAN_JOIN_ALL_SPACES | STATIONARY | IGNORES_CYCLE | FULLSCREEN_AUXILIARY;
        // setCollectionBehavior: is a main-thread AppKit call; setup runs on the
        // main thread.
        unsafe {
            let _: () = msg_send![ns_window, setCollectionBehavior: behavior];
        }
    }
}

/// Interactive rects per bar window (WebView CSS px, top-left origin), keyed by
/// window label. Written by each bar's WebView via `set_interactive_rects`,
/// read by the shared cursor monitors.
type RectMap = std::sync::Arc<Mutex<std::collections::HashMap<String, Vec<[f64; 4]>>>>;

// ───────────────────────── click-through bar window ─────────────────
// The bar window has to be tall enough to render the pills' drop-shadows and the
// corner fillets that hang below the bar band — but it sits over the top edge of
// the tiled windows, and a transparent window swallows clicks across its whole
// rect (returning nil from a view's hitTest does NOT pass the click to the app
// below — only the window-level `ignoresMouseEvents` flag does that). So we keep
// the window click-through by default and flip `ignoresMouseEvents` off only
// while the cursor is over a pill. Two NSEvent monitors drive it: a local one
// (events to us, i.e. cursor over the bar while it's interactive) and a global
// one (events to other apps, i.e. cursor over the bar while it's click-through —
// this is what re-arms interactivity). Event-driven, so no cursor-polling loop
// and none of the main-thread deadlock that polling Tauri getters would cause.

// The bar NSWindows the shared cursor monitors hit-test, keyed by window
// label. Main-thread only (NSWindow isn't Send); bars register here when
// created and deregister when their monitor unplugs.
#[cfg(target_os = "macos")]
thread_local! {
    static TRACKED_BARS: std::cell::RefCell<
        std::collections::HashMap<String, objc2::rc::Retained<objc2_app_kit::NSWindow>>,
    > = std::cell::RefCell::new(std::collections::HashMap::new());
}

/// Set one bar's `ignoresMouseEvents` from the cursor position: interactive when
/// it's over one of the reported rects (the pills, or a full-window rect while a
/// popup is open), click-through otherwise. `mouseLocation` and the window frame
/// are screen coords (bottom-left origin); the rects are window-relative CSS px
/// from the top-left, so we map each rect into screen space to compare.
#[cfg(target_os = "macos")]
fn sync_ignore_mouse(ns_window: &objc2_app_kit::NSWindow, rects: &[[f64; 4]]) {
    let loc = objc2_app_kit::NSEvent::mouseLocation();
    let frame = ns_window.frame();
    let win_top = frame.origin.y + frame.size.height;
    let over = rects.iter().any(|r| {
        let sx0 = frame.origin.x + r[0];
        let sx1 = sx0 + r[2];
        let sy1 = win_top - r[1];
        let sy0 = sy1 - r[3];
        loc.x >= sx0 && loc.x <= sx1 && loc.y >= sy0 && loc.y <= sy1
    });
    ns_window.setIgnoresMouseEvents(!over);
}

/// Hit-test every tracked bar against the current cursor position.
#[cfg(target_os = "macos")]
fn sync_all_bars(rects: &RectMap) {
    TRACKED_BARS.with(|bars| {
        let bars = bars.borrow();
        if bars.is_empty() {
            return;
        }
        let map = rects.lock().unwrap();
        for (label, win) in bars.iter() {
            sync_ignore_mouse(win, map.get(label).map(Vec::as_slice).unwrap_or(&[]));
        }
    });
}

/// Install the two NSEvent cursor monitors ONCE for the app; they serve every
/// tracked bar window (monitors are per-app, not per-window). Local monitor:
/// events delivered to us (cursor over an interactive bar) — must return the
/// event so the bar's own handling continues. Global monitor: events delivered
/// to other apps (cursor over a click-through bar, or anywhere else) — re-arms
/// interactivity on re-entry. Event-driven, so no cursor-polling loop and none
/// of the main-thread deadlock that polling Tauri getters would cause.
#[cfg(target_os = "macos")]
fn install_cursor_monitors(rects: RectMap) {
    use objc2_app_kit::{NSEvent, NSEventMask};

    let mask = NSEventMask::MouseMoved | NSEventMask::LeftMouseDragged;
    let rects_local = rects.clone();
    let local = block2::RcBlock::new(move |event: core::ptr::NonNull<NSEvent>| -> *mut NSEvent {
        sync_all_bars(&rects_local);
        event.as_ptr()
    });
    let global = block2::RcBlock::new(move |_event: core::ptr::NonNull<NSEvent>| {
        sync_all_bars(&rects);
    });

    // The monitors copy the blocks and AppKit keeps them alive; we never remove
    // them (they live for the app's lifetime), so the returned handles can drop.
    unsafe {
        let _ = NSEvent::addLocalMonitorForEventsMatchingMask_handler(mask, &local);
        let _ = NSEvent::addGlobalMonitorForEventsMatchingMask_handler(mask, &global);
    }
}

/// Register a bar window with the cursor monitors (idempotent). Starts
/// click-through; the monitors flip it on when the cursor reaches a pill.
#[cfg(target_os = "macos")]
fn track_bar_window(label: &str, window: &tauri::WebviewWindow) {
    use objc2::rc::Retained;
    use objc2_app_kit::NSWindow;

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let Some(ns_window) = (unsafe { Retained::retain(ptr as *mut NSWindow) }) else {
        return;
    };
    TRACKED_BARS.with(|bars| {
        let mut bars = bars.borrow_mut();
        if !bars.contains_key(label) {
            ns_window.setIgnoresMouseEvents(true);
            bars.insert(label.to_string(), ns_window);
        }
    });
}

/// Forget a bar window (its monitor unplugged): drop the NSWindow handle and
/// its interactive rects.
#[cfg(target_os = "macos")]
fn untrack_bar_window(label: &str, rects: &RectMap) {
    TRACKED_BARS.with(|bars| {
        bars.borrow_mut().remove(label);
    });
    rects.lock().unwrap().remove(label);
}

/// Update the interactive rects the cursor tracker checks (WebView CSS px,
/// top-left origin). Called by each bar's WebView whenever its layout changes;
/// stored per window label.
#[tauri::command]
fn set_interactive_rects(
    window: tauri::WebviewWindow,
    state: tauri::State<AppState>,
    rects: Vec<[f64; 4]>,
) {
    state
        .interactive_rects
        .lock()
        .unwrap()
        .insert(window.label().to_string(), rects);
}

// Commands are `async` so the IPC layer runs them off the main thread, and the
// blocking subprocess work goes through `spawn_blocking` — a sync command would
// run the `aerospace` calls on the main thread and beach-ball the UI.
/// Create one screen's frame as a native borderless NSWindow drawn with CALayer —
/// no WebView, so it costs no web-content process. Replicates the old CSS frame:
/// a green rounded-rect line hugging the screen edge (root layer cornerRadius +
/// border) plus black fills in the four corner notches outside that rounded rect
/// (an even-odd CAShapeLayer). Click-through, all-spaces, stationary. Called once
/// per NSScreen; the window is retained in FRAME_WINDOWS so a display-config
/// change can close and rebuild it.
#[cfg(target_os = "macos")]
fn create_native_frame(
    mtm: objc2::MainThreadMarker,
    screen: &objc2_app_kit::NSScreen,
    geometry: &Geometry,
    frame_line: &str,
    frame_corner: &str,
) {
    use objc2::MainThreadOnly;
    use objc2_app_kit::{
        NSBackingStoreType, NSBezierPath, NSColor, NSWindow, NSWindowCollectionBehavior,
        NSWindowStyleMask, NSWindingRule,
    };
    use objc2_core_foundation::{CGPoint, CGRect, CGSize};
    use objc2_quartz_core::{kCAFillRuleEvenOdd, CAShapeLayer};

    // Look comes from the shared config (config.json) + active palette.
    let radius = geometry.inner_radius;
    let line = geometry.line_thickness;
    let line_rgba = hex_to_rgba(frame_line);
    let corner_rgba = hex_to_rgba(frame_corner);

    let frame = screen.frame();

    let window = unsafe {
        NSWindow::initWithContentRect_styleMask_backing_defer(
            NSWindow::alloc(mtm),
            frame,
            NSWindowStyleMask::Borderless,
            NSBackingStoreType::Buffered,
            false,
        )
    };
    window.setOpaque(false);
    window.setBackgroundColor(Some(&NSColor::clearColor()));
    window.setHasShadow(false);
    // tao sets always-on-top windows (the bar) to kCGFloatingWindowLevelKey (the
    // key value 5), not the real NSFloatingWindowLevel (3) — so the bar sits at
    // level 5. Put the frame just above it so the edge line renders over the pills.
    const FRAME_WINDOW_LEVEL: isize = 6;
    window.setLevel(FRAME_WINDOW_LEVEL);
    window.setIgnoresMouseEvents(true);
    // Same collection behavior as the bar (see make_overlay).
    const CAN_JOIN_ALL_SPACES: usize = 1 << 0;
    const STATIONARY: usize = 1 << 4;
    const IGNORES_CYCLE: usize = 1 << 6;
    const FULLSCREEN_AUXILIARY: usize = 1 << 8;
    window.setCollectionBehavior(NSWindowCollectionBehavior(
        CAN_JOIN_ALL_SPACES | STATIONARY | IGNORES_CYCLE | FULLSCREEN_AUXILIARY,
    ));
    unsafe { window.setReleasedWhenClosed(false) };

    let Some(view) = window.contentView() else {
        return;
    };
    view.setWantsLayer(true);
    let Some(root) = view.layer() else {
        return;
    };

    let w = frame.size.width;
    let h = frame.size.height;

    // Work in whole FRAMEBUFFER PIXELS, not points. This display runs a scaled
    // mode: CoreAnimation renders to a HiDPI framebuffer (points * backingScale)
    // which the window-server then DOWNSCALES to the panel's native resolution.
    // That non-integer downscale is what eats the topmost framebuffer row (the
    // "dead row") — it's the scaler, not the panel. Geometry in points leaves
    // fractional values that round unpredictably across the two grids, so we snap
    // every dimension to an integer framebuffer pixel and convert to points
    // (÷scale) only at the CALayer/NSBezierPath boundary. Tweak the *_px values to
    // test in real pixels.
    let scale = screen.backingScaleFactor();
    let d = |px: f64| px / scale; // framebuffer device px -> points
    let line_px = (line * scale).round(); // frame line thickness (e.g. 8)
    let radius_px = (radius * scale).round(); // outer corner radius (e.g. 40)
    let top_inset_px = geometry.top_offset_px; // dead-row compensation (e.g. 1)

    let line_color = NSColor::colorWithSRGBRed_green_blue_alpha(
        line_rgba[0], line_rgba[1], line_rgba[2], line_rgba[3],
    );
    let corner_color = NSColor::colorWithSRGBRed_green_blue_alpha(
        corner_rgba[0], corner_rgba[1], corner_rgba[2], corner_rgba[3],
    );

    // root: clear, non-clipping container spanning the whole screen
    let full = CGRect::new(CGPoint::new(0.0, 0.0), CGSize::new(w, h));
    root.setFrame(full);
    root.setBackgroundColor(Some(&NSColor::clearColor().CGColor()));
    root.setMasksToBounds(false);

    // Outer contour: hugs the screen on the left/right/bottom, but its TOP edge is
    // pushed down `top_inset_px` so the rounded corners' tangent clears the dead
    // row. (Layer is non-flipped / bottom-left, so reducing the height lowers only
    // the top edge.)
    let outer = CGRect::new(
        CGPoint::new(0.0, 0.0),
        CGSize::new(w, h - d(top_inset_px)),
    );
    // Inner contour (the hole): a symmetric `line_px` inset from the SCREEN edges,
    // so the line is the full `line_px` on the sides and bottom while the top ends
    // up `line_px - top_inset_px` thick. That holds the line's BOTTOM edge where it
    // was, so the bar's pills (a separate webview window, aligned in logical px and
    // thus un-nudgeable by a single device px) still flare their concave fillets
    // into it cleanly. The inset is applied to the TOP only — sides keep full width.
    let inner = CGRect::new(
        CGPoint::new(d(line_px), d(line_px)),
        CGSize::new(w - 2.0 * d(line_px), h - 2.0 * d(line_px)),
    );

    // frame line = outer rounded rect minus inner rounded rect (even-odd ring)
    let ring = NSBezierPath::bezierPath();
    ring.appendBezierPathWithRoundedRect_xRadius_yRadius(outer, d(radius_px), d(radius_px));
    ring.appendBezierPathWithRoundedRect_xRadius_yRadius(
        inner,
        d(radius_px - line_px),
        d(radius_px - line_px),
    );
    ring.setWindingRule(NSWindingRule::EvenOdd);
    let line_layer = CAShapeLayer::new();
    line_layer.setFrame(full);
    line_layer.setPath(Some(&ring.CGPath()));
    line_layer.setFillRule(unsafe { kCAFillRuleEvenOdd });
    line_layer.setFillColor(Some(&line_color.CGColor()));
    root.addSublayer(&line_layer);

    // black corner fills = full screen rect minus the outer rounded rect (even-odd)
    let notch = NSBezierPath::bezierPath();
    notch.appendBezierPathWithRect(full);
    notch.appendBezierPathWithRoundedRect_xRadius_yRadius(outer, d(radius_px), d(radius_px));
    notch.setWindingRule(NSWindingRule::EvenOdd);
    let corners = CAShapeLayer::new();
    corners.setFrame(full);
    corners.setPath(Some(&notch.CGPath()));
    corners.setFillRule(unsafe { kCAFillRuleEvenOdd });
    corners.setFillColor(Some(&corner_color.CGColor()));
    root.addSublayer(&corners);

    window.orderFrontRegardless();

    // Retain the window + both shape layers: day/night + wallpaper changes
    // recolor the layers in place (cheap setFillColor), and a display-config
    // change closes the window and rebuilds for the new screen set.
    FRAME_WINDOWS.with(|cell| {
        cell.borrow_mut().push(FrameWindow {
            window,
            line: line_layer,
            corners,
        });
    });
}

/// One screen's native frame: the NSWindow plus its two fill layers, retained
/// on the main thread so a theme change can recolor in place and a display
/// change can close it. CALayer/NSWindow aren't `Send`, so this lives in a
/// main-thread `thread_local!`, not Tauri's managed state.
#[cfg(target_os = "macos")]
struct FrameWindow {
    window: objc2::rc::Retained<objc2_app_kit::NSWindow>,
    line: objc2::rc::Retained<objc2_quartz_core::CAShapeLayer>,
    corners: objc2::rc::Retained<objc2_quartz_core::CAShapeLayer>,
}

#[cfg(target_os = "macos")]
thread_local! {
    static FRAME_WINDOWS: std::cell::RefCell<Vec<FrameWindow>> =
        const { std::cell::RefCell::new(Vec::new()) };
}

/// Close every native frame window (before rebuilding for a new screen set).
/// Main thread only.
#[cfg(target_os = "macos")]
fn remove_native_frames() {
    FRAME_WINDOWS.with(|cell| {
        for f in cell.borrow_mut().drain(..) {
            f.window.close();
        }
    });
}

/// Recolor every native frame's line + corner layers. Must run on the main
/// thread (AppKit); callers hop via `run_on_main_thread`.
#[cfg(target_os = "macos")]
fn recolor_native_frame(line_hex: &str, corner_hex: &str) {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSColor;
    if MainThreadMarker::new().is_none() {
        return;
    }
    let l = hex_to_rgba(line_hex);
    let c = hex_to_rgba(corner_hex);
    FRAME_WINDOWS.with(|cell| {
        for f in cell.borrow().iter() {
            let lc = NSColor::colorWithSRGBRed_green_blue_alpha(l[0], l[1], l[2], l[3]);
            let cc = NSColor::colorWithSRGBRed_green_blue_alpha(c[0], c[1], c[2], c[3]);
            f.line.setFillColor(Some(&lc.CGColor()));
            f.corners.setFillColor(Some(&cc.CGColor()));
        }
    });
}

/// Query workspaces and fill in each occupied dot's app icon. The AeroSpace
/// query runs on the caller's (off-main) thread; icon resolution hops to the
/// main thread (AppKit) and is cached by bundle id.
fn workspaces_with_icons(app: &tauri::AppHandle) -> Vec<Workspace> {
    let mut ws = query_workspaces();
    attach_icons(app, &mut ws);
    ws
}

#[cfg(not(target_os = "macos"))]
fn attach_icons(_app: &tauri::AppHandle, _ws: &mut [Workspace]) {}

/// Fill `icon` for every workspace that has an app, resolving NSImage icons on
/// the main thread (AppKit isn't thread-safe) and caching the PNG by bundle id.
#[cfg(target_os = "macos")]
fn attach_icons(app: &tauri::AppHandle, ws: &mut [Workspace]) {
    use std::collections::HashSet;
    let mut seen = HashSet::new();
    let needed: Vec<String> = ws
        .iter()
        .filter(|w| !w.bundle_id.is_empty())
        .filter_map(|w| seen.insert(&w.bundle_id).then(|| w.bundle_id.clone()))
        .collect();
    if needed.is_empty() {
        return;
    }

    let app2 = app.clone();
    let (tx, rx) = std::sync::mpsc::channel();
    if app
        .run_on_main_thread(move || {
            let _ = tx.send(resolve_icons(&app2, needed));
        })
        .is_err()
    {
        return;
    }
    let Ok(map) = rx.recv() else { return };
    for w in ws.iter_mut() {
        if let Some(icon) = map.get(&w.bundle_id) {
            w.icon = icon.clone();
        }
    }
}

/// Resolve each bundle id to a PNG data URL, populating the shared cache. Must
/// run on the main thread (touches AppKit). Returns the subset requested.
#[cfg(target_os = "macos")]
fn resolve_icons(
    app: &tauri::AppHandle,
    bundle_ids: Vec<String>,
) -> std::collections::HashMap<String, String> {
    use objc2_app_kit::NSRunningApplication;
    use objc2_foundation::NSString;

    let state = app.state::<AppState>();
    let mut cache = state.icon_cache.lock().unwrap();
    let mut out = std::collections::HashMap::new();
    for bid in bundle_ids {
        if !cache.contains_key(&bid) {
            let ns = NSString::from_str(&bid);
            let icon = NSRunningApplication::runningApplicationsWithBundleIdentifier(&ns)
                .firstObject()
                .and_then(|a| a.icon())
                .and_then(|img| icon_png_data_url(&img))
                .unwrap_or_default();
            cache.insert(bid.clone(), icon);
        }
        if let Some(icon) = cache.get(&bid) {
            out.insert(bid, icon.clone());
        }
    }
    out
}

#[tauri::command]
async fn aerospace_workspaces(app: tauri::AppHandle) -> Vec<Workspace> {
    tauri::async_runtime::spawn_blocking(move || workspaces_with_icons(&app))
        .await
        .unwrap_or_default()
}

#[tauri::command]
async fn aerospace_focus(name: String) {
    let _ = tauri::async_runtime::spawn_blocking(move || {
        let _ = std::process::Command::new("aerospace")
            .args(["workspace", &name])
            .status();
    })
    .await;
}

/// Resize the calling bar window (logical px). Used to make room for the
/// clock's expanded panel; the window is transparent so the resize itself is
/// invisible. Per-window: each monitor's bar expands independently.
#[tauri::command]
fn set_bar_size(window: tauri::WebviewWindow, width: f64, height: f64) {
    let _ = window.set_size(LogicalSize::new(width, height));
}

// ───────────────────────── network (Wi-Fi / IP / VPN) ───────────────
// Mirrors sketchybar's ip_address.sh: shows the primary IP (not the SSID, which
// macOS now gates behind Location Services), flags an active VPN (utun), or
// "Not Connected". Parsed from `scutil --nwi`.
#[derive(Clone, Serialize)]
struct Network {
    /// "wifi" | "vpn" | "off"
    state: String,
    label: String,
    /// Wi-Fi signal strength in dBm (e.g. -65), when connected. `None` otherwise.
    rssi: Option<i32>,
    /// Whether the internet is actually reachable (false = connected but no WAN
    /// / captive portal). Only meaningful when `state == "wifi"`.
    online: bool,
}

impl Default for Network {
    fn default() -> Self {
        Network {
            state: String::new(),
            label: String::new(),
            rssi: None,
            online: true,
        }
    }
}

// True if the internet is actually reachable. Uses the same endpoint macOS's own
// captive-portal detection hits: it returns the literal body "Success" only on a
// working connection — a dead uplink yields nothing and a captive portal returns
// its own page, so both read as offline. 2s cap; runs inside `spawn_blocking`.
fn has_internet() -> bool {
    std::process::Command::new("curl")
        .args(["-s", "-m", "2", "http://captive.apple.com/hotspot-detect.html"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("Success"))
        .unwrap_or(false)
}

// Current Wi-Fi RSSI in dBm, parsed from `system_profiler SPAirPortDataType`.
// (`airport` was removed in recent macOS; system_profiler still reports
// signal without Location Services.) Only the "Current Network Information"
// block is the live link — everything after "Other Local Wi-Fi Networks" is a
// scan of nearby APs. Costs ~1s, so callers should only run it when connected.
fn read_wifi_rssi() -> Option<i32> {
    let out = std::process::Command::new("system_profiler")
        .arg("SPAirPortDataType")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default();
    let current = out.split("Other Local Wi-Fi Networks:").next().unwrap_or("");
    current
        .lines()
        .find(|l| l.trim_start().starts_with("Signal / Noise:"))
        // "Signal / Noise: -70 dBm / -95 dBm" -> "-70"
        .and_then(|l| l.split(':').nth(1))
        .and_then(|s| s.split_whitespace().next())
        .and_then(|s| s.parse::<i32>().ok())
}

fn read_network() -> Network {
    let nwi = std::process::Command::new("scutil")
        .arg("--nwi")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default();

    // `Network interfaces:` line lists active interfaces; a utun there = VPN.
    let is_vpn = nwi
        .lines()
        .find(|l| l.contains("Network interfaces:"))
        .is_some_and(|l| l.contains("utun"));

    // First `address : <ip>` line is the primary IPv4 address.
    let ip = nwi
        .lines()
        .find(|l| l.trim_start().starts_with("address"))
        .and_then(|l| l.splitn(2, ':').nth(1))
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    if is_vpn {
        Network {
            state: "vpn".into(),
            label: "VPN".into(),
            ..Default::default()
        }
    } else if let Some(ip) = ip {
        Network {
            state: "wifi".into(),
            label: ip,
            rssi: read_wifi_rssi(),
            online: has_internet(),
        }
    } else {
        Network {
            state: "off".into(),
            label: "Not Connected".into(),
            online: false,
            ..Default::default()
        }
    }
}

#[tauri::command]
async fn network() -> Network {
    tauri::async_runtime::spawn_blocking(read_network)
        .await
        .unwrap_or_default()
}

// ───────────────────────── launcher menu actions ────────────────────
// Mirrors sketchybar's command.logo popup: quick links to Settings / Activity
// Monitor and a display-sleep action. Whitelisted — never runs arbitrary input.
#[tauri::command]
fn launcher_action(action: String) {
    let _ = match action.as_str() {
        "settings" => std::process::Command::new("open")
            .args(["-a", "System Settings"])
            .spawn(),
        "activity" => std::process::Command::new("open")
            .args(["-a", "Activity Monitor"])
            .spawn(),
        "sleep" => std::process::Command::new("pmset")
            .arg("displaysleepnow")
            .spawn(),
        _ => return,
    };
}

// ───────────────────────── theme / wallpaper picker ─────────────────
// Backs the notch popup's theme view. Wallpaper-setting and matugen run through
// the same desktoppr / generate-edgebar-theme binaries the CLI uses (paths
// injected via config.json), so the in-app path and the watcher path are
// identical — the picker just makes it instant (no launchd round-trip).

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct Wallpaper {
    name: String,
    path: String,
    thumb: String, // "data:image/png;base64,…"
}

fn wallpapers_dir() -> Option<std::path::PathBuf> {
    std::env::var_os("HOME").map(|home| std::path::Path::new(&home).join("Pictures/Wallpapers"))
}

fn is_image(path: &std::path::Path) -> bool {
    matches!(
        path.extension()
            .and_then(|e| e.to_str())
            .map(|e| e.to_ascii_lowercase())
            .as_deref(),
        Some("jpg" | "jpeg" | "png" | "webp" | "heic")
    )
}

/// Standard base64 (with padding). Dependency-free + thread-safe, so thumbnail
/// encoding can run off the main thread.
fn base64_encode(bytes: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let b = [chunk[0], *chunk.get(1).unwrap_or(&0), *chunk.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | (b[2] as u32);
        out.push(T[((n >> 18) & 63) as usize] as char);
        out.push(T[((n >> 12) & 63) as usize] as char);
        out.push(if chunk.len() > 1 { T[((n >> 6) & 63) as usize] as char } else { '=' });
        out.push(if chunk.len() > 2 { T[(n & 63) as usize] as char } else { '=' });
    }
    out
}

/// Downscale an image to a thumbnail PNG via `sips` (a subprocess, so off the
/// main thread — no NSImage threading), returned as a base64 data URL. Cached by
/// path + mtime.
fn wallpaper_thumb(state: &AppState, path: &str) -> Option<String> {
    let mtime = std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    if let Some((m, url)) = state.thumb_cache.lock().unwrap().get(path) {
        if *m == mtime {
            return Some(url.clone());
        }
    }
    let stem: String = path
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
        .collect();
    let tmp = std::env::temp_dir().join(format!("edgebar-thumb-{stem}.png"));
    let ok = std::process::Command::new("sips")
        .args(["-Z", "240", "-s", "format", "png", path, "--out"])
        .arg(&tmp)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if !ok {
        return None;
    }
    let bytes = std::fs::read(&tmp).ok()?;
    let url = format!("data:image/png;base64,{}", base64_encode(&bytes));
    state
        .thumb_cache
        .lock()
        .unwrap()
        .insert(path.to_string(), (mtime, url.clone()));
    Some(url)
}

// Runs `sips` per uncached thumbnail, so it goes through `spawn_blocking` off the
// main thread; the AppState is re-fetched inside the closure from the AppHandle.
#[tauri::command]
async fn list_wallpapers(app: tauri::AppHandle) -> Vec<Wallpaper> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<AppState>();
        let Some(dir) = wallpapers_dir() else {
            return Vec::new();
        };
        let Ok(entries) = std::fs::read_dir(&dir) else {
            return Vec::new();
        };
        let mut paths: Vec<std::path::PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| is_image(p))
            .collect();
        paths.sort();
        paths
            .into_iter()
            .filter_map(|p| {
                let path = p.to_str()?.to_string();
                let name = p.file_name()?.to_str()?.to_string();
                let thumb = wallpaper_thumb(&state, &path).unwrap_or_default();
                Some(Wallpaper { name, path, thumb })
            })
            .collect()
    })
    .await
    .unwrap_or_default()
}

/// Runs the wallpaper command and returns the first display's picture path.
fn query_current_wallpaper(cmd: &str) -> String {
    std::process::Command::new(cmd)
        .output()
        .ok()
        .map(|o| {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .to_string()
        })
        .unwrap_or_default()
}

/// The current desktop picture (first display) — to highlight the active thumb.
#[tauri::command]
async fn current_wallpaper(app: tauri::AppHandle) -> String {
    tauri::async_runtime::spawn_blocking(move || {
        let cmd = app
            .state::<Mutex<ThemeState>>()
            .lock()
            .unwrap()
            .wallpaper_command
            .clone();
        query_current_wallpaper(&cmd)
    })
    .await
    .unwrap_or_default()
}

/// Touch a marker whose mtime tells the launchd watcher an in-app change just
/// happened, so it skips its redundant (and potentially clobbering) re-run.
fn touch_inapp_marker() {
    if let Some(home) = std::env::var_os("HOME") {
        let dir = std::path::Path::new(&home).join(".cache/edgebar");
        let _ = std::fs::create_dir_all(&dir);
        let _ = std::fs::write(dir.join(".inapp-change"), b"");
    }
}

fn palette_json_path() -> Option<std::path::PathBuf> {
    std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/palette.json"))
}

/// Per-(wallpaper, scheme) precomputed palette cache. Keyed by scheme + sanitized
/// path + mtime, so it auto-invalidates when the image or scheme changes.
fn palette_cache_path(path: &str, scheme: &str) -> Option<std::path::PathBuf> {
    let mtime = std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let sanitized: String = path
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
        .collect();
    std::env::var_os("HOME").map(|home| {
        std::path::Path::new(&home)
            .join(".cache/edgebar/palettes")
            .join(format!("{scheme}__{sanitized}__{mtime}.json"))
    })
}

/// Install a precomputed palette as the live palette.json atomically (copy to a
/// sibling temp, then rename) so edgebar never reads a partial file.
fn install_palette(cache: &std::path::Path) -> bool {
    let Some(dst) = palette_json_path() else {
        return false;
    };
    let tmp = dst.with_extension("json.install");
    std::fs::copy(cache, &tmp).is_ok() && std::fs::rename(&tmp, &dst).is_ok()
}

/// Background-precompute the palette for every wallpaper in the folder for
/// `scheme` (skipping cached ones), so picking one is an instant cache hit.
/// Sequential to avoid a matugen CPU spike; each is ~0.3s.
fn spawn_precompute(theme_cmd: String, scheme: String) {
    let Some(dir) = wallpapers_dir() else {
        return;
    };
    std::thread::spawn(move || {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            return;
        };
        let mut paths: Vec<std::path::PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| is_image(p))
            .collect();
        paths.sort();
        for p in paths {
            let Some(path) = p.to_str() else { continue };
            let Some(cache) = palette_cache_path(path, &scheme) else {
                continue;
            };
            if cache.exists() {
                continue;
            }
            let cache_str = cache.to_string_lossy();
            let _ = std::process::Command::new(&theme_cmd)
                .args(["--out", &cache_str, "--scheme", &scheme, path])
                .status();
        }
    });
}

/// Precompute every wallpaper's palette for the active scheme. Called when the
/// theme view opens so later picks are instant.
#[tauri::command]
fn precompute_palettes(state: tauri::State<Mutex<ThemeState>>) {
    let theme_cmd = state.lock().unwrap().theme_command.clone();
    spawn_precompute(theme_cmd, persisted_scheme());
}

/// Set the desktop on every display and re-theme the bar. Instant when the
/// palette is already precomputed (atomic copy + in-process reload); otherwise
/// generates it now. The in-app marker stops the watcher from double-running.
#[tauri::command]
fn set_wallpaper(app: tauri::AppHandle, state: tauri::State<Mutex<ThemeState>>, path: String) {
    let (wallpaper_cmd, theme_cmd) = {
        let ts = state.lock().unwrap();
        (ts.wallpaper_command.clone(), ts.theme_command.clone())
    };
    touch_inapp_marker();
    let _ = std::process::Command::new(wallpaper_cmd)
        .args(["all", &path])
        .spawn();

    let scheme = persisted_scheme();
    if let Some(cache) = palette_cache_path(&path, &scheme) {
        if cache.exists() && install_palette(&cache) {
            reload_theme(&app); // instant — no matugen, no socket round-trip
            return;
        }
    }
    // not precomputed yet: generate now (it pings the socket → reload)
    let _ = std::process::Command::new(theme_cmd).arg(&path).spawn();
}

/// Open a Finder file picker (owned by osascript, so the accessory app's no-focus
/// policy doesn't block it) and return the chosen image path, or None on cancel.
// Blocks until the user dismisses the Finder dialog, so it runs off the main
// thread via `spawn_blocking` — otherwise the bar freezes while the dialog is up.
#[tauri::command]
async fn pick_wallpaper_file() -> Option<String> {
    let path = tauri::async_runtime::spawn_blocking(|| {
        run_osa(
            "POSIX path of (choose file with prompt \"Choose a wallpaper\" of type {\"public.image\"})",
        )
    })
    .await
    .ok()
    .flatten()?;
    if path.is_empty() {
        None
    } else {
        Some(path)
    }
}

/// Set the matugen scheme: re-theme the current wallpaper with it now, and
/// precompute the rest in the background so subsequent picks stay instant.
#[tauri::command]
async fn set_scheme(app: tauri::AppHandle, scheme: String) {
    let _ = tauri::async_runtime::spawn_blocking(move || {
        persist_scheme(&scheme);
        // Clone the commands out and drop the guard before shelling out, so the
        // ThemeState lock isn't held across the wallpaper subprocess.
        let (wallpaper_cmd, theme_cmd) = {
            let state = app.state::<Mutex<ThemeState>>();
            let ts = state.lock().unwrap();
            (ts.wallpaper_command.clone(), ts.theme_command.clone())
        };
        let current = query_current_wallpaper(&wallpaper_cmd);
        spawn_precompute(theme_cmd.clone(), scheme.clone());
        // re-theme the current wallpaper now (cache is cold for the new scheme, so
        // this usually generates once; precompute warms the rest in the background)
        if !current.is_empty() {
            if let Some(cache) = palette_cache_path(&current, &scheme) {
                if cache.exists() && install_palette(&cache) {
                    reload_theme(&app);
                    return;
                }
            }
            let _ = std::process::Command::new(&theme_cmd).arg(&current).spawn();
        } else {
            let _ = std::process::Command::new(&theme_cmd).spawn();
        }
    })
    .await;
}

// ───────────────────────── shared app state ─────────────────────────
// Holds a persistent `sysinfo::System` (kept alive so the delta-based readings
// have a baseline — a fresh System always reports 0%; on macOS the CPU figure
// now comes from CpuState instead, leaving this to memory and swap) and a cache
// of app icons keyed by bundle id (PNG data URLs, resolved once on the main
// thread and reused for the workspace dots).
struct AppState {
    sys: Mutex<sysinfo::System>,
    icon_cache: Mutex<std::collections::HashMap<String, String>>,
    /// Wallpaper thumbnail data URLs for the theme view, keyed by path → (mtime
    /// secs, data URL). Avoids re-running sips on every theme-view open.
    thumb_cache: Mutex<std::collections::HashMap<String, (u64, String)>>,
    /// Interactive rects for each bar's click-through hitTest (WebView CSS px,
    /// top-left origin), keyed by window label. Shared with the cursor monitors.
    interactive_rects: RectMap,
}

// ───────────────────────── battery (pmset) ─────────────────────────
#[derive(Clone, Default, Serialize)]
struct Battery {
    percent: u8,
    /// "charging" | "discharging" | "charged" | "AC attached" | …
    state: String,
    /// "2:38" when an estimate exists, else None.
    time: Option<String>,
}

/// Parse `pmset -g batt`, whose battery line looks like:
///   ` -InternalBattery-0 (id=…)\t29%; charging; 2:38 remaining present: true`
fn read_battery() -> Battery {
    let text = std::process::Command::new("pmset")
        .args(["-g", "batt"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default();

    let Some(line) = text.lines().find(|l| l.contains('%')) else {
        return Battery::default();
    };

    let percent = line.find('%').map_or(0, |i| {
        let rev: String = line[..i]
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_digit())
            .collect();
        rev.chars().rev().collect::<String>().parse().unwrap_or(0)
    });
    let state = line
        .splitn(3, ';')
        .nth(1)
        .map(|s| s.trim().to_string())
        .unwrap_or_default();
    let time = line.splitn(3, ';').nth(2).and_then(|s| {
        s.trim()
            .split_whitespace()
            .next()
            .filter(|t| t.contains(':'))
            .map(str::to_string)
    });

    Battery {
        percent,
        state,
        time,
    }
}

#[tauri::command]
async fn battery() -> Battery {
    tauri::async_runtime::spawn_blocking(read_battery)
        .await
        .unwrap_or_default()
}

// ───────────────────────── system metrics (sysinfo) ─────────────────
// Memory, swap and disk are sampled on demand (lazy poll) only while the notch's
// Metrics view is open — mirrors ambxst, which polls SystemResources only when
// the dashboard is open. CPU is the exception: it's read from the bar's
// always-on sampler (see `cpu_percent`), which is running anyway.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct Metrics {
    cpu: f32, // percent 0..100
    mem_used: u64,
    mem_total: u64,
    swap_used: u64,
    swap_total: u64,
    disk_used: u64,
    disk_total: u64,
}

/// The notch's CPU figure comes from the bar's always-on sampler rather than a
/// second `refresh_cpu_usage()` here. Two independent samplers disagreed at the
/// same instant (mach tick delta over exactly CPU_POLL vs sysinfo's per-core
/// average), and sysinfo derives its percentage from the delta since *its* last
/// refresh — so the first reading after opening a notch that had been shut for
/// an hour was the average over that hour, self-correcting a tick later.
#[cfg(target_os = "macos")]
fn cpu_percent(app: &tauri::AppHandle, _sys: &mut sysinfo::System) -> f32 {
    app.state::<CpuState>().latest.lock().unwrap().total * 100.0
}

/// `host_statistics` is macOS-only, so the sampler never runs elsewhere — fall
/// back to sysinfo's own aggregate there.
#[cfg(not(target_os = "macos"))]
fn cpu_percent(_app: &tauri::AppHandle, sys: &mut sysinfo::System) -> f32 {
    sys.refresh_cpu_usage();
    sys.global_cpu_usage()
}

fn sample_metrics(sys: &mut sysinfo::System, cpu: f32) -> Metrics {
    sys.refresh_memory();

    // Root volume (the boot disk). Fall back to the largest disk if "/" isn't
    // listed (on macOS the data volume is mounted under /System/Volumes/Data).
    let disks = sysinfo::Disks::new_with_refreshed_list();
    let root = disks
        .list()
        .iter()
        .find(|d| d.mount_point() == std::path::Path::new("/"))
        .or_else(|| disks.list().iter().max_by_key(|d| d.total_space()));
    let (disk_total, disk_avail) = root.map_or((0, 0), |d| (d.total_space(), d.available_space()));

    Metrics {
        cpu,
        mem_used: sys.used_memory(),
        mem_total: sys.total_memory(),
        swap_used: sys.used_swap(),
        swap_total: sys.total_swap(),
        disk_used: disk_total.saturating_sub(disk_avail),
        disk_total,
    }
}

// Disks::new_with_refreshed_list() rescans all mounts, so sample off the main
// thread — this ticks every 2s while the notch is open.
#[tauri::command]
async fn metrics_sample(app: tauri::AppHandle) -> Metrics {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<AppState>();
        let mut sys = state.sys.lock().unwrap();
        // Lock order: AppState.sys then CpuState. The sampler thread never takes
        // AppState.sys, so the two can't invert on each other.
        let cpu = cpu_percent(&app, &mut sys);
        sample_metrics(&mut sys, cpu)
    })
    .await
    .unwrap_or_default()
}

// ───────────────────────── cpu load graph ───────────────────────────
// Always-on, unlike the notch's lazy Metrics view: the bar's CPU pill draws a
// rolling history, so it has to keep sampling whether or not anything is open.
// Ported from the old sketchybar mach helper — same system/user tick split from
// `host_statistics(HOST_CPU_LOAD_INFO)`, same top-process readout, same
// percentage thresholds (the colors now live in styles.css).

/// Sampling period. sketchybar's helper ran at `update_freq=4`; 2s matches the
/// cadence the notch's metrics already use and keeps the graph from looking
/// stepped. CPU_HISTORY samples at this rate is the window the graph covers.
const CPU_POLL: std::time::Duration = std::time::Duration::from_secs(2);
/// Ring-buffer depth — one entry per histogram column, each 1px wide. Must match
/// CPU_GRAPH.samples in main.ts, which is in turn pinned to the graph's pixel
/// width so columns land on whole pixels.
const CPU_HISTORY: usize = 108;
/// How many ticks between top-process lookups. The graph itself is nearly free
/// (one `host_statistics` call, ~11µs measured), but naming the hungriest
/// process means walking every PID — ~13ms with 600 processes, which every tick
/// would make a sustained 0.65% of a core. The name moves far more slowly than
/// the graph, so it lags a little instead; at CPU_POLL=2s this lands near the
/// 4s cadence the sketchybar helper ran at.
const CPU_TOP_PROC_EVERY: u32 = 3;

/// One point on the graph: fractions of total CPU capacity in 0..1, kept split
/// so the graph can draw the same filled-system / stroked-user pair sketchybar
/// layered into one box.
#[derive(Clone, Copy, Default, Serialize)]
struct CpuSample {
    sys: f32,
    user: f32,
}

/// The pill's current readout. `top_proc_pct` is percent of a single core (so it
/// can exceed 100 on a threaded process) — the same convention `ps pcpu` used.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct CpuStat {
    sys: f32,
    user: f32,
    total: f32,
    top_proc: String,
    top_proc_pct: f32,
    /// 0 when no process has been sampled yet — the bar hides the pid then.
    top_pid: u32,
}

/// Seed for a bar that just loaded: the full history plus the latest readout.
/// Bars are rebuilt on every display change, so a newly-created one would
/// otherwise draw an empty graph and fill in over the next two and a half
/// minutes; this hands it the buffer the sampler has been keeping all along.
#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct CpuSnapshot {
    history: Vec<CpuSample>,
    latest: CpuStat,
}

#[derive(Default)]
struct CpuState {
    history: Mutex<std::collections::VecDeque<CpuSample>>,
    latest: Mutex<CpuStat>,
}

#[tauri::command]
fn cpu_state(app: tauri::AppHandle) -> CpuSnapshot {
    let state = app.state::<CpuState>();
    let history = state.history.lock().unwrap().iter().copied().collect();
    let latest = state.latest.lock().unwrap().clone();
    CpuSnapshot { history, latest }
}

/// Cumulative CPU ticks since boot, indexed by `CPU_STATE_*`. Percentages come
/// from the delta between two reads, so a single sample means nothing on its own.
#[cfg(target_os = "macos")]
fn read_cpu_ticks(host: libc::host_t) -> Option<[u32; libc::CPU_STATE_MAX as usize]> {
    let mut info: libc::host_cpu_load_info = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_CPU_LOAD_INFO_COUNT;
    // SAFETY: `info` is the layout HOST_CPU_LOAD_INFO writes, and `count` tells
    // the kernel how many words it may write (the matching _COUNT constant).
    let err = unsafe {
        libc::host_statistics(
            host,
            libc::HOST_CPU_LOAD_INFO,
            &mut info as *mut _ as libc::host_info_t,
            &mut count,
        )
    };
    (err == libc::KERN_SUCCESS).then_some(info.cpu_ticks)
}

/// Daemons commonly carry reverse-DNS executable names (`com.apple.WebKit
/// .WebContent`); the leading domain is noise in a bar this narrow, so drop it
/// exactly as the sketchybar helper's FILTER_PATTERN did.
fn trim_proc_name(name: &str) -> &str {
    name.strip_prefix("com.apple.").unwrap_or(name)
}

/// Background sampler: reads the tick split, finds the hungriest process, pushes
/// both to every bar. Runs on its own thread — a display-config rebuild replaces
/// the bar windows but leaves this and its history untouched.
#[cfg(target_os = "macos")]
fn install_cpu_sampler(app: tauri::AppHandle) {
    use sysinfo::{ProcessRefreshKind, ProcessesToUpdate};

    std::thread::spawn(move || {
        // `mach_host_self` adds a send right per call, so take the port once and
        // reuse it for the process's lifetime rather than leaking one per tick.
        #[allow(deprecated)]
        let host = unsafe { libc::mach_host_self() };

        // Its own `System`, not the AppState one the notch samples: sysinfo
        // derives CPU from the delta since that instance's last refresh, so two
        // refreshers sharing one instance would measure each other's
        // milliseconds-apart deltas and report nonsense.
        let mut sys = sysinfo::System::new();
        let proc_cpu = ProcessRefreshKind::nothing().with_cpu();
        // Prime both baselines — the first delta of either is meaningless.
        sys.refresh_processes_specifics(ProcessesToUpdate::All, true, proc_cpu);
        let mut prev = read_cpu_ticks(host);
        // Last known hungriest process (name, percent, pid), carried across the
        // ticks that skip the walk so every emitted stat still names one.
        let mut top: (String, f32, u32) = Default::default();
        let mut tick: u32 = 0;

        loop {
            std::thread::sleep(CPU_POLL);

            let Some(now) = read_cpu_ticks(host) else {
                continue;
            };
            let Some(before) = prev else {
                prev = Some(now);
                continue;
            };
            prev = Some(now);

            // Ticks are monotonic but wrap at u32; wrapping_sub keeps the delta
            // right across the rollover instead of yielding a huge bogus jump.
            let delta = |i: libc::c_int| {
                now[i as usize].wrapping_sub(before[i as usize]) as f64
            };
            let user = delta(libc::CPU_STATE_USER);
            let system = delta(libc::CPU_STATE_SYSTEM);
            let idle = delta(libc::CPU_STATE_IDLE);
            // The helper this is ported from left NICE out of the denominator;
            // it's counted here so the fractions still total 1 if anything ever
            // runs re-niced (it's ~always 0 on macOS, so the two agree in
            // practice).
            let nice = delta(libc::CPU_STATE_NICE);
            let busy_total = user + system + idle + nice;
            if busy_total <= 0.0 {
                continue; // no elapsed ticks (clock skew / suspend) — nothing to plot
            }
            let sample = CpuSample {
                sys: (system / busy_total) as f32,
                // NICE is user-space work, so it belongs on the user trace.
                user: ((user + nice) / busy_total) as f32,
            };

            // `tick` starts at 0, so the first pass through names a process
            // immediately rather than leaving the pill blank for CPU_POLL ×
            // CPU_TOP_PROC_EVERY. Per-process usage is a delta since that
            // process's own last refresh, so skipping ticks widens the window
            // it averages over — which only steadies the reading.
            if tick % CPU_TOP_PROC_EVERY == 0 {
                sys.refresh_processes_specifics(ProcessesToUpdate::All, true, proc_cpu);
                top = sys
                    .processes()
                    .values()
                    .max_by(|a, b| a.cpu_usage().total_cmp(&b.cpu_usage()))
                    .map(|p| {
                        let name = p.name().to_string_lossy();
                        (
                            trim_proc_name(&name).to_string(),
                            p.cpu_usage(),
                            p.pid().as_u32(),
                        )
                    })
                    .unwrap_or_default();
            }
            tick = tick.wrapping_add(1);

            let stat = CpuStat {
                sys: sample.sys,
                user: sample.user,
                total: sample.sys + sample.user,
                top_proc: top.0.clone(),
                top_proc_pct: top.1,
                top_pid: top.2,
            };

            {
                let state = app.state::<CpuState>();
                let mut history = state.history.lock().unwrap();
                if history.len() == CPU_HISTORY {
                    history.pop_front();
                }
                history.push_back(sample);
                *state.latest.lock().unwrap() = stat.clone();
            }
            let _ = app.emit("cpu", &stat);
        }
    });
}

// ───────────────────────── volume / mic (osascript) ─────────────────
#[derive(Clone, Default, Serialize)]
struct Volume {
    output: u8,
    input: u8,
}

fn run_osa(script: &str) -> Option<String> {
    let out = std::process::Command::new("osascript")
        .args(["-e", script])
        .output()
        .ok()?;
    Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

fn osa_num(script: &str) -> u8 {
    run_osa(script)
        .and_then(|s| s.parse().ok())
        .unwrap_or(0)
}

#[tauri::command]
async fn get_volume() -> Volume {
    tauri::async_runtime::spawn_blocking(|| Volume {
        output: osa_num("output volume of (get volume settings)"),
        input: osa_num("input volume of (get volume settings)"),
    })
    .await
    .unwrap_or_default()
}

#[tauri::command]
async fn set_volume(output: u8) {
    let _ = tauri::async_runtime::spawn_blocking(move || {
        run_osa(&format!("set volume output volume {}", output.min(100)))
    })
    .await;
}

#[tauri::command]
async fn set_input_volume(input: u8) {
    let _ = tauri::async_runtime::spawn_blocking(move || {
        run_osa(&format!("set volume input volume {}", input.min(100)))
    })
    .await;
}

// ───────────────────────── brightness (DisplayServices) ─────────────
// Private framework; linked in build.rs. Works for the internal display.
#[cfg(target_os = "macos")]
mod brightness {
    type CGDirectDisplayID = u32;
    extern "C" {
        fn CGMainDisplayID() -> CGDirectDisplayID;
        fn DisplayServicesGetBrightness(id: CGDirectDisplayID, brightness: *mut f32) -> i32;
        fn DisplayServicesSetBrightness(id: CGDirectDisplayID, brightness: f32) -> i32;
    }
    pub fn get() -> f32 {
        let mut b: f32 = 0.0;
        unsafe {
            DisplayServicesGetBrightness(CGMainDisplayID(), &mut b);
        }
        b
    }
    pub fn set(value: f32) {
        unsafe {
            DisplayServicesSetBrightness(CGMainDisplayID(), value.clamp(0.0, 1.0));
        }
    }
}

#[tauri::command]
fn get_brightness() -> f32 {
    #[cfg(target_os = "macos")]
    {
        brightness::get()
    }
    #[cfg(not(target_os = "macos"))]
    {
        0.0
    }
}

#[tauri::command]
fn set_brightness(value: f32) {
    #[cfg(target_os = "macos")]
    {
        brightness::set(value);
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = value;
    }
}

// ───────────────────────── app icons (NSWorkspace) ──────────────────
// Event-driven, no polling: an NSWorkspace observer fires on every app
// activation and re-pushes the workspaces so the focused workspace's dot tracks
// whatever app you just switched to (AeroSpace's workspace-change hook only
// fires on workspace switches, not on focus moves within a workspace).

/// Encode an NSImage as a PNG data URL (TIFF rep → bitmap rep → PNG → base64).
#[cfg(target_os = "macos")]
fn icon_png_data_url(img: &objc2_app_kit::NSImage) -> Option<String> {
    use objc2_app_kit::{NSBitmapImageFileType, NSBitmapImageRep};
    use objc2_foundation::{NSDataBase64EncodingOptions, NSDictionary};

    let tiff = img.TIFFRepresentation()?;
    let rep = NSBitmapImageRep::imageRepWithData(&tiff)?;
    let png = unsafe {
        rep.representationUsingType_properties(NSBitmapImageFileType::PNG, &NSDictionary::new())
    }?;
    let b64 = png.base64EncodedStringWithOptions(NSDataBase64EncodingOptions::empty());
    Some(format!("data:image/png;base64,{}", &*b64))
}

#[cfg(target_os = "macos")]
struct FrontIvars {
    // A ping to the debounced worker; the worker owns the AppHandle.
    tx: std::sync::mpsc::Sender<()>,
}

#[cfg(target_os = "macos")]
use objc2::runtime::NSObjectProtocol;
#[cfg(target_os = "macos")]
use objc2::DefinedClass;

#[cfg(target_os = "macos")]
objc2::define_class!(
    #[unsafe(super(objc2::runtime::NSObject))]
    #[name = "EdgebarFrontAppObserver"]
    #[ivars = FrontIvars]
    struct FrontAppObserver;

    impl FrontAppObserver {
        #[unsafe(method(appActivated:))]
        fn app_activated(&self, _notification: *mut objc2::runtime::AnyObject) {
            // Runs on the main thread. Just ping the worker: it collapses a burst
            // (rapid cmd-tab) into one AeroSpace query, so activations can't spawn
            // racing threads whose out-of-order emits leave stale dot state.
            let _ = self.ivars().tx.send(());
        }
    }

    unsafe impl NSObjectProtocol for FrontAppObserver {}
);

#[cfg(target_os = "macos")]
fn install_front_app_observer(app: tauri::AppHandle) {
    use objc2::rc::Retained;
    use objc2::{msg_send, sel, AllocAnyThread};
    use objc2_app_kit::{NSWorkspace, NSWorkspaceDidActivateApplicationNotification};

    // Single worker: collapse a burst of activations into one AeroSpace query +
    // emit. query_workspaces shells out, so it never runs on the main thread.
    // Mirrors install_network_observer's debounce.
    let (tx, rx) = std::sync::mpsc::channel::<()>();
    let worker_app = app;
    std::thread::spawn(move || {
        while rx.recv().is_ok() {
            std::thread::sleep(std::time::Duration::from_millis(60));
            while rx.try_recv().is_ok() {}
            let _ = worker_app.emit("workspaces", workspaces_with_icons(&worker_app));
        }
    });

    let observer = FrontAppObserver::alloc().set_ivars(FrontIvars { tx });
    let observer: Retained<FrontAppObserver> = unsafe { msg_send![super(observer), init] };

    let center = NSWorkspace::sharedWorkspace().notificationCenter();
    unsafe {
        center.addObserver_selector_name_object(
            &observer,
            sel!(appActivated:),
            Some(NSWorkspaceDidActivateApplicationNotification),
            None,
        );
    }
    // Keep the observer alive for the app's lifetime (it stays registered).
    std::mem::forget(observer);
}

#[cfg(target_os = "macos")]
struct AppearanceIvars {
    app: tauri::AppHandle,
}

#[cfg(target_os = "macos")]
objc2::define_class!(
    #[unsafe(super(objc2::runtime::NSObject))]
    #[name = "EdgebarAppearanceObserver"]
    #[ivars = AppearanceIvars]
    struct AppearanceObserver;

    impl AppearanceObserver {
        #[unsafe(method(appearanceChanged:))]
        fn appearance_changed(&self, _notification: *mut objc2::runtime::AnyObject) {
            // Fires on the main thread when the system flips light/dark. Only act
            // in Auto mode — a pinned light/dark choice ignores the system.
            let app = self.ivars().app.clone();
            let is_auto = {
                app.state::<Mutex<ThemeState>>().lock().unwrap().appearance == Appearance::Auto
            };
            if is_auto {
                apply_theme(&app, Appearance::Auto);
            }
        }
    }

    unsafe impl NSObjectProtocol for AppearanceObserver {}
);

/// Observe macOS light/dark changes (`AppleInterfaceThemeChangedNotification` on
/// the distributed center) so Auto mode follows the system. Event-driven — no
/// polling.
#[cfg(target_os = "macos")]
fn install_appearance_observer(app: tauri::AppHandle) {
    use objc2::rc::Retained;
    use objc2::{msg_send, sel, AllocAnyThread};
    use objc2_foundation::{NSDistributedNotificationCenter, NSString};

    let observer = AppearanceObserver::alloc().set_ivars(AppearanceIvars { app });
    let observer: Retained<AppearanceObserver> = unsafe { msg_send![super(observer), init] };

    let center = NSDistributedNotificationCenter::defaultCenter();
    let name = NSString::from_str("AppleInterfaceThemeChangedNotification");
    unsafe {
        center.addObserver_selector_name_object(
            &observer,
            sel!(appearanceChanged:),
            Some(&name),
            None,
        );
    }
    std::mem::forget(observer);
}

/// Watch network reachability and push a fresh `Network` to the bar whenever
/// connectivity changes — interface up/down, IP change, VPN toggling. Replaces
/// polling the `network` command on a timer; idle cost is zero.
///
/// Reachability only reports *route* changes — it can't see a dead uplink or a
/// captive portal (the route still exists), so the real online check still runs
/// inside `read_network()` on each change. That's the same split macOS itself
/// uses: a passive path monitor plus an active probe.
#[cfg(target_os = "macos")]
fn install_network_observer(app: tauri::AppHandle) {
    use core_foundation::runloop::{kCFRunLoopCommonModes, CFRunLoop};
    use system_configuration::network_reachability::SCNetworkReachability;

    // Worker: receives "something changed" pings, debounces a burst into one
    // read, then pushes. `read_network()` shells out (scutil + system_profiler +
    // curl, ≈1–3s), so it runs here and not on the run-loop thread.
    let (tx, rx) = std::sync::mpsc::channel::<()>();
    let worker_app = app.clone();
    std::thread::spawn(move || {
        // Initial push so the bar reflects current state without waiting for the
        // first change event.
        let _ = worker_app.emit("network", read_network());
        while rx.recv().is_ok() {
            // A re-association flaps the flags several times; collapse the burst.
            std::thread::sleep(std::time::Duration::from_millis(400));
            while rx.try_recv().is_ok() {}
            let _ = worker_app.emit("network", read_network());
        }
    });

    // The reachability object isn't Send, so it's created and driven entirely on
    // this thread; its run loop invokes the callback. "0.0.0.0:0" tracks the
    // default-route reachability (general network availability).
    std::thread::spawn(move || {
        let addr = "0.0.0.0:0".parse::<std::net::SocketAddr>().unwrap();
        let mut reach = SCNetworkReachability::from(addr);
        // Mutex makes the Sender `Sync`, which the callback bound requires.
        let tx = std::sync::Mutex::new(tx);
        if reach
            .set_callback(move |_flags| {
                let _ = tx.lock().unwrap().send(());
            })
            .is_err()
        {
            return;
        }
        // SAFETY: kCFRunLoopCommonModes is Apple's documented run-loop mode.
        if unsafe { reach.schedule_with_runloop(&CFRunLoop::get_current(), kCFRunLoopCommonModes) }
            .is_err()
        {
            return;
        }
        CFRunLoop::run_current(); // blocks this thread for the app's lifetime
    });
}

// ───────────────────────── multi-monitor windows ────────────────────
// One bar + one frame per display. Geometry is never computed once and left
// stale: NSApplicationDidChangeScreenParametersNotification triggers a full
// re-sync, so dock/undock/rearrange/resolution changes reposition everything.

/// Label for the i-th monitor's bar window: the config-defined "bar" for the
/// first, "bar-1"/"bar-2"/… clones for the rest.
fn bar_label(i: usize) -> String {
    if i == 0 {
        "bar".to_string()
    } else {
        format!("bar-{i}")
    }
}

/// Inverse of `bar_label` (None for non-bar windows).
fn bar_index(label: &str) -> Option<usize> {
    if label == "bar" {
        return Some(0);
    }
    label.strip_prefix("bar-")?.parse().ok()
}

/// Create/position one bar window per monitor. The i-th monitor (left-to-right)
/// gets `bar_label(i)`, created from the tauri.conf.json "bar" template if
/// missing. Position/size are set in LOGICAL coordinates: converting each
/// monitor's physical origin with its own scale factor yields global points,
/// which tao hands straight to NSWindow — mixed-DPI safe (a 2x built-in next to
/// 1x externals breaks if you position with physical coords, because tao would
/// convert them with whichever screen the window currently sits on). Bars for
/// unplugged monitors are destroyed. Main thread only.
#[cfg(target_os = "macos")]
fn sync_bars_to_monitors(app: &tauri::AppHandle, window_height: f64, rects: &RectMap) {
    let Ok(mut monitors) = app.available_monitors() else {
        return;
    };
    if monitors.is_empty() {
        return;
    }
    // Stable order: left-to-right, then top-to-bottom.
    monitors.sort_by_key(|m| (m.position().x, m.position().y));
    let template = app.config().app.windows.first().cloned();
    for (i, m) in monitors.iter().enumerate() {
        let label = bar_label(i);
        let bar = app.get_webview_window(&label).or_else(|| {
            let mut cfg = template.clone()?;
            cfg.label = label.clone();
            tauri::WebviewWindowBuilder::from_config(app, &cfg)
                .ok()?
                .build()
                .ok()
        });
        let Some(bar) = bar else { continue };
        let scale = m.scale_factor();
        let pos: LogicalPosition<f64> = m.position().to_logical(scale);
        let size: LogicalSize<f64> = m.size().to_logical(scale);
        // The bar is NOT offset for the dead top row: its pills sit a full
        // line-thickness below the top edge (nowhere near row 0) and overlap the
        // native frame's top line, so moving the window down would only open a
        // 1px seam between the two windows. Only the native frame (drawn at the
        // very edge) needs top_offset_px.
        let _ = bar.set_position(pos);
        let _ = bar.set_size(LogicalSize::new(size.width, window_height));
        let _ = bar.set_always_on_top(true);
        let _ = bar.set_visible_on_all_workspaces(true);
        make_overlay(&bar);
        track_bar_window(&label, &bar);
        let _ = bar.show();
    }
    for (label, w) in app.webview_windows() {
        if bar_index(&label).is_some_and(|i| i >= monitors.len()) {
            untrack_bar_window(&label, rects);
            let _ = w.destroy();
        }
    }
}

/// (Re)build all per-display chrome: one native frame per NSScreen, one bar per
/// monitor. Called at setup and on every display-configuration change. Main
/// thread only; needs ThemeState + AppState managed.
#[cfg(target_os = "macos")]
fn rebuild_displays(app: &tauri::AppHandle) {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSScreen;

    let Some(mtm) = MainThreadMarker::new() else {
        return;
    };
    let (geometry, line, corner) = {
        let state = app.state::<Mutex<ThemeState>>();
        let ts = state.lock().unwrap();
        let c = resolve_colors(ts.colors.for_scheme(ts.scheme), ts.palettes.for_scheme(ts.scheme));
        (ts.geometry.clone(), c.frame_line, c.frame_corner)
    };
    remove_native_frames();
    let screens = NSScreen::screens(mtm);
    for screen in screens.iter() {
        create_native_frame(mtm, &screen, &geometry, &line, &corner);
    }
    let rects = app.state::<AppState>().interactive_rects.clone();
    sync_bars_to_monitors(app, geometry.window_height, &rects);
}

#[cfg(target_os = "macos")]
struct ScreenIvars {
    /// A ping to the debounced rebuild worker.
    tx: std::sync::mpsc::Sender<()>,
}

#[cfg(target_os = "macos")]
objc2::define_class!(
    #[unsafe(super(objc2::runtime::NSObject))]
    #[name = "EdgebarScreenObserver"]
    #[ivars = ScreenIvars]
    struct ScreenObserver;

    impl ScreenObserver {
        #[unsafe(method(screensChanged:))]
        fn screens_changed(&self, _notification: *mut objc2::runtime::AnyObject) {
            // Fires on the main thread for every display-config change (plug,
            // unplug, rearrange, resolution). A dock/undock flaps it several
            // times, so just ping the worker, which collapses the burst.
            let _ = self.ivars().tx.send(());
        }
    }

    unsafe impl NSObjectProtocol for ScreenObserver {}
);

/// Rebuild frames + bars whenever the display configuration changes
/// (NSApplicationDidChangeScreenParametersNotification). Debounced off-thread,
/// then hopped back to main for the AppKit work.
#[cfg(target_os = "macos")]
fn install_screen_observer(app: tauri::AppHandle) {
    use objc2::rc::Retained;
    use objc2::{msg_send, sel, AllocAnyThread};
    use objc2_app_kit::NSApplicationDidChangeScreenParametersNotification;
    use objc2_foundation::NSNotificationCenter;

    let (tx, rx) = std::sync::mpsc::channel::<()>();
    std::thread::spawn(move || {
        while rx.recv().is_ok() {
            std::thread::sleep(std::time::Duration::from_millis(500));
            while rx.try_recv().is_ok() {}
            let handle = app.clone();
            let _ = app.run_on_main_thread(move || rebuild_displays(&handle));
        }
    });

    let observer = ScreenObserver::alloc().set_ivars(ScreenIvars { tx });
    let observer: Retained<ScreenObserver> = unsafe { msg_send![super(observer), init] };
    let center = NSNotificationCenter::defaultCenter();
    unsafe {
        center.addObserver_selector_name_object(
            &observer,
            sel!(screensChanged:),
            Some(NSApplicationDidChangeScreenParametersNotification),
            None,
        );
    }
    std::mem::forget(observer);
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            aerospace_workspaces,
            aerospace_focus,
            set_bar_size,
            get_config,
            set_appearance,
            battery,
            metrics_sample,
            cpu_state,
            get_volume,
            set_volume,
            set_input_volume,
            get_brightness,
            set_brightness,
            network,
            launcher_action,
            set_interactive_rects,
            list_wallpapers,
            current_wallpaper,
            set_wallpaper,
            pick_wallpaper_file,
            set_scheme,
            precompute_palettes
        ])
        .setup(|app| {
            // Shared config (colors + geometry) — drives both the native frame
            // and the WebView (which fetches it via get_config and applies CSS vars).
            let config = load_config();
            let palettes = load_palettes();
            // Runtime override (the bar's light/dark/auto toggle) wins over the
            // config's default; Auto then resolves against the live system setting.
            let appearance = load_persisted_appearance().unwrap_or(config.appearance);
            let scheme = resolve_scheme(appearance);

            // Accessory app: no Dock icon, never becomes the active app, so it
            // never steals focus or bounces you back to the previously-active
            // app (e.g. Arc) when its windows are shown or touched.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Interactive rects per bar window; shared between the cursor
            // monitors and the set_interactive_rects command.
            let interactive_rects: RectMap = Default::default();

            // Both states go in before rebuild_displays, which reads them.
            app.manage(AppState {
                sys: Mutex::new(sysinfo::System::new()),
                icon_cache: Mutex::new(std::collections::HashMap::new()),
                thumb_cache: Mutex::new(std::collections::HashMap::new()),
                interactive_rects: interactive_rects.clone(),
            });
            // CPU history + latest readout. Managed before the sampler starts
            // (which happens below, after the bars exist) so `cpu_state` can
            // answer a bar that asks before the first tick lands.
            app.manage(CpuState::default());
            // Shared theme state (raw role maps + both palettes), resolved on
            // demand by get_config / apply_theme.
            app.manage(Mutex::new(ThemeState {
                colors: config.colors,
                geometry: config.geometry,
                palettes,
                appearance,
                scheme,
                theme_command: config
                    .theme_command
                    .unwrap_or_else(|| "generate-edgebar-theme".to_string()),
                wallpaper_command: config
                    .wallpaper_command
                    .unwrap_or_else(|| "desktoppr".to_string()),
            }));

            // Per-display chrome: one native frame per screen, one bar per
            // monitor — built now and rebuilt on every display-config change,
            // so geometry never goes stale when screens come, go, or move.
            #[cfg(target_os = "macos")]
            {
                install_cursor_monitors(interactive_rects.clone());
                rebuild_displays(app.handle());
                install_screen_observer(app.handle().clone());
            }
            #[cfg(not(target_os = "macos"))]
            if let Some(bar) = app.get_webview_window("bar") {
                let _ = bar.show();
            }

            // Event-driven workspace updates: AeroSpace's exec-on-workspace-change
            // callback pings this unix socket. The accept loop only ACKS (accept +
            // drop, so the nc client exits immediately) and pings a debounced
            // worker that runs the actual query — if a query wedges (a hung
            // `aerospace` CLI has frozen this loop before), pings keep draining
            // instead of piling stuck clients into the listen backlog.
            let ws_handle = app.handle().clone();
            std::thread::spawn(move || {
                use std::os::unix::net::UnixListener;
                let Some(home) = std::env::var_os("HOME") else {
                    return;
                };
                let dir = std::path::Path::new(&home).join(".cache/edgebar");
                let _ = std::fs::create_dir_all(&dir);
                let sock = dir.join("ws.sock");
                let _ = std::fs::remove_file(&sock); // clear any stale socket
                let Ok(listener) = UnixListener::bind(&sock) else {
                    return;
                };
                let (tx, rx) = std::sync::mpsc::channel::<()>();
                let query_handle = ws_handle.clone();
                std::thread::spawn(move || {
                    while rx.recv().is_ok() {
                        // Collapse a burst of pings into one query + push.
                        std::thread::sleep(std::time::Duration::from_millis(60));
                        while rx.try_recv().is_ok() {}
                        let _ = query_handle
                            .emit("workspaces", workspaces_with_icons(&query_handle));
                    }
                });
                for conn in listener.incoming() {
                    drop(conn); // a connection is just a "something changed" ping
                    let _ = tx.send(());
                }
            });

            // Theme reload: `generate-edgebar-theme` / matugen writes a new
            // palette.json then pings this socket; each ping reloads from disk and
            // re-themes the running bar live (no relaunch). Same pattern as ws.sock.
            let theme_handle = app.handle().clone();
            std::thread::spawn(move || {
                use std::os::unix::net::UnixListener;
                let Some(home) = std::env::var_os("HOME") else {
                    return;
                };
                let dir = std::path::Path::new(&home).join(".cache/edgebar");
                let _ = std::fs::create_dir_all(&dir);
                let sock = dir.join("theme.sock");
                let _ = std::fs::remove_file(&sock); // clear any stale socket
                let Ok(listener) = UnixListener::bind(&sock) else {
                    return;
                };
                for conn in listener.incoming() {
                    if conn.is_err() {
                        continue;
                    }
                    reload_theme(&theme_handle);
                }
            });

            // The NSWorkspace observer re-pushes workspaces on every app
            // activation so the focused dot stays current.
            #[cfg(target_os = "macos")]
            install_front_app_observer(app.handle().clone());

            // Follow the system light/dark setting while in Auto mode.
            #[cfg(target_os = "macos")]
            install_appearance_observer(app.handle().clone());

            // Event-driven Wi-Fi/network updates (replaces the old 15s poll).
            #[cfg(target_os = "macos")]
            install_network_observer(app.handle().clone());

            // Always-on CPU sampling for the bar's graph pill (the notch's other
            // metrics stay lazy — only this one is visible at rest).
            #[cfg(target_os = "macos")]
            install_cpu_sampler(app.handle().clone());

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
