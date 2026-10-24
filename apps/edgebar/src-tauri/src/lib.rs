// Don't toggle `ignore_cursor_events` from a polling loop instead: Tauri's
// getters block on the main event loop, which stops servicing them while the
// cursor is tracked over a window, so the loop deadlocks.

use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{Emitter, LogicalPosition, LogicalSize, Manager};

mod assistant;

/// Dynamic content for the collapsed notch (media / per-workspace / OSD).
mod notch;

mod metrics;

mod notifications;

mod toggles;

mod wallpapers;

mod keyboard;

#[cfg(all(debug_assertions, target_os = "macos"))]
mod devtools;

mod settings;

mod setup;

#[cfg(test)]
mod scratch;

/// Appearance preference. `Auto` follows the macOS system light/dark setting;
/// `Light`/`Dark` pin it.
#[derive(Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
enum Appearance {
    Light,
    Dark,
    Auto,
}

/// The scheme in effect once `Auto` is resolved against the system; picks the
/// palette and role map.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Scheme {
    Light,
    Dark,
}

#[derive(Clone, PartialEq, Deserialize, Serialize)]
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

/// Single source of truth for colours and geometry, read by both the native
/// frame and the bar WebView (as CSS custom properties).
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Config {
    appearance: Appearance,
    colors: Themes,
    geometry: Geometry,
    /// Binaries the theme picker shells out to (this and `wallpaper_command`).
    /// Nix injects store paths; when absent (bundled default, dev) a bare name
    /// is resolved on PATH.
    theme_command: Option<String>,
    wallpaper_command: Option<String>,
    /// Per-workspace notch rules + the idle fallback. See `notch.rs`.
    notch: notch::NotchConfig,
    toggles: toggles::TogglesConfig,
    wallpaper: wallpapers::WallpaperConfig,
    oled: bool,
    assistant: assistant::AssistantConfig,
    notifications: notifications::NotificationsConfig,
}

/// What `get_config` and the `theme` event hand the WebView: colours resolved
/// to hex for the active scheme, plus geometry, appearance and the matugen
/// scheme (so the theme view can mark the current selections).
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ResolvedConfig {
    colors: Colors,
    geometry: Geometry,
    appearance: Appearance,
    scheme: String,
    ink: InkInfo,
    /// What the notch shows when no provider has anything to say. Rendered
    /// entirely in the WebView (a clock ticks, and that shouldn't cost an event
    /// stream), so it travels with the config rather than the `notch` event.
    notch_idle: String,
}

fn resolve_colors(
    colors: &Colors,
    palette: &std::collections::HashMap<String, String>,
) -> Colors {
    let r = |v: &str| -> String {
        v.split('|')
            .find_map(|key| {
                if key.starts_with('#') {
                    Some(key.to_string())
                } else {
                    palette.get(key).cloned()
                }
            })
            .unwrap_or_else(|| v.to_string())
    };
    Colors {
        surface: r(&colors.surface),
        text: r(&colors.text),
        subtext: r(&colors.subtext),
        accent: r(&colors.accent),
        battery_charging: r(&colors.battery_charging),
        battery_low: r(&colors.battery_low),
        vpn: r(&colors.vpn),
        cpu_sys: r(&colors.cpu_sys),
        cpu_user: r(&colors.cpu_user),
    }
}

const MIN_INK_CONTRAST: f64 = 4.5;

const MIN_ACCENT_CONTRAST: f64 = 3.0;

/// WCAG 2 relative luminance of an sRGB `#hex` colour (alpha ignored).
fn luminance(hex: &str) -> f64 {
    let [r, g, b, _] = hex_to_rgba(hex);
    let lin = |c: f64| {
        if c <= 0.04045 {
            c / 12.92
        } else {
            ((c + 0.055) / 1.055).powf(2.4)
        }
    };
    0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

/// WCAG 2 contrast ratio between two colours, 1.0 (same) to 21.0 (black/white).
fn contrast(a: &str, b: &str) -> f64 {
    let (la, lb) = (luminance(a), luminance(b));
    (la.max(lb) + 0.05) / (la.min(lb) + 0.05)
}

#[derive(Clone, Default, Deserialize, Serialize)]
struct InkOverride {
    #[serde(default)]
    light: Option<String>,
    #[serde(default)]
    dark: Option<String>,
}

impl InkOverride {
    fn for_scheme(&self, s: Scheme) -> Option<&str> {
        match s {
            Scheme::Light => self.light.as_deref(),
            Scheme::Dark => self.dark.as_deref(),
        }
    }

    fn set(&mut self, s: Scheme, ink: Option<String>) {
        match s {
            Scheme::Light => self.light = ink,
            Scheme::Dark => self.dark = ink,
        }
    }
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct InkInfo {
    /// "config" (the role map's ink cleared the floor), "contrast" (the check
    /// replaced it) or "override" (set explicitly from the theme view).
    source: &'static str,
    ratio: f64,
    /// The role map's ink and its contrast, before any correction.
    configured: String,
    configured_ratio: f64,
    /// The scheme this ink belongs to ("light" | "dark"); an override edits it.
    mode: &'static str,
}

fn readable_on(
    ground: &str,
    configured: &str,
    palette: &std::collections::HashMap<String, String>,
    floor: f64,
) -> Option<String> {
    if contrast(configured, ground) >= floor {
        return None;
    }
    // Sorted so a tie between two distinct colours resolves the same way every
    // run (HashMap order doesn't).
    let mut candidates: Vec<&str> = palette
        .values()
        .map(String::as_str)
        .filter(|v| v.starts_with('#'))
        .collect();
    candidates.sort_unstable();
    let best_of = |c: &[&str]| -> String {
        c.iter()
            .copied()
            .max_by(|a, b| contrast(a, ground).total_cmp(&contrast(b, ground)))
            .unwrap_or(configured)
            .to_string()
    };
    let best = best_of(&candidates);
    if contrast(&best, ground) >= floor {
        return Some(best);
    }
    Some(best_of(&[configured, best.as_str(), "#000000", "#ffffff"]))
}

/// `#rrggbb` (any case) → lower-case, or None if it isn't one.
fn normalise_hex(s: &str) -> Option<String> {
    let h = s.trim().strip_prefix('#')?;
    (h.len() == 6 && h.bytes().all(|b| b.is_ascii_hexdigit()))
        .then(|| format!("#{}", h.to_ascii_lowercase()))
}

#[derive(Clone, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Colors {
    surface: String,
    text: String,
    subtext: String,
    accent: String,
    battery_charging: String,
    battery_low: String,
    vpn: String,
    /// The CPU graph's two stacked segments (system load, user load).
    cpu_sys: String,
    cpu_user: String,
}

#[derive(Clone, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Geometry {
    bar_height: f64,
    frame_thickness: f64,
    frame_radius: f64,
    window_height: f64,
}

fn load_config() -> Config {
    settings::load(settings::dir().as_deref()).config
}

/// Resolve `notch.idle` to what the WebView should draw when no provider owns
/// the slot. `handle` and `clock` are rendered there; `userHost` is expanded
/// here (the WebView has no way to ask who or where it is) and anything else is
/// passed through as literal text.
fn resolve_notch_idle(idle: Option<&str>) -> String {
    match idle {
        None | Some("handle") => "handle".to_string(),
        Some("userHost") => {
            let user = std::env::var("USER").unwrap_or_else(|_| "user".into());
            let host = run_osa("host name of (system info)")
                .filter(|h| !h.is_empty())
                .unwrap_or_else(|| "mac".into());
            format!("{user}@{host}")
        }
        Some(other) => other.to_string(),
    }
}

fn load_palettes() -> Palettes {
    const DEFAULT: &str = include_str!("../palette.default.json");
    palette_json_path()
        .and_then(|path| std::fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| {
            serde_json::from_str(DEFAULT).expect("bundled palette.default.json is valid")
        })
}

const DEFAULT_MATUGEN_SCHEME: &str = "scheme-tonal-spot";

/// matugen scheme persisted by `select-scheme` / the theme view, read by
/// `generate-edgebar-theme`.
fn scheme_state_path() -> Option<std::path::PathBuf> {
    Some(settings::dir()?.join("scheme"))
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

fn ink_state_path() -> Option<std::path::PathBuf> {
    Some(settings::dir()?.join("ink.json"))
}

fn load_ink_override() -> InkOverride {
    ink_state_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

fn persist_ink_override(ink: &InkOverride) {
    if let (Some(path), Ok(json)) = (ink_state_path(), serde_json::to_string(ink)) {
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::write(path, json);
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
    /// `notch.idle` from config, passed through to the WebView.
    notch_idle: String,
    ink: InkOverride,
    oled: bool,
}

impl ThemeState {
    fn palette(&self) -> std::collections::HashMap<String, String> {
        let palette = self.palettes.for_scheme(self.scheme);
        if self.oled && self.scheme == Scheme::Dark {
            wallpapers::blacken_base(palette)
        } else {
            palette.clone()
        }
    }

    fn resolve(&self) -> (Colors, InkInfo) {
        let palette = &self.palette();
        let mut colors = resolve_colors(self.colors.for_scheme(self.scheme), palette);
        let configured = std::mem::take(&mut colors.text);
        let (ink, source) = match self.ink.for_scheme(self.scheme) {
            Some(hex) => (hex.to_string(), "override"),
            None => match readable_on(&colors.surface, &configured, palette, MIN_INK_CONTRAST) {
                Some(better) => (better, "contrast"),
                None => (configured.clone(), "config"),
            },
        };
        if let Some(better) =
            readable_on(&colors.surface, &colors.accent, palette, MIN_ACCENT_CONTRAST)
        {
            colors.accent = better;
        }
        let info = InkInfo {
            source,
            ratio: contrast(&ink, &colors.surface),
            configured_ratio: contrast(&configured, &colors.surface),
            configured,
            mode: match self.scheme {
                Scheme::Light => "light",
                Scheme::Dark => "dark",
            },
        };
        colors.text = ink;
        (colors, info)
    }

    fn resolved_config(&self) -> ResolvedConfig {
        let (colors, ink) = self.resolve();
        ResolvedConfig {
            colors,
            geometry: self.geometry.clone(),
            appearance: self.appearance,
            scheme: persisted_scheme(),
            ink,
            notch_idle: self.notch_idle.clone(),
        }
    }
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

fn apply_theme(app: &tauri::AppHandle, appearance: Appearance) {
    let resolved: ResolvedConfig = {
        let state = app.state::<Mutex<ThemeState>>();
        let mut ts = state.lock().unwrap();
        ts.appearance = appearance;
        ts.scheme = resolve_scheme(appearance);
        ts.resolved_config()
    };
    let _ = app.emit("theme", &resolved);
    #[cfg(target_os = "macos")]
    {
        let surface = resolved.colors.surface.clone();
        let _ = app.run_on_main_thread(move || recolor_native_frame(&surface));
    }
    wallpapers::spawn_converge(app);
}

/// Reload palettes and role maps from disk and re-apply the current appearance.
/// Run on a `theme.sock` ping, or directly when an in-app pick finds its
/// palette precomputed. Geometry changes still need a relaunch.
fn reload_theme(app: &tauri::AppHandle) {
    let palettes = load_palettes();
    let config = load_config();
    let appearance = {
        let state = app.state::<Mutex<ThemeState>>();
        let mut ts = state.lock().unwrap();
        ts.palettes = palettes;
        ts.colors = config.colors;
        ts.geometry = config.geometry;
        ts.oled = config.oled;
        ts.appearance
    };
    apply_theme(app, appearance);
}

/// "#rrggbb" or "#rrggbbaa" -> [r, g, b, a] in 0..1 (defaults to opaque black).
fn hex_to_rgba(hex: &str) -> [f64; 4] {
    // Bytes, not str: slicing a str inside a multi-byte character (a stray
    // non-ASCII char in a hand-edited colour) would panic.
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
    state.lock().unwrap().resolved_config()
}

#[tauri::command]
fn set_ink(app: tauri::AppHandle, colour: Option<String>) {
    let ink = colour.as_deref().and_then(normalise_hex);
    if colour.is_some() && ink.is_none() {
        return; // not a colour; leave the current ink alone
    }
    let appearance = {
        let state = app.state::<Mutex<ThemeState>>();
        let mut ts = state.lock().unwrap();
        let scheme = ts.scheme;
        ts.ink.set(scheme, ink);
        persist_ink_override(&ts.ink);
        ts.appearance
    };
    apply_theme(&app, appearance);
}

/// Open the system colour picker (owned by osascript, like the wallpaper
/// picker) starting at `initial`, and return the choice as `#rrggbb`, or None
/// on cancel. Blocks until the dialog closes, hence `spawn_blocking`.
#[tauri::command]
async fn pick_colour(initial: String) -> Option<String> {
    let [r, g, b, _] = hex_to_rgba(&initial);
    // `choose color` speaks 16-bit channels: 0..=65535.
    let wide = |c: f64| (c * 65535.0).round() as u32;
    let script = format!(
        "set c to choose color default color {{{}, {}, {}}}\n\
         return ((item 1 of c) as text) & \" \" & (item 2 of c) & \" \" & (item 3 of c)",
        wide(r),
        wide(g),
        wide(b)
    );
    let out = tauri::async_runtime::spawn_blocking(move || run_osa(&script))
        .await
        .ok()
        .flatten()?;
    let rgb: Vec<u32> = out
        .split_whitespace()
        .filter_map(|v| v.parse().ok())
        .collect();
    let [r, g, b] = rgb[..] else {
        return None; // cancelled: osascript printed nothing
    };
    // 65535 / 255 = 257, so this maps the 16-bit range back onto 0..=255.
    Some(format!("#{:02x}{:02x}{:02x}", r / 257, g / 257, b / 257))
}

#[tauri::command]
async fn set_appearance(app: tauri::AppHandle, mode: String) -> Result<(), String> {
    settings::set_setting(
        app,
        "appearance".to_string(),
        serde_json::Value::String(mode),
    )
    .await
    .map(drop)
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

/// How a command run by `output_within` ended, with what it printed.
pub(crate) enum Ran {
    Exited(std::process::ExitStatus, String),
    Killed(String),
}

impl Ran {
    pub(crate) fn stdout(self) -> String {
        match self {
            Ran::Exited(_, text) | Ran::Killed(text) => text,
        }
    }
}

/// Run `cmd` with only stdout open, killing it once `limit` has passed. None
/// when it could not be started or reaped.
pub(crate) fn output_within(
    mut cmd: std::process::Command,
    limit: std::time::Duration,
) -> Option<Ran> {
    use std::io::Read;
    use std::process::Stdio;
    let mut child = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
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
    match rx.recv_timeout(limit) {
        Ok(text) => Some(Ran::Exited(child.wait().ok()?, text)),
        Err(_) => {
            let _ = child.kill();
            let text = rx.recv().unwrap_or_default();
            let _ = child.wait();
            Some(Ran::Killed(text))
        }
    }
}

/// Run the AeroSpace CLI and return its non-empty, trimmed stdout lines. Capped
/// at 5s, after which the child is killed and whatever it printed is used: a
/// wedged server would otherwise block the caller forever.
pub(crate) fn aerospace(args: &[&str]) -> Vec<String> {
    let mut cmd = std::process::Command::new("aerospace");
    cmd.args(args);
    output_within(cmd, std::time::Duration::from_secs(5))
        .map(Ran::stdout)
        .unwrap_or_default()
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect()
}

/// The dots we always draw: 1–9 then 0, matching the keyboard row. This list,
/// not AeroSpace, decides which dots exist: `list-workspaces --all` omits empty,
/// non-visible workspaces and includes stray on-demand ones (e.g. `11`), so
/// AeroSpace only supplies per-workspace state.
const WS_ORDER: [&str; 10] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];

/// Query AeroSpace for the state of each dot in `WS_ORDER`: which one is
/// focused, which hold windows, and the app icon to show on the occupied ones.
fn query_workspaces() -> Vec<Workspace> {
    let focused = aerospace(&["list-workspaces", "--focused"]).into_iter().next();
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

    WS_ORDER
        .iter()
        .map(|name| {
            let win = ws_app.get(*name);
            Workspace {
                has_windows: non_empty.iter().any(|n| n == name),
                focused: focused.as_deref() == Some(*name),
                app: win.map(|w| w.app.clone()).unwrap_or_default(),
                bundle_id: win.map(|w| w.bundle_id.clone()).unwrap_or_default(),
                icon: String::new(),
                name: (*name).to_string(),
            }
        })
        .collect()
}

/// Mark a window as a stationary, all-spaces overlay so Mission Control leaves
/// it in place. tao's set_visible_on_all_workspaces sets only CanJoinAllSpaces;
/// Stationary is the bit that keeps it put during Exposé.
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
        // setCollectionBehavior: is main-thread only; our caller,
        // `sync_bars_to_monitors`, runs there.
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
// A transparent window still swallows clicks across its whole rect, and
// returning nil from a view's hitTest doesn't pass them through; only the
// window's `ignoresMouseEvents` does. So bars stay click-through except while
// the cursor is over a rect the WebView reported.

// The bar NSWindows the shared cursor monitors hit-test, keyed by window
// label. Main-thread only (NSWindow isn't Send); bars register here when
// created and deregister when their monitor unplugs.
#[cfg(target_os = "macos")]
thread_local! {
    static TRACKED_BARS: std::cell::RefCell<
        std::collections::HashMap<String, objc2::rc::Retained<objc2_app_kit::NSWindow>>,
    > = std::cell::RefCell::new(std::collections::HashMap::new());
}

/// `mouseLocation` and the window frame are screen coords (bottom-left origin);
/// the rects are window-relative CSS px from the top-left, so we map each rect
/// into screen space to compare.
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

/// Install the app's two NSEvent cursor monitors, once; they serve every tracked
/// bar (monitors are per-app). The local one sees events sent to us (cursor over
/// an interactive bar) and must return the event so the bar still handles it.
/// The global one sees events sent to other apps (cursor over a click-through
/// bar, or anywhere else), which is what re-arms interactivity.
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

/// Register a bar window with the cursor monitors (idempotent).
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

/// Store the calling bar's interactive rects (see `RectMap`). Its WebView calls
/// this whenever the layout changes.
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

/// Click-through, all-spaces, stationary. Called once per NSScreen; the window
/// is kept in FRAME_WINDOWS so a display change can close and rebuild it.
#[cfg(target_os = "macos")]
fn create_native_frame(
    mtm: objc2::MainThreadMarker,
    screen: &objc2_app_kit::NSScreen,
    geometry: &Geometry,
    surface: &str,
) {
    use objc2::MainThreadOnly;
    use objc2_app_kit::{
        NSBackingStoreType, NSBezierPath, NSColor, NSWindow, NSWindowCollectionBehavior,
        NSWindowStyleMask,
    };
    use objc2_core_foundation::{CGPoint, CGRect, CGSize};
    use objc2_quartz_core::{
        kCAFillRuleEvenOdd, kCAGradientLayerRadial, CALayer, CAShapeLayer,
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
    // tao puts always-on-top windows (the bar) at kCGFloatingWindowLevelKey (5),
    // not NSFloatingWindowLevel (3).
    const FRAME_WINDOW_LEVEL: isize = 4;
    window.setLevel(FRAME_WINDOW_LEVEL);
    window.setIgnoresMouseEvents(true);
    // Same collection behaviour as the bar (see make_overlay).
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
    let full = CGRect::new(CGPoint::new(0.0, 0.0), CGSize::new(w, h));
    root.setFrame(full);
    root.setBackgroundColor(Some(&NSColor::clearColor().CGColor()));
    root.setMasksToBounds(false);

    let scale = screen.backingScaleFactor();
    let snap = |pt: f64| (pt * scale).round() / scale;
    let side = snap(geometry.frame_thickness);
    let top = snap(geometry.bar_height);
    let radius = snap(geometry.frame_radius);
    let hole_rect = CGRect::new(
        CGPoint::new(side, side),
        CGSize::new(w - 2.0 * side, h - side - top),
    );
    let hole = NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(hole_rect, radius, radius);

    let (hw, hh) = (hole_rect.size.width, hole_rect.size.height);
    let s = FRAME_SHADOW_SIZE;
    let along = |l: f64| frame_shadow_at(l * s);
    for (x, y, sw, sh, from, to) in [
        (side, side + radius, s, hh - 2.0 * radius, (0.0, 0.5), (1.0, 0.5)),
        (w - side - s, side + radius, s, hh - 2.0 * radius, (1.0, 0.5), (0.0, 0.5)),
        (side + radius, side, hw - 2.0 * radius, s, (0.5, 0.0), (0.5, 1.0)),
        (side + radius, h - top - s, hw - 2.0 * radius, s, (0.5, 1.0), (0.5, 0.0)),
    ] {
        let strip = shadow_gradient(&along);
        strip.setFrame(CGRect::new(CGPoint::new(x, y), CGSize::new(sw, sh)));
        strip.setStartPoint(CGPoint::new(from.0, from.1));
        strip.setEndPoint(CGPoint::new(to.0, to.1));
        root.addSublayer(&strip);
    }
    if radius > 0.0 {
        let around = |l: f64| frame_shadow_at(radius * (1.0 - l));
        for (x, y, cx, cy) in [
            (side, h - top - radius, radius, 0.0),
            (w - side - radius, h - top - radius, 0.0, 0.0),
            (side, side, radius, radius),
            (w - side - radius, side, 0.0, radius),
        ] {
            let corner = CALayer::new();
            corner.setFrame(CGRect::new(CGPoint::new(x, y), CGSize::new(radius, radius)));
            corner.setMasksToBounds(true);
            let ring = shadow_gradient(&around);
            ring.setType(unsafe { kCAGradientLayerRadial });
            ring.setFrame(CGRect::new(
                CGPoint::new(cx - radius, cy - radius),
                CGSize::new(2.0 * radius, 2.0 * radius),
            ));
            ring.setStartPoint(CGPoint::new(0.5, 0.5));
            ring.setEndPoint(CGPoint::new(1.0, 1.0));
            corner.addSublayer(&ring);
            root.addSublayer(&corner);
        }
    }

    let shape = NSBezierPath::bezierPathWithRect(full);
    shape.appendBezierPath(&hole);
    let fill = CAShapeLayer::new();
    fill.setFrame(full);
    fill.setPath(Some(&shape.CGPath()));
    fill.setFillRule(unsafe { kCAFillRuleEvenOdd });
    fill.setFillColor(Some(&srgb(surface).CGColor()));
    root.addSublayer(&fill);

    window.orderFrontRegardless();

    FRAME_WINDOWS.with(|cell| cell.borrow_mut().push(FrameWindow { window, fill }));
}

#[cfg(target_os = "macos")]
const FRAME_SHADOW_SIZE: f64 = 12.0;
#[cfg(target_os = "macos")]
const FRAME_SHADOW_OPACITY: f64 = 0.3;

#[cfg(target_os = "macos")]
fn frame_shadow_at(d: f64) -> f64 {
    let t = (1.0 - d / FRAME_SHADOW_SIZE).max(0.0);
    FRAME_SHADOW_OPACITY * t * t
}

#[cfg(target_os = "macos")]
fn shadow_gradient(
    darkness: &dyn Fn(f64) -> f64,
) -> objc2::rc::Retained<objc2_quartz_core::CAGradientLayer> {
    use objc2::runtime::AnyObject;
    use objc2_foundation::{NSArray, NSNumber};
    const STOPS: usize = 13;
    let at = |i: usize| i as f64 / (STOPS - 1) as f64;
    let colours: Vec<_> = (0..STOPS)
        .map(|i| {
            objc2_app_kit::NSColor::colorWithSRGBRed_green_blue_alpha(0.0, 0.0, 0.0, darkness(at(i)))
                .CGColor()
        })
        .collect();
    // CGColor is toll-free bridged, so the array can hold it as an object.
    let objects: Vec<&AnyObject> = colours
        .iter()
        .map(|c| unsafe { &*(&**c as *const objc2_core_graphics::CGColor).cast::<AnyObject>() })
        .collect();
    let locations: Vec<_> = (0..STOPS).map(|i| NSNumber::new_f64(at(i))).collect();
    let layer = objc2_quartz_core::CAGradientLayer::new();
    unsafe { layer.setColors(Some(&NSArray::from_slice(&objects))) };
    layer.setLocations(Some(&NSArray::from_retained_slice(&locations)));
    layer
}

#[cfg(target_os = "macos")]
fn srgb(hex: &str) -> objc2::rc::Retained<objc2_app_kit::NSColor> {
    let [r, g, b, a] = hex_to_rgba(hex);
    objc2_app_kit::NSColor::colorWithSRGBRed_green_blue_alpha(r, g, b, a)
}

#[cfg(target_os = "macos")]
struct FrameWindow {
    window: objc2::rc::Retained<objc2_app_kit::NSWindow>,
    fill: objc2::rc::Retained<objc2_quartz_core::CAShapeLayer>,
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

#[cfg(target_os = "macos")]
fn recolor_native_frame(surface: &str) {
    if objc2::MainThreadMarker::new().is_none() {
        return;
    }
    FRAME_WINDOWS.with(|cell| {
        for f in cell.borrow().iter() {
            f.fill.setFillColor(Some(&srgb(surface).CGColor()));
        }
    });
}

/// Query workspaces and fill in each occupied dot's app icon. Call off the main
/// thread: the AeroSpace query shells out.
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

/// How far up the process tree to look for the app behind an audio stream.
/// Chrome's audio service sits two hops below the browser; four is slack.
#[cfg(target_os = "macos")]
const PID_WALK_LIMIT: usize = 4;

/// One bundle id's icon as a PNG data URL ("" if the app isn't running or has
/// none), via the same cache and main-thread hop as the workspace dots. Call
/// off the main thread only: it blocks waiting for the main thread.
#[cfg(target_os = "macos")]
pub(crate) fn icon_for_bundle(app: &tauri::AppHandle, bundle_id: &str) -> String {
    if bundle_id.is_empty() {
        return String::new();
    }
    {
        // Scoped so the cache lock is released before the main thread — which
        // takes the same lock in resolve_icons — is asked to do anything.
        let state = app.state::<AppState>();
        let cache = state.icon_cache.lock().unwrap();
        if let Some(icon) = cache.get(bundle_id) {
            return icon.clone();
        }
    }
    let app2 = app.clone();
    let bid = bundle_id.to_string();
    let (tx, rx) = std::sync::mpsc::channel();
    if app
        .run_on_main_thread(move || {
            let _ = tx.send(resolve_icons(&app2, vec![bid]));
        })
        .is_err()
    {
        return String::new();
    }
    rx.recv()
        .ok()
        .and_then(|m| m.into_values().next())
        .unwrap_or_default()
}

/// Identify the app a pid belongs to: `(bundle id, display name, icon)`.
///
/// Audio usually comes from a helper process (Chrome's audio service, a WebKit
/// GPU process), so walk up the parent chain to the first regular (Dock-showing)
/// app, falling back to the first bundled process found (e.g. a menu-bar-only
/// app) rather than losing the readout.
#[cfg(target_os = "macos")]
pub(crate) fn app_info_for_pid(
    app: &tauri::AppHandle,
    pid: i32,
) -> Option<(String, String, String)> {
    use objc2_app_kit::{NSApplicationActivationPolicy, NSRunningApplication};

    let mut fallback: Option<(String, String)> = None;
    let mut pid = pid;
    for _ in 0..PID_WALK_LIMIT {
        // NSRunningApplication is documented thread-safe, so the lookup and its
        // string accessors need no main-thread hop (the icon does, and takes
        // one below).
        if let Some(running) = NSRunningApplication::runningApplicationWithProcessIdentifier(pid) {
            let bundle_id = running
                .bundleIdentifier()
                .map(|s| s.to_string())
                .unwrap_or_default();
            let name = running
                .localizedName()
                .map(|s| s.to_string())
                .unwrap_or_default();
            if !bundle_id.is_empty() {
                let found = (bundle_id, name);
                if running.activationPolicy() == NSApplicationActivationPolicy::Regular {
                    let icon = icon_for_bundle(app, &found.0);
                    return Some((found.0, found.1, icon));
                }
                fallback.get_or_insert(found);
            }
        }
        pid = parent_pid(pid)?;
    }
    fallback.map(|(bundle_id, name)| {
        let icon = icon_for_bundle(app, &bundle_id);
        (bundle_id, name, icon)
    })
}

/// BSD process info for `pid`, or None if it just exited.
#[cfg(target_os = "macos")]
fn proc_info(pid: i32) -> Option<libc::proc_bsdinfo> {
    let mut info: libc::proc_bsdinfo = unsafe { std::mem::zeroed() };
    let size = std::mem::size_of::<libc::proc_bsdinfo>() as i32;
    // SAFETY: `info` is a live proc_bsdinfo and `size` is exactly its size,
    // which is what PROC_PIDTBSDINFO writes.
    let written = unsafe {
        libc::proc_pidinfo(
            pid,
            libc::PROC_PIDTBSDINFO,
            0,
            &mut info as *mut libc::proc_bsdinfo as *mut libc::c_void,
            size,
        )
    };
    (written == size).then_some(info)
}

/// Parent of `pid`, or None at the top of the tree (or if it just exited).
#[cfg(target_os = "macos")]
fn parent_pid(pid: i32) -> Option<i32> {
    let ppid = proc_info(pid)?.pbi_ppid as i32;
    (ppid > 1).then_some(ppid) // launchd (1) is nobody's app
}

/// Unix seconds `pid` started, or 0 if it can't be read. Ranks simultaneously
/// audible apps by which audio process started most recently.
#[cfg(target_os = "macos")]
pub(crate) fn proc_start_secs(pid: i32) -> u64 {
    proc_info(pid).map(|i| i.pbi_start_tvsec).unwrap_or(0)
}

// Commands that block (subprocesses, dialogs) are `async` with the work in
// `spawn_blocking`: a sync command runs on the main thread and would
// beach-ball the UI.
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

/// Resize the calling bar window (logical px) to make room for an open notch or
/// popup panel. The window is transparent, so the resize itself is invisible.
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

// True if the internet is actually reachable. Hits the endpoint macOS's own
// captive-portal check uses, which returns "Success" only on a working
// connection (a dead uplink returns nothing, a portal its own page). 2s cap.
fn has_internet() -> bool {
    std::process::Command::new("curl")
        .args(["-s", "-m", "2", "http://captive.apple.com/hotspot-detect.html"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("Success"))
        .unwrap_or(false)
}

// Current Wi-Fi RSSI in dBm from `system_profiler SPAirPortDataType`, which
// still reports signal without Location Services (`airport` is gone). Only the
// text before "Other Local Wi-Fi Networks" is the live link; the rest is a scan
// of nearby APs. Takes ~1s, so only call it when connected.
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

/// The ids are the panes' extension bundle ids and the anchors their
/// `revealElementKeyName`s (SecurityPrivacyExtension.appex TCCServiceList.plist).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "camelCase")]
enum SettingsPane {
    Wifi,
    Bluetooth,
    Focus,
    Displays,
    FullDiskAccess,
    PrivacyBluetooth,
    PrivacyAutomation,
    Shortcuts,
}

impl SettingsPane {
    fn url(self) -> &'static str {
        match self {
            Self::Wifi => "x-apple.systempreferences:com.apple.wifi-settings-extension",
            Self::Bluetooth => "x-apple.systempreferences:com.apple.BluetoothSettings",
            Self::Focus => "x-apple.systempreferences:com.apple.Focus-Settings.extension",
            Self::Displays => "x-apple.systempreferences:com.apple.Displays-Settings.extension",
            Self::FullDiskAccess => {
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
            }
            Self::PrivacyBluetooth => {
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Bluetooth"
            }
            // Automation has no anchor of its own in TCCServiceList.plist; this
            // is the name the older Security pane used.
            Self::PrivacyAutomation => {
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation"
            }
            Self::Shortcuts => "shortcuts://",
        }
    }
}

fn open_pane(pane: SettingsPane) -> Result<(), String> {
    std::process::Command::new("/usr/bin/open")
        .arg(pane.url())
        .spawn()
        .map(drop)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn open_settings_pane(pane: SettingsPane) -> Result<(), String> {
    open_pane(pane)
}

// ───────────────────────── theme / wallpaper picker ─────────────────
// Backs the notch's theme view. Uses the same desktoppr and
// generate-edgebar-theme binaries as the CLI and the launchd watcher (paths
// from config.json), so results match; the picker just skips the launchd
// round-trip.

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct Wallpaper {
    name: String,
    path: String,
    thumb: String, // "data:image/png;base64,…"
    folder: String,
    kind: String,
}

/// Standard base64 with padding. Pure Rust, so thumbnails can be encoded off
/// the main thread.
pub(crate) fn base64_encode(bytes: &[u8]) -> String {
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

/// Downscale an image to a thumbnail PNG data URL via `sips`, which avoids
/// NSImage and so can run off the main thread. Cached by path and mtime.
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

#[tauri::command]
async fn list_wallpapers(app: tauri::AppHandle) -> Vec<Wallpaper> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<AppState>();
        let Some(dir) = wallpapers::folder() else {
            return Vec::new();
        };
        wallpapers::scan(&dir)
            .into_iter()
            .filter_map(|found| {
                let path = found.path.to_str()?.to_string();
                let thumb = wallpaper_thumb(&state, &path).unwrap_or_default();
                Some(Wallpaper {
                    name: found.name,
                    path,
                    thumb,
                    folder: found.folder,
                    kind: found.kind,
                })
            })
            .collect()
    })
    .await
    .unwrap_or_default()
}

fn query_desktop_picture(cmd: &str) -> String {
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

fn query_current_wallpaper(cmd: &str) -> String {
    wallpapers::original_of(&query_desktop_picture(cmd))
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
    if let Some(dir) = settings::cache_dir() {
        let _ = std::fs::create_dir_all(&dir);
        let _ = std::fs::write(dir.join(".inapp-change"), b"");
    }
}

fn palette_json_path() -> Option<std::path::PathBuf> {
    Some(settings::dir()?.join("palette.json"))
}

/// Per-(wallpaper, scheme) precomputed palette cache, keyed by scheme,
/// sanitised path and mtime so an edited image or new scheme misses it.
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
    Some(
        settings::cache_dir()?
            .join("palettes")
            .join(format!("{scheme}__{sanitized}__{mtime}.json")),
    )
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
    let Some(dir) = wallpapers::folder() else {
        return;
    };
    std::thread::spawn(move || {
        for found in wallpapers::scan(&dir) {
            let Some(path) = found.path.to_str() else { continue };
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

fn theme_from_wallpaper(app: &tauri::AppHandle, theme_cmd: &str, path: &str, wait: bool) {
    if let Some(cache) = palette_cache_path(path, &persisted_scheme()) {
        if cache.exists() && install_palette(&cache) {
            reload_theme(app);
            return;
        }
    }
    let mut generate = std::process::Command::new(theme_cmd);
    generate.arg(path);
    if wait {
        let _ = generate.status();
        reload_theme(app);
    } else {
        let _ = generate.spawn();
    }
}

#[tauri::command]
fn set_wallpaper(app: tauri::AppHandle, state: tauri::State<Mutex<ThemeState>>, path: String) {
    let (wallpaper_cmd, theme_cmd) = {
        let ts = state.lock().unwrap();
        (ts.wallpaper_command.clone(), ts.theme_command.clone())
    };
    if wallpapers::tint_on() {
        wallpapers::spawn_pick(&app, theme_cmd, path);
        return;
    }
    touch_inapp_marker();
    let _ = std::process::Command::new(wallpaper_cmd)
        .args(["all", &path])
        .spawn();
    theme_from_wallpaper(&app, &theme_cmd, &path, false);
}

/// Open a Finder file picker and return the chosen image path, or None on
/// cancel. osascript owns the dialog, so the accessory app's no-focus policy
/// doesn't block it.
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

#[tauri::command]
async fn pick_folder() -> Option<String> {
    let path = tauri::async_runtime::spawn_blocking(|| {
        run_osa("POSIX path of (choose folder with prompt \"Choose the wallpaper folder\")")
    })
    .await
    .ok()
    .flatten()?;
    let path = path.trim_end_matches('/');
    (!path.is_empty()).then(|| settings::tilde(std::path::Path::new(path)))
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
struct AppState {
    /// Kept alive because sysinfo's CPU reading is a delta since the last
    /// refresh (a fresh System reports 0%).
    sys: Mutex<sysinfo::System>,
    /// App icons as PNG data URLs, by bundle id.
    icon_cache: Mutex<std::collections::HashMap<String, String>>,
    /// Wallpaper thumbnails, path → (mtime secs, data URL), so `sips` doesn't
    /// rerun on every theme-view open.
    thumb_cache: Mutex<std::collections::HashMap<String, (u64, String)>>,
    /// The bars' click-through rects (see `RectMap`), shared with the cursor
    /// monitors.
    interactive_rects: RectMap,
}

// ───────────────────────── battery (pmset) ─────────────────────────
#[derive(Clone, Default, Serialize)]
struct Battery {
    /// False on machines with no battery (Mac mini, Studio, …), where the bar
    /// hides the battery readout entirely rather than showing a bogus 0%.
    present: bool,
    percent: u8,
    /// "charging" | "discharging" | "charged" | "AC attached" | …
    state: String,
    /// "2:38" when an estimate exists, else None.
    time: Option<String>,
}

/// Parse `pmset -g batt`, whose battery line looks like:
///   ` -InternalBattery-0 (id=…)\t29%; charging; 2:38 remaining present: true`
/// A desktop prints only `Now drawing from 'AC Power'` — no percentage line —
/// which is how we detect that there is no battery at all.
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
        present: true,
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

// ───────────────────────── volume / mic (osascript) ─────────────────
#[derive(Clone, Default, Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Volume {
    output: u8,
    input: u8,
    output_muted: bool,
    input_muted: bool,
}

static MIC_HELD: Mutex<Option<u8>> = Mutex::new(None);

pub(crate) fn run_osa(script: &str) -> Option<String> {
    let out = std::process::Command::new("osascript")
        .args(["-e", script])
        .output()
        .ok()?;
    Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

fn parse_volume_settings(reply: &str) -> Volume {
    let mut v = Volume::default();
    for field in reply.split(", ") {
        let Some((key, value)) = field.split_once(':') else {
            continue;
        };
        match key {
            "output volume" => v.output = value.parse().unwrap_or(0),
            "input volume" => v.input = value.parse().unwrap_or(0),
            "output muted" => v.output_muted = value == "true",
            _ => {}
        }
    }
    v
}

fn apply_mic_hold(mut v: Volume, held: &mut Option<u8>) -> Volume {
    if v.input > 0 {
        *held = None;
    }
    if let Some(level) = *held {
        v.input = level;
        v.input_muted = true;
    }
    v
}

fn mic_mute_target(muted: bool, read: &Volume, held: &mut Option<u8>) -> Option<u8> {
    match (muted, *held) {
        (true, None) => {
            *held = Some(read.input);
            Some(0)
        }
        (false, Some(level)) => {
            *held = None;
            Some(level)
        }
        _ => None,
    }
}

fn read_volume_settings() -> Volume {
    parse_volume_settings(&run_osa("get volume settings").unwrap_or_default())
}

#[tauri::command]
async fn get_volume() -> Volume {
    tauri::async_runtime::spawn_blocking(|| {
        apply_mic_hold(read_volume_settings(), &mut MIC_HELD.lock().unwrap())
    })
    .await
    .unwrap_or_default()
}

#[tauri::command]
async fn set_volume(app: tauri::AppHandle, output: u8) {
    let level = output.min(100);
    notch::flash(
        &app,
        "volume",
        format!("Volume {level}%"),
        Some(level as f64 / 100.0),
    );
    let _ = tauri::async_runtime::spawn_blocking(move || {
        run_osa(&format!(
            "set volume output volume {level} without output muted"
        ))
    })
    .await;
}

#[tauri::command]
async fn set_input_volume(app: tauri::AppHandle, input: u8) {
    let level = input.min(100);
    notch::flash(
        &app,
        "mic",
        format!("Mic {level}%"),
        Some(level as f64 / 100.0),
    );
    let _ = tauri::async_runtime::spawn_blocking(move || {
        *MIC_HELD.lock().unwrap() = None;
        run_osa(&format!("set volume input volume {level}"))
    })
    .await;
}

#[tauri::command]
async fn set_output_muted(app: tauri::AppHandle, muted: bool) {
    let level = tauri::async_runtime::spawn_blocking(move || {
        let verb = if muted { "with" } else { "without" };
        run_osa(&format!("set volume {verb} output muted"));
        read_volume_settings().output
    })
    .await
    .unwrap_or(0);
    flash_mute(&app, "volume", "Volume", muted, level);
}

#[tauri::command]
async fn set_input_muted(app: tauri::AppHandle, muted: bool) {
    let level = tauri::async_runtime::spawn_blocking(move || {
        let mut held = MIC_HELD.lock().unwrap();
        let read = apply_mic_hold(read_volume_settings(), &mut held);
        if let Some(target) = mic_mute_target(muted, &read, &mut held) {
            run_osa(&format!("set volume input volume {target}"));
        }
        read.input
    })
    .await
    .unwrap_or(0);
    flash_mute(&app, "mic", "Mic", muted, level);
}

fn flash_mute(app: &tauri::AppHandle, glyph: &str, name: &str, muted: bool, level: u8) {
    if muted {
        notch::flash(app, glyph, format!("{name} muted"), Some(0.0));
    } else {
        notch::flash(
            app,
            glyph,
            format!("{name} {level}%"),
            Some(level as f64 / 100.0),
        );
    }
}

// ───────────────────────── brightness (DisplayServices) ─────────────
// Private framework; linked in build.rs.
#[cfg(target_os = "macos")]
mod brightness {
    type CGDirectDisplayID = u32;
    extern "C" {
        fn CGGetOnlineDisplayList(
            max: u32,
            displays: *mut CGDirectDisplayID,
            count: *mut u32,
        ) -> i32;
        fn CGDisplayIsBuiltin(display: CGDirectDisplayID) -> u32;
        fn DisplayServicesGetBrightness(id: CGDirectDisplayID, brightness: *mut f32) -> i32;
        fn DisplayServicesSetBrightness(id: CGDirectDisplayID, brightness: f32) -> i32;
    }

    fn builtin() -> Option<CGDirectDisplayID> {
        let mut ids = [0; 16];
        let mut count = 0;
        let err = unsafe { CGGetOnlineDisplayList(ids.len() as u32, ids.as_mut_ptr(), &mut count) };
        if err != 0 {
            return None;
        }
        ids[..count as usize]
            .iter()
            .copied()
            .find(|&id| unsafe { CGDisplayIsBuiltin(id) } != 0)
    }

    pub fn get() -> Result<f32, String> {
        let id = builtin().ok_or("no built-in display is on")?;
        let mut b: f32 = 0.0;
        let err = unsafe { DisplayServicesGetBrightness(id, &mut b) };
        if err != 0 {
            return Err(format!("macOS won't read it (DisplayServices error {err})"));
        }
        Ok(b)
    }

    pub fn set(value: f32) {
        if let Some(id) = builtin() {
            unsafe {
                DisplayServicesSetBrightness(id, value.clamp(0.0, 1.0));
            }
        }
    }
}

#[tauri::command]
fn get_brightness() -> Result<f32, String> {
    #[cfg(target_os = "macos")]
    {
        brightness::get()
    }
    #[cfg(not(target_os = "macos"))]
    {
        Err("brightness needs macOS".to_string())
    }
}

#[tauri::command]
fn set_brightness(app: tauri::AppHandle, value: f32) {
    let level = value.clamp(0.0, 1.0);
    notch::flash(
        &app,
        "brightness",
        format!("Brightness {}%", (level * 100.0).round() as u8),
        Some(level as f64),
    );
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
// An NSWorkspace observer re-pushes the workspaces on every app activation, so
// the focused dot tracks the app you switched to. AeroSpace's workspace-change
// hook doesn't fire for focus moves within a workspace.

/// Edge of the rasterised app icon, in points. Bundles ship 1024² icons and
/// `TIFFRepresentation` returns the largest rep, so encoding one directly made a
/// ~1MB data URL per dot and per notch change. Nothing shows them above 24pt;
/// 64 covers that at 2x.
#[cfg(target_os = "macos")]
const ICON_PX: f64 = 64.0;

/// Encode an NSImage as a PNG data URL, redrawn at ICON_PX first (then TIFF rep
/// → bitmap rep → PNG → base64).
#[cfg(target_os = "macos")]
pub(crate) fn icon_png_data_url(img: &objc2_app_kit::NSImage) -> Option<String> {
    use objc2_app_kit::{NSBitmapImageFileType, NSBitmapImageRep, NSCompositingOperation, NSImage};
    use objc2_foundation::{NSDataBase64EncodingOptions, NSDictionary, NSPoint, NSRect, NSSize};

    let size = NSSize::new(ICON_PX, ICON_PX);
    let src: objc2::rc::Retained<NSImage> = objc2::rc::Retained::from(img);
    let handler = block2::RcBlock::new(move |rect: NSRect| {
        src.drawInRect_fromRect_operation_fraction(
            rect,
            NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(0.0, 0.0)), // whole source
            NSCompositingOperation::SourceOver,
            1.0,
        );
        objc2::runtime::Bool::YES
    });
    let scaled = NSImage::imageWithSize_flipped_drawingHandler(size, false, &handler);

    let tiff = scaled.TIFFRepresentation()?;
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
            // Main thread. Just ping the worker, so a burst (rapid cmd-tab)
            // can't spawn racing queries whose out-of-order emits leave stale
            // dots.
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

    // One worker collapses a burst of activations into a single query and
    // emit, off the main thread (query_workspaces shells out).
    let (tx, rx) = std::sync::mpsc::channel::<()>();
    let worker_app = app;
    std::thread::spawn(move || {
        while rx.recv().is_ok() {
            std::thread::sleep(std::time::Duration::from_millis(60));
            while rx.try_recv().is_ok() {}
            let _ = worker_app.emit("workspaces", workspaces_with_icons(&worker_app));
            // Focus moved: a focused-window rule's headline moves with it.
            notch::refresh_workspace(&worker_app);
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
/// the distributed centre) so Auto mode follows the system.
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

/// Push a fresh `Network` to the bar whenever reachability changes (interface
/// up/down, IP change, VPN toggle), instead of polling. Reachability only sees
/// route changes, not a dead uplink or captive portal, so `read_network()`
/// still probes for real connectivity on each change.
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
        // The callback must be `Sync`. std's `Sender` is itself `Sync` since
        // Rust 1.72, so this Mutex is no longer strictly needed.
        let tx = std::sync::Mutex::new(tx);
        if reach
            .set_callback(move |_flags| {
                let _ = tx.lock().unwrap().send(());
            })
            .is_err()
        {
            return;
        }
        // SAFETY: the mode must be a valid, non-null run-loop mode, which
        // kCFRunLoopCommonModes is.
        if unsafe { reach.schedule_with_runloop(&CFRunLoop::get_current(), kCFRunLoopCommonModes) }
            .is_err()
        {
            return;
        }
        CFRunLoop::run_current(); // blocks this thread for the app's lifetime
    });
}

// ───────────────────────── multi-monitor windows ────────────────────
// One bar and one frame per display, all rebuilt on
// NSApplicationDidChangeScreenParametersNotification (plug, unplug, rearrange,
// resolution change).

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

/// Create or reposition one bar per monitor (`bar_label(i)`, left to right),
/// cloning the tauri.conf.json "bar" window when missing, and destroy bars for
/// unplugged monitors. Main thread only. Position in logical coordinates: each
/// monitor's physical origin converted with its own scale gives global points,
/// which tao passes straight to NSWindow. Physical coordinates break mixed-DPI
/// setups, as tao converts them with the scale of whichever screen the window
/// is currently on.
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
        let placed = TRACKED_BARS.with(|bars| bars.borrow().contains_key(&label));
        let height = placed
            .then(|| {
                let px = bar.inner_size().ok()?;
                Some(px.to_logical::<f64>(bar.scale_factor().ok()?).height)
            })
            .flatten()
            .unwrap_or(window_height);
        let scale = m.scale_factor();
        let pos: LogicalPosition<f64> = m.position().to_logical(scale);
        let size: LogicalSize<f64> = m.size().to_logical(scale);
        let _ = bar.set_position(pos);
        let _ = bar.set_size(LogicalSize::new(size.width, height));
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
    let (geometry, surface) = {
        let state = app.state::<Mutex<ThemeState>>();
        let ts = state.lock().unwrap();
        let (c, _) = ts.resolve();
        (ts.geometry.clone(), c.surface)
    };
    remove_native_frames();
    let screens = NSScreen::screens(mtm);
    for screen in screens.iter() {
        create_native_frame(mtm, &screen, &geometry, &surface);
    }
    let rects = app.state::<AppState>().interactive_rects.clone();
    sync_bars_to_monitors(app, geometry.window_height, &rects);
    // Re-arm the fullscreen watcher against the new screen set: everything we
    // just built is visible, whatever the old per-screen state said.
    snapshot_screen_bounds(mtm);
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

// ───────────────────────── hide under fullscreen apps ───────────────
// Our chrome joins every space, so it draws over native-fullscreen apps.
// Collection-behaviour flags can't fix that: dropping FullScreenAuxiliary still
// shows it there, and dropping CanJoinAllSpaces hides it but pins it to one
// space. With no public "is this space fullscreen" query, poll the window list
// instead: an opaque layer-0 window covering a whole display is fullscreen
// (native, or borderless), and that display's chrome is ordered out until it
// goes.

/// How often the fullscreen check runs, and so the worst-case lag before the
/// bar returns. Each `CGWindowListCopyWindowInfo` call is ~1ms (~20 windows).
#[cfg(target_os = "macos")]
const FULLSCREEN_POLL: std::time::Duration = std::time::Duration::from_millis(500);

/// Every screen's frame in CG display coordinates (top-left origin), in
/// `NSScreen::screens` order — the space `CGWindowList` reports window bounds
/// in. Snapshotted on the main thread by `rebuild_displays` so the watcher
/// thread can compare without touching AppKit off-main.
#[cfg(target_os = "macos")]
static SCREEN_BOUNDS: Mutex<Vec<[f64; 4]>> = Mutex::new(Vec::new());

/// Per-screen hidden state as last applied, so the watcher only hops to the
/// main thread when something actually changed. Cleared alongside a screen
/// snapshot: a rebuild makes fresh (visible) windows that need re-hiding.
#[cfg(target_os = "macos")]
static FULLSCREEN_APPLIED: Mutex<Vec<bool>> = Mutex::new(Vec::new());

/// Snapshot the screen frames for the watcher thread. Main thread only.
#[cfg(target_os = "macos")]
fn snapshot_screen_bounds(mtm: objc2::MainThreadMarker) {
    use objc2_app_kit::NSScreen;

    let screens = NSScreen::screens(mtm);
    // CG measures from the top-left of the primary screen, NSScreen from each
    // screen's bottom-left. screens[0] is the primary and sits at (0, 0), so its
    // height is the whole conversion.
    let flip = screens
        .firstObject()
        .map(|s| s.frame().size.height)
        .unwrap_or(0.0);
    let bounds = screens
        .iter()
        .map(|s| {
            let f = s.frame();
            [
                f.origin.x,
                flip - (f.origin.y + f.size.height),
                f.size.width,
                f.size.height,
            ]
        })
        .collect();
    *SCREEN_BOUNDS.lock().unwrap() = bounds;
    FULLSCREEN_APPLIED.lock().unwrap().clear();
}

/// Read one CFNumber field out of a `CGWindowList` entry.
#[cfg(target_os = "macos")]
fn window_int(
    win: &objc2_core_foundation::CFDictionary,
    key: &objc2_core_foundation::CFString,
) -> Option<i32> {
    use objc2_core_foundation::{CFNumber, CFNumberType, CFString};

    let value = unsafe { win.value((key as *const CFString).cast()) } as *const CFNumber;
    let value = unsafe { value.as_ref() }?;
    let mut out: i32 = 0;
    unsafe { value.value(CFNumberType::SInt32Type, (&mut out as *mut i32).cast()) }.then_some(out)
}

/// Read one CFNumber field out of a `CGWindowList` entry as a float.
#[cfg(target_os = "macos")]
fn window_f64(
    win: &objc2_core_foundation::CFDictionary,
    key: &objc2_core_foundation::CFString,
) -> Option<f64> {
    use objc2_core_foundation::{CFNumber, CFNumberType, CFString};

    let value = unsafe { win.value((key as *const CFString).cast()) } as *const CFNumber;
    let value = unsafe { value.as_ref() }?;
    let mut out: f64 = 0.0;
    unsafe { value.value(CFNumberType::Float64Type, (&mut out as *mut f64).cast()) }.then_some(out)
}

/// Which screens are fully covered by an app window right now, in the order of
/// `bounds` (i.e. `NSScreen::screens` order). Runs off the main thread —
/// `CGWindowList` is thread-safe, and bounds/layer need no screen-recording
/// permission (only window *titles* do).
#[cfg(target_os = "macos")]
fn covered_screens(bounds: &[[f64; 4]]) -> Vec<bool> {
    use objc2_core_foundation::{CFDictionary, CFString, CGRect};
    use objc2_core_graphics::{
        kCGNullWindowID, kCGWindowAlpha, kCGWindowBounds, kCGWindowLayer,
        CGRectMakeWithDictionaryRepresentation, CGWindowListCopyWindowInfo, CGWindowListOption,
    };

    let mut covered = vec![false; bounds.len()];
    let Some(list) = CGWindowListCopyWindowInfo(
        CGWindowListOption::OptionOnScreenOnly | CGWindowListOption::ExcludeDesktopElements,
        kCGNullWindowID,
    ) else {
        return covered;
    };

    for i in 0..list.count() {
        let win = unsafe { list.value_at_index(i) } as *const CFDictionary;
        let Some(win) = (unsafe { win.as_ref() }) else {
            continue;
        };
        // Layer 0 is where ordinary app windows live. Our own bar (5) and frame
        // (6) sit above it, so they can never be read as a fullscreen app.
        if window_int(win, unsafe { kCGWindowLayer }) != Some(0) {
            continue;
        }
        // A fully transparent window occludes nothing, however big. Some apps
        // (RocketSim) park invisible display-sized windows here, and
        // `kCGWindowIsOnscreen` reports true for them.
        if window_f64(win, unsafe { kCGWindowAlpha }).is_some_and(|a| a <= 0.01) {
            continue;
        }
        let rect = unsafe { win.value((kCGWindowBounds as *const CFString).cast()) }
            as *const CFDictionary;
        let Some(rect) = (unsafe { rect.as_ref() }) else {
            continue;
        };
        let mut r = CGRect::ZERO;
        if !unsafe { CGRectMakeWithDictionaryRepresentation(Some(rect), &mut r) } {
            continue;
        }
        // Covers the screen edge to edge, menu-bar strip included. A tiled or
        // dragged window can't reach that: AeroSpace reserves the bar's height
        // as its top outer gap, and macOS won't let a normal window own the
        // menu-bar row.
        for (c, s) in covered.iter_mut().zip(bounds) {
            *c |= r.origin.x <= s[0] + 1.0
                && r.origin.y <= s[1] + 1.0
                && r.origin.x + r.size.width >= s[0] + s[2] - 1.0
                && r.origin.y + r.size.height >= s[1] + s[3] - 1.0;
        }
    }
    covered
}

/// Order a window in or out, skipping the call when it's already there.
#[cfg(target_os = "macos")]
fn set_window_hidden(window: &objc2_app_kit::NSWindow, hide: bool) {
    // Already where we want it (visible == !hide).
    if window.isVisible() != hide {
        return;
    }
    if hide {
        window.orderOut(None);
    } else {
        // Not makeKeyAndOrderFront: the bar must never steal focus.
        window.orderFrontRegardless();
    }
}

/// Show or hide each screen's frame + bar. Main thread only (AppKit).
#[cfg(target_os = "macos")]
fn apply_fullscreen_hiding(mtm: objc2::MainThreadMarker, hidden: &[bool]) {
    use objc2_app_kit::NSScreen;

    let screens = NSScreen::screens(mtm);
    if screens.len() != hidden.len() {
        // Displays changed between the snapshot and now; the rebuild takes a
        // fresh snapshot and the next tick re-applies.
        return;
    }
    // Frames are built one per screen in NSScreen order, so index == screen.
    FRAME_WINDOWS.with(|cell| {
        for (f, &hide) in cell.borrow().iter().zip(hidden) {
            set_window_hidden(&f.window, hide);
        }
    });
    // Bars are keyed by monitor, which isn't NSScreen order — match each one to
    // the screen its origin sits on. `frame` survives orderOut, so a hidden bar
    // still finds its screen when it's time to come back.
    TRACKED_BARS.with(|bars| {
        for win in bars.borrow().values() {
            let o = win.frame().origin;
            let on = screens.iter().position(|s| {
                let f = s.frame();
                o.x >= f.origin.x
                    && o.x < f.origin.x + f.size.width
                    && o.y >= f.origin.y
                    && o.y < f.origin.y + f.size.height
            });
            if let Some(&hide) = on.and_then(|i| hidden.get(i)) {
                set_window_hidden(win, hide);
            }
        }
    });
}

/// Poll for fullscreen apps and keep each display's chrome hidden while one is
/// up. Off-thread; only hops to main when the answer changes.
#[cfg(target_os = "macos")]
fn install_fullscreen_watcher(app: tauri::AppHandle) {
    std::thread::spawn(move || loop {
        std::thread::sleep(FULLSCREEN_POLL);
        let bounds = SCREEN_BOUNDS.lock().unwrap().clone();
        if bounds.is_empty() {
            continue;
        }
        let hidden = covered_screens(&bounds);
        {
            let mut applied = FULLSCREEN_APPLIED.lock().unwrap();
            if *applied == hidden {
                continue;
            }
            applied.clone_from(&hidden);
        }
        let _ = app.run_on_main_thread(move || {
            if let Some(mtm) = objc2::MainThreadMarker::new() {
                apply_fullscreen_hiding(mtm, &hidden);
            }
        });
    });
}

/// Bind `name` in edgebar's cache folder, replacing a socket a previous run
/// left behind.
pub(crate) fn listen(name: &str) -> Option<std::os::unix::net::UnixListener> {
    let dir = settings::cache_dir()?;
    let _ = std::fs::create_dir_all(&dir);
    let sock = dir.join(name);
    let _ = std::fs::remove_file(&sock);
    std::os::unix::net::UnixListener::bind(&sock).ok()
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
            set_ink,
            pick_colour,
            battery,
            metrics::metrics_sample,
            metrics::cpu_state,
            metrics::metrics_history,
            get_volume,
            set_volume,
            set_input_volume,
            set_output_muted,
            set_input_muted,
            get_brightness,
            set_brightness,
            network,
            launcher_action,
            open_settings_pane,
            set_interactive_rects,
            list_wallpapers,
            current_wallpaper,
            set_wallpaper,
            pick_wallpaper_file,
            pick_folder,
            set_scheme,
            precompute_palettes,
            notch::notch_state,
            notch::media_state,
            notch::media_art,
            notch::media_toggle,
            notch::media_next,
            notch::media_previous,
            notch::media_seek,
            settings::get_settings,
            settings::set_setting,
            settings::settings_files,
            settings::open_settings_file,
            setup::setup_status,
            setup::setup_run,
            notifications::notification_history,
            notifications::notification_dismiss,
            notifications::notification_clear,
            toggles::toggles,
            toggles::set_toggle,
            assistant::assistant_send,
            assistant::assistant_cancel,
            assistant::assistant_reset,
            assistant::assistant_open_link,
            keyboard::take_keyboard,
            keyboard::release_keyboard,
            #[cfg(all(debug_assertions, target_os = "macos"))]
            devtools::dev_result
        ])
        .setup(|app| {
            if let Some(dir) = settings::dir() {
                if let Err(why) = settings::import_legacy_appearance(&dir) {
                    eprintln!("edgebar: the old appearance file was not imported: {why}");
                }
            }
            let loaded = settings::load(settings::dir().as_deref());
            let config = loaded.config.clone();
            app.manage(settings::Store::new(loaded));
            app.manage(keyboard::Keyboard::default());
            let palettes = load_palettes();
            let appearance = config.appearance;
            let scheme = resolve_scheme(appearance);

            // Accessory app: no Dock icon and never the active app, so showing
            // or clicking the bar doesn't steal focus from the frontmost app.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            let interactive_rects: RectMap = Default::default();

            // AppState and ThemeState go in before rebuild_displays, which
            // reads both.
            app.manage(AppState {
                sys: Mutex::new(sysinfo::System::new()),
                icon_cache: Mutex::new(std::collections::HashMap::new()),
                thumb_cache: Mutex::new(std::collections::HashMap::new()),
                interactive_rects: interactive_rects.clone(),
            });
            metrics::install(app.handle().clone());
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
                notch_idle: resolve_notch_idle(config.notch.idle.as_deref()),
                ink: load_ink_override(),
                oled: config.oled,
            }));
            // The notch store, managed before the workspace socket below, which
            // publishes into it.
            app.manage(notch::NotchState::new(config.notch));
            app.manage(toggles::Toggles::new(config.toggles));
            app.manage(assistant::AssistantState::default());
            app.manage(setup::Setup::default());

            // Per-display chrome, rebuilt on every display-config change.
            #[cfg(target_os = "macos")]
            {
                install_cursor_monitors(interactive_rects.clone());
                rebuild_displays(app.handle());
                install_screen_observer(app.handle().clone());
                // Get out of the way of fullscreen apps (see FULLSCREEN_POLL).
                install_fullscreen_watcher(app.handle().clone());
            }
            #[cfg(not(target_os = "macos"))]
            if let Some(bar) = app.get_webview_window("bar") {
                let _ = bar.show();
            }

            // Workspace updates: AeroSpace's exec-on-workspace-change pings this
            // unix socket. The accept loop only accepts and drops (so the nc
            // client exits at once) and pings a debounced worker that runs the
            // query, so a wedged query can't back clients up in the listen
            // backlog.
            let ws_handle = app.handle().clone();
            std::thread::spawn(move || {
                let Some(listener) = listen("ws.sock") else {
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
                        notch::refresh_workspace(&query_handle);
                    }
                });
                for conn in listener.incoming() {
                    drop(conn); // a connection is just a "something changed" ping
                    let _ = tx.send(());
                }
            });

            // Theme reload: `generate-edgebar-theme` writes a new palette.json
            // and pings this socket; each ping reloads and re-themes live. Same
            // socket setup as ws.sock, but the reload runs inline (no debounce).
            let theme_handle = app.handle().clone();
            std::thread::spawn(move || {
                let Some(listener) = listen("theme.sock") else {
                    return;
                };
                for conn in listener.incoming() {
                    if conn.is_err() {
                        continue;
                    }
                    reload_theme(&theme_handle);
                }
            });

            wallpapers::spawn_converge(app.handle());

            // Re-push workspaces on every app activation.
            #[cfg(target_os = "macos")]
            install_front_app_observer(app.handle().clone());

            // Follow the system light/dark setting while in Auto mode.
            #[cfg(target_os = "macos")]
            install_appearance_observer(app.handle().clone());

            // Event-driven network updates.
            #[cfg(target_os = "macos")]
            install_network_observer(app.handle().clone());

            // Notch providers: what's making noise, and the focused workspace's
            // rule (seeded once here, then re-run on every workspace/focus event).
            notch::install_media_watcher(app.handle().clone());
            notch::install_rule_ticker(app.handle().clone());
            let seed = app.handle().clone();
            std::thread::spawn(move || notch::refresh_workspace(&seed));

            #[cfg(all(debug_assertions, target_os = "macos"))]
            devtools::start(app);

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod output_within_tests {
    use super::*;
    use std::process::Command;
    use std::time::{Duration, Instant};

    fn sh(script: &str) -> Command {
        let mut cmd = Command::new("/bin/sh");
        cmd.args(["-c", script]);
        cmd
    }

    #[test]
    fn a_command_that_finishes_reports_its_status_and_output() {
        let Some(Ran::Exited(status, text)) =
            output_within(sh("echo hi; exit 3"), Duration::from_secs(5))
        else {
            panic!("the command should have exited");
        };
        assert_eq!((status.code(), text.as_str()), (Some(3), "hi\n"));
    }

    #[test]
    fn a_command_past_its_limit_is_killed_and_keeps_what_it_printed() {
        let started = Instant::now();
        let Some(Ran::Killed(text)) = output_within(
            sh("echo started; exec sleep 30"),
            Duration::from_millis(200),
        ) else {
            panic!("the command should have been killed");
        };
        assert_eq!(text, "started\n");
        assert!(started.elapsed() < Duration::from_secs(5));
    }

    #[test]
    fn a_command_that_cannot_start_is_none() {
        let missing = Command::new("/nonexistent/edgebar-tool");
        assert!(output_within(missing, Duration::from_secs(1)).is_none());
    }
}

#[cfg(test)]
mod volume_tests {
    use super::*;

    #[test]
    fn parses_the_volume_settings_reply() {
        assert_eq!(
            parse_volume_settings(
                "output volume:62, input volume:100, alert volume:100, output muted:true"
            ),
            Volume {
                output: 62,
                input: 100,
                output_muted: true,
                input_muted: false,
            }
        );
        assert_eq!(
            parse_volume_settings(
                "output volume:missing value, input volume:40, alert volume:100, output muted:missing value"
            ),
            Volume {
                output: 0,
                input: 40,
                output_muted: false,
                input_muted: false,
            }
        );
    }

    fn mic(input: u8) -> Volume {
        Volume {
            output: 50,
            input,
            ..Volume::default()
        }
    }

    #[test]
    fn a_muted_mic_reports_the_level_it_will_restore() {
        let mut held = Some(70);
        let read = apply_mic_hold(mic(0), &mut held);
        assert_eq!((read.input, read.input_muted, held), (70, true, Some(70)));
    }

    #[test]
    fn a_level_set_elsewhere_ends_the_mute() {
        let mut held = Some(70);
        let read = apply_mic_hold(mic(30), &mut held);
        assert_eq!((read.input, read.input_muted, held), (30, false, None));
    }

    #[test]
    fn muting_holds_the_level_and_unmuting_restores_it() {
        let mut held = None;
        let read = apply_mic_hold(mic(55), &mut held);
        assert_eq!(mic_mute_target(true, &read, &mut held), Some(0));
        assert_eq!(held, Some(55));

        let read = apply_mic_hold(mic(0), &mut held);
        assert_eq!(mic_mute_target(true, &read, &mut held), None);
        assert_eq!(mic_mute_target(false, &read, &mut held), Some(55));
        assert_eq!(held, None);
        assert_eq!(mic_mute_target(false, &mic(55), &mut held), None);
    }
}
