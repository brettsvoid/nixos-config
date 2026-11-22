import QtQuick
import Quickshell
import "../components"
import "../config"
import "../services"
import "../theme"

// The displays: where each sits beside the others, which way up it is, and which is the
// main display. A display dragged and let go snaps flush to the nearest edge of another,
// lined up by the edges' starts or centres. Each change applies at once and goes back
// after 15 seconds unless kept (services/Displays.qml).
OptionsPage {
    id: root

    // The display the rows below edit, by description.
    property string selected: Displays.monitors[0]?.description ?? ""
    readonly property var selectedMonitor: Displays.monitors.find(m => m.description === root.selected)

    // Each connected display as placed, { description, x, y, width, height, transform },
    // the size turned with it.
    readonly property var boxes: Displays.monitors.filter(m => Displays.layout[m.description]).map(m => root._box(m, Displays.layout[m.description]))

    function _box(monitor, place) {
        const turned = place.transform % 2 === 1;
        return {
            description: monitor.description,
            x: place.x,
            y: place.y,
            width: turned ? monitor.height : monitor.width,
            height: turned ? monitor.width : monitor.height,
            transform: place.transform
        };
    }

    // The free spot nearest (x, y) for `moving` that is flush with an edge of another
    // box, lined up with that edge's start or centre.
    function _snap(moving, others, x, y) {
        if (others.length === 0)
            return {
                x: 0,
                y: 0
            };
        const w = moving.width;
        const h = moving.height;
        const spots = [];
        for (const o of others) {
            for (const sx of [o.x - w, o.x + o.width]) {
                for (const sy of [o.y, o.y + Math.round((o.height - h) / 2)])
                    spots.push({
                        x: sx,
                        y: sy
                    });
            }
            for (const sy of [o.y - h, o.y + o.height]) {
                for (const sx of [o.x, o.x + Math.round((o.width - w) / 2)])
                    spots.push({
                        x: sx,
                        y: sy
                    });
            }
        }
        const free = spots.filter(s => !others.some(o => s.x < o.x + o.width && s.x + w > o.x && s.y < o.y + o.height && s.y + h > o.y));
        const distance = s => (s.x - x) ** 2 + (s.y - y) ** 2;
        return free.reduce((best, s) => distance(s) < distance(best) ? s : best, free[0] ?? {
            x: moving.x,
            y: moving.y
        });
    }

    // Moves the display to near (x, y), turned to `transform`, snaps it, puts the
    // layout's top-left at 0,0, and tries the result if anything changed.
    function place(description, x, y, transform) {
        const monitor = Displays.monitors.find(m => m.description === description);
        const moving = root._box(monitor, {
            x: x,
            y: y,
            transform: transform
        });
        const others = root.boxes.filter(b => b.description !== description);
        const spot = root._snap(moving, others, x, y);
        const placed = others.concat([Object.assign(moving, spot)]);
        const left = Math.min(...placed.map(b => b.x));
        const top = Math.min(...placed.map(b => b.y));
        const layout = {};
        for (const b of placed)
            layout[b.description] = {
                x: b.x - left,
                y: b.y - top,
                transform: b.transform
            };
        const same = Object.keys(layout).every(d => {
            const now = Displays.layout[d];
            return now && now.x === layout[d].x && now.y === layout[d].y && now.transform === layout[d].transform;
        });
        if (!same)
            Displays.tryLayout(layout);
    }

    // Turns the display about its centre, then snaps it so nothing overlaps.
    function rotate(description, transform) {
        const box = root.boxes.find(b => b.description === description);
        const turned = root._box(Displays.monitors.find(m => m.description === description), {
            x: 0,
            y: 0,
            transform: transform
        });
        root.place(description, box.x + Math.round((box.width - turned.width) / 2), box.y + Math.round((box.height - turned.height) / 2), transform);
    }

    PageHeading {
        text: "Arrangement"
        topPadding: 0
    }

    Item {
        id: arrangement

        // For the search (index.js), which finds a row by its key and lights it up.
        readonly property string key: "displays.layout"

        readonly property int padding: Theme.spacingExtraLarge
        readonly property real minX: Math.min(...root.boxes.map(b => b.x))
        readonly property real minY: Math.min(...root.boxes.map(b => b.y))
        readonly property real spanX: Math.max(...root.boxes.map(b => b.x + b.width)) - arrangement.minX
        readonly property real spanY: Math.max(...root.boxes.map(b => b.y + b.height)) - arrangement.minY
        // Screen pixels to the canvas's.
        readonly property real ratio: root.boxes.length === 0 ? 1 : Math.min((canvas.width - arrangement.padding * 2) / arrangement.spanX, (canvas.height - arrangement.padding * 2) / arrangement.spanY)
        readonly property real originX: (canvas.width - arrangement.spanX * arrangement.ratio) / 2 - arrangement.minX * arrangement.ratio
        readonly property real originY: (canvas.height - arrangement.spanY * arrangement.ratio) / 2 - arrangement.minY * arrangement.ratio

        function flash() {
            flashing.restart();
        }

        width: parent.width
        height: 300 + strip.height + Theme.spacingSmall

        Rectangle {
            id: canvas
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 300
            radius: Theme.cornerMedium
            color: Theme.surfaceDim
            border.width: 2
            border.color: "transparent"

            SequentialAnimation {
                id: flashing

                loops: 2

                ColorAnimation {
                    target: canvas
                    property: "border.color"
                    to: Theme.primary
                    duration: 150
                }

                PauseAnimation {
                    duration: 450
                }

                ColorAnimation {
                    target: canvas
                    property: "border.color"
                    to: "transparent"
                    duration: 400
                }
            }

            Repeater {
                // Kept by description, so a display being dragged is not made again when
                // the layout changes.
                model: ScriptModel {
                    values: root.boxes.map(b => b.description)
                }

                Rectangle {
                    id: display

                    required property string modelData
                    readonly property var box: root.boxes.find(b => b.description === display.modelData)
                    readonly property var monitor: Displays.monitors.find(m => m.description === display.modelData)
                    readonly property bool isSelected: display.modelData === root.selected
                    // The drag so far, in the canvas's pixels.
                    property real dragX: 0
                    property real dragY: 0

                    x: arrangement.originX + (display.box?.x ?? 0) * arrangement.ratio + display.dragX
                    y: arrangement.originY + (display.box?.y ?? 0) * arrangement.ratio + display.dragY
                    z: drag.pressed ? 1 : 0
                    width: (display.box?.width ?? 0) * arrangement.ratio
                    height: (display.box?.height ?? 0) * arrangement.ratio
                    radius: Theme.cornerSmall
                    color: display.isSelected ? Theme.primary : drag.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.2)

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingSmall * 2
                        spacing: Theme.spacingExtraSmall

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: display.monitor?.model ?? ""
                            color: display.isSelected ? Theme.onPrimary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeBodyMedium
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: display.monitor?.name ?? ""
                            color: display.isSelected ? Theme.onPrimary : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeBodySmall
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: display.monitor?.name === Displays.primary
                            text: String.fromCodePoint(0xF04CE) + " Main" // md-star
                            color: display.isSelected ? Theme.onPrimary : Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeLabelLarge
                        }
                    }

                    // No wheel handler, so the wheel scrolls the page.
                    MouseArea {
                        id: drag

                        property point start

                        anchors.fill: parent
                        hoverEnabled: true
                        // The page would take a vertical drag as a scroll.
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            root.selected = display.modelData;
                            drag.start = drag.mapToItem(canvas, mouse.x, mouse.y);
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const at = drag.mapToItem(canvas, mouse.x, mouse.y);
                            display.dragX = at.x - drag.start.x;
                            display.dragY = at.y - drag.start.y;
                        }
                        onReleased: {
                            const moved = Math.abs(display.dragX) > 3 || Math.abs(display.dragY) > 3;
                            const x = display.box.x + display.dragX / arrangement.ratio;
                            const y = display.box.y + display.dragY / arrangement.ratio;
                            display.dragX = 0;
                            display.dragY = 0;
                            if (moved)
                                root.place(display.modelData, Math.round(x), Math.round(y), display.box.transform);
                        }
                        onCanceled: {
                            display.dragX = 0;
                            display.dragY = 0;
                        }
                    }
                }
            }
        }

        // A hint, or while a change is on trial, the choice to keep it.
        Rectangle {
            id: strip
            anchors.top: canvas.bottom
            anchors.topMargin: Theme.spacingSmall
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            radius: Theme.cornerMedium
            color: Displays.trying ? Theme.primaryContainer : "transparent"

            Text {
                anchors.left: parent.left
                anchors.right: buttons.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Displays.trying ? Theme.spacingMedium : 0
                anchors.rightMargin: Theme.spacingMedium
                elide: Text.ElideRight
                text: Displays.trying ? `Keep this layout? Going back in ${Displays.remaining} s.` : "Drag a display to move it; it snaps to the nearest edge."
                color: Displays.trying ? Theme.text : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                visible: Displays.trying
                spacing: Theme.spacingSmall

                Pill {
                    text: "Revert"
                    onClicked: Displays.revert()
                }

                Pill {
                    text: "Keep"
                    active: true
                    onClicked: Displays.keep()
                }
            }
        }
    }

    Text {
        width: parent.width
        topPadding: Theme.spacingMedium
        visible: root.selectedMonitor !== undefined
        text: root.selectedMonitor ? `${root.selectedMonitor.model} · ${root.selectedMonitor.name}` : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleSmall
        font.bold: true
    }

    // Not a setting of its own: the selected display's turn in its layout record.
    SettingRow {
        key: "displays.rotation"
        enabled: root.selectedMonitor !== undefined

        Flow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Repeater {
                model: [0, 1, 2, 3]

                Pill {
                    required property int modelData

                    text: `${modelData * 90}°`
                    active: Displays.layout[root.selected]?.transform === modelData
                    onClicked: {
                        if (!active)
                            root.rotate(root.selected, modelData);
                    }
                }
            }
        }
    }

    // Saved at once: it moves nothing on screen.
    SettingRow {
        key: "displays.main"
        enabled: root.selectedMonitor !== undefined

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMedium

            Pill {
                id: mainPill

                readonly property bool isMain: root.selectedMonitor?.name === Displays.primary

                anchors.verticalCenter: parent.verticalCenter
                text: isMain ? "Main display" : "Make main"
                active: isMain
                onClicked: {
                    if (!mainPill.isMain)
                        Settings.set("displays.main", root.selected);
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - mainPill.width - parent.spacing
                wrapMode: Text.Wrap
                text: Displays.main === "" ? "Games open here. Unset, it is the display with workspace 1." : "Games open here."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodySmall
            }
        }
    }
}
