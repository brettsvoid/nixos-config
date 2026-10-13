import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../theme"
import "../components/navigation.js" as Navigation

// The dashboard's effects tab: the window open and close effects in the effect library
// (window-dissolve.nix), each with Open and Close to choose it for windows opening or
// closing, and the current one previewed looping on both. Choosing runs `window-effect`,
// and the next window uses it. The choice is kept in
// ~/.local/state/window-effects/active.json, watched here, so a change from the command
// shows too. Up and Down, or Ctrl+P and Ctrl+N, move through the list, O and C choose
// the current effect for opening or closing, and Ctrl+D and Ctrl+U move half a page.
//
// It is a dashboard tab rather than a drawer of its own or a launcher mode: it chooses
// how the desktop looks, as the wallpaper tab does, it needs room for the previews, and
// as a tab it exists only while it shows, so the previews stop when it closes.
FocusScope {
    id: root

    readonly property string library: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/window-effects"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/window-effects/active.json"
    // index.json: { id, name, source, description, open: { duration }, close } each.
    property var effects: []
    // { open: id, close: id }
    property var active: ({})
    readonly property var current: root.effects[list.currentIndex] ?? null

    readonly property var sources: ({
            own: "Ours",
            liixini: "liixini/shaders",
            nirimation: "nirimation"
        })

    function choose(kind, effect) {
        if (effect && effect[kind])
            Quickshell.execDetached(["window-effect", kind, effect.id]);
    }

    function previewOf(kind) {
        const effect = root.current;
        if (!effect || !effect[kind] || effect.id === "none")
            return "";
        return `file://${root.library}/previews/${effect.id}-${kind}.frag.qsb`;
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
            list.currentIndex = Math.max(0, index);
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

    ListView {
        id: list
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingExtraSmall
        anchors.bottom: parent.bottom
        clip: true
        focus: true
        model: root.effects
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        Keys.onPressed: event => {
            const step = Navigation.step(event);
            const half = Navigation.halfPage(event);
            if (step > 0)
                list.incrementCurrentIndex();
            else if (step < 0)
                list.decrementCurrentIndex();
            else if (half !== 0)
                scrollBar.halfPage(half, true);
            else if (event.key === Qt.Key_O)
                root.choose("open", root.current);
            else if (event.key === Qt.Key_C)
                root.choose("close", root.current);
            else
                return;
            event.accepted = true;
        }

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 48
            radius: Theme.cornerLarge
            color: row.ListView.isCurrentItem ? Theme.surfaceContainerHigh : "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: list.currentIndex = row.index
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: choices.left
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyLarge
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: [root.sources[row.modelData.source] ?? row.modelData.source, row.modelData.description].filter(part => part).join(" · ")
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodySmall
                }
            }

            Row {
                id: choices
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingExtraSmall

                Repeater {
                    model: ["open", "close"]

                    Pill {
                        required property string modelData

                        text: modelData === "open" ? "Open" : "Close"
                        active: root.active[modelData] === row.modelData.id
                        opacity: row.modelData[modelData] ? 1 : 0.3
                        onClicked: root.choose(modelData, row.modelData)
                    }
                }
            }
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: list.top
        anchors.bottom: list.bottom
        anchors.right: previews.left
        anchors.rightMargin: Theme.spacingMedium
        flickable: list
    }

    Column {
        id: previews
        anchors.top: parent.top
        anchors.right: parent.right
        width: 220
        spacing: Theme.spacingExtraSmall

        Repeater {
            model: ["open", "close"]

            Column {
                id: preview

                required property string modelData

                spacing: Theme.spacingExtraSmall

                Text {
                    text: preview.modelData === "open" ? "Opening" : "Closing"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeLabelMedium
                }

                EffectPreview {
                    width: previews.width
                    height: width * 9 / 16
                    kind: preview.modelData
                    shader: root.previewOf(preview.modelData)
                    duration: root.current?.[preview.modelData]?.duration ?? 0.5
                    visible: !!root.current?.[preview.modelData]
                }
            }
        }

        Text {
            width: parent.width
            topPadding: Theme.spacingExtraSmall
            wrapMode: Text.Wrap
            text: "O: use on open · C: use on close"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodySmall
        }
    }
}
