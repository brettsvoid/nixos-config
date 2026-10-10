import QtQuick
import Quickshell
import "../lock"
import "../services"
import "../theme"

// The session drawer's content: lock, log out, restart and shut down, then the shell's
// settings. The arrow keys move between them, Enter or a click runs one. Lock is the
// shell's own lock screen; log out, restart and shut down go through session-exit,
// which saves the open apps for the next login.
FocusScope {
    id: root

    readonly property var actions: [
        {
            icon: 0xF033E, // md-lock
            label: "Lock",
            run: () => Lock.lock()
        },
        {
            icon: 0xF0343, // md-logout
            label: "Log out",
            command: ["session-exit", "logout"]
        },
        {
            icon: 0xF0709, // md-restart
            label: "Restart",
            command: ["session-exit", "reboot"]
        },
        {
            icon: 0xF0425, // md-power
            label: "Shut down",
            command: ["session-exit", "poweroff"]
        },
        {
            icon: 0xF0493, // md-cog
            label: "Settings",
            run: () => Windows.showSettings()
        }
    ]
    property int current: 0

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    function run(index) {
        const action = root.actions[index];
        if (action.run)
            action.run();
        else
            Quickshell.execDetached(action.command);
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
