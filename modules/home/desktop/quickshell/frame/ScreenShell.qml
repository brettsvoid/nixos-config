import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services"
import "../theme"

// Everything the shell puts on one screen: the wallpaper, the frame window, and four
// windows that keep tiled windows inside the frame and below the bar.
Scope {
    id: root

    // The screen, from the Variants over Quickshell.screens in shell.qml.
    required property var modelData

    readonly property var monitor: Hyprland.monitorFor(root.modelData)

    // A window in true fullscreen on this screen's workspace. Hyprland reports a
    // maximised window as `maximized` rather than `fullscreen` to foreign-toplevel
    // clients, so maximising keeps the frame. Quickshell can briefly hold another
    // screen's new workspace as this one's (see shell.qml); checking the workspace's
    // own monitor stops a fullscreen window over there shrinking this frame.
    readonly property bool fullscreen: {
        const ws = root.monitor?.activeWorkspace;
        if (!ws || ws.monitor !== root.monitor)
            return false;
        return ws.toplevels.values.some(t => t.wayland?.fullscreen ?? false);
    }

    // While fullscreen, the frame shrinks to nothing, which also leaves it no input
    // area, and grows back afterwards. The windows stay mapped: Hyprland fades
    // Top-layer surfaces out under a fullscreen window, and a faded one still lets that
    // window be `solitary` (`hyprctl monitors`), which direct scanout and tearing need.
    // Don't unmap them instead: remapping takes about 120 ms a window. The edges stay
    // reserved, as a fullscreen window ignores them and nothing behind it re-tiles.
    //
    // Game mode (services/GameMode.qml) does the same, and also releases the edges, so
    // a windowed game gets the whole screen.
    property real reveal: root.fullscreen || GameMode.on ? 0 : 1

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.frameRevealDuration
            easing.type: Easing.InOutCubic
        }
    }

    EdgeReservation {
        screen: root.modelData
        edge: "top"
        size: GameMode.on ? 0 : Theme.barHeight
    }

    EdgeReservation {
        screen: root.modelData
        edge: "bottom"
        size: GameMode.on ? 0 : Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        edge: "left"
        size: GameMode.on ? 0 : Theme.frameThickness
    }

    EdgeReservation {
        screen: root.modelData
        edge: "right"
        size: GameMode.on ? 0 : Theme.frameThickness
    }

    WallpaperWindow {
        screen: root.modelData
    }

    FrameWindow {
        screen: root.modelData
        reveal: root.reveal
    }
}
