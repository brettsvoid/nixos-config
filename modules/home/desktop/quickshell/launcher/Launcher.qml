import QtQuick
import Quickshell
import Quickshell.Widgets
import "../components"
import "../services"
import "../theme"
import "../components/navigation.js" as Navigation

// The launcher drawer's content: a search field over a list of results. What the list
// shows depends on the mode, picked by the prefix the query starts with; apps are the
// mode without one. A mode provides `name`, `prefix`, `placeholder`, `results(query)`
// and `activate(item)`, and optionally `refresh()`, called when the mode is entered; it
// is added to `modes`. A result with `hint: true` only informs, and Enter on it does
// nothing; one with `confirm: true` asks for a second Enter or click. Up and Down, or
// Ctrl+P and Ctrl+N, move through the results, and Ctrl+D and Ctrl+U half a page.
FocusScope {
    id: root

    readonly property var modes: [appsMode, clipboardMode, calculatorMode, actionsMode]
    readonly property var mode: root.modes.find(m => m.prefix !== "" && field.text.startsWith(m.prefix)) ?? appsMode
    readonly property string query: field.text.slice(root.mode.prefix.length).trim()
    readonly property var results: root.mode.results(root.query)
    // How many rows show: the screen's launcher.rows, from FrameWindow.
    required property int rows
    readonly property int rowHeight: 48
    // The title of the result waiting for its second press, or "".
    property string pending: ""

    implicitWidth: 560
    implicitHeight: search.height + Theme.spacingSmall + root.rows * root.rowHeight

    // A hint row does nothing. The drawer closes first, so an action that opens another
    // drawer keeps it; this content stays while the drawer slides away.
    function activate(index) {
        const item = root.results[index];
        if (!item || item.hint)
            return;
        if (item.confirm && root.pending !== item.title) {
            root.pending = item.title;
            return;
        }
        root.pending = "";
        Drawers.close();
        root.mode.activate(item);
    }

    // Types the prefix of the mode asked for in Drawers.launcherMode (apps has none), as
    // the drawer opens or while it is open.
    function showMode() {
        const mode = root.modes.find(m => m.name === Drawers.launcherMode);
        Drawers.launcherMode = "";
        if (mode)
            field.text = mode.prefix;
    }

    onModeChanged: root.mode.refresh?.()
    Component.onCompleted: root.showMode()

    Connections {
        target: Drawers

        function onLauncherModeChanged() {
            if (Drawers.launcherMode !== "")
                root.showMode();
        }
    }

    AppsMode {
        id: appsMode
    }

    ClipboardMode {
        id: clipboardMode
    }

    CalculatorMode {
        id: calculatorMode
        query: root.mode === calculatorMode ? root.query : ""
    }

    ActionsMode {
        id: actionsMode
    }

    Rectangle {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        radius: Theme.cornerLarge
        color: Theme.surfaceContainer

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0349) // md-magnify
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleLarge
        }

        TextInput {
            id: field
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.text
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
            clip: true

            onTextChanged: {
                list.currentIndex = 0;
                root.pending = "";
            }

            Keys.onPressed: event => {
                const step = Navigation.step(event);
                const half = Navigation.halfPage(event);
                if (step > 0)
                    list.incrementCurrentIndex();
                else if (step < 0)
                    list.decrementCurrentIndex();
                else if (half !== 0)
                    scrollBar.halfPage(half, true);
                else
                    return;
                event.accepted = true;
            }
            Keys.onReturnPressed: root.activate(list.currentIndex)
            Keys.onEnterPressed: root.activate(list.currentIndex)

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: field.text === ""
                text: root.mode.placeholder
                color: Theme.subtext
                font: field.font
            }
        }
    }

    ListView {
        id: list
        anchors.top: search.bottom
        anchors.topMargin: Theme.spacingSmall
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingExtraSmall
        height: root.rows * root.rowHeight
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        // Moving on gives up a press waiting for its second.
        onCurrentIndexChanged: root.pending = ""

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem

            width: ListView.view.width
            height: root.rowHeight
            radius: Theme.cornerLarge
            color: row.current ? Theme.primary : "transparent"

            IconImage {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 32
                asynchronous: true
                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
            }

            Column {
                anchors.left: rowIcon.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.title
                    color: row.current ? Theme.onPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyLarge
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    text: row.modelData.title === root.pending ? "Press Enter or click again to confirm" : row.modelData.subtitle ?? ""
                    color: row.current ? Theme.onPrimary : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodySmall
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = row.index
                onClicked: root.activate(row.index)
            }
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: list.top
        anchors.bottom: list.bottom
        anchors.right: parent.right
        flickable: list
    }
}
