import QtQuick
import "../theme"

// A small pill button with an icon and a label, for the history drawer's header.
Rectangle {
    id: root

    property int glyph
    property string label
    property bool active: false

    signal clicked

    width: row.implicitWidth + Theme.spacingMedium * 2
    height: 32
    radius: height / 2
    opacity: root.enabled ? 1 : 0.4
    color: root.active ? Theme.primary : area.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingExtraSmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(root.glyph)
            color: root.active ? Theme.onPrimary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.active ? Theme.onPrimary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabelLarge
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
