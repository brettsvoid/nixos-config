pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../config"

// Where the displays sit, which way up they are, and which is the main display, from
// the settings window's Displays page.
//
// A display the user has arranged has a record in displays.layout, by Hyprland's
// description of it: { x, y, transform }, the transform 0 to 3 for a quarter turn each.
// One with no record keeps the placement Hyprland's config gives it. The records are
// set with `hyprctl eval` at start, after each config reload (which drops them) and
// when a display is plugged in, keeping each display's mode and scale.
//
// A new arrangement is tried before it is saved: try() applies it, and unless keep()
// follows within 15 seconds, the displays go back to where they were.
//
// The main display is XWayland's primary output, the one games size themselves to:
// displays.main, or while that is unset or not connected, the display with workspace 1.
Singleton {
    id: root

    // The displays connected, each { name, description, model, x, y, transform, width,
    // height }, the size in layout pixels before any turn.
    readonly property var monitors: Hyprland.monitors.values.filter(m => m.lastIpcObject.description).map(m => {
        const o = m.lastIpcObject;
        return {
            name: o.name,
            description: o.description,
            model: o.model,
            x: o.x,
            y: o.y,
            // Flipped transforms (4 to 7) are not offered; they count as their turn.
            transform: o.transform % 4,
            width: Math.round(o.width / o.scale),
            height: Math.round(o.height / o.scale),
            mode: `${o.width}x${o.height}@${o.refreshRate.toFixed(2)}`,
            scale: o.scale
        };
    })

    // The saved records that are well formed, by description.
    readonly property var saved: {
        const records = Settings.value("displays.layout");
        const valid = {};
        for (const description of Object.keys(records)) {
            const r = records[description];
            if (r !== null && typeof r === "object" && Number.isInteger(r.x) && Number.isInteger(r.y) && [0, 1, 2, 3].includes(r.transform))
                valid[description] = {
                    x: r.x,
                    y: r.y,
                    transform: r.transform
                };
        }
        return valid;
    }

    // The arrangement on trial, by description, or null.
    property var trial: null
    readonly property bool trying: root.trial !== null
    // Seconds until the trial is undone.
    property int remaining: 0
    // Where the displays were before the trial.
    property var _before: ({})

    // Each connected display's place: on trial, saved, or else where it is now.
    readonly property var layout: {
        const chosen = root.trial ?? root.saved;
        const result = {};
        for (const m of root.monitors)
            result[m.description] = chosen[m.description] ?? root._place(m);
        return result;
    }

    readonly property string main: Settings.value("displays.main")
    // The main display's connector, or "" while there is none.
    readonly property string primary: {
        const chosen = root.main === "" ? undefined : Hyprland.monitors.values.find(m => m.description === root.main);
        return (chosen ?? Hyprland.workspaces.values.find(w => w.id === 1)?.monitor)?.name ?? "";
    }

    function _place(m) {
        return {
            x: m.x,
            y: m.y,
            transform: m.transform
        };
    }

    // Sets each connected display that `want` places, unless `current` already has it
    // there.
    // All in one eval: Hyprland applies monitor rules at its next frame and warns about
    // any overlap then, so rules sent apart could show a half-moved layout that overlaps.
    function _apply(want, current) {
        const rules = [];
        for (const m of root.monitors) {
            const to = want[m.description];
            const from = current[m.description];
            if (!to || (from && from.x === to.x && from.y === to.y && from.transform === to.transform))
                continue;
            rules.push(`hl.monitor({ output = ${JSON.stringify("desc:" + m.description)}, mode = "${m.mode}", position = "${to.x}x${to.y}", scale = ${m.scale}, transform = ${to.transform} })`);
        }
        if (rules.length === 0)
            return;
        Quickshell.execDetached(["hyprctl", "eval", rules.join("\n")]);
        // Hyprland sends no event for a moved display.
        refresh.restart();
    }

    function _live() {
        const result = {};
        for (const m of root.monitors)
            result[m.description] = root._place(m);
        return result;
    }

    // Applies `layout` (every connected display's place, by description) and starts the
    // countdown to undo it.
    function tryLayout(layout) {
        const current = root.layout;
        if (!root.trying)
            root._before = root._live();
        root.trial = layout;
        root.remaining = 15;
        countdown.restart();
        root._apply(layout, current);
    }

    function keep() {
        if (!root.trying)
            return;
        Settings.set("displays.layout", Object.assign({}, Settings.value("displays.layout"), root.trial));
        root.trial = null;
        countdown.stop();
    }

    function revert() {
        if (!root.trying)
            return;
        const trial = root.trial;
        root.trial = null;
        countdown.stop();
        root._apply(root._before, trial);
    }

    function setPrimary() {
        primaryTries.attempts = 0;
        primaryTries.restart();
    }

    Component.onCompleted: {
        settle.restart();
        root.setPrimary();
    }
    onPrimaryChanged: root.setPrimary()
    onSavedChanged: settle.restart()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded" || event.name === "monitoradded")
                settle.restart();
            if (event.name === "monitoradded")
                root.setPrimary();
        }
    }

    // Quickshell reads the monitors again after these events; place them after that.
    Timer {
        id: settle

        interval: 1000
        onTriggered: root._apply(root.layout, root._live())
    }

    Timer {
        id: refresh

        interval: 300
        onTriggered: Hyprland.refreshMonitors()
    }

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0)
                root.revert();
        }
    }

    // XWayland may not have the output yet (at start, or as a display comes back), and
    // xrandr exits 0 then, so success is read from its monitor list, once a second for
    // up to 30 seconds.
    Timer {
        id: primaryTries

        property int attempts: 0

        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.primary === "" || ++primaryTries.attempts > 30) {
                primaryTries.stop();
                return;
            }
            if (!xrandr.running)
                xrandr.running = true;
        }
    }

    Process {
        id: xrandr

        command: ["sh", "-c", "xrandr --output \"$1\" --primary 2>/dev/null; xrandr --listmonitors 2>/dev/null", "sh", root.primary]
        stdout: StdioCollector {
            // A line per monitor: " 0: +*DP-1 2560/700x1440/400+0+0  DP-1".
            onStreamFinished: {
                if (text.split("\n").some(line => line.trim().split(/\s+/)[1] === "+*" + root.primary))
                    primaryTries.stop();
            }
        }
    }
}
