import QtQuick
import "../theme"

// A horizontal slider for a number from `from` to `to`, in steps of `stepSize`. Drag
// it, click the track, scroll over it, or use the arrow keys once it has focus. It
// does not change `value` itself: `moved` reports each new value, so `value` can stay
// bound to what it shows.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real value: 0

    signal moved(real value)

    readonly property real fraction: (Math.min(Math.max(root.value, root.from), root.to) - root.from) / (root.to - root.from)

    implicitWidth: 240
    implicitHeight: 24
    activeFocusOnTab: true

    function _move(to) {
        const stepped = Math.round((to - root.from) / root.stepSize) * root.stepSize + root.from;
        const clamped = Number(Math.min(Math.max(stepped, root.from), root.to).toFixed(4));
        if (clamped !== root.value)
            root.moved(clamped);
    }

    Keys.onLeftPressed: root._move(root.value - root.stepSize)
    Keys.onRightPressed: root._move(root.value + root.stepSize)

    Rectangle {
        id: track
        x: handle.width / 2
        width: root.width - handle.width
        height: 6
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.surfaceContainerHigh

        Rectangle {
            width: root.fraction * track.width
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }

    Rectangle {
        id: handle
        x: root.fraction * track.width
        width: 18
        height: width
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: Theme.primary
        border.width: root.activeFocus ? 3 : 0
        border.color: Theme.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function valueAt(x) {
            const fraction = Math.min(Math.max((x - track.x) / track.width, 0), 1);
            return root.from + fraction * (root.to - root.from);
        }

        onPressed: mouse => {
            root.forceActiveFocus();
            root._move(valueAt(mouse.x));
        }
        onPositionChanged: mouse => {
            if (pressed)
                root._move(valueAt(mouse.x));
        }
        onWheel: wheel => root._move(root.value + Math.sign(wheel.angleDelta.y) * root.stepSize)
    }
}
