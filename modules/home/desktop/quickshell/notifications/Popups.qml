import QtQuick
import "../services"
import "../theme"

// The pop-up drawer's content: the notifications showing now, newest at the top.
Column {
    spacing: Theme.spacingSmall

    Repeater {
        model: Notifications.popups

        NotificationCard {
            required property var modelData

            notification: modelData
            popup: true
        }
    }
}
