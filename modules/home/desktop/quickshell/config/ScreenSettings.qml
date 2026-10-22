import QtQuick

// The per-screen settings in force on one screen (Settings.valueOn), made once per
// screen by ScreenShell for its windows. The shared settings stay on Settings.
QtObject {
    id: root

    // The screen's connector, as Quickshell names it.
    required property string screen

    // Its bar shows unless bar.hiddenScreens names it, either way.
    readonly property bool hasBar: {
        const names = Settings.namesOf(root.screen);
        return !Settings.bar.hiddenScreens.some(name => names.includes(name));
    }

    readonly property QtObject bar: QtObject {
        readonly property string edge: Settings.valueOn(root.screen, "bar.edge")
        readonly property bool vertical: edge === "left" || edge === "right"
        readonly property bool autoHide: Settings.valueOn(root.screen, "bar.autoHide")
        readonly property bool clockSeconds: Settings.valueOn(root.screen, "bar.clockSeconds")
        readonly property bool clockDate: Settings.valueOn(root.screen, "bar.clockDate")
        readonly property int workspaceCount: Settings.valueOn(root.screen, "bar.workspaceCount")
        readonly property bool showEmptyWorkspaces: Settings.valueOn(root.screen, "bar.showEmptyWorkspaces")
        readonly property bool workspacesPerMonitor: Settings.valueOn(root.screen, "bar.workspacesPerMonitor")
        readonly property bool showTray: Settings.valueOn(root.screen, "bar.showTray")
        readonly property bool showBluetooth: Settings.valueOn(root.screen, "bar.showBluetooth")
        readonly property bool showNetwork: Settings.valueOn(root.screen, "bar.showNetwork")
        readonly property bool showAudio: Settings.valueOn(root.screen, "bar.showAudio")
        readonly property bool showBattery: Settings.valueOn(root.screen, "bar.showBattery")
        readonly property bool volumeLabel: Settings.valueOn(root.screen, "bar.volumeLabel")
    }

    readonly property QtObject wallpaper: QtObject {
        readonly property string fill: Settings.valueOn(root.screen, "wallpaper.fill")
    }

    readonly property QtObject notifications: QtObject {
        readonly property string position: Settings.valueOn(root.screen, "notifications.position")
    }

    readonly property QtObject osd: QtObject {
        readonly property string position: Settings.valueOn(root.screen, "osd.position")
    }

    readonly property QtObject launcher: QtObject {
        readonly property int rows: Settings.valueOn(root.screen, "launcher.rows")
    }
}
