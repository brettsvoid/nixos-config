import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../config"
import "../services"
import "../theme"

// The app icon and title of the window last focused on this screen (services/
// ActiveWindows.qml), dimmed while focus is on another screen. The title elides to the
// width the bar gives it (`Layout.maximumWidth`). On a side bar (`vertical`) only the
// icon shows. Nothing shows with no window or with the screen's setting off.
RowLayout {
    id: root

    required property var screen
    required property ScreenSettings settings
    property bool vertical: false

    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property var window: ActiveWindows.on(root.monitor)
    // A window opened after the shell started has no class in lastIpcObject, so the app
    // id is the Wayland handle's.
    readonly property string appId: root.window?.wayland?.appId ?? root.window?.lastIpcObject?.class ?? ""
    readonly property var entry: root.appId === "" ? null : DesktopEntries.heuristicLookup(root.appId)
    // The entry's icon, else the app id itself (many themes name icons so).
    readonly property string iconName: root.entry?.icon || root.appId.toLowerCase()

    visible: root.settings.bar.showWindowTitle && root.window !== null
    opacity: !Hyprland.focusedMonitor || Hyprland.focusedMonitor === root.monitor ? 1 : 0.5
    spacing: Theme.spacingSmall

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDuration
        }
    }

    Image {
        Layout.alignment: Qt.AlignCenter
        Layout.preferredWidth: Theme.iconSize
        Layout.preferredHeight: Theme.iconSize
        sourceSize: Qt.size(Theme.iconSize, Theme.iconSize)
        source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName, "application-x-executable")
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        Layout.fillWidth: true
        visible: !root.vertical
        text: root.window?.title ?? ""
        elide: Text.ElideRight
        color: Theme.barText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
