import QtQuick
import "../theme"

// An on/off switch. It does not change `checked` itself: `toggled` asks for the other
// state, so `checked` can stay bound to what it shows. Click it, or press Space or
// Enter once it has focus.
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    activeFocusOnTab: true

    Keys.onSpacePressed: root.toggled(!root.checked)
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onEnterPressed: root.toggled(!root.checked)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHigh
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }

        Rectangle {
            x: root.checked ? parent.width - width - 4 : 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 8
            height: width
            radius: width / 2
            color: root.checked ? Theme.onPrimary : Theme.subtext

            Behavior on x {
                NumberAnimation {
                    duration: Theme.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggled(!root.checked);
        }
    }
}
