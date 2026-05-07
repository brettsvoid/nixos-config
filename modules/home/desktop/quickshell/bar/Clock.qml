import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property string timeStr: ""
    property string dateStr: ""

    implicitWidth: clockLayout.implicitWidth
    implicitHeight: clockLayout.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            root.timeStr = Qt.formatDateTime(now, "hh:mm")
            root.dateStr = Qt.formatDateTime(now, "ddd, MMM d")
        }
    }

    RowLayout {
        id: clockLayout
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.timeStr
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
            text: root.dateStr
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
