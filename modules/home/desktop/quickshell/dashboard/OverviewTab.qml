import QtQuick
import Quickshell
import "../theme"

// The dashboard's first tab: today's date and a month calendar, beside the media card.
Item {
    id: root

    // Minute precision: it wakes once a minute, and only while the tab exists.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: dateColumn
        anchors.left: parent.left
        anchors.top: parent.top
        width: 320
        spacing: Theme.spacingMedium

        Column {
            Text {
                text: Qt.formatDate(clock.date, "dddd")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleMedium
            }

            Text {
                text: Qt.formatDate(clock.date, "d MMMM yyyy")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeHeadlineSmall
                font.bold: true
            }
        }

        Calendar {
            width: parent.width
            today: clock.date
        }
    }

    MediaCard {
        anchors.left: dateColumn.right
        anchors.leftMargin: Theme.spacingExtraLarge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
