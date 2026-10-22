import QtQuick
import Quickshell
import "../components"
import "../config"
import "../services"
import "../theme"
import "../components/navigation.js" as Navigation
import "index.js" as Index

// The settings window: a normal window, which a window rule floats and centres
// (custom-shell.nix, matched on the title). The pages are listed on the left and only
// the one showing is loaded. Escape clears the search, then closes it; Ctrl+Tab moves
// to the next page, and Ctrl+D and Ctrl+U scroll it half a page. The whole window
// exists only while open (shell.qml), so nothing here runs otherwise.
//
// The search field sits above the pages (Ctrl+F or `/` takes the focus). While it has
// the focus and text, the matches (index.js) replace the page, which is not loaded
// meanwhile; choosing one loads its page and reveals the row. The text stays, so Ctrl+F
// and Down reach the next match.
FloatingWindow {
    id: root

    // A new page is an entry here and a Component below, and a name in
    // Windows.settingsPages; its rows (or, for a page of devices, the page itself) need
    // entries in index.js.
    readonly property var pages: [
        {
            name: "Appearance",
            icon: 0xF03D8, // md-palette
            component: appearancePage
        },
        {
            name: "Window effects",
            icon: 0xF05D8, // md-animation
            component: effectsPage
        },
        {
            name: "Bar",
            icon: 0xF1513, // md-dock_top
            component: barPage
        },
        {
            name: "Dashboard",
            icon: 0xF056E, // md-view_dashboard
            component: dashboardPage
        },
        {
            name: "Launcher",
            icon: 0xF003B, // md-apps
            component: launcherPage
        },
        {
            name: "Notifications",
            icon: 0xF009A, // md-bell
            component: notificationsPage
        },
        {
            name: "Session",
            icon: 0xF0425, // md-power
            component: sessionPage
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

    // The matches for what is typed, and whether they show instead of the page.
    readonly property var matches: Index.search(search.text)
    // Set by using the field (focus or typing), cleared by showing a page.
    property bool searching: false
    readonly property bool listing: root.searching && search.text !== ""
    // The row to reveal once its page has loaded.
    property string revealKey: ""

    // Back to the page, with the keys going to it rather than the search field.
    function showPage() {
        root.searching = false;
        page.forceActiveFocus();
    }

    function show(index) {
        Windows.settingsPage = root.pages[index].name;
        root.showPage();
    }

    function open(entry) {
        root.revealKey = entry.key;
        Windows.settingsPage = entry.page;
        root.showPage();
    }

    // Takes the search that Windows.searchSettings left, if there is one.
    function takeSearch() {
        if (Windows.pendingSearch === null)
            return;
        search.text = Windows.pendingSearch;
        Windows.pendingSearch = null;
        search.focusAll();
    }

    title: "Shell settings"
    implicitWidth: 960
    implicitHeight: 700
    minimumSize: Qt.size(760, 600)
    color: Theme.base

    // Closed by the compositor (Super+Q): unload it, so the next open starts afresh.
    onClosed: Windows.settings = false

    Component.onCompleted: root.takeSearch()

    Connections {
        target: Windows

        function onSearchRequested() {
            root.takeSearch();
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (search.text !== "") {
                search.text = "";
                root.showPage();
            } else {
                Windows.settings = false;
            }
        }
        Keys.onPressed: event => {
            const half = Navigation.halfPage(event);
            if ((event.key === Qt.Key_F && event.modifiers & Qt.ControlModifier) || event.text === "/") {
                search.focusAll();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab && event.modifiers & Qt.ControlModifier) {
                root.show((root.current + 1) % root.pages.length);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab && event.modifiers & Qt.ControlModifier) {
                root.show((root.current + root.pages.length - 1) % root.pages.length);
                event.accepted = true;
            } else if (half !== 0 && page.item.halfPage) {
                // Only a page that scrolls has halfPage().
                page.item.halfPage(half);
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

                SearchField {
                    id: search
                    width: parent.width

                    onFocusedChanged: if (focused)
                        root.searching = true

                    onStep: direction => results.step(direction)
                    onHalfPage: direction => root.listing ? results.halfPage(direction) : page.item?.halfPage?.(direction)
                    onChosen: results.chooseCurrent()
                }

                // A little room before the pages.
                Item {
                    width: 1
                    height: Theme.spacingSmall
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
                text: `${Settings.file} is not valid JSON, so it is ignored and changes made here are not saved. Fix or delete the file.`
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }

        // On a page with per-screen settings: which screen its rows edit, all of them or
        // one. A screen that is not connected is offered while it has values of its own.
        Column {
            id: screens

            readonly property var picked: Settings.screens.find(s => s.name === Windows.settingsScreen)

            anchors.top: warning.visible ? warning.bottom : parent.top
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: Theme.spacingExtraLarge
            anchors.bottomMargin: 0
            visible: !root.listing && Windows.screenPages.includes(root.pages[root.current].name)
            spacing: Theme.spacingMedium

            Flow {
                width: parent.width
                spacing: Theme.spacingSmall

                Pill {
                    text: "All screens"
                    active: Windows.settingsScreen === ""
                    onClicked: Windows.pickedScreen = ""
                }

                Repeater {
                    model: Settings.screens

                    Pill {
                        required property var modelData

                        text: modelData.model ? `${modelData.name} · ${modelData.model}` : modelData.name
                        active: Windows.settingsScreen === modelData.name
                        onClicked: Windows.pickedScreen = modelData.name
                    }
                }
            }

            Flow {
                width: parent.width
                visible: screens.picked !== undefined
                spacing: Theme.spacingMedium

                Text {
                    // A pill's height, to line up with the one beside it.
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                    text: (screens.picked?.connected ? "" : "Not connected. ") + "Faded settings are the same on every screen."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyMedium
                }

                Pill {
                    visible: !(screens.picked?.connected ?? true) && Settings.hasChoicesOn(Windows.settingsScreen)
                    text: "Forget its settings"
                    onClicked: Settings.forgetScreen(Windows.settingsScreen)
                }
            }
        }

        Loader {
            id: page
            anchors.top: screens.visible ? screens.bottom : warning.visible ? warning.bottom : parent.top
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: Theme.spacingExtraLarge
            focus: true
            active: !root.listing
            sourceComponent: root.pages[root.current].component

            // The row is placed once the page has laid out.
            onLoaded: Qt.callLater(() => {
                if (root.revealKey !== "")
                    page.item?.reveal?.(root.revealKey);
                root.revealKey = "";
            })
        }

        SearchResults {
            id: results
            anchors.top: warning.visible ? warning.bottom : parent.top
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.margins: Theme.spacingExtraLarge
            visible: root.listing
            results: root.matches

            onChosen: entry => root.open(entry)
        }
    }

    Component {
        id: appearancePage

        AppearancePage {}
    }

    Component {
        id: effectsPage

        EffectsPage {}
    }

    Component {
        id: barPage

        BarPage {}
    }

    Component {
        id: dashboardPage

        DashboardPage {}
    }

    Component {
        id: launcherPage

        LauncherPage {}
    }

    Component {
        id: notificationsPage

        NotificationsPage {}
    }

    Component {
        id: sessionPage

        SessionPage {}
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
