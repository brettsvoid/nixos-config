//! The dashboard's five quick toggles: Wi-Fi, Bluetooth, Focus, Night Shift and
//! Caffeine. Each is one row of `TABLE`, a reader and a writer, and
//! `Toggles::converge` is the one policy every write goes through.
//!
//! edgebar runs under herdr, which tccd attributes to kitty, so these calls run
//! with kitty's permissions (Full Disk Access among them) and kitty's usage
//! strings. That is why the Focus file is readable, and why switching Bluetooth
//! asks for Bluetooth permission for kitty.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::io::ErrorKind;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};
use tauri::{Emitter, Manager};

/// How long a write may take to show in its reader before the toggle reports
/// that it didn't take. blueutil waits for Bluetooth power the same way.
const SETTLE: Duration = Duration::from_secs(3);
const SETTLE_STEP: Duration = Duration::from_millis(100);
/// How long a `shortcuts list` answer is trusted, so a Shortcut made after
/// edgebar started enables the Focus toggle within half a minute.
const SHORTCUTS_TTL: Duration = Duration::from_secs(30);
/// Longest a helper command (networksetup, shortcuts) may run before it is killed.
const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);
/// IOBluetooth's setter can block on kitty's Bluetooth permission prompt; past
/// this the write counts as refused.
const BLUETOOTH_TIMEOUT: Duration = Duration::from_secs(3);
const BLUETOOTH_PERMISSION: &str = "Needs Bluetooth permission for kitty";

const ASSERTIONS: &str = "Library/DoNotDisturb/DB/Assertions.json";
const MODE_CONFIGURATIONS: &str = "Library/DoNotDisturb/DB/ModeConfigurations.json";

/// The `toggles` block of config.json.
#[derive(Clone, Default, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TogglesConfig {
    /// The Shortcut the Focus toggle runs. Empty leaves the toggle read-only.
    pub focus_shortcut: String,
}

/// The toggles in the order the dashboard draws them. Each discriminant is the
/// toggle's row in `TABLE`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum ToggleId {
    Wifi,
    Bluetooth,
    Focus,
    NightShift,
    Caffeine,
}

/// One toggle as the WebView sees it (`ToggleState` in ipc.ts).
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct ToggleState {
    pub id: ToggleId,
    pub on: bool,
    pub available: bool,
    pub detail: String,
}

/// What a row's reader sees, before `read_all` pins the row's id on.
#[derive(Debug, PartialEq)]
struct Reading {
    on: bool,
    /// False when edgebar has no way to set it; `detail` then says why.
    available: bool,
    detail: String,
}

impl Reading {
    fn settable(on: bool, detail: impl Into<String>) -> Self {
        Self {
            on,
            available: true,
            detail: detail.into(),
        }
    }

    fn unavailable(on: bool, why: impl Into<String>) -> Self {
        Self {
            on,
            available: false,
            detail: why.into(),
        }
    }
}

fn on_off(on: bool) -> &'static str {
    if on {
        "On"
    } else {
        "Off"
    }
}

struct Toggle {
    id: ToggleId,
    read: fn(&Toggles) -> Reading,
    write: fn(&Toggles, bool) -> Result<(), String>,
    /// The detail shown when a write returned but the reader never followed it.
    unconfirmed: &'static str,
}

const TABLE: [Toggle; 5] = [
    Toggle {
        id: ToggleId::Wifi,
        read: read_wifi,
        write: write_wifi,
        unconfirmed: "Wi-Fi didn't change",
    },
    Toggle {
        id: ToggleId::Bluetooth,
        read: read_bluetooth,
        write: write_bluetooth,
        // The setter returns nothing, so a refusal can only show as power that
        // didn't change.
        unconfirmed: BLUETOOTH_PERMISSION,
    },
    Toggle {
        id: ToggleId::Focus,
        read: read_focus,
        write: write_focus,
        unconfirmed: "The Shortcut ran but Focus didn't change",
    },
    Toggle {
        id: ToggleId::NightShift,
        read: read_night_shift,
        write: write_night_shift,
        unconfirmed: "Night Shift didn't change",
    },
    Toggle {
        id: ToggleId::Caffeine,
        read: read_caffeine,
        write: write_caffeine,
        unconfirmed: "caffeinate exited at once",
    },
];

const _: () = {
    let mut i = 0;
    while i < TABLE.len() {
        assert!(
            TABLE[i].id as usize == i,
            "TABLE rows must follow ToggleId's order"
        );
        i += 1;
    }
};

/// Managed state: the config the rows read and what they keep between calls.
pub struct Toggles {
    config: TogglesConfig,
    /// `shortcuts list`'s output, and when it was read.
    shortcuts: Mutex<Option<(Instant, String)>>,
    /// The device networksetup names for Wi-Fi ("en0"), once a write has found it.
    wifi_device: OnceLock<String>,
    /// The caffeinate child while Caffeine is on.
    caffeine: Mutex<Option<Child>>,
}

impl Toggles {
    pub fn new(config: TogglesConfig) -> Self {
        Self {
            config,
            shortcuts: Mutex::new(None),
            wifi_device: OnceLock::new(),
            caffeine: Mutex::new(None),
        }
    }

    fn read_all(&self) -> Vec<ToggleState> {
        TABLE
            .iter()
            .map(|row| {
                let r = (row.read)(self);
                ToggleState {
                    id: row.id,
                    on: r.on,
                    available: r.available,
                    detail: r.detail,
                }
            })
            .collect()
    }

    /// Set one toggle, then read all five. If it didn't take, its detail says why.
    fn set(&self, id: ToggleId, on: bool) -> Vec<ToggleState> {
        let failure = self.converge(&TABLE[id as usize], on, SETTLE);
        let mut all = self.read_all();
        if let Some(why) = failure {
            all[id as usize].detail = why;
        }
        all
    }

    /// Drive `row` to `on` and return why it didn't get there. Writes nothing
    /// when it is already there (the Focus Shortcut toggles, so a second run
    /// would undo the first) or when the row has no way to set it.
    fn converge(&self, row: &Toggle, on: bool, settle: Duration) -> Option<String> {
        let now = (row.read)(self);
        if !now.available || now.on == on {
            return None;
        }
        if let Err(why) = (row.write)(self, on) {
            return Some(why);
        }
        let deadline = Instant::now() + settle;
        while (row.read)(self).on != on {
            if Instant::now() >= deadline {
                return Some(row.unconfirmed.to_string());
            }
            std::thread::sleep(SETTLE_STEP);
        }
        None
    }

    /// Whether a Shortcut called `name` exists, or None if `shortcuts list` failed.
    fn has_shortcut(&self, name: &str) -> Option<bool> {
        let mut cache = self.shortcuts.lock().unwrap();
        let fresh = cache
            .as_ref()
            .is_some_and(|(at, _)| at.elapsed() < SHORTCUTS_TTL);
        if !fresh {
            let mut cmd = Command::new("/usr/bin/shortcuts");
            cmd.arg("list");
            *cache = Some((Instant::now(), run(cmd)?));
        }
        cache.as_ref().map(|(_, list)| lists_shortcut(list, name))
    }
}

#[tauri::command]
pub async fn toggles(app: tauri::AppHandle) -> Vec<ToggleState> {
    tauri::async_runtime::spawn_blocking(move || app.state::<Toggles>().read_all())
        .await
        .unwrap_or_default()
}

/// Set one toggle and return its new state, then push all five as `toggles`.
/// Blocks until the change shows (up to `SETTLE`, plus `BLUETOOTH_TIMEOUT` for
/// Bluetooth), hence `spawn_blocking`.
#[tauri::command]
pub async fn set_toggle(
    app: tauri::AppHandle,
    id: ToggleId,
    on: bool,
) -> Result<ToggleState, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let all = app.state::<Toggles>().set(id, on);
        let _ = app.emit("toggles", &all);
        all[id as usize].clone()
    })
    .await
    .map_err(|e| e.to_string())
}

// ───────────────────────── Wi-Fi ────────────────────────────────────

fn read_wifi(_: &Toggles) -> Reading {
    match sys::wifi_power() {
        Some(on) => Reading::settable(on, on_off(on)),
        None => Reading::unavailable(false, "No Wi-Fi interface"),
    }
}

fn write_wifi(t: &Toggles, on: bool) -> Result<(), String> {
    if t.wifi_device.get().is_none() {
        let mut cmd = Command::new("/usr/sbin/networksetup");
        cmd.arg("-listallhardwareports");
        if let Some(device) = run(cmd).and_then(|listing| wifi_device(&listing)) {
            let _ = t.wifi_device.set(device);
        }
    }
    let device = t
        .wifi_device
        .get()
        .ok_or("networksetup lists no Wi-Fi device")?;
    let mut cmd = Command::new("/usr/sbin/networksetup");
    cmd.args([
        "-setairportpower",
        device.as_str(),
        if on { "on" } else { "off" },
    ]);
    run(cmd)
        .map(drop)
        .ok_or_else(|| "networksetup couldn't switch Wi-Fi".to_string())
}

/// The device of the "Wi-Fi" port in `networksetup -listallhardwareports`.
fn wifi_device(listing: &str) -> Option<String> {
    let mut lines = listing.lines();
    lines.find(|l| l.trim() == "Hardware Port: Wi-Fi")?;
    lines
        .next()?
        .trim()
        .strip_prefix("Device: ")
        .map(str::to_string)
}

// ───────────────────────── Bluetooth ────────────────────────────────

fn read_bluetooth(_: &Toggles) -> Reading {
    // 1 is on (seen live). Off has never been observed, so any other value
    // reads as off.
    match sys::bluetooth_power() {
        Some(state) => Reading::settable(state == 1, on_off(state == 1)),
        None => Reading::unavailable(false, "Bluetooth state unreadable"),
    }
}

/// Set while a setter call is in flight. One blocked on the permission prompt
/// keeps its thread, and a second click shouldn't pile another on top.
static BLUETOOTH_WRITING: AtomicBool = AtomicBool::new(false);

fn write_bluetooth(_: &Toggles, on: bool) -> Result<(), String> {
    if BLUETOOTH_WRITING.swap(true, Ordering::AcqRel) {
        return Err(BLUETOOTH_PERMISSION.into());
    }
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let result = sys::set_bluetooth_power(on);
        BLUETOOTH_WRITING.store(false, Ordering::Release);
        let _ = tx.send(result);
    });
    rx.recv_timeout(BLUETOOTH_TIMEOUT)
        .unwrap_or_else(|_| Err(BLUETOOTH_PERMISSION.into()))
}

// ───────────────────────── Focus ────────────────────────────────────

fn read_focus(t: &Toggles) -> Reading {
    let Some(home) = std::env::var_os("HOME").map(PathBuf::from) else {
        return Reading::unavailable(false, "HOME is not set");
    };
    let mode = match std::fs::read_to_string(home.join(ASSERTIONS)) {
        Ok(text) => match active_focus(&text) {
            Ok(mode) => mode,
            Err(_) => return Reading::unavailable(false, "Focus state unreadable"),
        },
        Err(e) if e.kind() == ErrorKind::NotFound => None,
        Err(e) if e.kind() == ErrorKind::PermissionDenied => {
            return Reading::unavailable(false, "Needs Full Disk Access to read Focus")
        }
        Err(_) => return Reading::unavailable(false, "Focus state unreadable"),
    };
    let on = mode.is_some();

    let name = t.config.focus_shortcut.as_str();
    if name.is_empty() {
        return Reading::unavailable(on, "Name a Shortcut in toggles.focusShortcut");
    }
    match t.has_shortcut(name) {
        Some(true) => {}
        Some(false) => {
            return Reading::unavailable(
                on,
                format!("Make a Shortcut \"{name}\" with Set Focus (Do Not Disturb, Toggle)"),
            )
        }
        None => return Reading::unavailable(on, "Shortcuts didn't answer"),
    }

    let detail = match mode {
        None => "Off".to_string(),
        Some(id) => std::fs::read_to_string(home.join(MODE_CONFIGURATIONS))
            .ok()
            .and_then(|text| mode_name(&text, &id))
            .unwrap_or_else(|| "On".to_string()),
    };
    Reading::settable(on, detail)
}

/// The Shortcut toggles Focus, so `on` is not passed on: `converge` only calls
/// this when Focus is in the other state.
fn write_focus(t: &Toggles, _on: bool) -> Result<(), String> {
    let name = &t.config.focus_shortcut;
    let mut cmd = Command::new("/usr/bin/shortcuts");
    cmd.args(["run", name.as_str()]);
    run(cmd)
        .map(drop)
        .ok_or_else(|| format!("The \"{name}\" Shortcut failed"))
}

/// The mode id of the Focus turned on by hand, None when none is. Assertions.json
/// keeps each live one under `data[].storeAssertionRecords` (a key the
/// DoNotDisturb framework names) and ended ones under `storeInvalidationRecords`.
fn active_focus(assertions: &str) -> Result<Option<String>, serde_json::Error> {
    let doc: Value = serde_json::from_str(assertions)?;
    let record = doc["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|store| store["storeAssertionRecords"].as_array())
        .flatten()
        .next();
    Ok(record.map(|r| {
        r["assertionDetails"]["assertionDetailsModeIdentifier"]
            .as_str()
            .unwrap_or_default()
            .to_string()
    }))
}

/// A Focus mode's display name from ModeConfigurations.json.
fn mode_name(configs: &str, id: &str) -> Option<String> {
    let doc: Value = serde_json::from_str(configs).ok()?;
    doc["data"]
        .as_array()?
        .iter()
        .find_map(|store| store["modeConfigurations"][id]["mode"]["name"].as_str())
        .map(str::to_string)
}

/// Whether `shortcuts list` output names `name` exactly (one name per line).
fn lists_shortcut(list: &str, name: &str) -> bool {
    list.lines().any(|line| line == name)
}

// ───────────────────────── Night Shift ──────────────────────────────

/// CoreBrightness's status struct, in the layout of the nightlight crate's
/// `BlueLightStatus` (smudge/nightlight 1.0, src/macos/status.rs). On macOS
/// 26.7.1 the runtime encoding of `getBlueLightStatus:`'s argument,
/// `^{?=BBBi{?={?=ii}{?=ii}}QB}`, matches it field for field. The underscored
/// fields are unread; they keep their place in the layout.
#[repr(C)]
#[derive(Clone, Copy, Default)]
struct BlueLightStatus {
    _active: bool,
    enabled: bool,
    _sun_schedule_permitted: bool,
    /// 0 no schedule, 1 sunset to sunrise, 2 custom.
    mode: i32,
    from_hour: i32,
    from_minute: i32,
    to_hour: i32,
    to_minute: i32,
    _disable_flags: u64,
    available: bool,
}

const _: () = assert!(std::mem::size_of::<BlueLightStatus>() == 40);

fn read_night_shift(_: &Toggles) -> Reading {
    match sys::night_shift() {
        Some(status) => night_shift_reading(&status),
        None => Reading::unavailable(false, "Night Shift unreadable"),
    }
}

fn night_shift_reading(s: &BlueLightStatus) -> Reading {
    if !s.available {
        return Reading::unavailable(false, "Night Shift isn't available");
    }
    let detail = match s.mode {
        1 => "Sunset to sunrise".to_string(),
        2 => format!(
            "{:02}:{:02} to {:02}:{:02}",
            s.from_hour, s.from_minute, s.to_hour, s.to_minute
        ),
        _ => on_off(s.enabled).to_string(),
    };
    Reading::settable(s.enabled, detail)
}

fn write_night_shift(_: &Toggles, on: bool) -> Result<(), String> {
    sys::set_night_shift(on)
        .then_some(())
        .ok_or_else(|| "CoreBrightness refused".to_string())
}

// ───────────────────────── Caffeine ─────────────────────────────────

fn read_caffeine(t: &Toggles) -> Reading {
    let mut child = t.caffeine.lock().unwrap();
    // try_wait reaps a child that has exited, so a dead one reads as off.
    let on = child
        .as_mut()
        .is_some_and(|c| matches!(c.try_wait(), Ok(None)));
    if !on {
        *child = None;
    }
    Reading::settable(on, if on { "Keeping the Mac awake" } else { "Off" })
}

fn write_caffeine(t: &Toggles, on: bool) -> Result<(), String> {
    let mut child = t.caffeine.lock().unwrap();
    if let Some(mut old) = child.take() {
        let _ = old.kill();
        let _ = old.wait();
    }
    if on {
        // -w ties it to edgebar's pid, so it ends with edgebar however edgebar ends.
        let spawned = Command::new("/usr/bin/caffeinate")
            .args(["-di", "-w", &std::process::id().to_string()])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("caffeinate didn't start: {e}"))?;
        *child = Some(spawned);
    }
    Ok(())
}

/// stdout of `cmd` if it exits 0 within `COMMAND_TIMEOUT`; killed past that.
fn run(mut cmd: Command) -> Option<String> {
    use std::io::Read;
    let mut child = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    // Drained on a side thread so a full pipe can't wedge the child; the kill
    // on timeout ends the read.
    let mut stdout = child.stdout.take()?;
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut text = String::new();
        let _ = stdout.read_to_string(&mut text);
        let _ = tx.send(text);
    });
    let Ok(text) = rx.recv_timeout(COMMAND_TIMEOUT) else {
        let _ = child.kill();
        let _ = child.wait();
        return None;
    };
    child.wait().ok()?.success().then_some(text)
}

// ───────────────────────── macOS calls ──────────────────────────────

#[cfg(target_os = "macos")]
mod sys {
    use super::BlueLightStatus;
    use objc2::rc::{autoreleasepool, Retained};
    use objc2::runtime::{AnyClass, AnyObject, Bool, Sel};
    use objc2::{msg_send, sel};
    use std::ffi::{c_char, c_int, c_void, CStr};
    use std::sync::OnceLock;

    /// CoreWLAN's power flag for the default Wi-Fi interface, None without one.
    pub fn wifi_power() -> Option<bool> {
        autoreleasepool(|_| {
            let class = AnyClass::get(c"CWWiFiClient")?;
            // SAFETY: documented CoreWLAN getters that return an object or nil.
            let client: Option<Retained<AnyObject>> = unsafe { msg_send![class, sharedWiFiClient] };
            let interface: Option<Retained<AnyObject>> = unsafe { msg_send![&*client?, interface] };
            // SAFETY: CWInterface's BOOL getter.
            let on: bool = unsafe { msg_send![&*interface?, powerOn] };
            Some(on)
        })
    }

    extern "C" {
        fn notify_register_check(name: *const c_char, out_token: *mut c_int) -> u32;
        fn notify_get_state(token: c_int, state: *mut u64) -> u32;
        fn notify_cancel(token: c_int) -> u32;
    }

    /// The state on the `com.apple.bluetooth.power` notify key. Unlike
    /// IOBluetooth's getters, reading it raises no permission prompt.
    pub fn bluetooth_power() -> Option<u64> {
        let mut token: c_int = 0;
        // SAFETY: a NUL-terminated name and a live out-pointer.
        if unsafe { notify_register_check(c"com.apple.bluetooth.power".as_ptr(), &mut token) } != 0
        {
            return None;
        }
        let mut state = 0;
        // SAFETY: `token` was just registered; it is cancelled straight after.
        let status = unsafe { notify_get_state(token, &mut state) };
        unsafe { notify_cancel(token) };
        (status == 0).then_some(state)
    }

    fn open(library: &CStr) -> Option<*mut c_void> {
        // SAFETY: a NUL-terminated path; a null handle is checked.
        let handle = unsafe { libc::dlopen(library.as_ptr(), libc::RTLD_NOW) };
        (!handle.is_null()).then_some(handle)
    }

    fn symbol(library: &CStr, name: &CStr) -> Option<*mut c_void> {
        // SAFETY: a live handle and a NUL-terminated name; a null symbol is checked.
        let sym = unsafe { libc::dlsym(open(library)?, name.as_ptr()) };
        (!sym.is_null()).then_some(sym)
    }

    /// IOBluetooth's private power setter, looked up at call time so nothing
    /// loads IOBluetooth until Bluetooth is switched. It can block on kitty's
    /// Bluetooth permission prompt.
    pub fn set_bluetooth_power(on: bool) -> Result<(), String> {
        let sym = symbol(
            c"/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth",
            c"IOBluetoothPreferenceSetControllerPowerState",
        )
        .ok_or("IOBluetooth has no power setter")?;
        // SAFETY: blueutil declares it `void IOBluetoothPreferenceSetControllerPowerState(int)`.
        let set: unsafe extern "C" fn(c_int) = unsafe { std::mem::transmute(sym) };
        unsafe { set(c_int::from(on)) };
        Ok(())
    }

    fn blue_light_client() -> Option<Retained<AnyObject>> {
        static LOADED: OnceLock<bool> = OnceLock::new();
        let loaded = *LOADED.get_or_init(|| {
            open(c"/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness")
                .is_some()
        });
        if !loaded {
            return None;
        }
        let class = AnyClass::get(c"CBBlueLightClient")?;
        // SAFETY: an NSObject subclass; `new` returns a +1 instance or nil.
        unsafe { msg_send![class, new] }
    }

    /// An unknown selector raises an Objective-C exception that nothing here
    /// catches, so each private selector is checked before it is sent.
    fn responds(obj: &AnyObject, sel: Sel) -> bool {
        // SAFETY: NSObject's respondsToSelector:.
        unsafe { msg_send![obj, respondsToSelector: sel] }
    }

    pub fn night_shift() -> Option<BlueLightStatus> {
        autoreleasepool(|_| {
            let client = blue_light_client()?;
            let sel = sel!(getBlueLightStatus:);
            if !responds(&client, sel) {
                return None;
            }
            let mut status = BlueLightStatus::default();
            // The struct has no objc2 `Encode` impl, so this goes through
            // objc_msgSend directly. SAFETY: the selector takes a pointer to the
            // 40-byte struct `BlueLightStatus` mirrors and returns BOOL.
            let get: unsafe extern "C-unwind" fn(
                *const AnyObject,
                Sel,
                *mut BlueLightStatus,
            ) -> Bool = unsafe {
                std::mem::transmute(objc2::ffi::objc_msgSend as unsafe extern "C-unwind" fn())
            };
            let ok = unsafe { get(Retained::as_ptr(&client), sel, &mut status) };
            ok.as_bool().then_some(status)
        })
    }

    pub fn set_night_shift(on: bool) -> bool {
        autoreleasepool(|_| {
            let Some(client) = blue_light_client() else {
                return false;
            };
            let sel = sel!(setEnabled:);
            if !responds(&client, sel) {
                return false;
            }
            // SAFETY: `- (BOOL)setEnabled:(BOOL)`.
            let set: unsafe extern "C-unwind" fn(*const AnyObject, Sel, Bool) -> Bool = unsafe {
                std::mem::transmute(objc2::ffi::objc_msgSend as unsafe extern "C-unwind" fn())
            };
            unsafe { set(Retained::as_ptr(&client), sel, Bool::new(on)) }.as_bool()
        })
    }
}

#[cfg(not(target_os = "macos"))]
mod sys {
    use super::BlueLightStatus;
    pub fn wifi_power() -> Option<bool> {
        None
    }
    pub fn bluetooth_power() -> Option<u64> {
        None
    }
    pub fn set_bluetooth_power(_: bool) -> Result<(), String> {
        Err("Bluetooth is macOS-only".into())
    }
    pub fn night_shift() -> Option<BlueLightStatus> {
        None
    }
    pub fn set_night_shift(_: bool) -> bool {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_the_wifi_device_among_hardware_ports() {
        let listing = "Hardware Port: Ethernet Adapter (en3)\nDevice: en3\n\
                       Ethernet Address: 00:00:00:00:00:01\n\n\
                       Hardware Port: Wi-Fi\nDevice: en0\n\
                       Ethernet Address: 00:00:00:00:00:02\n\n\
                       VLAN Configurations\n===================\n";
        assert_eq!(wifi_device(listing).as_deref(), Some("en0"));
        assert_eq!(
            wifi_device("Hardware Port: Thunderbolt Bridge\nDevice: bridge0\n"),
            None
        );
    }

    #[test]
    fn a_live_assertion_is_the_active_focus() {
        let file = r#"{"data":[{"storeAssertionRecords":[{"assertionDetails":
            {"assertionDetailsModeIdentifier":"com.apple.donotdisturb.mode.default"}}]}],
            "header":{"version":2}}"#;
        assert_eq!(
            active_focus(file).unwrap().as_deref(),
            Some("com.apple.donotdisturb.mode.default")
        );
    }

    #[test]
    fn an_ended_assertion_is_no_focus() {
        // The shape this Mac's file has with no Focus on.
        let file = r#"{"data":[{"storeInvalidationRecords":[{"invalidationAssertion":
            {"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.focus.work"}},
            "invalidationReason":"user"}],"storeInvalidationRequestRecords":[]}],
            "header":{"timestamp":1.0,"version":2}}"#;
        assert_eq!(active_focus(file).unwrap(), None);
        assert!(active_focus("{").is_err());
    }

    #[test]
    fn names_a_mode_from_its_configuration() {
        let file = r#"{"data":[{"modeConfigurations":{"com.apple.focus.work":
            {"mode":{"name":"Work","modeIdentifier":"com.apple.focus.work"}}}}]}"#;
        assert_eq!(
            mode_name(file, "com.apple.focus.work").as_deref(),
            Some("Work")
        );
        assert_eq!(mode_name(file, "com.apple.focus.sleep"), None);
    }

    #[test]
    fn a_shortcut_matches_its_whole_line_only() {
        let list = "Morning\nToggle Focus 2\nToggle Focus\n";
        assert!(lists_shortcut(list, "Toggle Focus"));
        assert!(!lists_shortcut("Morning\nToggle Focus 2\n", "Toggle Focus"));
    }

    #[test]
    fn night_shift_detail_follows_the_schedule() {
        let custom = BlueLightStatus {
            enabled: true,
            mode: 2,
            from_hour: 22,
            to_hour: 7,
            to_minute: 30,
            available: true,
            ..Default::default()
        };
        assert_eq!(
            night_shift_reading(&custom),
            Reading::settable(true, "22:00 to 07:30")
        );
        let sunset = BlueLightStatus {
            mode: 1,
            available: true,
            ..Default::default()
        };
        assert_eq!(
            night_shift_reading(&sunset),
            Reading::settable(false, "Sunset to sunrise")
        );
        assert_eq!(
            night_shift_reading(&BlueLightStatus::default()),
            Reading::unavailable(false, "Night Shift isn't available")
        );
    }

    fn reads_off(_: &Toggles) -> Reading {
        Reading::settable(false, "Off")
    }

    #[test]
    fn converge_skips_a_toggle_already_there() {
        let row = Toggle {
            id: ToggleId::Focus,
            read: reads_off,
            write: |_, _| panic!("wrote a toggle that was already off"),
            unconfirmed: "",
        };
        let t = Toggles::new(TogglesConfig::default());
        assert_eq!(t.converge(&row, false, Duration::ZERO), None);
    }

    #[test]
    fn converge_reports_a_write_that_failed_or_didnt_take() {
        let t = Toggles::new(TogglesConfig::default());
        let refused = Toggle {
            id: ToggleId::Bluetooth,
            read: reads_off,
            write: |_, _| Err("refused".into()),
            unconfirmed: "didn't take",
        };
        assert_eq!(
            t.converge(&refused, true, Duration::ZERO).as_deref(),
            Some("refused")
        );
        let ignored = Toggle {
            write: |_, _| Ok(()),
            ..refused
        };
        assert_eq!(
            t.converge(&ignored, true, Duration::ZERO).as_deref(),
            Some("didn't take")
        );
    }

    fn summary(s: &ToggleState) -> String {
        format!(
            "{:?} on={} available={} detail={:?}",
            s.id, s.on, s.available, s.detail
        )
    }

    /// Reads all five on this Mac; writes nothing.
    #[test]
    #[ignore]
    fn live_reads_all_five() {
        let t = Toggles::new(TogglesConfig {
            focus_shortcut: "Toggle Focus".into(),
        });
        for row in &TABLE {
            let started = Instant::now();
            let r = (row.read)(&t);
            println!(
                "{:?} on={} available={} detail={:?} ({:.2} ms)",
                row.id,
                r.on,
                r.available,
                r.detail,
                started.elapsed().as_secs_f64() * 1e3
            );
        }
        let started = Instant::now();
        let again = t.read_all();
        println!(
            "read_all again: {:.2} ms (shortcuts list cached)",
            started.elapsed().as_secs_f64() * 1e3
        );
        assert_eq!(
            again.iter().map(|s| s.id).collect::<Vec<_>>(),
            [
                ToggleId::Wifi,
                ToggleId::Bluetooth,
                ToggleId::Focus,
                ToggleId::NightShift,
                ToggleId::Caffeine
            ]
        );
        println!("{}", serde_json::to_string(&again[3]).unwrap());

        let mut cmd = Command::new("/usr/sbin/networksetup");
        cmd.arg("-listallhardwareports");
        println!(
            "wifi write device: {:?}",
            run(cmd).and_then(|l| wifi_device(&l))
        );
        let mut cmd = Command::new("/usr/sbin/networksetup");
        cmd.arg("-printcommands");
        println!(
            "networksetup offers -setairportpower: {}",
            run(cmd).is_some_and(|out| out.contains("-setairportpower <device name> <on off>"))
        );

        #[cfg(target_os = "macos")]
        {
            use objc2::runtime::AnyClass;
            use objc2::sel;
            let class = AnyClass::get(c"CBBlueLightClient").expect("loaded by the read");
            for sel in [sel!(getBlueLightStatus:), sel!(setEnabled:)] {
                let m = class.instance_method(sel).expect("selector exists");
                println!(
                    "{}: returns {:?}, takes {:?}",
                    sel,
                    m.return_type(),
                    m.argument_type(2)
                );
            }
        }
    }

    /// Night Shift is harmless and reversible: flips it, reads it, flips it back.
    #[test]
    #[ignore]
    fn live_night_shift_flips_and_back() {
        let t = Toggles::new(TogglesConfig::default());
        let id = ToggleId::NightShift;
        let before = t.read_all()[id as usize].clone();
        println!("before: {}", summary(&before));
        let flipped = t.set(id, !before.on)[id as usize].clone();
        println!("flipped: {}", summary(&flipped));
        let back = t.set(id, before.on)[id as usize].clone();
        println!("back: {}", summary(&back));
        assert_eq!(flipped.on, !before.on);
        assert_eq!(back, before);
    }

    /// Starts and stops caffeinate, checking pmset sees its assertion.
    #[test]
    #[ignore]
    fn live_caffeine_both_ways() {
        let assertions = || {
            let mut cmd = Command::new("/usr/bin/pmset");
            cmd.args(["-g", "assertions"]);
            run(cmd).unwrap_or_default()
        };
        let t = Toggles::new(TogglesConfig::default());
        let id = ToggleId::Caffeine;
        let on = t.set(id, true)[id as usize].clone();
        println!("on: {}", summary(&on));
        let pid = t.caffeine.lock().unwrap().as_ref().map(Child::id).unwrap();
        let tag = format!("pid {pid}(caffeinate)");
        let held: Vec<String> = assertions()
            .lines()
            .filter(|l| l.contains(&tag))
            .map(|l| l.trim().to_string())
            .collect();
        println!("pmset while on: {held:?}");
        let off = t.set(id, false)[id as usize].clone();
        println!("off: {}", summary(&off));
        let after = assertions().contains(&tag);
        println!("pmset still lists pid {pid} after off: {after}");
        assert!(on.on && !off.on);
        assert!(held
            .iter()
            .any(|l| l.contains("PreventUserIdleDisplaySleep")));
        assert!(!after);
    }
}
