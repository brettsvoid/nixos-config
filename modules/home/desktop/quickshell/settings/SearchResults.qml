import QtQuick
import "../components"
import "../theme"

// The settings that match the search, best first: the label, and the page and heading
// it is under. The window sends the keys; the mouse moves the current one by hover and
// chooses by click.
Item {
    id: root

    // Entries of index.js.
    property var results: []

    signal chosen(var entry)

    function step(direction) {
        if (direction > 0)
            list.incrementCurrentIndex();
        else
            list.decrementCurrentIndex();
    }

    function halfPage(direction) {
        scrollBar.halfPage(direction, true);
    }

    function chooseCurrent() {
        const entry = root.results[list.currentIndex];
        if (entry)
            root.chosen(entry);
    }

    // A new search starts from its best match.
    onResultsChanged: list.currentIndex = 0

    ListView {
        id: list
        anchors.fill: parent
        anchors.rightMargin: scrollBar.width + Theme.spacingSmall
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 56
            radius: Theme.cornerMedium
            color: row.ListView.isCurrentItem ? Theme.surfaceContainerHigh : "transparent"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyLarge
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.heading ? `${row.modelData.page} › ${row.modelData.heading}` : "Page"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodySmall
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = row.index
                onClicked: root.chosen(row.modelData)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.results.length === 0
        text: "No setting matches"
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }

    ScrollBar {
        id: scrollBar
        anchors.top: list.top
        anchors.bottom: list.bottom
        anchors.right: parent.right
        flickable: list
    }
}
