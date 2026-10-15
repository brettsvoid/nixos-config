import QtQuick
import "../config"

// Notifications (pop-ups and the history) and the on-screen display.
OptionsPage {
    id: root

    PageHeading {
        text: "Pop-ups"
        topPadding: 0
    }

    ChoiceRow {
        label: "Where"
        key: "notifications.position"
        choices: [
            {
                value: "top-left",
                label: "Top left"
            },
            {
                value: "top",
                label: "Top"
            },
            {
                value: "top-right",
                label: "Top right"
            },
            {
                value: "bottom-left",
                label: "Bottom left"
            },
            {
                value: "bottom",
                label: "Bottom"
            },
            {
                value: "bottom-right",
                label: "Bottom right"
            }
        ]
    }

    SliderRow {
        label: "Timeout"
        key: "notifications.timeout"
        format: value => value + " s"
    }

    // Off: every pop-up takes the timeout above (critical and resident ones still wait).
    SwitchRow {
        label: "App's timeout"
        key: "notifications.appTimeout"
    }

    SliderRow {
        label: "At most"
        key: "notifications.maxPopups"
        format: value => value === 0 ? "No limit" : value
    }

    SliderRow {
        label: "Body lines"
        key: "notifications.popupBodyLines"
    }

    PageHeading {
        text: "History"
    }

    SliderRow {
        label: "Keep the last"
        key: "notifications.historyCount"
        format: value => value === 0 ? "All" : value
    }

    SliderRow {
        label: "Keep for"
        key: "notifications.historyDays"
        format: value => value === 0 ? "Ever" : value === 1 ? "1 day" : value + " days"
    }

    PageHeading {
        text: "On-screen display"
    }

    ChoiceRow {
        label: "Where"
        key: "osd.position"
        choices: [
            {
                value: "bottom",
                label: "Bottom"
            },
            {
                value: "top",
                label: "Top"
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

    SliderRow {
        label: "Stays for"
        key: "osd.timeout"
        format: value => value + " s"
    }

    SwitchRow {
        label: "Volume"
        key: "osd.showVolume"
    }

    SwitchRow {
        label: "Microphone"
        key: "osd.showMicrophone"
    }

    SwitchRow {
        label: "Brightness"
        key: "osd.showBrightness"
    }

    SwitchRow {
        label: "In game mode"
        key: "osd.showInGameMode"
    }
}
