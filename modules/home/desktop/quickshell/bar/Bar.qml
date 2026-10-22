import QtQuick
import QtQuick.Layouts
import "../config"
import "../theme"

// The bar's content, laid out along the frame's bar band: workspaces at the start, the
// clock in the middle, the tray and status icons at the end. On a side edge
// (`vertical`) they run from top to bottom. The screen's settings choose which status
// icons show.
Item {
    id: root

    required property var screen
    required property ScreenSettings settings
    readonly property bool vertical: root.settings.bar.vertical

    // Placed by x and y rather than anchors: anchors swapped by bindings, as the bar
    // moves between a side and the top, left items where they had been.
    Workspaces {
        x: root.vertical ? (root.width - width) / 2 : Theme.barPadding
        y: root.vertical ? Theme.barPadding : (root.height - height) / 2
        screen: root.screen
        settings: root.settings
        vertical: root.vertical
    }

    Clock {
        id: clock
        anchors.centerIn: parent
        vertical: root.vertical
        showSeconds: root.settings.bar.clockSeconds
        showDate: root.settings.bar.clockDate
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
        x: root.vertical ? (root.width - width) / 2 : root.width - width - Theme.barPadding
        y: root.vertical ? root.height - height - Theme.barPadding : (root.height - height) / 2
        // One column, or (never more than 99 icons) one row.
        columns: root.vertical ? 1 : 99
        rowSpacing: Theme.spacingLarge
        columnSpacing: Theme.spacingLarge

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
    }
}
