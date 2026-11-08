import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../components"
import "../theme"

// The default Bluetooth adapter, through Quickshell's Bluetooth module (BlueZ). Paired
// devices connect, disconnect and are forgotten here; nearby ones are found while the
// page shows and paired. A device paired here is trusted, so it may reconnect by
// itself, and connected.
//
// While the page shows, it runs the pairing agent that BlueZ asks for a confirmation, a
// PIN or a passkey (shell-bluetooth-agent, custom-shell.nix). Only the device Pair was
// pressed on gets an answer: a confirmation is accepted without a click and its passkey
// shows in the row, a PIN or passkey is typed into the row, and a code to type on the
// device shows in the row. A request for any other device is rejected.
FocusScope {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: root.adapter?.devices.values ?? []
    readonly property var paired: root.devices.filter(device => device.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices (mostly beacons) are left out.
    readonly property var nearby: root.devices.filter(device => !device.paired && device.deviceName !== "").sort((a, b) => a.name.localeCompare(b.name))

    // The device Pair was pressed on, until its pairing ends.
    property string pairingAddress: ""
    // What the agent asked about that device, for its row; null when nothing. By `kind`:
    // "confirm" and "displayPasskey" carry `passkey`, "displayPincode" `pincode`,
    // "displayPasskey" also `entered`; "pincode" and "passkey" carry the `id` to answer.
    property var prompt: null

    // The agent lives as long as the page: Quickshell kills a Process with its object.
    Process {
        id: agent
        command: ["shell-bluetooth-agent"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        stderr: SplitParser {
            onRead: line => console.info("shell-bluetooth-agent:", line)
        }
    }

    function answer(reply) {
        agent.write(JSON.stringify(reply) + "\n");
    }

    function handle(line) {
        console.info("shell-bluetooth-agent:", line);
        let request;
        try {
            request = JSON.parse(line);
        } catch (e) {
            return;
        }
        const target = request.device === root.pairingAddress;
        switch (request.method) {
        case "RequestConfirmation":
            if (target)
                root.prompt = {
                    kind: "confirm",
                    address: request.device,
                    passkey: String(request.passkey).padStart(6, "0")
                };
            root.answer({
                id: request.id,
                accept: target
            });
            break;
        case "RequestAuthorization":
        case "AuthorizeService":
            root.answer({
                id: request.id,
                accept: target
            });
            break;
        case "RequestPinCode":
        case "RequestPasskey":
            if (target)
                root.prompt = {
                    kind: request.method === "RequestPinCode" ? "pincode" : "passkey",
                    id: request.id,
                    address: request.device
                };
            else
                root.answer({
                    id: request.id,
                    accept: false
                });
            break;
        case "DisplayPinCode":
            if (target)
                root.prompt = {
                    kind: "displayPincode",
                    address: request.device,
                    pincode: request.pincode
                };
            break;
        case "DisplayPasskey":
            if (target)
                root.prompt = {
                    kind: "displayPasskey",
                    address: request.device,
                    passkey: String(request.passkey).padStart(6, "0"),
                    entered: request.entered
                };
            break;
        case "Cancel":
            root.prompt = null;
            break;
        }
    }

    function submitCode(text) {
        const prompt = root.prompt;
        root.answer(prompt.kind === "pincode" ? {
            id: prompt.id,
            pincode: text
        } : {
            id: prompt.id,
            passkey: Number(text)
        });
        root.prompt = null;
    }

    function endPairing() {
        if (root.prompt?.id !== undefined)
            root.answer({
                id: root.prompt.id,
                accept: false
            });
        root.prompt = null;
        root.pairingAddress = "";
    }

    // Pair() has returned, paired or not, once `pairing` turns false.
    Connections {
        id: pairingDevice
        target: root.devices.find(device => device.address === root.pairingAddress) ?? null

        function onPairingChanged() {
            if (!pairingDevice.target.pairing)
                root.endPairing();
        }
    }

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

    // Ctrl+D and Ctrl+U, from the settings window.
    function halfPage(direction) {
        scrollBar.halfPage(direction, false);
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
        id: page
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingSmall
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
                // A ScriptModel keeps the rows of the devices that stay as others come and
                // go, and so a PIN half typed.
                model: ScriptModel {
                    values: root.adapter?.enabled ? root.nearby : []
                }

                DeviceRow {
                    id: nearbyRow

                    readonly property var prompt: root.prompt?.address === nearbyRow.device.address ? root.prompt : null
                    readonly property bool asking: nearbyRow.prompt?.id !== undefined

                    function submit() {
                        if (code.acceptableInput)
                            root.submitCode(code.text);
                    }

                    status: {
                        const prompt = nearbyRow.prompt;
                        switch (prompt?.kind) {
                        case "confirm":
                            return `Pairing, passkey ${prompt.passkey}`;
                        case "displayPincode":
                            return `Type ${prompt.pincode} on the device`;
                        case "displayPasskey":
                            return `Type ${prompt.passkey} on the device` + (prompt.entered > 0 ? `, ${prompt.entered} typed` : "");
                        }
                        return nearbyRow.device.pairing ? "Pairing…" : nearbyRow.device.address;
                    }

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

                    // The PIN or passkey the agent asks for.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nearbyRow.asking
                        width: 180
                        height: 32
                        radius: height / 2
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.primary

                        onVisibleChanged: {
                            if (visible) {
                                code.text = "";
                                code.forceActiveFocus();
                            }
                        }

                        TextInput {
                            id: code
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingLarge
                            anchors.rightMargin: Theme.spacingLarge
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            validator: RegularExpressionValidator {
                                regularExpression: nearbyRow.prompt?.kind === "passkey" ? /[0-9]{1,6}/ : /[0-9A-Za-z]{1,16}/
                            }
                            color: Theme.text
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.onPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeBodyMedium

                            Keys.onReturnPressed: nearbyRow.submit()
                            Keys.onEnterPressed: nearbyRow.submit()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: code.text === ""
                                text: nearbyRow.prompt?.kind === "passkey" ? "Passkey" : "PIN"
                                color: Theme.subtext
                                font: code.font
                            }
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nearbyRow.asking
                        text: "OK"
                        active: code.acceptableInput
                        onClicked: nearbyRow.submit()
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        text: nearbyRow.device.pairing ? "Cancel" : "Pair"
                        onClicked: {
                            if (nearbyRow.device.pairing) {
                                root.endPairing();
                                nearbyRow.device.cancelPair();
                            } else {
                                root.pairingAddress = nearbyRow.device.address;
                                nearbyRow.device.pair();
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: page.top
        anchors.bottom: page.bottom
        anchors.right: parent.right
        flickable: page
    }
}
