import QtQuick
import Quickshell
import "../services"
import "../theme"

// The pop-up drawer's content: the notifications showing now, the newest nearest the
// screen edge they come from (at the top, or at the bottom when the settings put them
// there).
Column {
    id: root

    // Whether they come from the bottom: the screen's notifications.position.
    required property bool fromBottom

    spacing: Theme.spacingSmall

    Repeater {
        // A ScriptModel keeps the cards of the notifications that stay as others come and
        // go. A plain array would make every card again on each change, which started
        // each card's timeout again.
        model: ScriptModel {
            values: root.fromBottom ? Notifications.popups.slice().reverse() : Notifications.popups
        }

        NotificationCard {
            required property var modelData

            entry: modelData
            popup: true
        }
    }
}
