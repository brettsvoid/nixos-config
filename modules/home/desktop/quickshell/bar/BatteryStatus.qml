import QtQuick
import Quickshell.Services.UPower
import "../theme"

// The laptop's battery: its level, coloured by how full it is, or a bolt while charging.
StatusIcon {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device !== null && device.isLaptopBattery
    readonly property int percentage: available ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: available && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)

    glyph: {
        if (root.charging)
            return 0xF0E7; // bolt
        if (root.percentage > 75)
            return 0xF240; // battery-full
        if (root.percentage > 50)
            return 0xF241; // battery-three-quarters
        if (root.percentage > 25)
            return 0xF242; // battery-half
        return 0xF243; // battery-quarter
    }
    label: root.percentage + "%"
    widestLabel: "100%"
    color: {
        if (root.charging || root.percentage > 60)
            return Theme.batteryGood;
        if (root.percentage > 20)
            return Theme.batteryMid;
        return Theme.batteryLow;
    }
}
