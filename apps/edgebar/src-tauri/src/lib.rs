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

use serde::Serialize;
use tauri::{Emitter, Manager, PhysicalPosition, PhysicalSize};

/// Height (logical px) of the interactive top strip. Kept small so it only
/// covers the area AeroSpace already reserves for the bar.
const BAR_HEIGHT: f64 = 64.0;

#[derive(Clone, Serialize)]
struct Workspace {
    name: String,
    focused: bool,
    has_windows: bool,
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
fn query_workspaces() -> Vec<Workspace> {
    let rows = aerospace(&[
        "list-workspaces",
        "--all",
        "--format",
        "%{workspace}|%{workspace-is-focused}",
    ]);
    let non_empty = aerospace(&["list-workspaces", "--monitor", "all", "--empty", "no"]);

    rows.into_iter()
        .filter_map(|row| {
            let mut parts = row.splitn(2, '|');
            let name = parts.next()?.to_string();
            let focused = parts.next() == Some("true");
            Some(Workspace {
                has_windows: non_empty.contains(&name),
                focused,
                name,
            })
        })
        .collect()
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
fn create_native_frame() {
    use objc2::{MainThreadMarker, MainThreadOnly};
    use objc2_app_kit::{
        NSBackingStoreType, NSBezierPath, NSColor, NSFloatingWindowLevel, NSScreen, NSWindow,
        NSWindowCollectionBehavior, NSWindowStyleMask, NSWindingRule,
    };
    use objc2_core_foundation::{CGPoint, CGRect, CGSize};
    use objc2_quartz_core::{kCAFillRuleEvenOdd, CAShapeLayer};

    // Frame look — edit here (until the shared config lands). RGBA in 0..1.
    const RADIUS: f64 = 20.0; // interior corner radius
    const LINE: f64 = 4.0; // edge line thickness
    const LINE_RGBA: [f64; 4] = [0.651, 0.890, 0.631, 1.0]; // #a6e3a1 edge line
    const CORNER_RGBA: [f64; 4] = [0.0, 0.0, 0.0, 1.0]; // filled screen corners

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
    window.setLevel(NSFloatingWindowLevel);
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
        LINE_RGBA[0], LINE_RGBA[1], LINE_RGBA[2], LINE_RGBA[3],
    );
    let corner_color = NSColor::colorWithSRGBRed_green_blue_alpha(
        CORNER_RGBA[0], CORNER_RGBA[1], CORNER_RGBA[2], CORNER_RGBA[3],
    );

    // root layer = the rounded-rect edge line
    layer.setFrame(bounds);
    layer.setBackgroundColor(Some(&NSColor::clearColor().CGColor()));
    layer.setCornerRadius(RADIUS);
    layer.setBorderWidth(LINE);
    layer.setBorderColor(Some(&line_color.CGColor()));
    layer.setMasksToBounds(false);

    // black corner fills = full rect minus the rounded interior (even-odd)
    let path = NSBezierPath::bezierPath();
    path.appendBezierPathWithRect(bounds);
    path.appendBezierPathWithRoundedRect_xRadius_yRadius(bounds, RADIUS, RADIUS);
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

#[tauri::command]
async fn aerospace_workspaces() -> Vec<Workspace> {
    tauri::async_runtime::spawn_blocking(query_workspaces)
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            aerospace_workspaces,
            aerospace_focus,
            set_bar_size
        ])
        .setup(|app| {
            // Accessory app: no Dock icon, never becomes the active app, so it
            // never steals focus or bounces you back to the previously-active
            // app (e.g. Arc) when its windows are shown or touched.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Frame: a native borderless NSWindow drawn with CALayer — no
            // WebView, so it costs no extra web-content process.
            #[cfg(target_os = "macos")]
            create_native_frame();

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
                    let _ = ws_handle.emit("workspaces", query_workspaces());
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
