import QtQuick
import Quickshell.Bluetooth
import "../components"
import "../theme"

// The default Bluetooth adapter, through Quickshell's Bluetooth module (BlueZ). Paired
// devices connect, disconnect and are forgotten here; nearby ones are found while the
// page shows and paired. A device paired here is trusted, so it may reconnect by
// itself, and connected.
//
// BlueZ asks an agent for a PIN or a passkey confirmation, and the shell does not run
// one, so devices that need either do not pair here (use `bluetoothctl`). Most headsets,
// mice and controllers need neither.
FocusScope {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: root.adapter?.devices.values ?? []
    readonly property var paired: root.devices.filter(device => device.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices (mostly beacons) are left out.
    readonly property var nearby: root.devices.filter(device => !device.paired && device.deviceName !== "").sort((a, b) => a.name.localeCompare(b.name))

    // Look for devices while the page shows.
    Component.onCompleted: {
        if (root.adapter?.enabled)
            root.adapter.discovering = true;
    }
    Component.onDestruction: {
        if (root.adapter?.discovering)
            root.adapter.discovering = false;
    }

    // Turned on with the page showing: look for devices once it is up. `enabled` turns
    // true while it is still powering on, and BlueZ refuses discovery until `state`
    // says Enabled ("Resource Not Ready").
    Connections {
        target: root.adapter

        function onStateChanged() {
            if (root.adapter.state === BluetoothAdapterState.Enabled)
                root.adapter.discovering = true;
        }
    }

    function glyph(device) {
        // BlueZ's icon names, as in freedesktop's icon theme.
        const glyphs = {
            "audio-headset": 0xF02CE, // md-headset
            "audio-headphones": 0xF02CB, // md-headphones
            "audio-card": 0xF04C3, // md-speaker
            "input-keyboard": 0xF030C, // md-keyboard
            "input-mouse": 0xF037D, // md-mouse
            "input-gaming": 0xF0297, // md-gamepad_variant
            "input-tablet": 0xF04F6, // md-tablet
            "phone": 0xF011C, // md-cellphone
            "computer": 0xF0322, // md-laptop
            "video-display": 0xF0379, // md-monitor
            "printer": 0xF042A, // md-printer
            "camera-photo": 0xF0100 // md-camera
        };
        return glyphs[device.icon] ?? 0xF00AF; // md-bluetooth
    }

    component Heading: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleSmall
        font.bold: true
        topPadding: Theme.spacingLarge
        bottomPadding: Theme.spacingSmall
    }

    component Line: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyMedium
        bottomPadding: Theme.spacingSmall
    }

    // One device: its icon, name and state, and the buttons the row passes in.
    component DeviceRow: Item {
        id: row

        required property var modelData
        readonly property var device: row.modelData
        property string status
        default property alias buttons: buttonRow.data

        width: parent?.width ?? 0
        height: 56

        Text {
            id: icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            text: String.fromCodePoint(root.glyph(row.device))
            color: row.device.connected ? Theme.primary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleLarge
        }

        Column {
            anchors.left: icon.right
            anchors.right: buttonRow.left
            anchors.leftMargin: Theme.spacingSmall
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.device.name
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyLarge
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: row.status
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodySmall
            }
        }

        Row {
            id: buttonRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width

            Line {
                visible: root.adapter === null
                text: "No Bluetooth adapter"
            }

            Item {
                visible: root.adapter !== null
                width: parent.width
                height: 40

                Heading {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 0
                    bottomPadding: 0
                    text: "Bluetooth"
                }

                Switch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.adapter?.enabled ?? false
                    enabled: root.adapter?.state !== BluetoothAdapterState.Blocked
                    onToggled: checked => root.adapter.enabled = checked
                }
            }

            Line {
                visible: root.adapter?.state === BluetoothAdapterState.Blocked
                text: "Blocked by rfkill"
            }

            Line {
                visible: root.adapter !== null
                text: root.adapter ? `${root.adapter.name}   ${root.adapter.adapterId}` : ""
            }

            Heading {
                visible: root.adapter?.enabled ?? false
                text: "Paired devices"
            }

            Line {
                visible: (root.adapter?.enabled ?? false) && root.paired.length === 0
                text: "None yet"
            }

            Repeater {
                model: root.adapter?.enabled ? root.paired : []

                DeviceRow {
                    id: pairedRow

                    status: {
                        const state = BluetoothDeviceState.toString(pairedRow.device.state);
                        return pairedRow.device.batteryAvailable ? `${state}, battery ${Math.round(pairedRow.device.battery * 100)}%` : state;
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: 0xF01B4 // md-delete
                        onClicked: pairedRow.device.forget()
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pairedRow.device.connected ? "Disconnect" : "Connect"
                        onClicked: pairedRow.device.connected ? pairedRow.device.disconnect() : pairedRow.device.connect()
                    }
                }
            }

            Heading {
                visible: root.adapter?.enabled ?? false
                text: "Nearby"
            }

            Line {
                visible: (root.adapter?.enabled ?? false) && root.nearby.length === 0
                text: root.adapter?.discovering ? "Looking for devices…" : "Not looking for devices"
            }

            Repeater {
                model: root.adapter?.enabled ? root.nearby : []

                DeviceRow {
                    id: nearbyRow

                    status: nearbyRow.device.pairing ? "Pairing…" : nearbyRow.device.address

                    // Once paired, keep it and connect: what pairing is for here.
                    Connections {
                        target: nearbyRow.device

                        function onPairedChanged() {
                            if (nearbyRow.device.paired) {
                                nearbyRow.device.trusted = true;
                                nearbyRow.device.connect();
                            }
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        text: nearbyRow.device.pairing ? "Cancel" : "Pair"
                        onClicked: nearbyRow.device.pairing ? nearbyRow.device.cancelPair() : nearbyRow.device.pair()
                    }
                }
            }
        }
    }
}
