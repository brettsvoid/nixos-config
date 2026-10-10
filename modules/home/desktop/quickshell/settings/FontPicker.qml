import QtQuick
import "../config"
import "../theme"

// Chooses the shell's font from the installed families, each shown in itself. Typing
// filters the list; the arrow keys move, Enter or a click chooses, Escape closes.
// The icons are Nerd Font glyphs: in a font without them, fontconfig falls back to one
// that has them (FiraCode Nerd Font here).
Rectangle {
    id: root

    signal done

    readonly property var families: {
        const query = search.text.trim().toLowerCase();
        return Qt.fontFamilies().filter(family => family.toLowerCase().includes(query));
    }

    function choose(family) {
        if (family)
            Settings.set("appearance.fontFamily", family);
        root.done();
    }

    color: Theme.surfaceDim
    radius: Theme.cornerLarge
    border.width: 1
    border.color: Theme.surfaceContainerHigh

    Component.onCompleted: {
        search.forceActiveFocus();
        list.currentIndex = Math.max(0, root.families.indexOf(Settings.fontFamily));
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }

    Rectangle {
        id: field
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingMedium
        height: 44
        radius: height / 2
        color: Theme.surfaceContainer

        TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingLarge
            anchors.rightMargin: Theme.spacingLarge
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
            clip: true

            onTextChanged: list.currentIndex = 0
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: root.choose(root.families[list.currentIndex])
            Keys.onEnterPressed: root.choose(root.families[list.currentIndex])
            Keys.onEscapePressed: root.done()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Search fonts"
                color: Theme.subtext
                font: search.font
            }
        }
    }

    ListView {
        id: list
        anchors.top: field.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingMedium
        clip: true
        model: root.families
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: row

            required property string modelData
            required property int index
            readonly property bool chosen: row.modelData === Settings.fontFamily

            width: ListView.view.width
            height: 40
            radius: Theme.cornerMedium
            color: row.ListView.isCurrentItem ? Theme.surfaceContainerHigh : "transparent"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: tick.left
                anchors.leftMargin: Theme.spacingMedium
                elide: Text.ElideRight
                text: row.modelData
                color: row.chosen ? Theme.primary : Theme.text
                font.family: row.modelData
                font.pixelSize: Theme.typeBodyLarge
            }

            Text {
                id: tick
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                visible: row.chosen
                text: String.fromCodePoint(0xF012C) // md-check
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleMedium
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = row.index
                onClicked: root.choose(row.modelData)
            }
        }
    }
}
