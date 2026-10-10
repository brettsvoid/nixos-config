import QtQuick
import Quickshell
import "../config"
import "../services"
import "../theme"

// The settings window: a normal window, which a window rule floats and centres
// (custom-shell.nix, matched on the title). The pages are listed on the left and only
// the one showing is loaded. Escape closes it; Ctrl+Tab moves to the next page. The
// whole window exists only while open (shell.qml), so nothing here runs otherwise.
FloatingWindow {
    id: root

    // A new page is an entry here and a Component below.
    readonly property var pages: [
        {
            name: "Appearance",
            icon: 0xF03D8, // md-palette
            component: appearancePage
        },
        {
            name: "Audio",
            icon: 0xF057E, // md-volume_high
            component: audioPage
        },
        {
            name: "Network",
            icon: 0xF05A9, // md-wifi
            component: networkPage
        },
        {
            name: "Bluetooth",
            icon: 0xF00AF, // md-bluetooth
            component: bluetoothPage
        }
    ]
    readonly property int current: Math.max(0, root.pages.findIndex(page => page.name === Windows.settingsPage))

    function show(index) {
        Windows.settingsPage = root.pages[index].name;
    }

    title: "Shell settings"
    implicitWidth: 960
    implicitHeight: 700
    minimumSize: Qt.size(760, 600)
    color: Theme.base

    // Closed by the compositor (Super+Q): unload it, so the next open starts afresh.
    onClosed: Windows.settings = false

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Windows.settings = false
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab && event.modifiers & Qt.ControlModifier) {
                root.show((root.current + 1) % root.pages.length);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab && event.modifiers & Qt.ControlModifier) {
                root.show((root.current + root.pages.length - 1) % root.pages.length);
                event.accepted = true;
            }
        }

        Rectangle {
            id: sidebar
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 220
            color: Theme.surfaceDim

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingExtraSmall

                Text {
                    leftPadding: Theme.spacingMedium
                    bottomPadding: Theme.spacingMedium
                    topPadding: Theme.spacingSmall
                    text: "Settings"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeTitleLarge
                    font.bold: true
                }

                Repeater {
                    model: root.pages

                    Rectangle {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool active: entry.index === root.current

                        width: parent.width
                        height: 44
                        radius: height / 2
                        color: entry.active ? Theme.primary : area.containsMouse ? Theme.surfaceContainer : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingLarge
                            spacing: Theme.spacingMedium

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String.fromCodePoint(entry.modelData.icon)
                                color: entry.active ? Theme.onPrimary : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeTitleMedium
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.name
                                color: entry.active ? Theme.onPrimary : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeBodyLarge
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.show(entry.index)
                        }
                    }
                }
            }
        }

        // The settings file cannot be read: say so above every page.
        Rectangle {
            id: warning
            anchors.top: parent.top
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: Theme.spacingLarge
            visible: Settings.broken
            height: visible ? warningText.implicitHeight + Theme.spacingMedium * 2 : 0
            radius: Theme.cornerMedium
            color: Qt.alpha(Theme.error, 0.15)
            border.width: 1
            border.color: Theme.error

            Text {
                id: warningText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingMedium
                wrapMode: Text.Wrap
                text: `${Settings.file} is not valid JSON, so the defaults are in use and changes made here are not saved. Fix or delete the file.`
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }

        Loader {
            anchors.top: warning.visible ? warning.bottom : parent.top
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: Theme.spacingExtraLarge
            focus: true
            sourceComponent: root.pages[root.current].component
        }
    }

    Component {
        id: appearancePage

        AppearancePage {}
    }

    Component {
        id: audioPage

        AudioPage {}
    }

    Component {
        id: networkPage

        NetworkPage {}
    }

    Component {
        id: bluetoothPage

        BluetoothPage {}
    }
}
