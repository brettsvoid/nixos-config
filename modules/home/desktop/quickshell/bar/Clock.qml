import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Item {
    id: root

    implicitWidth: clockLayout.implicitWidth
    implicitHeight: clockLayout.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    // Minute precision: wakes once a minute instead of the old 1s Timer.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: clockLayout
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Rectangle {
            width: 1
            height: 16
            color: Theme.surfaceBright
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
