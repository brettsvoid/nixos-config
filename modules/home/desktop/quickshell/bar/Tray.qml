import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../theme"

// Apps' tray icons. Left click activates the app (or opens its menu, when that is all it
// offers), right click opens its menu, middle click runs its secondary action, and the
// wheel scrolls it. On a side bar (`vertical`) they stack, and a menu opens beside the
// icon rather than below it.
Grid {
    id: root

    property bool vertical: false
    // The bar's edge, which the menus open away from.
    property string edge: "top"
    readonly property bool hasItems: repeater.count > 0

    // One column, or one row. Exactly as many columns as icons: with more, Grid adds a
    // spacing's width at the end (Qt 6.11).
    columns: root.vertical ? 1 : Math.max(1, repeater.count)
    spacing: Theme.spacingSmall

    Repeater {
        id: repeater
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Theme.iconSize
            implicitHeight: Theme.iconSize

            // The menu opens just off the icon, on the side away from the bar's edge.
            function openMenu() {
                if (!entry.modelData.hasMenu)
                    return;
                const gap = Theme.spacingSmall;
                let at;
                switch (root.edge) {
                case "bottom":
                    at = entry.mapToItem(null, 0, -gap);
                    break;
                case "left":
                    at = entry.mapToItem(null, entry.width + gap, 0);
                    break;
                case "right":
                    at = entry.mapToItem(null, -gap, 0);
                    break;
                default:
                    at = entry.mapToItem(null, 0, entry.height + gap);
                }
                entry.modelData.display(entry.QsWindow.window, at.x, at.y);
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
