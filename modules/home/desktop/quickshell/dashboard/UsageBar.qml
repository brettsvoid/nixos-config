import QtQuick
import "../theme"

// A label, "used / total", and a bar, for memory, swap and disks.
Column {
    id: root

    property string label
    property real used
    property real total
    // Formats a byte count.
    property var format: n => String(n)

    spacing: Theme.spacingExtraSmall

    Item {
        width: parent.width
        height: labelText.implicitHeight

        Text {
            id: labelText
            anchors.left: parent.left
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyMedium
        }

        Text {
            anchors.right: parent.right
            text: root.format(root.used) + " / " + root.format(root.total)
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabelMedium
        }
    }

    Rectangle {
        width: parent.width
        height: 6
        radius: height / 2
        color: Theme.surfaceContainer

        Rectangle {
            width: root.total > 0 ? parent.width * Math.min(1, root.used / root.total) : 0
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }
}
