import QtQuick
import "../config"

// The session: the session menu and the launcher's session actions.
OptionsPage {
    id: root

    PageHeading {
        text: "Session menu"
        topPadding: 0
    }

    // Log out, restart and shut down, here and in the launcher's actions.
    SwitchRow {
        label: "Confirm"
        key: "session.confirm"
    }

    SwitchRow {
        label: "Sleep"
        key: "session.showSleep"
    }
}
