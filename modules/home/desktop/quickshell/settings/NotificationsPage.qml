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
        key: "notifications.timeout"
        format: value => value + " s"
    }

    // Off: every pop-up takes the timeout above (critical and resident ones still wait).
    SwitchRow {
        key: "notifications.appTimeout"
    }

    SliderRow {
        key: "notifications.maxPopups"
        format: value => value === 0 ? "No limit" : value
    }

    SliderRow {
        key: "notifications.popupBodyLines"
    }

    PageHeading {
        text: "History"
    }

    SliderRow {
        key: "notifications.historyCount"
        format: value => value === 0 ? "All" : value
    }

    SliderRow {
        key: "notifications.historyDays"
        format: value => value === 0 ? "Ever" : value === 1 ? "1 day" : value + " days"
    }

    PageHeading {
        text: "On-screen display"
    }

    ChoiceRow {
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
        key: "osd.timeout"
        format: value => value + " s"
    }

    SwitchRow {
        key: "osd.showVolume"
    }

    SwitchRow {
        key: "osd.showMicrophone"
    }

    SwitchRow {
        key: "osd.showBrightness"
    }

    SwitchRow {
        key: "osd.showInGameMode"
    }
}
