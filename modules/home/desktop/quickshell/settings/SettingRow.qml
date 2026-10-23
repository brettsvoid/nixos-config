import QtQuick
import "../config"
import "../services"
import "../theme"
import "index.js" as Index

// One setting: its name on the left, its control (the row's children) in the middle,
// and a button to put it back to the default while it is set. A row that does not
// apply (`enabled: false`) is faded and takes no input.
//
// With a screen picked above the page (Windows.settingsScreen), a per-screen setting's
// row edits that screen, and its reset drops the screen's own value; any other row is
// faded and takes no input, as it is the same on every screen. With every screen, a
// per-screen row names the screens where it differs, and a click picks one.
Item {
    id: root

    // Its key in config/Settings.qml, or for a row that is not a setting, its name in
    // index.js. The label is written there too, so the search and the row agree.
    property string key
    readonly property string label: Index.label(root.key)
    default property alias control: holder.data

    readonly property bool perScreen: Settings.schema[root.key]?.perScreen ?? false
    // The screen the control reads and writes, or "" for every screen.
    readonly property string screen: root.perScreen ? Windows.settingsScreen : ""
    readonly property bool shared: Windows.settingsScreen !== "" && !root.perScreen
    readonly property var differsOn: root.perScreen && Windows.settingsScreen === "" ? Settings.screensWithOwn(root.key) : []

    width: parent?.width ?? 0
    implicitHeight: Math.max(48, names.implicitHeight + Theme.spacingSmall * 2)
    opacity: root.enabled && !root.shared ? 1 : 0.4

    // The row pulses twice, to show where a search result is. The highlight reaches
    // past the row's left edge, so the label is not flush with it; OptionsPage leaves
    // that room unclipped.
    function flash() {
        flashing.restart();
    }

    Rectangle {
        id: highlight
        anchors.fill: parent
        anchors.leftMargin: -Theme.spacingMedium
        radius: Theme.cornerMedium
        color: Qt.alpha(Theme.primary, 0.3)
        opacity: 0
        visible: flashing.running
    }

    SequentialAnimation {
        id: flashing

        loops: 2

        NumberAnimation {
            target: highlight
            property: "opacity"
            to: 1
            duration: 150
        }

        PauseAnimation {
            duration: 450
        }

        NumberAnimation {
            target: highlight
            property: "opacity"
            to: 0
            duration: 400
            easing.type: Easing.OutQuad
        }
    }

    Column {
        id: names
        anchors.verticalCenter: parent.verticalCenter
        // Room for the longest name, at any text size.
        width: Theme.typeBodyLarge * 11

        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
        }

        Text {
            width: parent.width
            visible: root.differsOn.length > 0
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: "Differs on " + root.differsOn.map(name => {
                const shown = name.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                return `<a href="${encodeURIComponent(name)}">${shown}</a>`;
            }).join(", ")
            color: Theme.subtext
            linkColor: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodySmall
            onLinkActivated: link => Windows.pickedScreen = decodeURIComponent(link)

            HoverHandler {
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }

    Item {
        id: holder
        anchors.left: names.right
        anchors.right: reset.left
        anchors.rightMargin: Theme.spacingMedium
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        enabled: !root.shared
    }

    Rectangle {
        id: reset
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: width
        radius: width / 2
        visible: Settings.isSet(root.key, root.screen)
        enabled: !root.shared
        color: area.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF054C) // md-undo
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Settings.reset(root.key, root.screen)
        }
    }
}
