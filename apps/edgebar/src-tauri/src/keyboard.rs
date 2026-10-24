use std::sync::Mutex;
use tauri::{AppHandle, Manager, WebviewWindow};

#[derive(Default)]
pub struct Keyboard(Mutex<Option<Held>>);

struct Held {
    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    previous_pid: Option<i32>,
}

#[tauri::command]
pub fn take_keyboard(app: AppHandle, window: WebviewWindow) {
    let handle = app.clone();
    let _ = app.run_on_main_thread(move || {
        let state = handle.state::<Keyboard>();
        let mut held = state.0.lock().unwrap();
        if held.is_none() {
            *held = Some(Held {
                previous_pid: other_front_app_pid(),
            });
        }
        let _ = window.set_focusable(true);
        let _ = window.set_focus();
    });
}

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

/// The frontmost app's pid, or None when edgebar itself is in front.
#[cfg(target_os = "macos")]
fn other_front_app_pid() -> Option<i32> {
    let me = std::process::id() as i32;
    objc2_app_kit::NSWorkspace::sharedWorkspace()
        .frontmostApplication()
        .map(|app| app.processIdentifier())
        .filter(|&pid| pid != me)
}

#[cfg(not(target_os = "macos"))]
fn other_front_app_pid() -> Option<i32> {
    None
}

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
        .previous_pid
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
