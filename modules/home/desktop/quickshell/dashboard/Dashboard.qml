import QtQuick
import "../config"
import "../services"
import "../theme"

// The dashboard drawer's content: tabs, of which only the one showing is loaded (a tab
// left behind is destroyed). A new tab is an entry in `allTabs`, a Component below and
// a setting (dashboard.show<Name>). Tab, or Ctrl+Tab, moves to the next tab. It opens
// on the first tab shown, or on the last one used if the settings say so.
FocusScope {
    id: root

    readonly property var allTabs: [
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
    // The tab asked for by name (the launcher's Wallpaper action, `custom-shell drawers
    // dashboard`), shown even when the settings hide it. Drawers.dashboardTabs lists the
    // names.
    property string asked: ""
    // The tabs shown; with none, Overview.
    readonly property var tabs: {
        const shown = root.allTabs.filter(tab => Settings.value("dashboard.show" + tab.name) || tab.name === root.asked);
        return shown.length > 0 ? shown : root.allTabs.slice(0, 1);
    }
    property int current: 0
    readonly property var shownTab: root.tabs[Math.min(root.current, root.tabs.length - 1)]

    implicitWidth: 760
    implicitHeight: tabBar.height + Theme.spacingMedium + 320

    Keys.onTabPressed: root.current = (root.current + 1) % root.tabs.length

    // Not before completion: the handler also runs as the dashboard is made, with the
    // first tab, before the last one has been read.
    property bool opened: false

    onShownTabChanged: {
        if (root.opened)
            Drawers.lastDashboardTab = root.shownTab.name;
    }

    // Opened for one tab: show it this time only.
    Component.onCompleted: {
        root.asked = Drawers.dashboardTab;
        Drawers.dashboardTab = "";
        const name = root.asked || (Settings.dashboard.rememberTab ? Drawers.lastDashboardTab : "");
        root.current = Math.max(0, root.tabs.findIndex(tab => tab.name === name));
        root.opened = true;
        Drawers.lastDashboardTab = root.shownTab.name;
    }

    // Asked for another tab while it is open (services/Drawers.qml).
    Connections {
        target: Drawers

        function onDashboardTabChanged() {
            if (Drawers.dashboardTab === "")
                return;
            root.asked = Drawers.dashboardTab;
            Drawers.dashboardTab = "";
            root.current = Math.max(0, root.tabs.findIndex(tab => tab.name === root.asked));
        }
    }

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
                readonly property bool active: tab.modelData.name === root.shownTab.name

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
        sourceComponent: root.shownTab.component
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
