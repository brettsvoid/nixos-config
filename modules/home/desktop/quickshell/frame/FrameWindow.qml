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

    // 1 shows the frame in full; towards 0 its thickness, rounding and bar shrink to
    // nothing. ScreenShell animates it around fullscreen.
    property real reveal: 1

    readonly property real thickness: Theme.frameThickness * reveal
    readonly property real barHeight: Theme.barHeight * reveal
    readonly property real rounding: Theme.frameRounding * reveal
    readonly property real fillet: Theme.frameFillet * reveal

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

    // The whole window minus the area inside the frame, with the same corners as the
    // drawn shape: the fillet where the bar meets the sides, the rounding at the bottom.
    mask: Region {
        width: root.width
        height: root.height

        Region {
            x: root.thickness
            y: root.barHeight
            width: root.width - root.thickness * 2
            height: root.height - root.barHeight - root.thickness
            topLeftRadius: root.fillet
            topRightRadius: root.fillet
            bottomLeftRadius: root.rounding
            bottomRightRadius: root.rounding
            intersection: Intersection.Subtract
        }
    }

    FrameShape {
        anchors.fill: parent

        // The hole runs off the top of the screen: the bar is the top edge.
        hole: Qt.rect(root.thickness, -root.height, root.width - root.thickness * 2, root.height * 2 - root.thickness)
        holeRadius: root.rounding
        shapes: [
            {
                x: -Theme.frameFillet,
                y: -Theme.frameFillet,
                width: root.width + Theme.frameFillet * 2,
                height: root.barHeight + Theme.frameFillet,
                radius: 0
            }
        ]
        fillet: root.fillet
        shadowSize: Theme.frameShadowSize * root.reveal
        fillColor: Theme.frameColor
        shadowColor: Theme.frameShadowColor
    }

    Bar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.barHeight
        opacity: root.reveal
        screen: root.screen
    }
}
