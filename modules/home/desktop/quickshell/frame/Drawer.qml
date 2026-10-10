import QtQuick
import "../components"
import "../services"
import "../theme"

// A panel that grows out of one edge of the frame. Its background is a box in the frame's
// shape (`shape`, for FrameShape), so it joins the frame with fillets at every point of
// the motion, and its content only exists while it shows. It fills FrameWindow, so its
// coordinates are the screen's.
Item {
    id: root

    // "right", "left", "top" or "bottom".
    property string edge: "right"
    property bool open: false
    property Component content
    // The inside of the frame. The drawer centres on it, and the content is clipped to
    // it, so it slides out from behind the frame.
    property rect inside
    // How thick the frame is along this edge.
    readonly property real inset: {
        switch (root.edge) {
        case "left":
            return root.inside.x;
        case "right":
            return root.width - root.inside.x - root.inside.width;
        case "top":
            return root.inside.y;
        default:
            return root.height - root.inside.y - root.inside.height;
        }
    }

    readonly property bool shown: root.open || spring.running
    // The part of the screen it covers, for the window's input mask.
    readonly property Item hitArea: hit
    // The box for FrameShape: { x, y, width, height, radius }.
    readonly property var shape: ({
            x: root.box.x,
            y: root.box.y,
            width: root.box.width,
            height: root.box.height,
            radius: Theme.drawerRadius
        })

    readonly property bool sideways: root.edge === "left" || root.edge === "right"
    readonly property real panelWidth: (loader.item?.implicitWidth ?? 0) + Theme.drawerPadding * 2
    readonly property real panelHeight: (loader.item?.implicitHeight ?? 0) + Theme.drawerPadding * 2
    // How far the panel reaches into the frame when open.
    readonly property real extent: root.sideways ? root.panelWidth : root.panelHeight
    readonly property real breadth: root.sideways ? root.panelHeight : root.panelWidth
    // Distance from the screen edge to the box's inner edge. Closed, that edge waits a
    // fillet's width behind the frame's inner edge: the fillet union blends any two edges
    // closer than that, so closer it would bulge the frame. As it comes out it raises a
    // smooth bump first, then a panel joined by fillets.
    readonly property real reach: root.inset - Theme.frameFillet + Math.max(spring.value, 0) * (root.extent + Theme.frameFillet)
    // The box runs this far past the screen edge, so its outer corners never show.
    readonly property real overhang: Theme.drawerRadius + 1
    readonly property real centreX: root.inside.x + root.inside.width / 2
    readonly property real centreY: root.inside.y + root.inside.height / 2
    readonly property rect box: {
        switch (root.edge) {
        case "left":
            return Qt.rect(-root.overhang, root.centreY - root.breadth / 2, root.reach + root.overhang, root.breadth);
        case "right":
            return Qt.rect(root.width - root.reach, root.centreY - root.breadth / 2, root.reach + root.overhang, root.breadth);
        case "top":
            return Qt.rect(root.centreX - root.breadth / 2, -root.overhang, root.breadth, root.reach + root.overhang);
        default:
            return Qt.rect(root.centreX - root.breadth / 2, root.height - root.reach, root.breadth, root.reach + root.overhang);
        }
    }

    Spring {
        id: spring
        spec: Theme.drawerSpring
        target: root.open ? 1 : 0
    }

    Item {
        id: hit
        x: Math.max(root.box.x, 0)
        y: Math.max(root.box.y, 0)
        width: Math.max(Math.min(root.box.x + root.box.width, root.width) - x, 0)
        height: Math.max(Math.min(root.box.y + root.box.height, root.height) - y, 0)
    }

    Item {
        x: root.inside.x
        y: root.inside.y
        width: root.inside.width
        height: root.inside.height
        clip: true
        visible: root.shown

        // The open panel, travelling with the box's inner edge.
        Item {
            id: panel
            x: {
                switch (root.edge) {
                case "left":
                    return root.reach - root.panelWidth - parent.x;
                case "right":
                    return root.width - root.reach - parent.x;
                default:
                    return root.box.x - parent.x;
                }
            }
            y: {
                switch (root.edge) {
                case "top":
                    return root.reach - root.panelHeight - parent.y;
                case "bottom":
                    return root.height - root.reach - parent.y;
                default:
                    return root.box.y - parent.y;
                }
            }
            width: root.panelWidth
            height: root.panelHeight

            Keys.onEscapePressed: Drawers.close()

            Loader {
                id: loader
                anchors.fill: parent
                anchors.margins: Theme.drawerPadding
                active: root.shown
                sourceComponent: root.content
                focus: true

                onLoaded: item.forceActiveFocus()
            }
        }
    }
}
