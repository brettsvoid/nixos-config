import QtQuick
import "../components"
import "../theme"
import "index.js" as Index

// A page of setting rows that scrolls when they do not fit. Its children go in one
// column.
FocusScope {
    id: root

    default property alias content: column.data

    // Ctrl+D and Ctrl+U, from the settings window.
    function halfPage(direction) {
        scrollBar.halfPage(direction, false);
    }

    // Scrolls the row with `key` to the middle and lights it up (a search result).
    function reveal(key) {
        column.forceLayout();
        const row = Index.rowFor(column.children, key);
        if (!row)
            return;
        page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, row.y + row.height / 2 - page.height / 2));
        row.flash();
    }

    Flickable {
        id: page
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingSmall
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: page.top
        anchors.bottom: page.bottom
        anchors.right: parent.right
        flickable: page
    }
}
