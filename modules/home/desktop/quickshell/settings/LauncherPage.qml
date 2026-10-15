import QtQuick
import "../components"
import "../config"
import "../services"
import "../theme"

// The launcher: its size, how apps rank, the terminal for terminal apps, and the
// prefixes that switch its mode.
OptionsPage {
    id: root

    PageHeading {
        text: "Results"
        topPadding: 0
    }

    SliderRow {
        label: "Rows"
        key: "launcher.rows"
    }

    SwitchRow {
        label: "Rank by use"
        key: "launcher.rankByUse"
    }

    // Not a setting: forgets how often each app was started.
    SettingRow {
        label: "Use so far"

        Pill {
            readonly property int apps: Object.keys(AppUsage.counts).length

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: apps === 0 ? "Nothing counted yet" : `Forget ${apps} ${apps === 1 ? "app" : "apps"}`
            enabled: apps > 0
            opacity: enabled ? 1 : 0.4
            onClicked: AppUsage.reset()
        }
    }

    PageHeading {
        text: "Apps"
    }

    // The app's command goes after it, so a terminal that needs a separator (for
    // example `foot --` or `wezterm start --`) takes it here.
    TextRow {
        label: "Terminal"
        key: "launcher.terminal"
    }

    PageHeading {
        text: "Prefixes"
    }

    TextRow {
        label: "Clipboard"
        key: "launcher.clipboardPrefix"
        fieldWidth: 120
    }

    TextRow {
        label: "Calculator"
        key: "launcher.calculatorPrefix"
        fieldWidth: 120
    }

    TextRow {
        label: "Actions"
        key: "launcher.actionsPrefix"
        fieldWidth: 120
    }
}
