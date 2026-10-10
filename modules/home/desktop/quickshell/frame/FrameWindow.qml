import QtQuick
import Quickshell
import Quickshell.Wayland
import "../bar"
import "../theme"

// The frame and bar for one screen, in one window that covers the whole screen.
// It ignores exclusive zones (EdgeReservation makes those) and takes input only on
// the frame and the bar, so clicks inside the frame reach the windows underneath.
// Top layer, never Overlay: an always-mapped Overlay surface stops Hyprland sending
// a fullscreen game straight to the display.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "custom-shell-frame"

    // The whole window minus the area inside the frame.
    mask: Region {
        width: root.width
        height: root.height

        Region {
            x: Theme.frameThickness
            y: Theme.barHeight
            width: root.width - Theme.frameThickness * 2
            height: root.height - Theme.barHeight - Theme.frameThickness
            intersection: Intersection.Subtract
        }
    }

    // Plain rectangles for now; the frame shader (custom-shell issue 03) replaces them.
    Rectangle {
        id: topEdge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.barHeight
        color: Theme.frameColor
    }

    Rectangle {
        id: leftEdge
        anchors.top: topEdge.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Theme.frameThickness
        color: Theme.frameColor
    }

    Rectangle {
        id: rightEdge
        anchors.top: topEdge.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Theme.frameThickness
        color: Theme.frameColor
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: leftEdge.right
        anchors.right: rightEdge.left
        height: Theme.frameThickness
        color: Theme.frameColor
    }

    Bar {
        anchors.fill: topEdge
        screen: root.screen
    }
}
