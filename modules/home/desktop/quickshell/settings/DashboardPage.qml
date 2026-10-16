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
        label: "Overview"
        key: "dashboard.showOverview"
    }

    SwitchRow {
        label: "Performance"
        key: "dashboard.showPerformance"
    }

    SwitchRow {
        label: "Wallpaper"
        key: "dashboard.showWallpaper"
    }

    SwitchRow {
        label: "Open on last"
        key: "dashboard.rememberTab"
    }

    PageHeading {
        text: "Overview"
    }

    ChoiceRow {
        label: "Week starts"
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
        label: "Visualiser"
        key: "dashboard.visualiser"
    }

    SliderRow {
        label: "Its bars"
        key: "dashboard.visualiserBars"
        enabled: Settings.dashboard.visualiser
    }

    PageHeading {
        text: "Performance"
    }

    SwitchRow {
        label: "CPU"
        key: "dashboard.showCpu"
    }

    SwitchRow {
        label: "GPU"
        key: "dashboard.showGpu"
    }

    SwitchRow {
        label: "Memory"
        key: "dashboard.showMemory"
    }

    SwitchRow {
        label: "Swap"
        key: "dashboard.showSwap"
    }

    SwitchRow {
        label: "Disks"
        key: "dashboard.showDisks"
    }

    SwitchRow {
        label: "Network"
        key: "dashboard.showNetwork"
    }

    ChoiceRow {
        label: "Sizes"
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
        label: "Fahrenheit"
        key: "dashboard.fahrenheit"
    }

    SliderRow {
        label: "Graph length"
        key: "dashboard.graphSeconds"
        format: value => value < 60 ? value + " s" : value / 60 + " min"
    }

    SliderRow {
        label: "Sample every"
        key: "dashboard.sampleInterval"
        format: value => value + " s"
    }
}
