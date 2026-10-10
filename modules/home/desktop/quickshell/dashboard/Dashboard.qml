import QtQuick
import "../theme"

// The dashboard drawer's content: tabs, of which only the one showing is loaded (a tab
// left behind is destroyed). A new tab is an entry in `tabs` and a Component below.
// Tab, or Ctrl+Tab, moves to the next tab.
FocusScope {
    id: root

    readonly property var tabs: [
        {
            name: "Overview",
            component: overviewTab
        },
        {
            name: "Performance",
            component: performanceTab
        }
    ]
    property int current: 0

    implicitWidth: 760
    implicitHeight: tabBar.height + Theme.spacingMedium + 320

    Keys.onTabPressed: root.current = (root.current + 1) % root.tabs.length

    Row {
        id: tabBar
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingSmall
        height: 36

        Repeater {
            model: root.tabs

            Rectangle {
                id: tab

                required property var modelData
                required property int index
                readonly property bool active: tab.index === root.current

                width: label.implicitWidth + Theme.spacingLarge * 2
                height: parent.height
                radius: height / 2
                color: tab.active ? Theme.primary : area.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tab.modelData.name
                    color: tab.active ? Theme.onPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeLabelLarge
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.current = tab.index
                }
            }
        }
    }

    Loader {
        anchors.top: tabBar.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: root.tabs[root.current].component
    }

    Component {
        id: overviewTab

        OverviewTab {}
    }

    Component {
        id: performanceTab

        PerformanceTab {}
    }
}
