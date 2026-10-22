pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config"

// The shell's own app windows (so far the settings window): whether each is open. A
// window is loaded only while open (shell.qml).
Singleton {
    id: root

    property bool settings: false
    // The page the settings window shows, by name (settings/SettingsWindow.qml).
    property string settingsPage: ""
    // Its pages' names, as SettingsWindow gives them, for the commands that open it on
    // one.
    readonly property var settingsPages: ["Appearance", "Window effects", "Bar", "Dashboard", "Launcher", "Notifications", "Session", "Audio", "Network", "Bluetooth"]
    // The pages with per-screen settings, which offer a screen to edit.
    readonly property var screenPages: ["Appearance", "Bar", "Launcher", "Notifications"]
    // The screen picked above them, by name as in Settings.screens; "" for all.
    property string pickedScreen: ""
    // The screen the window's rows edit: the one picked, while the page shows the
    // choice and the screen is still offered; otherwise "", every screen.
    readonly property string settingsScreen: {
        const page = root.settingsPages.includes(root.settingsPage) ? root.settingsPage : root.settingsPages[0];
        const offered = Settings.screens.some(s => s.name === root.pickedScreen);
        return root.screenPages.includes(page) && offered ? root.pickedScreen : "";
    }

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
