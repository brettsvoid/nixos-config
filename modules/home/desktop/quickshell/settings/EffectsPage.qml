import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../theme"
import "../components/navigation.js" as Navigation

// The window open and close effects in the effect library (window-dissolve.nix), as a
// grid of looping previews named for their shaders. Clicking one uses it for both
// opening and closing; its Open and Close chips, shown on hover and while in use,
// choose it for one only. Choosing runs `window-effect`, and the next window uses it.
// The choice is kept in ~/.local/state/window-effects/active.json, watched here, so a
// change from the command shows too. The arrow keys move through the grid, Enter
// chooses for both, O and C for opening or closing, and Ctrl+D and Ctrl+U move half a
// page.
//
// A settings page rather than a dashboard tab: it is chosen once in a while, not
// glanced at, and the window has room for the grid. The page exists only while it
// shows, so the previews stop when the window closes or another page shows.
FocusScope {
    id: root

    // The settings window's Loader passes focus on only to an item that asks for it.
    focus: true

    readonly property string library: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/window-effects"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/window-effects/active.json"
    // index.json: { id, name, source, description, open: { duration }, close } each.
    property var effects: []
    // { open: id, close: id }
    property var active: ({})
    readonly property var current: root.effects[grid.currentIndex] ?? null
    // Names that more than one effect has: on those not our own, the label says where
    // each comes from.
    readonly property var sharedNames: {
        const seen = {};
        const shared = {};
        for (const effect of root.effects) {
            if (seen[effect.name])
                shared[effect.name] = true;
            seen[effect.name] = true;
        }
        return shared;
    }

    // Uses `effect` for each of `kinds` it has.
    function choose(kinds, effect) {
        for (const kind of kinds) {
            if (effect?.[kind])
                Quickshell.execDetached(["window-effect", kind, effect.id]);
        }
    }

    // A small rounded button, filled while `active`.
    component Chip: Rectangle {
        id: chip

        property string text
        property bool active: false

        signal clicked

        width: chipLabel.implicitWidth + Theme.spacingSmall * 2
        height: chipLabel.implicitHeight + Theme.spacingExtraSmall
        radius: height / 2
        color: chip.active ? Theme.primary : chipArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            color: chip.active ? Theme.onPrimary : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabelSmall
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    FileView {
        path: root.library + "/index.json"
        printErrors: false
        onLoaded: {
            try {
                root.effects = JSON.parse(text());
            } catch (e) {
                console.warn(`Effects: ${path} is not valid JSON (${e.message})`);
            }
            const index = root.effects.findIndex(e => e.id === root.active.open);
            grid.currentIndex = Math.max(0, index);
        }
    }

    FileView {
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.active = JSON.parse(text());
            } catch (e) {
                root.active = {};
            }
        }
    }

    Text {
        id: hint
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        wrapMode: Text.Wrap
        text: root.effects.length > 0 ? "Click an effect to use it when windows open and close, or Open or Close for one of the two. Previews play at half speed." : "No window effects are installed."
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyMedium
    }

    GridView {
        id: grid

        readonly property int labelHeight: 30

        anchors.top: hint.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingExtraSmall
        anchors.bottom: parent.bottom
        cellWidth: width / Math.max(2, Math.floor(width / 220))
        cellHeight: (cellWidth - Theme.spacingExtraSmall * 2) * 9 / 16 + Theme.spacingExtraSmall + labelHeight
        clip: true
        focus: true
        model: root.effects
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        Keys.onReturnPressed: root.choose(["open", "close"], root.current)
        Keys.onEnterPressed: root.choose(["open", "close"], root.current)
        Keys.onPressed: event => {
            const half = Navigation.halfPage(event);
            if (half !== 0)
                scrollBar.halfPage(half, true);
            else if (event.key === Qt.Key_O)
                root.choose(["open"], root.current);
            else if (event.key === Qt.Key_C)
                root.choose(["close"], root.current);
            else
                return;
            event.accepted = true;
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool inUse: root.active.open === cell.modelData.id || root.active.close === cell.modelData.id

            width: grid.cellWidth
            height: grid.cellHeight

            // A handler on the cell, not the MouseArea's hover: Qt passes hover on to
            // ancestors but not siblings, so a chip under the pointer would hide it.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        grid.currentIndex = cell.index;
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.choose(["open", "close"], cell.modelData)
            }

            Rectangle {
                id: frame
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingExtraSmall
                height: width * 9 / 16
                radius: Theme.cornerMedium
                color: cell.inUse ? Theme.primary : cell.GridView.isCurrentItem ? Theme.subtext : Theme.surfaceContainer

                EffectPreview {
                    anchors.fill: parent
                    anchors.margins: 3
                    effect: cell.modelData
                    library: root.library
                }
            }

            Row {
                anchors.left: frame.left
                anchors.leftMargin: Theme.spacingExtraSmall
                anchors.right: chips.left
                anchors.rightMargin: Theme.spacingExtraSmall
                anchors.verticalCenter: chips.verticalCenter
                spacing: Theme.spacingSmall

                Text {
                    id: name
                    width: Math.min(implicitWidth, parent.width - (source.visible ? source.implicitWidth + parent.spacing : 0))
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyMedium
                }

                Text {
                    id: source
                    anchors.baseline: name.baseline
                    visible: cell.modelData.source !== "own" && !!root.sharedNames[cell.modelData.name]
                    text: cell.modelData.source
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodySmall
                }
            }

            Row {
                id: chips
                anchors.top: frame.bottom
                anchors.right: frame.right
                height: grid.labelHeight
                spacing: Theme.spacingExtraSmall

                Repeater {
                    model: ["open", "close"]

                    Chip {
                        required property string modelData

                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData === "open" ? "Open" : "Close"
                        active: root.active[modelData] === cell.modelData.id
                        visible: !!cell.modelData[modelData] && (active || cell.GridView.isCurrentItem)
                        onClicked: root.choose([modelData], cell.modelData)
                    }
                }
            }
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: grid.top
        anchors.bottom: grid.bottom
        anchors.right: parent.right
        flickable: grid
    }
}
