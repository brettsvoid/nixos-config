// Tray menus are Qt platform menus, which need QApplication rather than the default
// QGuiApplication.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "frame"
import "services"

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = true

    // Hyprland's workspacev2 event does not say which monitor the workspace is on, so
    // Quickshell gives it to the monitor it last saw focused. Switching another screen
    // to a new workspace while the pointer is on this one moves focus there and back
    // before that event, so this screen takes the workspace and keeps it until it is
    // next focused. Re-reading the monitors once the burst of events is over puts each
    // screen's active workspace right again.
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

    // One set of windows per screen; screens added or removed come and go with
    // Quickshell.screens.
    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
