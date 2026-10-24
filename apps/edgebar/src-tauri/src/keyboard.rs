//! Typing into the open notch.
//!
//! The bar windows never take the keyboard on their own: tauri.conf.json makes
//! them unfocusable, so showing or clicking the bar leaves typing with the app
//! in front. A view with a text field takes the keyboard while the notch is
//! open: its bar window becomes focusable and key, which makes edgebar the
//! active app. Releasing makes every bar unfocusable again and, if edgebar is
//! still the active app, hands it back to the app that was in front.

use std::sync::Mutex;
use tauri::{AppHandle, Manager, WebviewWindow};

/// Set while edgebar holds the keyboard.
#[derive(Default)]
pub struct Keyboard(Mutex<Option<Held>>);

struct Held {
    /// The app that was in front when the keyboard was taken, to hand it back
    /// to; None when there was none but edgebar.
    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    previous: Option<i32>,
}

/// Make the calling bar window key, so its focused field gets what is typed.
/// Taking it again while held keeps the app to hand back to.
#[tauri::command]
pub fn take_keyboard(app: AppHandle, window: WebviewWindow) {
    let handle = app.clone();
    let _ = app.run_on_main_thread(move || {
        let state = handle.state::<Keyboard>();
        let mut held = state.0.lock().unwrap();
        if held.is_none() {
            *held = Some(Held {
                previous: front_app(),
            });
        }
        let _ = window.set_focusable(true);
        let _ = window.set_focus();
    });
}

/// Give the keyboard back. Safe to call when it isn't held: it still makes
/// every bar unfocusable, so a reloaded WebView can't leave one able to take
/// focus.
#[tauri::command]
pub fn release_keyboard(app: AppHandle) {
    let handle = app.clone();
    let _ = app.run_on_main_thread(move || {
        for window in handle.webview_windows().values() {
            let _ = window.set_focusable(false);
        }
        let held = handle.state::<Keyboard>().0.lock().unwrap().take();
        if let Some(held) = held {
            hand_back(held);
        }
    });
}

/// The frontmost app's pid, unless it is edgebar.
#[cfg(target_os = "macos")]
fn front_app() -> Option<i32> {
    let me = std::process::id() as i32;
    objc2_app_kit::NSWorkspace::sharedWorkspace()
        .frontmostApplication()
        .map(|app| app.processIdentifier())
        .filter(|&pid| pid != me)
}

#[cfg(not(target_os = "macos"))]
fn front_app() -> Option<i32> {
    None
}

/// Re-activate the app that was in front. Only while edgebar is still active:
/// a user who has clicked into another app since keeps it.
#[cfg(target_os = "macos")]
fn hand_back(held: Held) {
    use objc2_app_kit::{NSApplication, NSApplicationActivationOptions, NSRunningApplication};

    let Some(mtm) = objc2::MainThreadMarker::new() else {
        return;
    };
    let ns_app = NSApplication::sharedApplication(mtm);
    if !ns_app.isActive() {
        return;
    }
    match held
        .previous
        .and_then(NSRunningApplication::runningApplicationWithProcessIdentifier)
    {
        Some(previous) => {
            previous.activateWithOptions(NSApplicationActivationOptions::empty());
        }
        None => ns_app.deactivate(),
    }
}

#[cfg(not(target_os = "macos"))]
fn hand_back(_held: Held) {}
