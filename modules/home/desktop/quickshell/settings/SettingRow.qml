import QtQuick
import "../config"
import "../theme"

// One setting: its name on the left, its control (the row's children) in the middle,
// and a button to put it back to the default while it is set.
Item {
    id: root

    property string label
    // Its key in config/Settings.qml.
    property string key
    default property alias control: holder.data

    width: parent?.width ?? 0
    implicitHeight: 48

    Text {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        // Room for the longest name, at any text size.
        width: Theme.typeBodyLarge * 11
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }

    Item {
        id: holder
        anchors.left: name.right
        anchors.right: reset.left
        anchors.rightMargin: Theme.spacingMedium
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    Rectangle {
        id: reset
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: width
        radius: width / 2
        visible: Settings.isSet(root.key)
        color: area.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF054C) // md-undo
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Settings.reset(root.key)
        }
    }
}
