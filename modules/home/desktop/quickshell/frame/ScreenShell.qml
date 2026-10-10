import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

// Everything the shell puts on one screen: the frame window, and four windows that
// keep tiled windows inside the frame and below the bar.
Scope {
    id: root

    // The screen, from the Variants over Quickshell.screens in shell.qml.
    required property var modelData

    readonly property var monitor: Hyprland.monitorFor(root.modelData)

    // A window in true fullscreen on this screen's workspace. Hyprland reports a
    // maximised window as `maximized` rather than `fullscreen` to foreign-toplevel
    // clients, so maximising keeps the frame.
    //
    // For a moment after another screen switches to a new workspace, Quickshell can
    // hold that workspace as this screen's active one (see shell.qml). The workspace's
    // own monitor comes from Hyprland, so checking it stops a fullscreen window over
    // there from hiding this screen's frame and re-tiling its windows.
    readonly property bool fullscreen: {
        const ws = root.monitor?.activeWorkspace;
        if (!ws || ws.monitor !== root.monitor)
            return false;
        return ws.toplevels.values.some(t => t.wayland?.fullscreen ?? false);
    }

    // While fullscreen, every window here is unmapped: nothing reserved, drawn or
    // clickable, so a game can go straight to the display.
    readonly property bool shown: !root.fullscreen

    EdgeReservation {
        screen: root.modelData
        visible: root.shown
        edge: "top"
        size: Theme.barHeight
    }

    EdgeReservation {
        screen: root.modelData
        visible: root.shown
        edge: "bottom"
        size: Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        visible: root.shown
        edge: "left"
        size: Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        visible: root.shown
        edge: "right"
        size: Theme.frameThickness
    }

    FrameWindow {
        screen: root.modelData
        visible: root.shown
    }
}
