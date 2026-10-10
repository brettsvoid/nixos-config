// Tray menus are Qt platform menus, which need QApplication rather than the default
// QGuiApplication.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "frame"
import "lock"
import "services"

ShellRoot {
    Component.onCompleted: {
        Quickshell.watchFiles = true;
        // Read the desktop entries now, not on the launcher's first open.
        DesktopEntries.applications;
        // Set the lock up now, so the first lock does not wait for it.
        Lock.locked;
    }

    // Hyprland's workspacev2 event does not name the monitor, so Quickshell gives the
    // workspace to the monitor it last saw focused. Switching another screen's
    // workspace while the pointer is here moves focus there and back first, so this
    // screen takes it. Re-reading the monitors once the events settle puts each screen
    // right again.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "workspacev2")
                monitorRefresh.restart();
        }
    }

    Timer {
        id: monitorRefresh

        interval: 50
        onTriggered: Hyprland.refreshMonitors()
    }

    // Hyprland binds the keys to these (custom-shell.nix). Each drawer opens on the
    // focused monitor.
    GlobalShortcut {
        appid: "custom-shell"
        name: "session"
        description: "Open or close the session menu"
        onPressed: Drawers.toggle("session")
    }

    GlobalShortcut {
        appid: "custom-shell"
        name: "launcher"
        description: "Open or close the app launcher"
        onPressed: Drawers.toggle("launcher")
    }

    GlobalShortcut {
        appid: "custom-shell"
        name: "cheatsheet"
        description: "Open or close the keybind cheatsheet"
        onPressed: Drawers.toggle("cheatsheet")
    }

    GlobalShortcut {
        appid: "custom-shell"
        name: "notifications"
        description: "Open or close the notification history"
        onPressed: Drawers.toggle("notifications")
    }

    GlobalShortcut {
        appid: "custom-shell"
        name: "dashboard"
        description: "Open or close the dashboard"
        onPressed: Drawers.toggle("dashboard")
    }

    // Super+L, and hypridle on `loginctl lock-session` (before sleep). There is no
    // unlock shortcut: only the password unlocks.
    GlobalShortcut {
        appid: "custom-shell"
        name: "lock"
        description: "Lock the session"
        onPressed: Lock.lock()
    }

    // One set of windows per screen; screens added or removed come and go with
    // Quickshell.screens.
    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
