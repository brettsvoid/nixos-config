import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
        left: 0
        right: 0
    }

    implicitHeight: Theme.barHeight + Theme.barMargin * 2

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight + Theme.barMargin * 2

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "custom-bar"

    color: "transparent"

    mask: Region {
        item: barContent
    }

    Item {
        id: barContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.barMargin
        anchors.leftMargin: Theme.barMargin
        anchors.rightMargin: Theme.barMargin
        height: Theme.barHeight

        RowLayout {
            anchors.fill: parent
            spacing: 4

            BarSegment {
                implicitWidth: workspaces.implicitWidth + 24

                Workspaces {
                    id: workspaces
                    screen: bar.screen
                    anchors.centerIn: parent
                }
            }

            Item { Layout.fillWidth: true }

            BarSegment {
                implicitWidth: clock.implicitWidth + 24

                Clock {
                    id: clock
                    anchors.centerIn: parent
                }
            }

            Item { Layout.fillWidth: true }

            BarSegment {
                implicitWidth: battery.implicitWidth + 24
                visible: battery.available

                BatteryStatus {
                    id: battery
                    anchors.centerIn: parent
                }
            }
        }
    }
}
