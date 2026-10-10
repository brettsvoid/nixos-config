pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// The shell's own app windows (so far the settings window): whether each is open. A
// window is loaded only while open (shell.qml).
Singleton {
    id: root

    property bool settings: false
    // The page the settings window shows, by name (settings/SettingsWindow.qml).
    property string settingsPage: ""

    // Opens the settings window, on `page` if given. Already open, it is brought
    // forward: Hyprland focuses a new window, but not one asked for again.
    function showSettings(page) {
        if (page)
            root.settingsPage = page;
        if (root.settings)
            Hyprland.dispatch("focuswindow title:^(Shell settings)$");
        root.settings = true;
    }
}
