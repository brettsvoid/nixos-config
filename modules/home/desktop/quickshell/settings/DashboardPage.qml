import QtQuick
import "../config"

// The dashboard: its tabs, the calendar, the media card's visualiser and the
// performance tab.
OptionsPage {
    id: root

    PageHeading {
        text: "Tabs"
        topPadding: 0
    }

    SwitchRow {
        key: "dashboard.showOverview"
    }

    SwitchRow {
        key: "dashboard.showPerformance"
    }

    SwitchRow {
        key: "dashboard.showWallpaper"
    }

    SwitchRow {
        key: "dashboard.rememberTab"
    }

    PageHeading {
        text: "Overview"
    }

    ChoiceRow {
        key: "dashboard.weekStart"
        choices: [
            {
                value: "monday",
                label: "Monday"
            },
            {
                value: "sunday",
                label: "Sunday"
            },
            {
                value: "saturday",
                label: "Saturday"
            }
        ]
    }

    SwitchRow {
        key: "dashboard.visualiser"
    }

    SliderRow {
        key: "dashboard.visualiserBars"
        enabled: Settings.dashboard.visualiser
    }

    PageHeading {
        text: "Performance"
    }

    SwitchRow {
        key: "dashboard.showCpu"
    }

    SwitchRow {
        key: "dashboard.showGpu"
    }

    SwitchRow {
        key: "dashboard.showMemory"
    }

    SwitchRow {
        key: "dashboard.showSwap"
    }

    SwitchRow {
        key: "dashboard.showDisks"
    }

    SwitchRow {
        key: "dashboard.showNetwork"
    }

    ChoiceRow {
        key: "dashboard.byteUnits"
        choices: [
            {
                value: "binary",
                label: "KiB, MiB, GiB"
            },
            {
                value: "decimal",
                label: "kB, MB, GB"
            }
        ]
    }

    SwitchRow {
        key: "dashboard.fahrenheit"
    }

    SliderRow {
        key: "dashboard.graphSeconds"
        format: value => value < 60 ? value + " s" : value / 60 + " min"
    }

    SliderRow {
        key: "dashboard.sampleInterval"
        format: value => value + " s"
    }
}
