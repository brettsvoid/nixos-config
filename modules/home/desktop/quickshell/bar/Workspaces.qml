import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland._Ipc
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
                    for (var i = 0; i < Hyprland.workspaces.count; i++) {
                        var ws = Hyprland.workspaces.get(i)
                        if (ws && ws.id === wsId) {
                            return ws.toplevels.count > 0
                        }
                    }
                    return false
                }

                Layout.preferredWidth: isActive ? 24 : 8
                implicitHeight: 8
                radius: 4
                color: isActive ? Theme.wsActive : (hasWindows ? Theme.wsOccupied : Theme.wsEmpty)

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
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
