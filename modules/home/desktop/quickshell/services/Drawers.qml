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
    // The tab it last showed, for the setting that reopens it there.
    property string lastDashboardTab: ""
    // The launcher's mode to open in, by name (launcher/Launcher.qml); it clears it.
    property string launcherMode: ""

    // Every drawer that can be opened by name, as FrameWindow makes them.
    readonly property var names: ["session", "launcher", "cheatsheet", "notifications", "dashboard"]
    // The launcher's modes and the dashboard's tabs, by the names their content gives
    // them (Launcher.qml, Dashboard.qml), for the commands that open them there.
    readonly property var launcherModes: ["apps", "clipboard", "calculator", "actions"]
    readonly property var dashboardTabs: ["Overview", "Performance", "Wallpaper"]

    function isOpen(name, screenName) {
        return root.open === name && root.screen === screenName;
    }

    function focusedScreen() {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    function openOn(name, screenName) {
        root.screen = screenName;
        root.open = name;
    }

    // On the focused monitor, or on `screenName`: a click in a screen's bar opens the
    // drawer there.
    function toggle(name, screenName) {
        const target = screenName ?? root.focusedScreen();
        if (root.isOpen(name, target))
            root.close();
        else
            root.openOn(name, target);
    }

    function close() {
        root.open = "";
    }
}
