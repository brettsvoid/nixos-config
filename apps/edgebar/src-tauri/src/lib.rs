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

/// Single source of truth for colors + geometry, read by both the native frame
/// (Rust) and the bar WebView (applied as CSS custom properties). Loaded from
/// `~/.config/edgebar/config.json` if present, else the bundled default.
#[derive(Clone, Deserialize, Serialize)]
struct Config {
    /// Named colors (e.g. Catppuccin Mocha). Color fields below may reference
    /// these by name; anything starting with '#' is treated as a literal hex.
    #[serde(default)]
    palette: std::collections::HashMap<String, String>,
    colors: Colors,
    geometry: Geometry,
}

impl Config {
    /// Resolve every color field: palette name -> hex (literal hex passes through).
    fn resolved(mut self) -> Self {
        let palette = self.palette.clone();
        let resolve = |v: &str| -> String {
            if v.starts_with('#') {
                v.to_string()
            } else {
                palette.get(v).cloned().unwrap_or_else(|| v.to_string())
            }
        };
        let c = &mut self.colors;
        c.base = resolve(&c.base);
        c.pill_bg = resolve(&c.pill_bg);
        c.text = resolve(&c.text);
        c.subtext = resolve(&c.subtext);
        c.accent = resolve(&c.accent);
        c.occupied = resolve(&c.occupied);
        c.empty = resolve(&c.empty);
        c.frame_line = resolve(&c.frame_line);
        c.frame_corner = resolve(&c.frame_corner);
        self
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
    frame_line: String,
    frame_corner: String,
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Geometry {
    inner_radius: f64,
    line_thickness: f64,
    pill_height: f64,
    pill_radius: f64,
    concave: f64,
}

fn load_config() -> Config {
    const DEFAULT: &str = include_str!("../config.default.json");
    let raw: Config = std::env::var_os("HOME")
        .map(|home| std::path::Path::new(&home).join(".config/edgebar/config.json"))
        .and_then(|path| std::fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| {
            serde_json::from_str(DEFAULT).expect("bundled config.default.json is valid")
        });
    raw.resolved()
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
fn get_config(config: tauri::State<Config>) -> Config {
    config.inner().clone()
}

/// Height (logical px) of the interactive top strip. Kept small so it only
/// covers the area AeroSpace already reserves for the bar.
const BAR_HEIGHT: f64 = 64.0;

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

// Commands are `async` so the IPC layer runs them off the main thread, and the
// blocking subprocess work goes through `spawn_blocking` — a sync command would
// run the `aerospace` calls on the main thread and beach-ball the UI.
/// Create the screen frame as a native borderless NSWindow drawn with CALayer —
/// no WebView, so it costs no web-content process. Replicates the old CSS frame:
/// a green rounded-rect line hugging the screen edge (root layer cornerRadius +
/// border) plus black fills in the four corner notches outside that rounded rect
/// (an even-odd CAShapeLayer). Click-through, all-spaces, stationary.
#[cfg(target_os = "macos")]
fn create_native_frame(cfg: &Config) {
    use objc2::{MainThreadMarker, MainThreadOnly};
    use objc2_app_kit::{
        NSBackingStoreType, NSBezierPath, NSColor, NSScreen, NSWindow,
        NSWindowCollectionBehavior, NSWindowStyleMask, NSWindingRule,
    };
    use objc2_core_foundation::{CGPoint, CGRect, CGSize};
    use objc2_quartz_core::{kCAFillRuleEvenOdd, CAShapeLayer};

    // Look comes from the shared config (config.json).
    let radius = cfg.geometry.inner_radius;
    let line = cfg.geometry.line_thickness;
    let line_rgba = hex_to_rgba(&cfg.colors.frame_line);
    let corner_rgba = hex_to_rgba(&cfg.colors.frame_corner);

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
    let Some(layer) = view.layer() else {
        return;
    };

    let bounds = CGRect::new(
        CGPoint::new(0.0, 0.0),
        CGSize::new(frame.size.width, frame.size.height),
    );
    let line_color = NSColor::colorWithSRGBRed_green_blue_alpha(
        line_rgba[0], line_rgba[1], line_rgba[2], line_rgba[3],
    );
    let corner_color = NSColor::colorWithSRGBRed_green_blue_alpha(
        corner_rgba[0], corner_rgba[1], corner_rgba[2], corner_rgba[3],
    );

    // root layer = the rounded-rect edge line
    layer.setFrame(bounds);
    layer.setBackgroundColor(Some(&NSColor::clearColor().CGColor()));
    layer.setCornerRadius(radius);
    layer.setBorderWidth(line);
    layer.setBorderColor(Some(&line_color.CGColor()));
    layer.setMasksToBounds(false);

    // black corner fills = full rect minus the rounded interior (even-odd)
    let path = NSBezierPath::bezierPath();
    path.appendBezierPathWithRect(bounds);
    path.appendBezierPathWithRoundedRect_xRadius_yRadius(bounds, radius, radius);
    path.setWindingRule(NSWindingRule::EvenOdd);

    let corners = CAShapeLayer::new();
    corners.setFrame(bounds);
    corners.setPath(Some(&path.CGPath()));
    corners.setFillRule(unsafe { kCAFillRuleEvenOdd });
    corners.setFillColor(Some(&corner_color.CGColor()));
    layer.addSublayer(&corners);

    window.orderFrontRegardless();
    std::mem::forget(window); // keep it alive for the app's lifetime
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            aerospace_workspaces,
            aerospace_focus,
            set_bar_size,
            get_config,
            battery,
            metrics_sample,
            get_volume,
            set_volume,
            set_input_volume,
            get_brightness,
            set_brightness,
            network,
            launcher_action
        ])
        .setup(|app| {
            // Shared config (colors + geometry) — drives both the native frame
            // and the WebView (which fetches it via get_config and applies CSS vars).
            let config = load_config();

            // Accessory app: no Dock icon, never becomes the active app, so it
            // never steals focus or bounces you back to the previously-active
            // app (e.g. Arc) when its windows are shown or touched.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Frame: a native borderless NSWindow drawn with CALayer — no
            // WebView, so it costs no extra web-content process.
            #[cfg(target_os = "macos")]
            create_native_frame(&config);

            // Bar: full-width strip pinned to the top, normally interactive.
            if let Some(bar) = app.get_webview_window("bar") {
                if let Ok(Some(m)) = bar.current_monitor() {
                    let pos = *m.position();
                    let size = *m.size();
                    let scale = bar.scale_factor().unwrap_or(1.0);
                    let h = (BAR_HEIGHT * scale).round() as u32;
                    let _ = bar.set_position(PhysicalPosition::new(pos.x, pos.y));
                    let _ = bar.set_size(PhysicalSize::new(size.width, h));
                }
                let _ = bar.set_always_on_top(true);
                let _ = bar.set_visible_on_all_workspaces(true);
                #[cfg(target_os = "macos")]
                make_overlay(&bar);
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

            // Metrics state + app-icon cache. The NSWorkspace observer re-pushes
            // workspaces on every app activation so the focused dot stays current.
            app.manage(AppState {
                sys: Mutex::new(sysinfo::System::new()),
                icon_cache: Mutex::new(std::collections::HashMap::new()),
            });
            #[cfg(target_os = "macos")]
            install_front_app_observer(app.handle().clone());

            // Expose the config to the WebView (get_config).
            app.manage(config);

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
