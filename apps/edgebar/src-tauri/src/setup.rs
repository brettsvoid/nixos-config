use crate::notch::PLAYERS;
use crate::toggles::{self, BluetoothPermission, Toggles};
use crate::SettingsPane;
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;
use tauri::{AppHandle, Manager};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum State {
    Ready,
    Missing,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct SetupItem {
    id: &'static str,
    label: &'static str,
    state: State,
    detail: String,
    action: Option<&'static str>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    Open(SettingsPane),
    OpenShortcuts,
    /// Ask the player at this index of `PLAYERS`.
    Ask(usize),
}

impl Action {
    fn label(self) -> &'static str {
        match self {
            Action::Open(_) => "Open System Settings",
            Action::OpenShortcuts => "Open Shortcuts",
            Action::Ask(_) => "Ask",
        }
    }

    fn run(self, app: &AppHandle) -> Result<(), String> {
        match self {
            Action::Open(pane) => crate::open_settings_pane(pane),
            Action::OpenShortcuts => crate::open_url("shortcuts://"),
            Action::Ask(player) => ask(app, player),
        }
    }
}

struct Status {
    state: State,
    detail: String,
    action: Option<Action>,
}

impl Status {
    fn new(state: State, detail: impl Into<String>, action: Option<Action>) -> Self {
        Self {
            state,
            detail: detail.into(),
            action,
        }
    }
}

struct Check {
    id: &'static str,
    label: &'static str,
    probe: fn(&AppHandle) -> Status,
}

const CHECKS: [Check; 9] = [
    Check {
        id: "fullDiskAccess",
        label: "Full Disk Access",
        probe: full_disk_access,
    },
    Check {
        id: "bluetooth",
        label: "Bluetooth",
        probe: bluetooth,
    },
    Check {
        id: "spotify",
        label: "Automation: Spotify",
        probe: |app| automation_as_last_asked(app, 0),
    },
    Check {
        id: "music",
        label: "Automation: Music",
        probe: |app| automation_as_last_asked(app, 1),
    },
    Check {
        id: "focusShortcut",
        label: "Focus Shortcut",
        probe: focus_shortcut,
    },
    Check {
        id: "aerospace",
        label: "AeroSpace CLI",
        probe: |_| {
            tool(
                "aerospace",
                Search::Path,
                "Not on edgebar's PATH. The workspace dots and the notch's workspace rules need it.",
            )
        },
    },
    Check {
        id: "themeCommand",
        label: "Theme command",
        probe: |app| {
            tool(
                &crate::theme_command(app),
                Search::Path,
                "Not found, so a wallpaper pick can't re-theme the bar. The Nix config installs it.",
            )
        },
    },
    Check {
        id: "wallpaperCommand",
        label: "Wallpaper command",
        probe: |app| {
            tool(
                &crate::wallpaper_command(app),
                Search::Path,
                "Not found, so the Wallpapers view can't set the desktop. The Nix config installs it.",
            )
        },
    },
    Check {
        id: "claude",
        label: "Claude CLI",
        probe: |app| {
            tool(
                &crate::settings::current(app).assistant.command,
                Search::PathAndLocalBin,
                "Not on PATH or in ~/.local/bin. Install Claude Code, or set the CLI command under Assistant.",
            )
        },
    },
];

#[derive(Default)]
pub struct Setup {
    asked: Mutex<[Option<State>; PLAYERS.len()]>,
}

fn item(check: &Check, status: Status) -> SetupItem {
    SetupItem {
        id: check.id,
        label: check.label,
        state: status.state,
        detail: status.detail,
        action: status.action.map(Action::label),
    }
}

fn status_all(app: &AppHandle) -> Vec<SetupItem> {
    CHECKS
        .iter()
        .map(|check| item(check, (check.probe)(app)))
        .collect()
}

#[tauri::command]
pub async fn setup_status(app: AppHandle) -> Vec<SetupItem> {
    tauri::async_runtime::spawn_blocking(move || status_all(&app))
        .await
        .unwrap_or_default()
}

#[tauri::command]
pub async fn setup_run(app: AppHandle, id: String) -> Result<Vec<SetupItem>, String> {
    tauri::async_runtime::spawn_blocking(move || {
        let check = CHECKS
            .iter()
            .find(|c| c.id == id)
            .ok_or_else(|| format!("no setup check `{id}`"))?;
        let action = (check.probe)(&app)
            .action
            .ok_or_else(|| format!("{} has nothing to do", check.label))?;
        action.run(&app)?;
        Ok(status_all(&app))
    })
    .await
    .map_err(|e| e.to_string())?
}

/// The AppleScript error macOS returns when the user refused Automation.
const ERR_AE_EVENT_NOT_PERMITTED: &str = "-1743";

/// The app macOS checks edgebar's permissions against, so the one a grant goes
/// to: edgebar's responsible process. That is edgebar itself when launchd or
/// Finder starts edgebar.app, and the terminal when a shell runs the binary,
/// as `pnpm tauri dev` does (kitty, through herdr).
#[cfg(target_os = "macos")]
fn grantee() -> &'static str {
    use objc2_app_kit::NSRunningApplication;
    use std::sync::OnceLock;
    extern "C" {
        // Private, in libSystem (libquarantine).
        fn responsibility_get_pid_responsible_for_pid(pid: libc::pid_t) -> libc::pid_t;
    }
    static GRANTEE: OnceLock<String> = OnceLock::new();
    GRANTEE.get_or_init(|| {
        // SAFETY: takes and returns a plain pid.
        let pid = unsafe { responsibility_get_pid_responsible_for_pid(std::process::id() as _) };
        NSRunningApplication::runningApplicationWithProcessIdentifier(pid)
            .and_then(|app| app.localizedName())
            .map(|name| name.to_string())
            .unwrap_or_else(|| "the app that started edgebar".into())
    })
}

#[cfg(not(target_os = "macos"))]
fn grantee() -> &'static str {
    "the app that started edgebar"
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Opened {
    Yes,
    Refused,
    Untested,
}

fn try_open(path: &Path) -> Opened {
    match std::fs::File::open(path) {
        Ok(_) => Opened::Yes,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => Opened::Refused,
        Err(_) => Opened::Untested,
    }
}

fn full_disk_access(app: &AppHandle) -> Status {
    let Some(home) = std::env::var_os("HOME").map(PathBuf::from) else {
        return Status::new(State::Unknown, "HOME is not set", None);
    };
    let history = crate::settings::current(app).notifications.history;
    let focus = try_open(&home.join(toggles::ASSERTIONS));
    let store = match crate::notifications::store_dir() {
        Some(dir) if history => try_open(&dir.join("db")),
        _ => Opened::Untested,
    };
    let pane = Some(Action::Open(SettingsPane::FullDiskAccess));
    let store_note = if history {
        ""
    } else {
        " The notification store is not opened while notification history is off."
    };
    if focus == Opened::Refused || store == Opened::Refused {
        Status::new(
            State::Missing,
            format!(
                "Needed to read the Focus state and macOS's notification history. The grant goes to {}.",
                grantee()
            ),
            pane,
        )
    } else if focus == Opened::Yes || store == Opened::Yes {
        let what = if store == Opened::Yes {
            "the Focus state and the notification history"
        } else {
            "the Focus state"
        };
        Status::new(
            State::Ready,
            format!("Granted: {what} can be read.{store_note}"),
            None,
        )
    } else {
        Status::new(
            State::Unknown,
            format!(
                "Nothing to test it on yet: the Focus file doesn't exist.{store_note} The grant goes to {}.",
                grantee()
            ),
            pane,
        )
    }
}

fn bluetooth(_: &AppHandle) -> Status {
    let pane = Some(Action::Open(SettingsPane::PrivacyBluetooth));
    match toggles::bluetooth_permission() {
        Some(BluetoothPermission::Granted) => Status::new(
            State::Ready,
            format!("Granted to {}, so the dashboard can switch Bluetooth.", grantee()),
            None,
        ),
        Some(BluetoothPermission::NotAsked) => Status::new(
            State::Unknown,
            format!(
                "Not asked yet. The first Bluetooth switch from the dashboard asks, for {}.",
                grantee()
            ),
            None,
        ),
        Some(BluetoothPermission::Denied) => Status::new(
            State::Missing,
            format!(
                "Refused, so the dashboard can't switch Bluetooth. Allow {} under Privacy & Security, Bluetooth.",
                grantee()
            ),
            pane,
        ),
        Some(BluetoothPermission::Restricted) => Status::new(
            State::Missing,
            "Restricted on this Mac, so the dashboard can't switch Bluetooth.",
            None,
        ),
        None => Status::new(State::Unknown, "CoreBluetooth didn't answer.", None),
    }
}

#[cfg(target_os = "macos")]
fn installed(bundle_id: &str) -> bool {
    use objc2_app_kit::NSWorkspace;
    use objc2_foundation::NSString;
    NSWorkspace::sharedWorkspace()
        .URLForApplicationWithBundleIdentifier(&NSString::from_str(bundle_id))
        .is_some()
}

#[cfg(not(target_os = "macos"))]
fn installed(_: &str) -> bool {
    false
}

fn automation_as_last_asked(app: &AppHandle, player: usize) -> Status {
    let name = PLAYERS[player].name;
    if !installed(PLAYERS[player].bundle_id) {
        return Status::new(State::Unknown, format!("{name} isn't installed."), None);
    }
    match app.state::<Setup>().asked.lock().unwrap()[player] {
        Some(State::Ready) => Status::new(
            State::Ready,
            format!(
                "{} may control {name}, so the player shows its track and its transport works.",
                grantee()
            ),
            None,
        ),
        Some(_) => Status::new(
            State::Missing,
            format!(
                "Refused. Allow {} to control {name} under Privacy & Security, Automation.",
                grantee()
            ),
            Some(Action::Open(SettingsPane::PrivacyAutomation)),
        ),
        None => Status::new(
            State::Unknown,
            format!("Not checked yet. Ask reads {name}'s player state once, so macOS asks if it hasn't already."),
            Some(Action::Ask(player)),
        ),
    }
}

fn ask(app: &AppHandle, player: usize) -> Result<(), String> {
    let name = PLAYERS[player].name;
    let script = format!(
        "if application \"{name}\" is running then\n\
         tell application \"{name}\" to get player state\n\
         return \"asked\"\n\
         end if\n\
         return \"not running\""
    );
    let out = Command::new("/usr/bin/osascript")
        .args(["-e", &script])
        .output()
        .map_err(|e| format!("osascript didn't run: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
    let state = if out.status.success() && stdout == "asked" {
        State::Ready
    } else if out.status.success() {
        return Err(format!("{name} isn't running. Start it, then ask again."));
    } else if stderr.contains(ERR_AE_EVENT_NOT_PERMITTED) {
        State::Missing
    } else {
        return Err(format!("{name} didn't answer: {stderr}"));
    };
    app.state::<Setup>().asked.lock().unwrap()[player] = Some(state);
    Ok(())
}

fn focus_shortcut(app: &AppHandle) -> Status {
    let toggles = app.state::<Toggles>();
    let name = toggles.focus_shortcut();
    let shortcuts = Some(Action::OpenShortcuts);
    if name.is_empty() {
        return Status::new(
            State::Missing,
            "No Shortcut is named, so the Focus toggle can only show Focus. Name one under Dashboard.",
            None,
        );
    }
    match toggles.has_shortcut(&name) {
        Some(true) => Status::new(
            State::Ready,
            format!("\"{name}\" exists, so the Focus toggle can switch Focus."),
            None,
        ),
        Some(false) => Status::new(
            State::Missing,
            format!(
                "Make a Shortcut named \"{name}\" with one Set Focus action (Do Not Disturb, Toggle). \
                 The Focus toggle runs it."
            ),
            shortcuts,
        ),
        None => Status::new(State::Unknown, "The shortcuts command didn't answer.", shortcuts),
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Search {
    Path,
    /// PATH, then ~/.local/bin, where Claude Code's installer puts it.
    PathAndLocalBin,
}

fn tool(command: &str, search: Search, missing: &str) -> Status {
    let path = std::env::var_os("PATH");
    let home = (search == Search::PathAndLocalBin)
        .then(|| std::env::var_os("HOME").map(PathBuf::from))
        .flatten();
    match crate::assistant::resolve_command(command, path.as_deref(), home.as_deref()) {
        Some(found) => Status::new(State::Ready, found.display().to_string(), None),
        None => Status::new(State::Missing, format!("`{command}`: {missing}"), None),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_check_has_its_own_id() {
        let mut ids: Vec<&str> = CHECKS.iter().map(|c| c.id).collect();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), CHECKS.len());
    }

    #[test]
    fn a_tool_is_found_by_path_or_on_path_and_named_when_missing() {
        let found = tool("/bin/sh", Search::Path, "gone");
        assert_eq!(
            (found.state, found.detail.as_str()),
            (State::Ready, "/bin/sh")
        );
        let missing = tool("no-such-edgebar-tool", Search::Path, "gone");
        assert_eq!(
            (missing.state, missing.detail.as_str()),
            (State::Missing, "`no-such-edgebar-tool`: gone")
        );
    }
}
