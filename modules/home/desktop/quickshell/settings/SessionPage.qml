import QtQuick
import "../config"

// The session: the lock screen, what happens when idle, and the session menu with the
// launcher's session actions.
OptionsPage {
    id: root

    PageHeading {
        text: "Lock screen"
        topPadding: 0
    }

    SliderRow {
        key: "lock.blur"
        format: value => value === 0 ? "Off" : Math.round(value * 100) + "%"
    }

    SliderRow {
        key: "lock.dim"
        format: value => Math.round(value * 100) + "%"
    }

    SwitchRow {
        key: "lock.media"
    }

    PageHeading {
        text: "When idle"
    }

    SliderRow {
        key: "idle.lockMinutes"
        format: value => value === 0 ? "Never" : value + " min"
    }

    SliderRow {
        key: "idle.screenOffMinutes"
        format: value => value === 0 ? "Never" : value + " min"
    }

    PageHeading {
        text: "Session menu"
    }

    // Log out, restart and shut down, here and in the launcher's actions.
    SwitchRow {
        key: "session.confirm"
    }

    SwitchRow {
        key: "session.showSleep"
    }
}
