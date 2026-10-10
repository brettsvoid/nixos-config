import QtQuick
import "../theme"

// A rounded button with a label, highlighted while `active`.
Rectangle {
    id: root

    property string text
    property bool active: false

    signal clicked

    width: label.implicitWidth + Theme.spacingLarge * 2
    height: 32
    radius: height / 2
    color: root.active ? Theme.primary : area.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.active ? Theme.onPrimary : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeLabelLarge
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
