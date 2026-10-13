pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which drawer is open, and on which screen. One drawer at a time; a drawer opens on
// the focused monitor.
Singleton {
    id: root

    // The open drawer's name, or "" when none is.
    property string open: ""
    // The name of the screen it is on.
    property string screen: ""
    // The tab the dashboard opens on next, by name; it clears it (dashboard/Dashboard.qml).
    property string dashboardTab: ""

    function isOpen(name, screenName) {
        return root.open === name && root.screen === screenName;
    }

    function toggle(name) {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        if (root.isOpen(name, focused)) {
            root.close();
        } else {
            root.screen = focused;
            root.open = name;
        }
    }

    function close() {
        root.open = "";
    }
}
