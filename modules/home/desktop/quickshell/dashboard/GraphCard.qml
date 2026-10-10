import QtQuick
import "../theme"

// A title, a big value, a line of detail and a history graph, for the performance tab.
Rectangle {
    id: root

    property string title
    property string value
    property string detail
    property alias values: graph.values
    property alias capacity: graph.capacity

    height: 140
    radius: Theme.cornerLarge
    color: Theme.surfaceContainer

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingMedium
        anchors.right: valueText.left
        elide: Text.ElideRight
        text: root.title
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeLabelLarge
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingMedium
        text: root.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleLarge
        font.bold: true
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: valueText.bottom
        anchors.leftMargin: Theme.spacingMedium
        anchors.rightMargin: Theme.spacingMedium
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: root.detail
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeLabelMedium
    }

    HistoryGraph {
        id: graph
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingMedium
        height: 56
    }
}
