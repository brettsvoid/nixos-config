import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../theme"

// Apps' tray icons. Left click activates the app (or opens its menu, when that is all it
// offers), right click opens its menu, middle click runs its secondary action, and the
// wheel scrolls it.
Row {
    id: root

    spacing: Theme.spacingSmall
    visible: repeater.count > 0

    Repeater {
        id: repeater
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Theme.iconSize
            implicitHeight: Theme.iconSize

            function openMenu() {
                if (!entry.modelData.hasMenu)
                    return;
                const below = entry.mapToItem(null, 0, entry.height);
                entry.modelData.display(entry.QsWindow.window, below.x, below.y + Theme.spacingSmall);
            }

            IconImage {
                anchors.fill: parent
                source: entry.modelData.icon
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu)
                        entry.openMenu();
                    else
                        entry.modelData.activate();
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
