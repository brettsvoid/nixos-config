//! Debug-only developer socket: lets an agent drive and see the live bar
//! without screen-recording permission (`screencapture` needs it; nothing here
//! does).
//!
//! `~/.cache/edgebar/dev.sock` takes one request per connection, read to EOF,
//! and answers with one line on the same connection:
//!
//!   * `eval <js>` runs `<js>` in the main bar WebView (label `bar`) and replies
//!     with the JSON of what it evaluates to, promises awaited.
//!   * `snap <abs-path.png>` writes the main display as edgebar draws it (see
//!     `start_snap`) and replies `ok <path>`.
//!
//! Failures reply `ERR <message>`. `scripts/dev.sh` is the client.

use serde::Deserialize;
use std::cell::RefCell;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{self, Sender};
use std::sync::Mutex;
use std::time::Duration;

use objc2::rc::Retained;
use objc2::{AllocAnyThread, MainThreadMarker};
use objc2_app_kit::{NSBitmapImageFileType, NSBitmapImageRep, NSImage, NSScreen, NSWindow};
use objc2_core_foundation::{CFRetained, CGPoint, CGRect, CGSize};
use objc2_core_graphics::{
    kCGColorSpaceSRGB, CGBitmapContextCreate, CGBitmapContextCreateImage, CGColorSpace, CGContext,
    CGImage, CGImageAlphaInfo, CGRectIntersectsRect,
};
use objc2_foundation::{NSDictionary, NSError};
use objc2_quartz_core::CALayer;
use objc2_web_kit::WKWebView;
use tauri::{AppHandle, Manager};

/// How long a request may take (reading it, the page's answer, the snapshot)
/// before it fails.
const TIMEOUT: Duration = Duration::from_secs(5);

/// A request's answer: the reply line, or the message after `ERR `.
type Reply = Result<String, String>;

/// One parsed request.
enum Request {
    Eval(String),
    Snap(PathBuf),
}

impl Request {
    fn parse(text: &str) -> Result<Self, String> {
        let text = text.strip_suffix('\n').unwrap_or(text);
        let (verb, arg) = text.split_once(' ').unwrap_or((text, ""));
        match verb {
            "eval" if !arg.trim().is_empty() => Ok(Request::Eval(arg.to_string())),
            "snap" => {
                let path = PathBuf::from(arg.trim());
                if !path.is_absolute() || path.extension().is_none_or(|e| e != "png") {
                    return Err(format!("snap wants an absolute .png path, got {arg:?}"));
                }
                Ok(Request::Snap(path))
            }
            _ => Err("want `eval <js>` or `snap <abs-path.png>`".to_string()),
        }
    }
}

/// Evals waiting for their page to answer through `dev_result`, keyed by id.
#[derive(Default)]
pub struct Evals {
    next_id: AtomicU64,
    waiting: Mutex<HashMap<u64, Sender<Reply>>>,
}

/// What the page reports for one eval: the value's JSON, or the error thrown.
#[derive(Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Outcome {
    Ok(String),
    Err(String),
}

/// The bar WebView's answer to an `eval`, posted by the wrapper `eval` sends.
/// An answer after its eval timed out finds no waiter and is dropped.
#[tauri::command]
pub fn dev_result(evals: tauri::State<Evals>, id: u64, outcome: Outcome) {
    let Some(tx) = evals.waiting.lock().unwrap().remove(&id) else {
        return;
    };
    let _ = tx.send(match outcome {
        Outcome::Ok(json) => Ok(json),
        Outcome::Err(message) => Err(message),
    });
}

/// Bind `~/.cache/edgebar/dev.sock` and serve it on its own thread, one
/// connection at a time.
pub fn start(app: &tauri::App) {
    app.manage(Evals::default());
    let handle = app.handle().clone();
    std::thread::spawn(move || {
        let Some(home) = std::env::var_os("HOME") else {
            return;
        };
        let dir = Path::new(&home).join(".cache/edgebar");
        let _ = std::fs::create_dir_all(&dir);
        let sock = dir.join("dev.sock");
        let _ = std::fs::remove_file(&sock); // clear any stale socket
        let Ok(listener) = UnixListener::bind(&sock) else {
            return;
        };
        for mut conn in listener.incoming().flatten() {
            serve(&handle, &mut conn);
        }
    });
}

/// Read one request to EOF, run it, write the reply line.
fn serve(app: &AppHandle, conn: &mut UnixStream) {
    let _ = conn.set_read_timeout(Some(TIMEOUT));
    let mut text = String::new();
    let reply = match conn.read_to_string(&mut text) {
        Ok(_) => Request::parse(&text).and_then(|request| match request {
            Request::Eval(js) => eval(app, &js),
            Request::Snap(path) => snap(app, path),
        }),
        Err(e) => Err(format!("reading the request: {e}")),
    };
    let line = reply.unwrap_or_else(|e| format!("ERR {e}"));
    let _ = writeln!(conn, "{line}");
}

/// Wraps an eval so the page answers through `dev_result` whatever happens.
/// The source goes in as a string for indirect `eval`, so a syntax error
/// becomes a catchable SyntaxError rather than a script that never answers.
const EVAL_WRAPPER: &str = r#"(async () => {
  let outcome;
  try {
    outcome = { ok: JSON.stringify(await (0, eval)(__SRC__)) ?? "undefined" };
  } catch (e) {
    outcome = { err: String(e) };
  }
  await window.__TAURI_INTERNALS__.invoke("dev_result", { id: __ID__, outcome });
})();"#;

/// Run `js` in the main bar WebView and wait for its answer.
fn eval(app: &AppHandle, js: &str) -> Reply {
    let Some(bar) = app.get_webview_window("bar") else {
        return Err("no bar window".to_string());
    };
    let evals = app.state::<Evals>();
    let id = evals.next_id.fetch_add(1, Ordering::Relaxed);
    let (tx, rx) = mpsc::channel();
    evals.waiting.lock().unwrap().insert(id, tx);
    let script = EVAL_WRAPPER
        .replace("__SRC__", &serde_json::to_string(js).unwrap_or_default())
        .replace("__ID__", &id.to_string());
    let reply = match bar.eval(script) {
        Ok(()) => rx
            .recv_timeout(TIMEOUT)
            .unwrap_or_else(|_| Err(format!("no answer within {}s", TIMEOUT.as_secs()))),
        Err(e) => Err(format!("eval: {e}")),
    };
    evals.waiting.lock().unwrap().remove(&id);
    reply
}

/// Hop to the main thread for the snapshot and wait for it.
fn snap(app: &AppHandle, path: PathBuf) -> Reply {
    let (tx, rx) = mpsc::channel();
    let handle = app.clone();
    app.run_on_main_thread(move || start_snap(&handle, path, tx))
        .map_err(|e| format!("main thread: {e}"))?;
    rx.recv_timeout(TIMEOUT)
        .unwrap_or_else(|_| Err(format!("no snapshot within {}s", TIMEOUT.as_secs())))
}

/// One edgebar window's pixels, placed in global screen points (bottom-left
/// origin). `image` is None while its WebView snapshot is in flight, or once
/// it has failed to render.
struct Plane {
    level: isize,
    rect: CGRect,
    image: Option<CFRetained<CGImage>>,
}

/// A snapshot waiting on its WebViews.
struct Snap {
    screen: CGRect,
    scale: f64,
    planes: Vec<Plane>,
    in_flight: usize,
    path: PathBuf,
    reply: Sender<Reply>,
}

/// Composite the main display (the primary, `NSScreen::screens()[0]`) at its
/// backing scale: a mid-grey stand-in for the wallpaper, then every visible
/// edgebar window on it in level order. Native frames are drawn from their
/// layer trees here; bar WebViews snapshot asynchronously, and the last one in
/// writes the PNG. Main thread only.
fn start_snap(app: &AppHandle, path: PathBuf, reply: Sender<Reply>) {
    let Some(mtm) = MainThreadMarker::new() else {
        let _ = reply.send(Err("not on the main thread".to_string()));
        return;
    };
    let Some(screen) = NSScreen::screens(mtm).firstObject() else {
        let _ = reply.send(Err("no screen".to_string()));
        return;
    };
    let screen_rect = screen.frame();
    let scale = screen.backingScaleFactor();
    let shown = |w: &NSWindow| w.isVisible() && CGRectIntersectsRect(w.frame(), screen_rect);

    let mut planes = Vec::new();
    super::FRAME_WINDOWS.with(|cell| {
        for f in cell.borrow().iter().filter(|f| shown(&f.window)) {
            let rect = f.window.frame();
            let layer = f.window.contentView().and_then(|v| v.layer());
            planes.push(Plane {
                level: f.window.level(),
                rect,
                image: layer.and_then(|l| render_layer(&l, rect.size, scale)),
            });
        }
    });
    let mut webviews = Vec::new();
    for window in app.webview_windows().values() {
        let Some(ns_window) = window
            .ns_window()
            .ok()
            .and_then(|p| unsafe { Retained::retain(p as *mut NSWindow) })
        else {
            continue;
        };
        if !shown(&ns_window) {
            continue;
        }
        let level = ns_window.level();
        let Some(wk) = wk_webview(window) else {
            planes.push(Plane {
                level,
                rect: ns_window.frame(),
                image: None,
            });
            continue;
        };
        let rect = ns_window.convertRectToScreen(wk.convertRect_toView(wk.bounds(), None));
        webviews.push((planes.len(), wk));
        planes.push(Plane {
            level,
            rect,
            image: None,
        });
    }

    let job = Rc::new(RefCell::new(Snap {
        screen: screen_rect,
        scale,
        planes,
        in_flight: webviews.len(),
        path,
        reply,
    }));
    if webviews.is_empty() {
        finish(&job.borrow());
    }
    for (i, wk) in webviews {
        let job = job.clone();
        snapshot_webview(&wk, move |image| {
            let mut job = job.borrow_mut();
            job.planes[i].image = image;
            job.in_flight -= 1;
            if job.in_flight == 0 {
                finish(&job);
            }
        });
    }
}

/// Composite, encode and write the PNG, then send the reply.
fn finish(job: &Snap) {
    let reply = compose(job)
        .and_then(|image| write_png(&image, &job.path))
        .map(|()| format!("ok {}", job.path.display()));
    let _ = job.reply.send(reply);
}

/// The display as one image: grey backdrop, then each plane in window-level
/// order. Fails if any window did not render, rather than leave it out.
fn compose(job: &Snap) -> Result<CFRetained<CGImage>, String> {
    let mut planes: Vec<&Plane> = job.planes.iter().collect();
    planes.sort_by_key(|p| p.level);
    let ctx = bitmap(job.screen.size, job.scale).ok_or("no bitmap context")?;
    CGContext::set_rgb_fill_color(Some(&ctx), 0.5, 0.5, 0.5, 1.0);
    CGContext::fill_rect(
        Some(&ctx),
        CGRect::new(CGPoint::new(0.0, 0.0), job.screen.size),
    );
    CGContext::translate_ctm(Some(&ctx), -job.screen.origin.x, -job.screen.origin.y);
    for p in planes {
        let Some(image) = p.image.as_deref() else {
            return Err(format!("a level {} window did not render", p.level));
        };
        CGContext::draw_image(Some(&ctx), p.rect, Some(image));
    }
    CGBitmapContextCreateImage(Some(&ctx)).ok_or_else(|| "compositing failed".to_string())
}

/// A transparent sRGB bitmap context of `size` points at `scale` pixels per
/// point, its CTM in points.
fn bitmap(size: CGSize, scale: f64) -> Option<CFRetained<CGContext>> {
    let space = CGColorSpace::with_name(Some(unsafe { kCGColorSpaceSRGB }))?;
    let ctx = unsafe {
        CGBitmapContextCreate(
            std::ptr::null_mut(),
            (size.width * scale).round() as usize,
            (size.height * scale).round() as usize,
            8,
            0,
            Some(&space),
            CGImageAlphaInfo::PremultipliedLast.0,
        )
    }?;
    CGContext::scale_ctm(Some(&ctx), scale, scale);
    Some(ctx)
}

/// Render a layer tree (a native frame) into an image of `size` points.
fn render_layer(layer: &CALayer, size: CGSize, scale: f64) -> Option<CFRetained<CGImage>> {
    let ctx = bitmap(size, scale)?;
    layer.renderInContext(&ctx);
    CGBitmapContextCreateImage(Some(&ctx))
}

/// The WKWebView behind a Tauri window. `with_webview` runs its closure inline
/// when called on the main thread, so the pointer is waiting in the channel by
/// the time it returns.
fn wk_webview(window: &tauri::WebviewWindow) -> Option<Retained<WKWebView>> {
    let (tx, rx) = mpsc::channel();
    window
        .with_webview(move |wv| {
            let _ = tx.send(wv.inner() as usize);
        })
        .ok()?;
    let ptr = rx.try_recv().ok()? as *mut WKWebView;
    unsafe { Retained::retain(ptr) }
}

/// Snapshot a WebView's visible bounds, calling `done` on the main thread with
/// the image (None if WebKit fails).
fn snapshot_webview(wk: &WKWebView, done: impl Fn(Option<CFRetained<CGImage>>) + 'static) {
    let block = block2::RcBlock::new(move |image: *mut NSImage, _error: *mut NSError| {
        let image = unsafe { image.as_ref() }.and_then(|image| unsafe {
            image.CGImageForProposedRect_context_hints(std::ptr::null_mut(), None, None)
        });
        done(image.map(CFRetained::from));
    });
    unsafe { wk.takeSnapshotWithConfiguration_completionHandler(None, &block) };
}

/// Encode as PNG and write to `path`.
fn write_png(image: &CGImage, path: &Path) -> Result<(), String> {
    let rep = NSBitmapImageRep::initWithCGImage(NSBitmapImageRep::alloc(), image);
    let png = unsafe {
        rep.representationUsingType_properties(NSBitmapImageFileType::PNG, &NSDictionary::new())
    }
    .ok_or_else(|| "PNG encoding failed".to_string())?;
    std::fs::write(path, png.to_vec()).map_err(|e| format!("{}: {e}", path.display()))
}
