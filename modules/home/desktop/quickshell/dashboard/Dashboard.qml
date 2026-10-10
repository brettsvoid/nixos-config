import QtQuick
import "../services"
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
        },
        {
            name: "Wallpaper",
            component: wallpaperTab
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

    // Opens the settings window, and closes the dashboard.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: tabBar.height
        height: width
        radius: width / 2
        color: settingsArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0493) // md-cog
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
        }

        MouseArea {
            id: settingsArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Drawers.close();
                Windows.showSettings();
            }
        }
    }

    Loader {
        anchors.top: tabBar.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Keys reach the tab (the wallpaper grid's arrows); Tab still comes back here.
        focus: true
        sourceComponent: root.tabs[root.current].component
        onLoaded: item.forceActiveFocus()
    }

    Component {
        id: overviewTab

        OverviewTab {}
    }

    Component {
        id: performanceTab

        PerformanceTab {}
    }

    Component {
        id: wallpaperTab

        WallpaperTab {}
    }
}
