import QtQuick
import "../theme"

// A round button with an icon.
Rectangle {
    id: button

    property int glyph

    signal clicked

    width: 36
    height: width
    radius: width / 2
    color: buttonArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(button.glyph)
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleMedium
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
