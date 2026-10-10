import QtQuick
import "../theme"

// The bar's content, laid out along the top band of the frame: workspaces on the
// left, the clock in the middle, the tray and status icons on the right.
Item {
    id: root

    required property var screen

    Workspaces {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
    }

    Clock {
        anchors.centerIn: parent
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingLarge

        Tray {
            anchors.verticalCenter: parent.verticalCenter
        }

        BluetoothStatus {
            anchors.verticalCenter: parent.verticalCenter
        }

        NetworkStatus {
            anchors.verticalCenter: parent.verticalCenter
        }

        AudioStatus {
            anchors.verticalCenter: parent.verticalCenter
        }

        BatteryStatus {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
