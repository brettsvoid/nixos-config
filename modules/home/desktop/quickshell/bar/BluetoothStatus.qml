import QtQuick
import Quickshell.Bluetooth
import "../theme"

// Bluetooth on or off, and whether something is connected. Hidden without an adapter.
StatusIcon {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int connected: root.adapter ? root.adapter.devices.values.filter(d => d.connected).length : 0

    visible: root.adapter !== null
    glyph: {
        if (!root.adapter?.enabled)
            return 0xF00B2; // md-bluetooth_off
        if (root.connected > 0)
            return 0xF00B1; // md-bluetooth_connect
        return 0xF00AF; // md-bluetooth
    }
    label: root.connected > 1 ? String(root.connected) : ""
    color: root.adapter?.enabled ? Theme.barText : Theme.subtext
}
