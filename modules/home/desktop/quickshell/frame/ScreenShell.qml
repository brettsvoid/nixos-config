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
    // there from shrinking this screen's frame away.
    readonly property bool fullscreen: {
        const ws = root.monitor?.activeWorkspace;
        if (!ws || ws.monitor !== root.monitor)
            return false;
        return ws.toplevels.values.some(t => t.wayland?.fullscreen ?? false);
    }

    // While fullscreen, the frame shrinks to nothing, which also leaves it no input
    // area, and grows back afterwards. The windows stay mapped. Hyprland fades Top-layer
    // surfaces out under a fullscreen window, and a faded one does not stop that window
    // being the only thing on the monitor (`solitary` in `hyprctl monitors`), which
    // direct scanout and tearing need. Mapping the five windows again instead took about
    // 120 ms each, which held the frame back for most of a second. The edges stay
    // reserved: a fullscreen window ignores them, and the windows behind it do not
    // re-tile.
    property real reveal: root.fullscreen ? 0 : 1

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.frameRevealDuration
            easing.type: Easing.InOutCubic
        }
    }

    EdgeReservation {
        screen: root.modelData
        edge: "top"
        size: Theme.barHeight
    }

    EdgeReservation {
        screen: root.modelData
        edge: "bottom"
        size: Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        edge: "left"
        size: Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        edge: "right"
        size: Theme.frameThickness
    }

    WallpaperWindow {
        screen: root.modelData
    }

    FrameWindow {
        screen: root.modelData
        reveal: root.reveal
    }
}
