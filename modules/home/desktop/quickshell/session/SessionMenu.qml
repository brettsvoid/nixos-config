import QtQuick
import Quickshell
import "../services"
import "../theme"

// The session drawer's content: lock, log out, restart and shut down. The arrow keys
// move between them, Enter or a click runs one. Log out, restart and shut down go
// through session-exit, which saves the open apps for the next login.
FocusScope {
    id: root

    readonly property var actions: [
        {
            icon: 0xF033E, // nf-md-lock
            label: "Lock",
            command: ["hyprlock"]
        },
        {
            icon: 0xF0343, // nf-md-logout
            label: "Log out",
            command: ["session-exit", "logout"]
        },
        {
            icon: 0xF0709, // nf-md-restart
            label: "Restart",
            command: ["session-exit", "reboot"]
        },
        {
            icon: 0xF0425, // nf-md-power
            label: "Shut down",
            command: ["session-exit", "poweroff"]
        }
    ]
    property int current: 0

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    function run(index) {
        Quickshell.execDetached(root.actions[index].command);
        Drawers.close();
    }

    Keys.onUpPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
    Keys.onDownPressed: root.current = (root.current + 1) % root.actions.length
    Keys.onReturnPressed: root.run(root.current)
    Keys.onEnterPressed: root.run(root.current)

    Column {
        id: column
        spacing: Theme.spacingSmall

        Repeater {
            model: root.actions

            Rectangle {
                id: button

                required property var modelData
                required property int index
                readonly property bool current: button.index === root.current

                implicitWidth: 176
                implicitHeight: 48
                radius: Theme.cornerLarge
                color: button.current ? Theme.primary : Theme.surfaceContainer

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animDuration
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingLarge
                    spacing: Theme.spacingMedium

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(button.modelData.icon)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeTitleLarge
                        color: button.current ? Theme.onPrimary : Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: button.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeBodyLarge
                        color: button.current ? Theme.onPrimary : Theme.text
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = button.index
                    onClicked: root.run(button.index)
                }
            }
        }
    }
}
