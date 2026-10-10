import QtQuick
import Quickshell.Io
import "../components"
import "../theme"
import "binds.js" as Binds
import "../components/navigation.js" as Navigation

// The keybind cheatsheet drawer's content: every Hyprland bind, read when it opens,
// grouped by purpose. Typing filters by keys or description; Up and Down, or Ctrl+P and
// Ctrl+N, move through the list.
FocusScope {
    id: root

    property var allRows: []
    readonly property var words: field.text.toLowerCase().split(/\s+/).filter(w => w !== "")
    readonly property var rows: root.allRows.filter(r => {
        const text = (r.keys.join(" ") + " " + r.description + " " + r.group).toLowerCase();
        return root.words.every(w => text.includes(w));
    })

    implicitWidth: 720
    implicitHeight: search.height + Theme.spacingSmall + 520

    Process {
        command: ["hyprctl", "binds", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.allRows = Binds.rows(JSON.parse(text))
        }
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
            text: String.fromCodePoint(0xF030C) // md-keyboard
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

            Keys.onPressed: event => {
                const step = Navigation.step(event);
                if (step === 0)
                    return;
                list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + step));
                event.accepted = true;
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: field.text === ""
                text: "Search keybinds"
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
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingExtraSmall
        anchors.bottom: parent.bottom
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        section.property: "group"
        section.delegate: Text {
            required property string section

            width: ListView.view.width
            topPadding: Theme.spacingMedium
            bottomPadding: Theme.spacingExtraSmall
            leftPadding: Theme.spacingSmall
            text: section
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleSmall
            font.bold: true
        }

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 32
            radius: Theme.cornerSmall
            color: row.ListView.isCurrentItem ? Theme.surfaceContainerHigh : "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: list.currentIndex = row.index
            }

            Row {
                id: keys
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                spacing: Theme.spacingExtraSmall

                Repeater {
                    model: row.modelData.keys

                    Rectangle {
                        required property string modelData

                        width: keyText.implicitWidth + Theme.spacingMedium
                        height: 24
                        radius: Theme.cornerSmall
                        color: Theme.surfaceContainer

                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeLabelMedium
                        }
                    }
                }
            }

            Text {
                anchors.left: keys.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.description
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: list.top
        anchors.bottom: list.bottom
        anchors.right: parent.right
        flickable: list
    }
}
