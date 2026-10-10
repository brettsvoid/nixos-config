import QtQuick
import Quickshell
import Quickshell.Hyprland
import "frame"

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

    // One set of windows per screen; screens added or removed come and go with
    // Quickshell.screens.
    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
