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
use tauri::{Emitter, Manager, PhysicalPosition, PhysicalSize};

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
struct Config {
    #[serde(default = "default_appearance")]
    appearance: Appearance,
    colors: Themes,
    geometry: Geometry,
}

/// What `get_config` and the `theme` event hand the WebView: colors already
/// resolved to hex for the active scheme, plus geometry and the appearance.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ResolvedConfig {
    colors: Colors,
    geometry: Geometry,
    appearance: Appearance,
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

/// Shared, mutable theme state behind a `Mutex` (managed by Tauri). Holds the
/// raw per-scheme role maps + both palettes; `get_config`/`apply_theme` resolve
/// to hex on demand for whichever scheme is active.
struct ThemeState {
    colors: Themes,
    geometry: Geometry,
    palettes: Palettes,
    appearance: Appearance,
    scheme: Scheme,
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
    let h = hex.trim().trim_start_matches('#');
    let byte = |i: usize| u8::from_str_radix(&h[i..i + 2], 16).map(|v| v as f64 / 255.0);
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

/// Run the AeroSpace CLI and return non-empty, trimmed stdout lines.
fn aerospace(args: &[&str]) -> Vec<String> {
    std::process::Command::new("aerospace")
        .args(args)
        .output()
        .map(|o| {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .map(|l| l.trim().to_string())
                .filter(|l| !l.is_empty())
                .collect()
        })
        .unwrap_or_default()
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

/// Set the bar's `ignoresMouseEvents` from the cursor position: interactive when
/// it's over one of the reported rects (the pills, or a full-window rect while a
/// popup is open), click-through otherwise. `mouseLocation` and the window frame
/// are screen coords (bottom-left origin); the rects are window-relative CSS px
/// from the top-left, so we map each rect into screen space to compare.
#[cfg(target_os = "macos")]
fn sync_ignore_mouse(
    ns_window: &objc2_app_kit::NSWindow,
    rects: &std::sync::Mutex<Vec<[f64; 4]>>,
) {
    let loc = objc2_app_kit::NSEvent::mouseLocation();
    let frame = ns_window.frame();
    let win_top = frame.origin.y + frame.size.height;
    let over = rects.lock().unwrap().iter().any(|r| {
        let sx0 = frame.origin.x + r[0];
        let sx1 = sx0 + r[2];
        let sy1 = win_top - r[1];
        let sy0 = sy1 - r[3];
        loc.x >= sx0 && loc.x <= sx1 && loc.y >= sy0 && loc.y <= sy1
    });
    ns_window.setIgnoresMouseEvents(!over);
}

/// Track the cursor with NSEvent monitors and toggle the bar's
/// `ignoresMouseEvents` so it's interactive only over the pills.
#[cfg(target_os = "macos")]
fn install_cursor_tracking(
    window: &tauri::WebviewWindow,
    rects: std::sync::Arc<std::sync::Mutex<Vec<[f64; 4]>>>,
) {
    use objc2::rc::Retained;
    use objc2_app_kit::{NSEvent, NSEventMask, NSWindow};

    let Ok(ptr) = window.ns_window() else {
        return;
    };
    let Some(ns_window) = (unsafe { Retained::retain(ptr as *mut NSWindow) }) else {
        return;
    };

    // Start click-through; the monitors flip it on when the cursor reaches a pill.
    ns_window.setIgnoresMouseEvents(true);

    let mask = NSEventMask::MouseMoved | NSEventMask::LeftMouseDragged;

    // Local monitor: events delivered to us. Must return the event so the bar's
    // own handling (hover, clicks) continues.
    let nw_local = ns_window.clone();
    let rects_local = rects.clone();
    let local = block2::RcBlock::new(move |event: core::ptr::NonNull<NSEvent>| -> *mut NSEvent {
        sync_ignore_mouse(&nw_local, &rects_local);
        event.as_ptr()
    });
    // Global monitor: events delivered to other apps (cursor over the bar while
    // it's click-through, or anywhere else). Re-arms interactivity on re-entry.
    let nw_global = ns_window.clone();
    let rects_global = rects.clone();
    let global = block2::RcBlock::new(move |_event: core::ptr::NonNull<NSEvent>| {
        sync_ignore_mouse(&nw_global, &rects_global);
    });

    // The monitors copy the blocks and AppKit keeps them alive; we never remove
    // them (they live for the app's lifetime), so the returned handles can drop.
    unsafe {
        let _ = NSEvent::addLocalMonitorForEventsMatchingMask_handler(mask, &local);
        let _ = NSEvent::addGlobalMonitorForEventsMatchingMask_handler(mask, &global);
    }
}

/// Update the interactive rects the cursor tracker checks (WebView CSS px,
/// top-left origin). Called by the WebView whenever its layout changes.
#[tauri::command]
fn set_interactive_rects(state: tauri::State<AppState>, rects: Vec<[f64; 4]>) {
    *state.interactive_rects.lock().unwrap() = rects;
}

// Commands are `async` so the IPC layer runs them off the main thread, and the
// blocking subprocess work goes through `spawn_blocking` — a sync command would
// run the `aerospace` calls on the main thread and beach-ball the UI.
/// Create the screen frame as a native borderless NSWindow drawn with CALayer —
/// no WebView, so it costs no web-content process. Replicates the old CSS frame:
/// a green rounded-rect line hugging the screen edge (root layer cornerRadius +
/// border) plus black fills in the four corner notches outside that rounded rect
/// (an even-odd CAShapeLayer). Click-through, all-spaces, stationary.
#[cfg(target_os = "macos")]
fn create_native_frame(geometry: &Geometry, frame_line: &str, frame_corner: &str) {
    use objc2::{MainThreadMarker, MainThreadOnly};
    use objc2_app_kit::{
        NSBackingStoreType, NSBezierPath, NSColor, NSScreen, NSWindow,
        NSWindowCollectionBehavior, NSWindowStyleMask, NSWindingRule,
    };
    use objc2_core_foundation::{CGPoint, CGRect, CGSize};
    use objc2_quartz_core::{kCAFillRuleEvenOdd, CAShapeLayer};

    // Look comes from the shared config (config.json) + active palette.
    let radius = geometry.inner_radius;
    let line = geometry.line_thickness;
    let line_rgba = hex_to_rgba(frame_line);
    let corner_rgba = hex_to_rgba(frame_corner);

    let Some(mtm) = MainThreadMarker::new() else {
        return;
    };
    let Some(screen) = NSScreen::mainScreen(mtm) else {
        return;
    };
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
    window.setLevel(6);
    window.setIgnoresMouseEvents(true);
    // CanJoinAllSpaces | Stationary | IgnoresCycle | FullScreenAuxiliary
    window.setCollectionBehavior(NSWindowCollectionBehavior(1 | (1 << 4) | (1 << 6) | (1 << 8)));
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

    // Retain both shape layers so day/night + wallpaper changes can recolor them
    // in place (cheap setFillColor) instead of rebuilding the window.
    FRAME_LAYERS.with(|cell| {
        *cell.borrow_mut() = Some(FrameLayers {
            line: line_layer.clone(),
            corners: corners.clone(),
        });
    });

    window.orderFrontRegardless();
    std::mem::forget(window); // keep it alive for the app's lifetime
}

/// The native frame's two fill layers, retained on the main thread so a theme
/// change can recolor them without recreating the window. CALayer isn't `Send`,
/// so this lives in a main-thread `thread_local!`, not Tauri's managed state.
#[cfg(target_os = "macos")]
struct FrameLayers {
    line: objc2::rc::Retained<objc2_quartz_core::CAShapeLayer>,
    corners: objc2::rc::Retained<objc2_quartz_core::CAShapeLayer>,
}

#[cfg(target_os = "macos")]
thread_local! {
    static FRAME_LAYERS: std::cell::RefCell<Option<FrameLayers>> =
        const { std::cell::RefCell::new(None) };
}

/// Recolor the native frame's line + corner layers. Must run on the main thread
/// (AppKit); callers hop via `run_on_main_thread`.
#[cfg(target_os = "macos")]
fn recolor_native_frame(line_hex: &str, corner_hex: &str) {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSColor;
    if MainThreadMarker::new().is_none() {
        return;
    }
    let l = hex_to_rgba(line_hex);
    let c = hex_to_rgba(corner_hex);
    FRAME_LAYERS.with(|cell| {
        if let Some(f) = cell.borrow().as_ref() {
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

/// Resize the bar window (logical px). Used to make room for the clock's
/// expanded panel; the window is transparent so the resize itself is invisible.
#[tauri::command]
fn set_bar_size(app: tauri::AppHandle, width: f64, height: f64) {
    if let Some(bar) = app.get_webview_window("bar") {
        let _ = bar.set_size(tauri::LogicalSize::new(width, height));
    }
}

// ───────────────────────── network (Wi-Fi / IP / VPN) ───────────────
// Mirrors sketchybar's ip_address.sh: shows the primary IP (not the SSID, which
// macOS now gates behind Location Services), flags an active VPN (utun), or
// "Not Connected". Parsed from `scutil --nwi`.
#[derive(Clone, Default, Serialize)]
struct Network {
    /// "wifi" | "vpn" | "off"
    state: String,
    label: String,
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
        }
    } else if let Some(ip) = ip {
        Network {
            state: "wifi".into(),
            label: ip,
        }
    } else {
        Network {
            state: "off".into(),
            label: "Not Connected".into(),
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

// ───────────────────────── shared app state ─────────────────────────
// Holds a persistent `sysinfo::System` (kept alive so CPU usage can be computed
// from the delta between samples — a fresh System always reports 0%) and a cache
// of app icons keyed by bundle id (PNG data URLs, resolved once on the main
// thread and reused for the workspace dots).
struct AppState {
    sys: Mutex<sysinfo::System>,
    icon_cache: Mutex<std::collections::HashMap<String, String>>,
    /// Interactive rects for the bar's click-through hitTest (WebView CSS px,
    /// top-left origin). Shared with the native `ClickThroughView`.
    interactive_rects: std::sync::Arc<std::sync::Mutex<Vec<[f64; 4]>>>,
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
// Sampled on demand (lazy poll) only while the notch's Metrics view is open —
// mirrors ambxst, which polls SystemResources only when the dashboard is open.
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

fn sample_metrics(sys: &mut sysinfo::System) -> Metrics {
    sys.refresh_cpu_usage();
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
        cpu: sys.global_cpu_usage(),
        mem_used: sys.used_memory(),
        mem_total: sys.total_memory(),
        swap_used: sys.used_swap(),
        swap_total: sys.total_swap(),
        disk_used: disk_total.saturating_sub(disk_avail),
        disk_total,
    }
}

#[tauri::command]
fn metrics_sample(state: tauri::State<AppState>) -> Metrics {
    let mut sys = state.sys.lock().unwrap();
    sample_metrics(&mut sys)
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
    app: tauri::AppHandle,
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
            // The callback runs on the main thread; query_workspaces shells out to
            // AeroSpace, so do the work off-thread (it hops back to the main thread
            // only for icon resolution) to avoid beach-balling the UI.
            let app = self.ivars().app.clone();
            std::thread::spawn(move || {
                let _ = app.emit("workspaces", workspaces_with_icons(&app));
            });
        }
    }

    unsafe impl NSObjectProtocol for FrontAppObserver {}
);

#[cfg(target_os = "macos")]
fn install_front_app_observer(app: tauri::AppHandle) {
    use objc2::rc::Retained;
    use objc2::{msg_send, sel, AllocAnyThread};
    use objc2_app_kit::{NSWorkspace, NSWorkspaceDidActivateApplicationNotification};

    let observer = FrontAppObserver::alloc().set_ivars(FrontIvars { app });
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            aerospace_workspaces,
            aerospace_focus,
            set_bar_size,
            get_config,
            set_appearance,
            battery,
            metrics_sample,
            get_volume,
            set_volume,
            set_input_volume,
            get_brightness,
            set_brightness,
            network,
            launcher_action,
            set_interactive_rects
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

            // Interactive rects for the bar's click-through hitTest; shared
            // between the native ClickThroughView and the set_interactive_rects
            // command (created before both so they hold clones of the same Arc).
            let interactive_rects = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));

            // Accessory app: no Dock icon, never becomes the active app, so it
            // never steals focus or bounces you back to the previously-active
            // app (e.g. Arc) when its windows are shown or touched.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Frame: a native borderless NSWindow drawn with CALayer — no
            // WebView, so it costs no extra web-content process. Built with the
            // frame colors resolved for the active scheme; recolored live after.
            #[cfg(target_os = "macos")]
            {
                let fc = resolve_colors(config.colors.for_scheme(scheme), palettes.for_scheme(scheme));
                create_native_frame(&config.geometry, &fc.frame_line, &fc.frame_corner);
            }

            // Bar: full-width strip pinned to the top, normally interactive.
            if let Some(bar) = app.get_webview_window("bar") {
                if let Ok(Some(m)) = bar.current_monitor() {
                    let pos = *m.position();
                    let size = *m.size();
                    let scale = bar.scale_factor().unwrap_or(1.0);
                    let h = (config.geometry.window_height * scale).round() as u32;
                    // The bar is NOT offset for the dead top row: its pills sit a
                    // full line-thickness below the top edge (nowhere near row 0)
                    // and overlap the native frame's top line, so moving the window
                    // down would only open a 1px seam between the two windows. Only
                    // the native frame (drawn at the very edge) needs top_offset_px.
                    let _ = bar.set_position(PhysicalPosition::new(pos.x, pos.y));
                    let _ = bar.set_size(PhysicalSize::new(size.width, h));
                }
                let _ = bar.set_always_on_top(true);
                let _ = bar.set_visible_on_all_workspaces(true);
                #[cfg(target_os = "macos")]
                make_overlay(&bar);
                #[cfg(target_os = "macos")]
                install_cursor_tracking(&bar, interactive_rects.clone());
                let _ = bar.show();
            }

            // Event-driven workspace updates: AeroSpace's exec-on-workspace-change
            // callback pings this unix socket; each ping triggers one query and a
            // push to the bar. No polling — idle cost is zero.
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
                for conn in listener.incoming() {
                    if conn.is_err() {
                        continue;
                    }
                    // a connection is just a "something changed" ping
                    let _ = ws_handle.emit("workspaces", workspaces_with_icons(&ws_handle));
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

            // Metrics state + app-icon cache. The NSWorkspace observer re-pushes
            // workspaces on every app activation so the focused dot stays current.
            app.manage(AppState {
                sys: Mutex::new(sysinfo::System::new()),
                icon_cache: Mutex::new(std::collections::HashMap::new()),
                interactive_rects,
            });
            #[cfg(target_os = "macos")]
            install_front_app_observer(app.handle().clone());

            // Shared theme state (raw role maps + both palettes), resolved on
            // demand by get_config / apply_theme. Replaces the old immutable config.
            app.manage(Mutex::new(ThemeState {
                colors: config.colors,
                geometry: config.geometry,
                palettes,
                appearance,
                scheme,
            }));
            // Follow the system light/dark setting while in Auto mode.
            #[cfg(target_os = "macos")]
            install_appearance_observer(app.handle().clone());

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
