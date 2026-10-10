import QtQuick
import Quickshell.Networking
import "../theme"

// Wired or Wi-Fi state, from NetworkManager. A wired link wins over Wi-Fi; Wi-Fi shows
// its signal strength. Hidden when there is neither kind of device.
StatusIcon {
    id: root

    readonly property var wired: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var wifi: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property bool wiredUp: root.wired.some(d => d.connected)
    readonly property var wifiNetwork: {
        for (const device of root.wifi) {
            const network = device.networks.values.find(n => n.connected);
            if (network)
                return network;
        }
        return null;
    }

    visible: root.wired.length > 0 || root.wifi.length > 0
    glyph: {
        if (root.wiredUp)
            return 0xF0200; // md-ethernet
        if (root.wifiNetwork) {
            const s = root.wifiNetwork.signalStrength;
            if (s >= 0.75)
                return 0xF0928; // md-wifi_strength_4
            if (s >= 0.5)
                return 0xF0925; // md-wifi_strength_3
            if (s >= 0.25)
                return 0xF0922; // md-wifi_strength_2
            return 0xF091F; // md-wifi_strength_1
        }
        if (root.wifi.length > 0 && Networking.wifiEnabled)
            return 0xF092F; // md-wifi_strength_outline: Wi-Fi on, not connected
        return 0xF0C9B; // md-network_off
    }
    color: root.wiredUp || root.wifiNetwork ? Theme.barText : Theme.subtext
}
