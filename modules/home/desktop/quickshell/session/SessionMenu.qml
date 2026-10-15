import QtQuick
import Quickshell
import "../config"
import "../lock"
import "../services"
import "../theme"
import "../components/navigation.js" as Navigation

// The session drawer's content: lock, sleep (if the settings show it), log out, restart
// and shut down, then the shell's settings. Up and Down, or Ctrl+P and Ctrl+N, move
// between them; Enter or a click runs one. Lock is the shell's own lock screen; log
// out, restart and shut down go through session-exit, which saves the open apps for the
// next login, and with the settings' confirm on they wait for a second press.
FocusScope {
    id: root

    readonly property var actions: [
        {
            icon: 0xF033E, // md-lock
            label: "Lock",
            run: () => Lock.lock()
        },
        {
            icon: 0xF0904, // md-power_sleep
            label: "Sleep",
            // Locks first: hypridle locks on logind's request.
            command: ["systemctl", "suspend"],
            hidden: !Settings.session.showSleep
        },
        {
            icon: 0xF0343, // md-logout
            label: "Log out",
            command: ["session-exit", "logout"],
            dangerous: true
        },
        {
            icon: 0xF0709, // md-restart
            label: "Restart",
            command: ["session-exit", "reboot"],
            dangerous: true
        },
        {
            icon: 0xF0425, // md-power
            label: "Shut down",
            command: ["session-exit", "poweroff"],
            dangerous: true
        },
        {
            icon: 0xF0493, // md-cog
            label: "Settings",
            run: () => Windows.showSettings()
        }
    ].filter(action => !action.hidden)
    property int current: 0
    // The entry waiting for its second press, or -1. Moving to another gives it up.
    property int pending: -1

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    onCurrentChanged: root.pending = -1

    function run(index) {
        const action = root.actions[index];
        if (action.dangerous && Settings.session.confirm && root.pending !== index) {
            root.pending = index;
            return;
        }
        if (action.run)
            action.run();
        else
            Quickshell.execDetached(action.command);
        Drawers.close();
    }

    Keys.onPressed: event => {
        const step = Navigation.step(event);
        if (step === 0)
            return;
        root.current = (root.current + step + root.actions.length) % root.actions.length;
        event.accepted = true;
    }
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
                        text: button.index === root.pending ? "Press again" : button.modelData.label
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
