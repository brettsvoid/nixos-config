import QtQuick
import "../theme"
import "../components/navigation.js" as Navigation

// The search field in the settings window's sidebar. It reports the keys that move
// through the results, and Enter; Escape is left to the window, which clears the field
// before it closes.
Rectangle {
    id: root

    property alias text: input.text
    readonly property bool focused: input.activeFocus

    // 1 for Down, -1 for Up.
    signal step(int direction)
    // Ctrl+D (1) and Ctrl+U (-1): the field takes these keys, so it passes them on.
    signal halfPage(int direction)
    signal chosen

    // Takes the focus and selects what is typed, so the next key replaces it.
    function focusAll() {
        input.forceActiveFocus();
        input.selectAll();
    }

    height: 40
    radius: height / 2
    color: Theme.surfaceContainer
    border.width: root.focused ? 2 : 0
    border.color: Theme.primary

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingLarge
        text: String.fromCodePoint(0xF0349) // md-magnify
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleMedium
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingLarge * 2 + icon.implicitWidth
        anchors.rightMargin: Theme.spacingLarge
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.onPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyMedium

        Keys.onPressed: event => {
            const step = Navigation.step(event);
            const half = Navigation.halfPage(event);
            if (step !== 0)
                root.step(step);
            else if (half !== 0)
                root.halfPage(half);
            else
                return;
            event.accepted = true;
        }
        Keys.onReturnPressed: root.chosen()
        Keys.onEnterPressed: root.chosen()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "Search"
            color: Theme.subtext
            font: input.font
        }
    }
}
