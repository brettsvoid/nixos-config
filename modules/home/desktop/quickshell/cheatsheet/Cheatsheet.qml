import QtQuick
import Quickshell.Io
import "../theme"
import "binds.js" as Binds

// The keybind cheatsheet drawer's content: every Hyprland bind, read when it opens,
// grouped by purpose. Typing filters by keys or description.
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

            Keys.onUpPressed: list.flick(0, 800)
            Keys.onDownPressed: list.flick(0, -800)

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
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

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

        delegate: Item {
            id: row

            required property var modelData

            width: ListView.view.width
            height: 32

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
}
