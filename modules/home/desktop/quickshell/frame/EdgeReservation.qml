import QtQuick
import Quickshell
import Quickshell.Wayland

// Keeps tiled windows off one screen edge. Only the exclusive zone matters: the
// window is 1 px, transparent and takes no input. The frame window cannot reserve
// the edges itself, because it covers the whole screen and ignores exclusive zones.
PanelWindow {
    id: root

    // "top", "bottom", "left" or "right".
    required property string edge
    // How far in from that edge tiled windows start.
    required property int size

    anchors {
        top: root.edge !== "bottom"
        bottom: root.edge !== "top"
        left: root.edge !== "right"
        right: root.edge !== "left"
    }

    implicitWidth: 1
    implicitHeight: 1
    exclusiveZone: root.size
    color: "transparent"

    // An empty region makes the window transparent for input.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "custom-shell-edge"
}
