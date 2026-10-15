import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../config"
import "../theme"

// The workspaces as pills, the active one longer. Click one to go there. The settings
// choose which show: workspaces 1 to N, with or without the empty ones, or only those on
// this screen; and whether scrolling over them moves to the next or previous one shown.
Item {
    id: root

    required property var screen
    property bool vertical: false

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1

    // The ids shown, in order. Hyprland.workspaces is an ObjectModel: search .values (it
    // has no count or get()). Reading toplevels.values keeps this live as windows open
    // and close. Special workspaces have negative ids.
    readonly property var shown: {
        const existing = Hyprland.workspaces.values.filter(w => w.id > 0);
        if (Settings.bar.workspacesPerMonitor)
            return existing.filter(w => w.monitor === root.monitor).map(w => w.id).sort((a, b) => a - b);
        const ids = [];
        for (let id = 1; id <= Settings.bar.workspaceCount; ++id) {
            if (Settings.bar.showEmptyWorkspaces || id === root.activeWorkspaceId || existing.some(w => w.id === id && w.toplevels.values.length > 0))
                ids.push(id);
        }
        return ids;
    }
    // The same as a string, which changes only when the ids do. A new array on every
    // workspace event would rebuild the pills and cut short their animations.
    readonly property string shownKey: root.shown.join(" ")

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function hasWindows(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        return ws ? ws.toplevels.values.length > 0 : false;
    }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        // One column, or one row (see Bar.qml).
        columns: root.vertical ? 1 : 99
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: root.shownKey === "" ? [] : root.shownKey.split(" ").map(Number)

            Rectangle {
                required property int modelData
                readonly property bool isActive: modelData === root.activeWorkspaceId
                readonly property bool occupied: root.hasWindows(modelData)

                Layout.preferredWidth: !root.vertical && isActive ? 24 : 8
                Layout.preferredHeight: root.vertical && isActive ? 24 : 8
                Layout.alignment: Qt.AlignCenter
                radius: 4
                color: isActive ? Theme.wsActive : (occupied ? Theme.wsOccupied : Theme.wsEmpty)

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: Theme.animDuration
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Theme.animDuration
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animDuration
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: root.vertical ? Theme.barHeight : parent.width + 8
                    height: root.vertical ? parent.height + 8 : Theme.barHeight
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + parent.modelData)
                }
            }
        }
    }

    // Under the pills, so their clicks come first; it only takes the wheel. As deep as
    // the bar, like the pills' click areas.
    MouseArea {
        anchors.centerIn: layout
        width: root.vertical ? Theme.barHeight : layout.width + 8
        height: root.vertical ? layout.height + 8 : Theme.barHeight
        z: -1
        enabled: Settings.bar.scrollWorkspaces && root.shown.length > 0
        acceptedButtons: Qt.NoButton

        // One workspace per notch, down or right for the next; touchpads add up their
        // small steps to a notch.
        property real pending: 0

        onWheel: wheel => {
            const delta = wheel.angleDelta.y !== 0 ? -wheel.angleDelta.y : wheel.angleDelta.x;
            pending += delta;
            if (Math.abs(pending) < 120)
                return;
            const step = pending > 0 ? 1 : -1;
            pending = 0;
            const ids = root.shown;
            const at = ids.indexOf(root.activeWorkspaceId);
            const next = at < 0 ? (step > 0 ? 0 : ids.length - 1) : (at + step + ids.length) % ids.length;
            Hyprland.dispatch("workspace " + ids[next]);
        }
    }
}
