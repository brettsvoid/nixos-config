import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

Item {
    id: root

    required property var screen

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

    property int workspaceCount: 10

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.workspaceCount

            Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeWorkspaceId
                readonly property bool hasWindows: {
                    // Hyprland.workspaces is an ObjectModel — iterate .values, not
                    // a non-existent .count/.get(). Reading .toplevels.values keeps
                    // this binding reactive to windows opening/closing.
                    const ws = Hyprland.workspaces.values.find(w => w.id === wsId)
                    return ws ? ws.toplevels.values.length > 0 : false
                }

                Layout.preferredWidth: isActive ? 24 : 8
                implicitHeight: 8
                radius: 4
                color: isActive ? Theme.wsActive : (hasWindows ? Theme.wsOccupied : Theme.wsEmpty)

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: Theme.barHeight
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }
    }
}
