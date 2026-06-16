import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../theme"

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device !== null && device.isLaptopBattery
    readonly property int percentage: available ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging

    visible: available

    implicitWidth: batteryRow.implicitWidth
    implicitHeight: batteryRow.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function batteryColor() {
        if (charging) return Theme.batteryGood
        if (percentage > 60) return Theme.batteryGood
        if (percentage > 20) return Theme.batteryMid
        return Theme.batteryLow
    }

    function batteryIcon() {
        if (charging) return "\uf0e7" // bolt
        if (percentage > 75) return "\uf240" // battery-full
        if (percentage > 50) return "\uf241" // battery-three-quarters
        if (percentage > 25) return "\uf242" // battery-half
        return "\uf243" // battery-quarter
    }

    RowLayout {
        id: batteryRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.batteryIcon()
            color: root.batteryColor()
            font.family: Theme.fontFamily
            font.pixelSize: 16
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.percentage + "%"
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
