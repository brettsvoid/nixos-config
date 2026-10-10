import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"
import "../theme"

// The launcher drawer's content: a search field over a list of results. What the list
// shows depends on the mode, picked by the prefix the query starts with; apps are the
// mode without one. A mode provides `prefix`, `placeholder`, `results(query)` and
// `activate(item)`, and optionally `refresh()`, called when the mode is entered; it is
// added to `modes`.
FocusScope {
    id: root

    readonly property var modes: [appsMode, clipboardMode]
    readonly property var mode: root.modes.find(m => m.prefix !== "" && field.text.startsWith(m.prefix)) ?? appsMode
    readonly property string query: field.text.slice(root.mode.prefix.length).trim()
    readonly property var results: root.mode.results(root.query)
    readonly property int rows: 8
    readonly property int rowHeight: 48

    implicitWidth: 560
    implicitHeight: search.height + Theme.spacingSmall + root.rows * root.rowHeight

    function activate(index) {
        const item = root.results[index];
        if (!item)
            return;
        root.mode.activate(item);
        Drawers.close();
    }

    onModeChanged: root.mode.refresh?.()

    AppsMode {
        id: appsMode
    }

    ClipboardMode {
        id: clipboardMode
    }

    Rectangle {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        radius: Theme.cornerLarge
        color: Theme.surfaceContainer

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0349) // md-magnify
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleLarge
        }

        TextInput {
            id: field
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.text
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
            clip: true

            onTextChanged: list.currentIndex = 0

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: root.activate(list.currentIndex)
            Keys.onEnterPressed: root.activate(list.currentIndex)

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: field.text === ""
                text: root.mode.placeholder
                color: Theme.subtext
                font: field.font
            }
        }
    }

    ListView {
        id: list
        anchors.top: search.bottom
        anchors.topMargin: Theme.spacingSmall
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rows * root.rowHeight
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem

            width: ListView.view.width
            height: root.rowHeight
            radius: Theme.cornerLarge
            color: row.current ? Theme.primary : "transparent"

            IconImage {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 32
                asynchronous: true
                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
            }

            Column {
                anchors.left: rowIcon.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.title
                    color: row.current ? Theme.onPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyLarge
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    text: row.modelData.subtitle ?? ""
                    color: row.current ? Theme.onPrimary : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodySmall
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = row.index
                onClicked: root.activate(row.index)
            }
        }
    }
}
