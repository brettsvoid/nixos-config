import QtQuick
import Quickshell
import "../components"
import "../config"
import "../services"
import "../theme"

// The bar: where it sits and when it shows, the clock, the workspaces, the status
// icons and the pomodoro timer.
OptionsPage {
    id: root

    PageHeading {
        text: "Position"
        topPadding: 0
    }

    ChoiceRow {
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
        key: "bar.autoHide"
    }

    // A pill per screen, filled where the bar shows. Hiding names the screen by its
    // description, so the choice stays with the screen whichever port it is on.
    SettingRow {
        key: "bar.hiddenScreens"

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Repeater {
                model: Quickshell.screens

                Pill {
                    required property var modelData
                    readonly property var names: Settings.namesOf(modelData.name)
                    readonly property bool shown: !Settings.bar.hiddenScreens.some(name => names.includes(name))

                    text: modelData.name
                    active: shown
                    onClicked: {
                        const hidden = Settings.bar.hiddenScreens.filter(name => !names.includes(name));
                        if (shown)
                            hidden.push(names[0]);
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
        key: "clock.twelveHour"
    }

    SwitchRow {
        key: "bar.clockSeconds"
    }

    SwitchRow {
        key: "bar.clockDate"
    }

    PageHeading {
        text: "Workspaces"
    }

    SwitchRow {
        key: "bar.workspacesPerMonitor"
    }

    SliderRow {
        key: "bar.workspaceCount"
        enabled: !Settings.valueOn(Windows.settingsScreen, "bar.workspacesPerMonitor")
    }

    SwitchRow {
        key: "bar.showEmptyWorkspaces"
        enabled: !Settings.valueOn(Windows.settingsScreen, "bar.workspacesPerMonitor")
    }

    SwitchRow {
        key: "bar.scrollWorkspaces"
    }

    PageHeading {
        text: "Status icons"
    }

    SwitchRow {
        key: "bar.showLogo"
    }

    SwitchRow {
        key: "bar.showLockKeys"
    }

    SwitchRow {
        key: "bar.showTray"
    }

    SwitchRow {
        key: "bar.showBluetooth"
    }

    SwitchRow {
        key: "bar.showNetwork"
    }

    SwitchRow {
        key: "bar.showMicrophone"
    }

    SwitchRow {
        key: "bar.showAudio"
    }

    SwitchRow {
        key: "bar.showBattery"
    }

    SwitchRow {
        key: "bar.showPower"
    }

    PageHeading {
        text: "Volume"
    }

    SwitchRow {
        key: "bar.volumeLabel"
    }

    SliderRow {
        key: "bar.volumeStep"
        format: value => value + " %"
    }

    SliderRow {
        key: "bar.volumeMax"
        format: value => value + " %"
    }

    PageHeading {
        text: "Pomodoro"
    }

    SliderRow {
        key: "pomodoro.workMinutes"
        format: value => value + " min"
    }

    SliderRow {
        key: "pomodoro.breakMinutes"
        format: value => value + " min"
    }

    SliderRow {
        key: "pomodoro.longBreakMinutes"
        format: value => value + " min"
    }

    SliderRow {
        key: "pomodoro.longBreakEvery"
        format: value => value === 0 ? "Never" : String(value)
    }

    SwitchRow {
        key: "pomodoro.autoStart"
    }

    SwitchRow {
        key: "pomodoro.sound"
    }
}
