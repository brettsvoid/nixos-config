import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../theme"

// The time, and the date after a divider. The settings choose 12- or 24-hour time, and
// the screen's settings whether seconds and the date show. On a side bar (`vertical`)
// each part of the time takes its own line, and the date shortens to the day and its
// number. A click on it signals `clicked`.
Item {
    id: root

    property bool vertical: false
    property bool showSeconds: false
    property bool showDate: true

    signal clicked

    readonly property string timeFormat: (Settings.clock.twelveHour ? "h:mm" : "hh:mm") + (root.showSeconds ? ":ss" : "") + (Settings.clock.twelveHour ? " AP" : "")
    readonly property string time: Qt.formatDateTime(clock.date, root.timeFormat)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Wakes once a minute (or second, with seconds shown), and not at all while the bar
    // is hidden (game mode, fullscreen), so it asks for no redraws then.
    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
        enabled: root.visible
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // A GridLayout, not a Grid, which leaves room for a hidden date (see Bar.qml).
    GridLayout {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 3
        rowSpacing: Theme.spacingSmall
        columnSpacing: 8

        Text {
            Layout.alignment: Qt.AlignCenter
            text: root.vertical ? root.time.split(/[: ]/).join("\n") : root.time
            horizontalAlignment: Text.AlignHCenter
            lineHeight: root.vertical ? 0.9 : 1
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: root.vertical ? 16 : 1
            Layout.preferredHeight: root.vertical ? 1 : 16
            visible: root.showDate
            color: Theme.surfaceBright
        }

        Text {
            Layout.alignment: Qt.AlignCenter
            visible: root.showDate
            text: Qt.formatDateTime(clock.date, root.vertical ? "ddd\nd" : "ddd, MMM d")
            horizontalAlignment: Text.AlignHCenter
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
