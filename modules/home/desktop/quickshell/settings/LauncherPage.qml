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
        key: "launcher.rows"
    }

    SwitchRow {
        key: "launcher.rankByUse"
    }

    // Not a setting: forgets how often each app was started.
    SettingRow {
        key: "launcher.useSoFar"

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
        key: "launcher.terminal"
    }

    PageHeading {
        text: "Prefixes"
    }

    TextRow {
        key: "launcher.clipboardPrefix"
        fieldWidth: 120
    }

    TextRow {
        key: "launcher.calculatorPrefix"
        fieldWidth: 120
    }

    TextRow {
        key: "launcher.actionsPrefix"
        fieldWidth: 120
    }
}
