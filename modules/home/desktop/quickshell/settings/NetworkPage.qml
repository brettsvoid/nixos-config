import QtQuick
import Quickshell.Io
import Quickshell.Networking
import "../components"
import "../theme"

// Ethernet and Wi-Fi, from NetworkManager through Quickshell's Networking module. Wi-Fi
// networks are NetworkManager's own profiles, not declared in Nix, so the page joins,
// forgets and stops networks connecting by themselves. The Wi-Fi scanner runs only
// while the page shows; with it off, NetworkManager lists only known networks.
FocusScope {
    id: root

    readonly property var wired: Networking.devices.values.filter(device => device.type === DeviceType.Wired)
    readonly property var wifi: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    // The security types a password (PSK) is enough for.
    readonly property var pskTypes: [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae]

    // The network whose password is being asked for, and the last one given one.
    property var askingFor: null
    property string triedPassword: ""
    // What went wrong, by network name.
    property var failures: ({})

    function setFailure(name, text) {
        const failures = Object.assign({}, root.failures);
        if (text)
            failures[name] = text;
        else
            delete failures[name];
        root.failures = failures;
    }

    function join(network) {
        root.setFailure(network.name, "");
        const open = network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
        if (network.known || open)
            network.connect();
        else if (root.pskTypes.includes(network.security))
            root.askingFor = network;
        else
            root.setFailure(network.name, "Needs more than a password: use nm-connection-editor");
    }

    function joinWithPassword(network, password) {
        root.askingFor = null;
        root.triedPassword = network.name;
        network.connectWithPsk(password);
    }

    function failed(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets && root.pskTypes.includes(network.security)) {
            // Asked again after a password was given: it was wrong.
            root.setFailure(network.name, root.triedPassword === network.name ? "Wrong password" : "");
            root.askingFor = network;
        } else {
            root.setFailure(network.name, "Could not connect: " + ConnectionFailReason.toString(reason));
        }
        root.triedPassword = "";
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
    }

    component IconButton: Rectangle {
        id: button

        property int glyph
        property color glyphColor: Theme.text

        signal clicked

        width: 36
        height: width
        radius: width / 2
        color: buttonArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(button.glyph)
            color: button.glyphColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
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

            Repeater {
                model: root.wired

                Column {
                    id: wiredDevice

                    required property var modelData
                    required property int index
                    property var addresses: []

                    width: parent?.width ?? 0
                    spacing: Theme.spacingExtraSmall

                    // The addresses come from `ip`: Quickshell has only the hardware
                    // address. Read when the page opens and when the link changes.
                    Process {
                        id: addressReader
                        command: ["ip", "-j", "address", "show", "dev", wiredDevice.modelData.name]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: {
                                try {
                                    const info = JSON.parse(text)[0]?.addr_info ?? [];
                                    wiredDevice.addresses = info.filter(a => a.scope === "global").map(a => `${a.local}/${a.prefixlen}`);
                                } catch (e) {
                                    wiredDevice.addresses = [];
                                }
                            }
                        }
                    }

                    Connections {
                        target: wiredDevice.modelData

                        function onConnectedChanged() {
                            addressReader.running = true;
                        }
                    }

                    Heading {
                        text: root.wired.length > 1 ? `Ethernet (${wiredDevice.modelData.name})` : "Ethernet"
                        topPadding: wiredDevice.index === 0 ? 0 : Theme.spacingLarge
                    }

                    Row {
                        spacing: Theme.spacingMedium

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(0xF0200) // md-ethernet
                            color: wiredDevice.modelData.connected ? Theme.primary : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeTitleLarge
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: {
                                    const device = wiredDevice.modelData;
                                    if (device.connected)
                                        return device.linkSpeed > 0 ? `Connected, ${device.linkSpeed} Mb/s` : "Connected";
                                    if (!device.hasLink)
                                        return "Cable unplugged";
                                    return ConnectionState.toString(device.state);
                                }
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeBodyLarge
                            }

                            Line {
                                visible: wiredDevice.addresses.length > 0
                                text: wiredDevice.addresses.join("   ")
                            }

                            Line {
                                text: `${wiredDevice.modelData.name}   ${wiredDevice.modelData.address}`
                            }
                        }
                    }
                }
            }

            Repeater {
                model: root.wifi

                Column {
                    id: wifiDevice

                    required property var modelData

                    readonly property var networks: wifiDevice.modelData.networks.values.filter(network => network.name !== "").sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

                    width: parent?.width ?? 0

                    // Scan while the page shows.
                    Component.onCompleted: wifiDevice.modelData.scannerEnabled = true
                    Component.onDestruction: wifiDevice.modelData.scannerEnabled = false

                    Item {
                        width: parent.width
                        height: wifiHeading.implicitHeight

                        Heading {
                            id: wifiHeading
                            text: root.wifi.length > 1 ? `Wi-Fi (${wifiDevice.modelData.name})` : "Wi-Fi"
                            topPadding: root.wired.length > 0 ? Theme.spacingLarge : 0
                        }

                        Switch {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.spacingSmall
                            checked: Networking.wifiEnabled
                            enabled: Networking.wifiHardwareEnabled
                            onToggled: checked => Networking.wifiEnabled = checked
                        }
                    }

                    Line {
                        visible: !Networking.wifiHardwareEnabled
                        bottomPadding: Theme.spacingSmall
                        text: "Turned off by a hardware switch"
                    }

                    Line {
                        visible: Networking.wifiEnabled && wifiDevice.networks.length === 0
                        bottomPadding: Theme.spacingSmall
                        text: "Looking for networks…"
                    }

                    Repeater {
                        model: Networking.wifiEnabled ? wifiDevice.networks : []

                        Column {
                            id: row

                            required property var modelData
                            readonly property var network: row.modelData
                            readonly property bool secured: row.network.security !== WifiSecurityType.Open && row.network.security !== WifiSecurityType.Owe
                            readonly property string failure: root.failures[row.network.name] ?? ""
                            readonly property var profile: row.network.nmSettings[0] ?? null
                            // NetworkManager's default is on.
                            property bool autoconnect: true

                            function readProfile() {
                                row.autoconnect = row.profile?.read()?.connection?.autoconnect ?? true;
                            }

                            width: parent?.width ?? 0

                            onProfileChanged: row.readProfile()
                            Component.onCompleted: row.readProfile()

                            Connections {
                                target: row.network

                                function onConnectionFailed(reason) {
                                    root.failed(row.network, reason);
                                }

                                function onConnectedChanged() {
                                    if (row.network.connected)
                                        root.setFailure(row.network.name, "");
                                }
                            }

                            Connections {
                                target: row.profile

                                function onSettingsChanged() {
                                    row.readProfile();
                                }

                                function onLoaded() {
                                    row.readProfile();
                                }
                            }

                            Item {
                                width: parent.width
                                height: 56

                                Text {
                                    id: strength
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    text: {
                                        const level = Math.min(3, Math.floor(row.network.signalStrength * 4));
                                        // md-wifi_strength_1..4, and their _lock forms.
                                        const glyphs = row.secured ? [0xF0921, 0xF0924, 0xF0927, 0xF092A] : [0xF091F, 0xF0922, 0xF0925, 0xF0928];
                                        return String.fromCodePoint(glyphs[level]);
                                    }
                                    color: row.network.connected ? Theme.primary : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeTitleLarge
                                }

                                Column {
                                    anchors.left: strength.right
                                    anchors.right: buttons.left
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.rightMargin: Theme.spacingMedium
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: row.network.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.typeBodyLarge
                                    }

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                        text: {
                                            if (row.failure)
                                                return row.failure;
                                            switch (row.network.state) {
                                            case ConnectionState.Connecting:
                                                return "Connecting…";
                                            case ConnectionState.Disconnecting:
                                                return "Disconnecting…";
                                            case ConnectionState.Connected:
                                                return "Connected";
                                            }
                                            return row.network.known ? "Saved" : "";
                                        }
                                        color: row.failure ? Theme.error : Theme.subtext
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.typeBodySmall
                                    }
                                }

                                Row {
                                    id: buttons
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingSmall

                                    // Whether NetworkManager joins it by itself.
                                    Line {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: row.profile !== null
                                        text: "Auto"
                                    }

                                    Switch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: row.profile !== null
                                        checked: row.autoconnect
                                        onToggled: checked => row.profile.write({
                                                connection: {
                                                    autoconnect: checked
                                                }
                                            })
                                    }

                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: row.network.known
                                        glyph: 0xF01B4 // md-delete
                                        onClicked: {
                                            root.setFailure(row.network.name, "");
                                            row.network.forget();
                                        }
                                    }

                                    Pill {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.network.connected ? "Disconnect" : "Connect"
                                        active: false
                                        onClicked: row.network.connected ? row.network.disconnect() : root.join(row.network)
                                    }
                                }
                            }

                            // The password, while it is asked for.
                            Rectangle {
                                visible: root.askingFor === row.network
                                width: parent.width
                                height: visible ? 48 : 0
                                radius: height / 2
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.primary

                                onVisibleChanged: {
                                    if (visible) {
                                        password.text = "";
                                        password.forceActiveFocus();
                                    }
                                }

                                TextInput {
                                    id: password
                                    anchors.left: parent.left
                                    anchors.right: join.left
                                    anchors.leftMargin: Theme.spacingLarge
                                    anchors.rightMargin: Theme.spacingMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    echoMode: TextInput.Password
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.typeBodyLarge
                                    clip: true

                                    Keys.onReturnPressed: root.joinWithPassword(row.network, password.text)
                                    Keys.onEnterPressed: root.joinWithPassword(row.network, password.text)
                                    Keys.onEscapePressed: root.askingFor = null

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: password.text === ""
                                        text: "Password for " + row.network.name
                                        color: Theme.subtext
                                        font: password.font
                                    }
                                }

                                Pill {
                                    id: join
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Join"
                                    active: true
                                    onClicked: root.joinWithPassword(row.network, password.text)
                                }
                            }
                        }
                    }
                }
            }

            Line {
                visible: root.wired.length === 0 && root.wifi.length === 0
                text: Networking.backend === NetworkBackendType.None ? "NetworkManager is not running" : "No network devices"
            }
        }
    }
}
