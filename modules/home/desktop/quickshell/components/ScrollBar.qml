import QtQuick
import "../theme"

// A scrollbar for a Flickable, ListView or GridView, placed beside it (a sibling): drag
// the thumb, or click the track to move a page. Hidden while everything fits.
//
// It also takes over the mouse wheel over the view: a notch moves it `wheelStep` pixels,
// with a short animation, and a touchpad moves it by its own pixel amount. Flickable's
// own wheel handling turns a notch into a flick of about 72 px, which felt slow. The
// wheel is caught by an area over the view, as a sibling: Flickable takes wheel events
// from its children, so a handler inside it never sees them. That area takes only the
// wheel, so clicks and hover still reach the view.
//
// The keys are left to the view's owner, which knows what has focus: it calls
// halfPage() for Ctrl+D and Ctrl+U (navigation.js).
Item {
    id: root

    required property Flickable flickable
    // Pixels a wheel notch moves.
    property real wheelStep: 160

    readonly property real contentHeight: root.flickable.contentHeight
    // The content's first and last scroll positions.
    readonly property real firstY: root.flickable.originY
    readonly property real lastY: root.flickable.originY + Math.max(0, root.contentHeight - root.flickable.height)
    readonly property bool needed: root.contentHeight > root.flickable.height + 1

    // Scrolls to `y` (content coordinates), kept within the content.
    function scrollTo(y, animate) {
        const clamped = Math.max(root.firstY, Math.min(root.lastY, y));
        motion.stop();
        if (animate) {
            motion.to = clamped;
            motion.start();
        } else {
            root.flickable.contentY = clamped;
        }
    }

    function scrollBy(delta) {
        // Repeated notches add up from where the last one was heading.
        const from = motion.running ? motion.to : root.flickable.contentY;
        root.scrollTo(from + delta, true);
    }

    // Half a page down (1) or up (-1), for Ctrl+D and Ctrl+U. With `moveCurrent`, the
    // view's current item (a ListView's or GridView's) moves as far too, as in Vim, so
    // it keeps its place on screen; where the view can go no further, the current item
    // still moves. That takes no animation: the view keeps its current item in sight,
    // and would jump to it part way through one.
    function halfPage(direction, moveCurrent) {
        const view = root.flickable;
        const distance = direction * view.height / 2;
        const current = moveCurrent ? view.currentItem : null;
        if (!current) {
            root.scrollBy(distance);
            return;
        }
        const before = view.contentY;
        // Where its middle is on screen; one scrolled out of sight counts as at the edge.
        const offset = Math.max(0, Math.min(view.height - 1, current.y + current.height / 2 - before));
        root.scrollTo(before + distance, false);
        view.forceLayout();
        // The item half a page on from that place, in the same column (a GridView's). A
        // section heading or gap has no item, so it looks on in the same direction; past
        // either end, it is the first or last item.
        const x = current.x + current.width / 2;
        const end = view.originY + view.contentHeight;
        let index = -1;
        for (let y = before + offset + distance; index < 0 && y >= view.originY && y < end; y += direction * 4)
            index = view.indexAt(x, y);
        if (index < 0)
            index = direction > 0 ? view.count - 1 : 0;
        view.currentIndex = index;
    }

    implicitWidth: 8
    visible: root.needed

    NumberAnimation {
        id: motion
        target: root.flickable
        property: "contentY"
        duration: Theme.animDuration
        easing.type: Easing.OutCubic
    }

    // A handler, not a MouseArea: Qt delivers the wheel only to items that accept a mouse
    // button, and a MouseArea that did would take the clicks too. Placed by x and y, not
    // anchors, which are set before the new parent and so fail.
    Item {
        parent: root.flickable.parent
        x: root.flickable.x
        y: root.flickable.y
        width: root.flickable.width
        height: root.flickable.height
        z: root.flickable.z + 1

        WheelHandler {
            target: null
            enabled: root.needed
            // Touchpads too: by default it takes only mice.
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.pixelDelta.y !== 0)
                    root.scrollTo(root.flickable.contentY - event.pixelDelta.y, false);
                else
                    root.scrollBy(-event.angleDelta.y / 120 * root.wheelStep);
            }
        }
    }

    Rectangle {
        id: thumb
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - (drag.containsMouse || drag.pressed ? 0 : 2)
        height: Math.max(24, root.height * root.flickable.height / Math.max(1, root.contentHeight))
        y: root.lastY > root.firstY ? (root.flickable.contentY - root.firstY) / (root.lastY - root.firstY) * (root.height - height) : 0
        radius: width / 2
        color: drag.pressed ? Theme.primary : drag.containsMouse ? Theme.subtext : Qt.alpha(Theme.subtext, 0.4)
    }

    MouseArea {
        id: drag

        // Where on the thumb it was grabbed.
        property real grab: -1

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                drag.grab = mouse.y - thumb.y;
            } else {
                drag.grab = -1;
                root.scrollBy((mouse.y < thumb.y ? -1 : 1) * root.flickable.height);
            }
        }
        onPositionChanged: mouse => {
            if (!pressed || drag.grab < 0)
                return;
            const travel = root.height - thumb.height;
            const fraction = travel > 0 ? (mouse.y - drag.grab) / travel : 0;
            root.scrollTo(root.firstY + fraction * (root.lastY - root.firstY), false);
        }
    }
}
