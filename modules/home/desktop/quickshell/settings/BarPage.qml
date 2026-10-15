import QtQuick
import Quickshell
import "../components"
import "../config"
import "../theme"

// The bar: where it sits and when it shows, the clock, the workspaces and the status
// icons.
OptionsPage {
    id: root

    PageHeading {
        text: "Position"
        topPadding: 0
    }

    ChoiceRow {
        label: "Edge"
        key: "bar.edge"
        choices: [
            {
                value: "top",
                label: "Top"
            },
            {
                value: "bottom",
                label: "Bottom"
            },
            {
                value: "left",
                label: "Left"
            },
            {
                value: "right",
                label: "Right"
            }
        ]
    }

    SwitchRow {
        label: "Auto-hide"
        key: "bar.autoHide"
    }

    // A pill per screen, filled where the bar shows.
    SettingRow {
        label: "Screens"
        key: "bar.hiddenScreens"

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Repeater {
                model: Quickshell.screens

                Pill {
                    required property var modelData
                    readonly property bool shown: !Settings.bar.hiddenScreens.includes(modelData.name)

                    text: modelData.name
                    active: shown
                    onClicked: {
                        const hidden = Settings.bar.hiddenScreens.filter(name => name !== modelData.name);
                        if (shown)
                            hidden.push(modelData.name);
                        Settings.set("bar.hiddenScreens", hidden);
                    }
                }
            }
        }
    }

    PageHeading {
        text: "Clock"
    }

    // The lock screen's clock follows this too.
    SwitchRow {
        label: "12-hour"
        key: "clock.twelveHour"
    }

    SwitchRow {
        label: "Seconds"
        key: "bar.clockSeconds"
    }

    SwitchRow {
        label: "Date"
        key: "bar.clockDate"
    }

    PageHeading {
        text: "Workspaces"
    }

    SwitchRow {
        label: "Per screen"
        key: "bar.workspacesPerMonitor"
    }

    SliderRow {
        label: "How many"
        key: "bar.workspaceCount"
        enabled: !Settings.bar.workspacesPerMonitor
    }

    SwitchRow {
        label: "Empty ones"
        key: "bar.showEmptyWorkspaces"
        enabled: !Settings.bar.workspacesPerMonitor
    }

    SwitchRow {
        label: "Scroll to switch"
        key: "bar.scrollWorkspaces"
    }

    PageHeading {
        text: "Status icons"
    }

    SwitchRow {
        label: "Tray"
        key: "bar.showTray"
    }

    SwitchRow {
        label: "Bluetooth"
        key: "bar.showBluetooth"
    }

    SwitchRow {
        label: "Network"
        key: "bar.showNetwork"
    }

    SwitchRow {
        label: "Volume"
        key: "bar.showAudio"
    }

    SwitchRow {
        label: "Battery"
        key: "bar.showBattery"
    }

    PageHeading {
        text: "Volume"
    }

    SwitchRow {
        label: "Percentage"
        key: "bar.volumeLabel"
    }

    SliderRow {
        label: "Scroll step"
        key: "bar.volumeStep"
        format: value => value + " %"
    }

    SliderRow {
        label: "Scroll up to"
        key: "bar.volumeMax"
        format: value => value + " %"
    }
}
