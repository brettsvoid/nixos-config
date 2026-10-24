//! The Settings view's Setup checklist: what edgebar needs from this Mac to
//! work fully. Each thing is one row of `CHECKS`, a probe that reports its
//! state together with the one action that can move it on: a System Settings
//! pane, the Shortcuts app, or a harmless AppleScript read that makes macOS ask
//! for Automation. A probe never asks for anything; only an action does.
//!
//! edgebar runs under herdr, which tccd attributes to kitty, so every
//! permission here is kitty's (see toggles.rs).

use crate::toggles::{self, BluetoothPermission, Toggles};
use crate::{SettingsPane, ThemeState};
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
    /// edgebar can't tell without asking, or hasn't asked yet.
    Unknown,
}

/// One row as the WebView sees it (`SetupItem` in ipc.ts).
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct SetupItem {
    id: &'static str,
    label: &'static str,
    state: State,
    detail: String,
    /// The action button's label; None when edgebar can do nothing about it.
    action: Option<&'static str>,
}

/// The two players edgebar reads over AppleScript (notch.rs).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Player {
    Spotify,
    Music,
}

impl Player {
    fn name(self) -> &'static str {
        match self {
            Player::Spotify => "Spotify",
            Player::Music => "Music",
        }
    }

    fn bundle_id(self) -> &'static str {
        match self {
            Player::Spotify => "com.spotify.client",
            Player::Music => "com.apple.Music",
        }
    }
}

/// What can move a check on.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    Open(SettingsPane),
    /// One harmless read of the player, so macOS asks for Automation.
    Ask(Player),
}

impl Action {
    fn label(self) -> &'static str {
        match self {
            Action::Open(SettingsPane::Shortcuts) => "Open Shortcuts",
            Action::Open(_) => "Open System Settings",
            Action::Ask(_) => "Ask",
        }
    }

    fn run(self, app: &AppHandle) -> Result<(), String> {
        match self {
            Action::Open(pane) => crate::open_pane(pane),
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
        probe: |app| automation(app, Player::Spotify),
    },
    Check {
        id: "music",
        label: "Automation: Music",
        probe: |app| automation(app, Player::Music),
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
                false,
                "Not on edgebar's PATH. The workspace dots and the notch's workspace rules need it.",
            )
        },
    },
    Check {
        id: "themeCommand",
        label: "Theme command",
        probe: |app| {
            let cmd = app
                .state::<Mutex<ThemeState>>()
                .lock()
                .unwrap()
                .theme_command
                .clone();
            tool(
                &cmd,
                false,
                "Not found, so a wallpaper pick can't re-theme the bar. The Nix config installs it.",
            )
        },
    },
    Check {
        id: "wallpaperCommand",
        label: "Wallpaper command",
        probe: |app| {
            let cmd = app
                .state::<Mutex<ThemeState>>()
                .lock()
                .unwrap()
                .wallpaper_command
                .clone();
            tool(
                &cmd,
                false,
                "Not found, so the Wallpapers view can't set the desktop. The Nix config installs it.",
            )
        },
    },
    Check {
        id: "claude",
        label: "Claude CLI",
        probe: |_| {
            tool(
                &crate::load_config().assistant.command,
                true,
                "Not on PATH or in ~/.local/bin. Install Claude Code, or set the CLI command under Assistant.",
            )
        },
    },
];

/// Managed state: what each player's Automation ask found, by `Player`.
#[derive(Default)]
pub struct Setup {
    asked: Mutex<[Option<State>; 2]>,
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

/// Run the action check `id` offers right now, then probe everything again.
/// Blocks while macOS shows an Automation prompt, hence `spawn_blocking`.
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

// ───────────────────────── Full Disk Access ─────────────────────────

const INHERITED: &str = "edgebar has the permissions of the app that started it \
(kitty today, through herdr), so the grant goes to that app.";

/// What opening one protected file showed.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Opened {
    Yes,
    Refused,
    /// Missing or unreadable for some other reason: no evidence either way.
    Untested,
}

fn try_open(path: &Path) -> Opened {
    match std::fs::File::open(path) {
        Ok(_) => Opened::Yes,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => Opened::Refused,
        Err(_) => Opened::Untested,
    }
}

/// Judged by opening, never reading, the Focus file and macOS's notification
/// store. The store is opened only while `notifications.history` is on: off
/// means edgebar never touches it.
fn full_disk_access(_: &AppHandle) -> Status {
    let Some(home) = std::env::var_os("HOME").map(PathBuf::from) else {
        return Status::new(State::Unknown, "HOME is not set", None);
    };
    let history = crate::load_config().notifications.history;
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
            format!("Needed to read the Focus state and macOS's notification history. {INHERITED}"),
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
                "Nothing to test it on yet: the Focus file doesn't exist.{store_note} {INHERITED}"
            ),
            pane,
        )
    }
}

// ───────────────────────── Bluetooth ────────────────────────────────

fn bluetooth(_: &AppHandle) -> Status {
    let pane = Some(Action::Open(SettingsPane::PrivacyBluetooth));
    match toggles::bluetooth_permission() {
        Some(BluetoothPermission::Granted) => Status::new(
            State::Ready,
            "Granted to kitty, so the dashboard can switch Bluetooth.",
            None,
        ),
        Some(BluetoothPermission::NotAsked) => Status::new(
            State::Unknown,
            "Not asked yet. The first Bluetooth switch from the dashboard asks, for kitty.",
            None,
        ),
        Some(BluetoothPermission::Denied) => Status::new(
            State::Missing,
            "Refused, so the dashboard can't switch Bluetooth. Allow kitty under Privacy & Security, Bluetooth.",
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

// ───────────────────────── Automation ───────────────────────────────

#[cfg(target_os = "macos")]
fn installed(player: Player) -> bool {
    use objc2_app_kit::NSWorkspace;
    use objc2_foundation::NSString;
    NSWorkspace::sharedWorkspace()
        .URLForApplicationWithBundleIdentifier(&NSString::from_str(player.bundle_id()))
        .is_some()
}

#[cfg(not(target_os = "macos"))]
fn installed(_: Player) -> bool {
    false
}

/// Unknown until asked: telling without asking needs an AppleEvents call that
/// blocks for an unbundled process like the dev build (measured: it never
/// returned for a running Spotify). The answer of the last ask is kept.
fn automation(app: &AppHandle, player: Player) -> Status {
    let name = player.name();
    if !installed(player) {
        return Status::new(State::Unknown, format!("{name} isn't installed."), None);
    }
    match app.state::<Setup>().asked.lock().unwrap()[player as usize] {
        Some(State::Ready) => Status::new(
            State::Ready,
            format!("kitty may control {name}, so the player shows its track and its transport works."),
            None,
        ),
        Some(_) => Status::new(
            State::Missing,
            format!("Refused. Allow kitty to control {name} under Privacy & Security, Automation."),
            Some(Action::Open(SettingsPane::PrivacyAutomation)),
        ),
        None => Status::new(
            State::Unknown,
            format!("Not checked yet. Ask reads {name}'s player state once, so macOS asks if it hasn't already."),
            Some(Action::Ask(player)),
        ),
    }
}

/// The read is guarded by `is running`, so it never starts the player.
fn ask(app: &AppHandle, player: Player) -> Result<(), String> {
    let name = player.name();
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
    } else if stderr.contains("-1743") {
        // errAEEventNotPermitted: the user, or an earlier answer, refused.
        State::Missing
    } else {
        return Err(format!("{name} didn't answer: {stderr}"));
    };
    app.state::<Setup>().asked.lock().unwrap()[player as usize] = Some(state);
    Ok(())
}

// ───────────────────────── the Focus Shortcut ───────────────────────

fn focus_shortcut(app: &AppHandle) -> Status {
    let toggles = app.state::<Toggles>();
    let name = toggles.focus_shortcut();
    let shortcuts = Some(Action::Open(SettingsPane::Shortcuts));
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

// ───────────────────────── tools ────────────────────────────────────

/// Found the way edgebar runs it: a path as it is, a bare name on PATH (and in
/// `~/.local/bin` when `local_bin`, as the Assistant looks for the CLI).
fn tool(command: &str, local_bin: bool, missing: &str) -> Status {
    let path = std::env::var_os("PATH");
    let home = local_bin
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
        let found = tool("/bin/sh", false, "gone");
        assert_eq!(
            (found.state, found.detail.as_str()),
            (State::Ready, "/bin/sh")
        );
        let missing = tool("no-such-edgebar-tool", false, "gone");
        assert_eq!(
            (missing.state, missing.detail.as_str()),
            (State::Missing, "`no-such-edgebar-tool`: gone")
        );
    }

    #[test]
    fn each_action_has_a_button_label() {
        assert_eq!(
            Action::Open(SettingsPane::Shortcuts).label(),
            "Open Shortcuts"
        );
        assert_eq!(
            Action::Open(SettingsPane::FullDiskAccess).label(),
            "Open System Settings"
        );
        assert_eq!(Action::Ask(Player::Music).label(), "Ask");
    }
}
