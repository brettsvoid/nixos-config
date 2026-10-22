import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"
import "../theme"

// The bar's content, laid out along the frame's bar band: the logo and workspaces at the
// start, the clock in the middle, the lock keys, tray and status icons and the power
// button at the end. On a side edge (`vertical`) they run from top to bottom. The
// screen's settings choose which of the icons show.
Item {
    id: root

    required property var screen
    required property ScreenSettings settings
    readonly property bool vertical: root.settings.bar.vertical

    // Placed by x and y rather than anchors: anchors swapped by bindings, as the bar
    // moves between a side and the top, left items where they had been. A GridLayout,
    // not a Grid (see below).
    GridLayout {
        id: startItems
        x: root.vertical ? (root.width - width) / 2 : Theme.barPadding
        y: root.vertical ? Theme.barPadding : (root.height - height) / 2
        columns: root.vertical ? 1 : 99
        rowSpacing: Theme.spacingLarge
        columnSpacing: Theme.spacingLarge

        DrawerButton {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showLogo
            vertical: root.vertical
            screen: root.screen
            drawer: "launcher"
            glyph: 0xF313 // nf-linux-nixos
        }

        Workspaces {
            Layout.alignment: Qt.AlignCenter
            screen: root.screen
            settings: root.settings
            vertical: root.vertical
        }
    }

    Clock {
        id: clock
        anchors.centerIn: parent
        vertical: root.vertical
        showSeconds: root.settings.bar.clockSeconds
        showDate: root.settings.bar.clockDate
        onClicked: Drawers.toggle("dashboard", root.screen.name)
    }

    // Beside the clock, after it.
    PomodoroStatus {
        x: root.vertical ? (root.width - width) / 2 : clock.x + clock.width + Theme.spacingLarge
        y: root.vertical ? clock.y + clock.height + Theme.spacingLarge : (root.height - height) / 2
        visible: available
        vertical: root.vertical
    }

    // A GridLayout, not a Grid: with more columns than visible items, Grid adds a
    // spacing's width at the end (Qt 6.11), so the icons would sit off the padding.
    GridLayout {
        id: endItems
        x: root.vertical ? (root.width - width) / 2 : root.width - width - Theme.barPadding
        y: root.vertical ? root.height - height - Theme.barPadding : (root.height - height) / 2
        // One column, or (never more than 99 icons) one row.
        columns: root.vertical ? 1 : 99
        rowSpacing: Theme.spacingLarge
        columnSpacing: Theme.spacingLarge

        // Caps Lock and Num Lock, each only while on. Checking the setting first leaves the
        // lock keys' service unstarted until a screen shows them.
        StatusIcon {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showLockKeys && LockKeys.caps
            vertical: root.vertical
            glyph: 0xF030E // md-keyboard_caps
        }

        StatusIcon {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showLockKeys && LockKeys.num
            vertical: root.vertical
            glyph: 0xF061C // md-dialpad
        }

        Tray {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showTray && hasItems
            vertical: root.vertical
            edge: root.settings.bar.edge
        }

        BluetoothStatus {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showBluetooth && available
            vertical: root.vertical
        }

        NetworkStatus {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showNetwork && available
            vertical: root.vertical
        }

        MicrophoneStatus {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showMicrophone && available
            vertical: root.vertical
        }

        AudioStatus {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showAudio && available
            vertical: root.vertical
            showLabel: root.settings.bar.volumeLabel
        }

        BatteryStatus {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showBattery && available
            vertical: root.vertical
        }

        DrawerButton {
            Layout.alignment: Qt.AlignCenter
            visible: root.settings.bar.showPower
            vertical: root.vertical
            screen: root.screen
            drawer: "session"
            glyph: 0xF0425 // md-power
        }
    }
}
