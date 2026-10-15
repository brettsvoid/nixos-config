pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's preferences, from three layers: each one's default in `schema`, then the
// Nix config's values in ~/.config/custom-shell/defaults.json (local.customShell.settings
// in custom-shell.nix, read only), then the user's own choices, from the settings window
// or a hand edit, in ~/.config/custom-shell/settings.json. That file holds only what the
// user changed, so resetting a setting returns it to the Nix value or the default.
// home-manager does not manage it, so the window can write it. A rebuild that changes a
// Nix value applies at once, unless the user has chosen that setting.
//
// A change applies at once: `set()` updates the value in memory and saves shortly
// after, and the file is watched, so a hand edit applies too. A file that is not valid
// JSON is ignored and never written over, so the edit is not lost; the settings window
// says so.
//
// This module imports nothing else from the shell, so Theme can read it.
Singleton {
    id: root

    readonly property string directory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/custom-shell"
    readonly property string file: root.directory + "/settings.json"
    readonly property string nixFile: root.directory + "/defaults.json"

    // Every setting by its key ("section.name", stored as nested objects). A number is
    // kept within min..max and rounded to `step`. A string must not be empty, and must
    // be one of `options` where there are some. A list (a default of []) must hold only
    // strings. Anything else must have the default's type. A value that fails gives the
    // default.
    readonly property var schema: ({
            "appearance.fontFamily": { default: "FiraCode Nerd Font" },
            "appearance.textScale": { default: 1, min: 0.8, max: 1.5, step: 0.05 },
            "appearance.cornerScale": { default: 1, min: 0, max: 1.5, step: 0.05 },
            "appearance.frameThickness": { default: 8, min: 2, max: 24, step: 1 },
            "appearance.animationSpeed": { default: 1, min: 0.5, max: 2, step: 0.1 },

            "clock.twelveHour": { default: false },

            "bar.edge": { default: "top", options: ["top", "bottom", "left", "right"] },
            "bar.autoHide": { default: false },
            // Screens by name (`hyprctl monitors`), so a screen plugged in later has one.
            "bar.hiddenScreens": { default: [] },
            "bar.clockSeconds": { default: false },
            "bar.clockDate": { default: true },
            "bar.workspaceCount": { default: 10, min: 1, max: 20, step: 1 },
            "bar.showEmptyWorkspaces": { default: true },
            "bar.workspacesPerMonitor": { default: false },
            "bar.scrollWorkspaces": { default: false },
            "bar.showTray": { default: true },
            "bar.showBluetooth": { default: true },
            "bar.showNetwork": { default: true },
            "bar.showAudio": { default: true },
            "bar.showBattery": { default: true },
            "bar.volumeLabel": { default: true },
            // Percent.
            "bar.volumeStep": { default: 5, min: 1, max: 20, step: 1 },
            "bar.volumeMax": { default: 100, min: 100, max: 150, step: 5 },

            "dashboard.showOverview": { default: true },
            "dashboard.showPerformance": { default: true },
            "dashboard.showWallpaper": { default: true },
            "dashboard.showEffects": { default: true },
            "dashboard.rememberTab": { default: false },
            "dashboard.weekStart": { default: "monday", options: ["monday", "sunday", "saturday"] },
            "dashboard.visualiser": { default: true },
            "dashboard.visualiserBars": { default: 32, min: 8, max: 96, step: 4 },
            "dashboard.showCpu": { default: true },
            "dashboard.showGpu": { default: true },
            "dashboard.showMemory": { default: true },
            "dashboard.showSwap": { default: true },
            "dashboard.showDisks": { default: true },
            "dashboard.showNetwork": { default: true },
            "dashboard.byteUnits": { default: "binary", options: ["binary", "decimal"] },
            "dashboard.fahrenheit": { default: false },
            // Seconds.
            "dashboard.graphSeconds": { default: 60, min: 30, max: 600, step: 30 },
            "dashboard.sampleInterval": { default: 1, min: 0.5, max: 10, step: 0.5 },

            "launcher.rows": { default: 8, min: 4, max: 16, step: 1 },
            "launcher.rankByUse": { default: true },
            // A command, split at spaces; the app's command follows it.
            "launcher.terminal": { default: "kitty" },
            "launcher.clipboardPrefix": { default: "cc" },
            "launcher.calculatorPrefix": { default: "=" },
            "launcher.actionsPrefix": { default: ">" },

            // Seconds.
            "notifications.timeout": { default: 5, min: 1, max: 30, step: 1 },
            "notifications.appTimeout": { default: true },
            // 0 is no limit.
            "notifications.maxPopups": { default: 0, min: 0, max: 10, step: 1 },
            "notifications.position": { default: "top-right", options: ["top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"] },
            // 0 is no limit, for both.
            "notifications.historyCount": { default: 0, min: 0, max: 500, step: 10 },
            "notifications.historyDays": { default: 0, min: 0, max: 90, step: 1 },
            "notifications.popupBodyLines": { default: 4, min: 1, max: 12, step: 1 },

            // Seconds.
            "osd.timeout": { default: 1.5, min: 0.5, max: 5, step: 0.5 },
            "osd.showVolume": { default: true },
            "osd.showMicrophone": { default: true },
            "osd.showBrightness": { default: true },
            "osd.position": { default: "bottom", options: ["bottom", "top", "left", "right"] },
            "osd.showInGameMode": { default: true },

            // Log out, restart and shut down wait for a second press.
            "session.confirm": { default: false },
            "session.showSleep": { default: false }
        })

    // The values in force.
    readonly property string fontFamily: root.value("appearance.fontFamily")
    readonly property real textScale: root.value("appearance.textScale")
    readonly property real cornerScale: root.value("appearance.cornerScale")
    readonly property int frameThickness: root.value("appearance.frameThickness")
    readonly property real animationSpeed: root.value("appearance.animationSpeed")

    readonly property QtObject clock: QtObject {
        readonly property bool twelveHour: root.value("clock.twelveHour")
    }

    readonly property QtObject bar: QtObject {
        readonly property string edge: root.value("bar.edge")
        readonly property bool vertical: edge === "left" || edge === "right"
        readonly property bool autoHide: root.value("bar.autoHide")
        readonly property var hiddenScreens: root.value("bar.hiddenScreens")
        readonly property bool clockSeconds: root.value("bar.clockSeconds")
        readonly property bool clockDate: root.value("bar.clockDate")
        readonly property int workspaceCount: root.value("bar.workspaceCount")
        readonly property bool showEmptyWorkspaces: root.value("bar.showEmptyWorkspaces")
        readonly property bool workspacesPerMonitor: root.value("bar.workspacesPerMonitor")
        readonly property bool scrollWorkspaces: root.value("bar.scrollWorkspaces")
        readonly property bool showTray: root.value("bar.showTray")
        readonly property bool showBluetooth: root.value("bar.showBluetooth")
        readonly property bool showNetwork: root.value("bar.showNetwork")
        readonly property bool showAudio: root.value("bar.showAudio")
        readonly property bool showBattery: root.value("bar.showBattery")
        readonly property bool volumeLabel: root.value("bar.volumeLabel")
        readonly property int volumeStep: root.value("bar.volumeStep")
        readonly property int volumeMax: root.value("bar.volumeMax")
    }

    // The tabs are read by name (dashboard.show<Name>) with value().
    readonly property QtObject dashboard: QtObject {
        readonly property bool rememberTab: root.value("dashboard.rememberTab")
        readonly property string weekStart: root.value("dashboard.weekStart")
        readonly property bool visualiser: root.value("dashboard.visualiser")
        readonly property int visualiserBars: root.value("dashboard.visualiserBars")
        readonly property bool showCpu: root.value("dashboard.showCpu")
        readonly property bool showGpu: root.value("dashboard.showGpu")
        readonly property bool showMemory: root.value("dashboard.showMemory")
        readonly property bool showSwap: root.value("dashboard.showSwap")
        readonly property bool showDisks: root.value("dashboard.showDisks")
        readonly property bool showNetwork: root.value("dashboard.showNetwork")
        readonly property string byteUnits: root.value("dashboard.byteUnits")
        readonly property bool fahrenheit: root.value("dashboard.fahrenheit")
        readonly property int graphSeconds: root.value("dashboard.graphSeconds")
        readonly property real sampleInterval: root.value("dashboard.sampleInterval")
    }

    readonly property QtObject launcher: QtObject {
        readonly property int rows: root.value("launcher.rows")
        readonly property bool rankByUse: root.value("launcher.rankByUse")
        readonly property string terminal: root.value("launcher.terminal")
        readonly property string clipboardPrefix: root.value("launcher.clipboardPrefix")
        readonly property string calculatorPrefix: root.value("launcher.calculatorPrefix")
        readonly property string actionsPrefix: root.value("launcher.actionsPrefix")
    }

    readonly property QtObject notifications: QtObject {
        readonly property int timeout: root.value("notifications.timeout")
        readonly property bool appTimeout: root.value("notifications.appTimeout")
        readonly property int maxPopups: root.value("notifications.maxPopups")
        readonly property string position: root.value("notifications.position")
        readonly property int historyCount: root.value("notifications.historyCount")
        readonly property int historyDays: root.value("notifications.historyDays")
        readonly property int popupBodyLines: root.value("notifications.popupBodyLines")
    }

    // The kinds are read by name (osd.show<Kind>) with value().
    readonly property QtObject osd: QtObject {
        readonly property real timeout: root.value("osd.timeout")
        readonly property string position: root.value("osd.position")
        readonly property bool showInGameMode: root.value("osd.showInGameMode")
    }

    readonly property QtObject session: QtObject {
        readonly property bool confirm: root.value("session.confirm")
        readonly property bool showSleep: root.value("session.showSleep")
    }

    // The user's file: { "appearance": { "textScale": 1.2 } }.
    property var user: ({})
    // The Nix config's file, the same shape.
    property var nix: ({})
    // The file is not valid JSON.
    property bool broken: false

    // The text last written, to tell our own write from a hand edit when the file
    // changes.
    property string _written: ""

    function _lookup(object, key) {
        let node = object;
        for (const part of key.split(".")) {
            if (node === null || typeof node !== "object" || !(part in node))
                return undefined;
            node = node[part];
        }
        return node;
    }

    // The value checked against the schema, or undefined if it does not fit.
    function _valid(key, value) {
        const spec = root.schema[key];
        if (!spec || value === undefined || value === null)
            return undefined;
        if (Array.isArray(spec.default))
            return Array.isArray(value) && value.every(item => typeof item === "string") ? value : undefined;
        if (typeof value !== typeof spec.default)
            return undefined;
        if (typeof value === "number") {
            if (!isFinite(value))
                return undefined;
            const clamped = Math.min(Math.max(value, spec.min), spec.max);
            // toFixed: 23 steps of 0.05 make 1.1500000000000001.
            return spec.step ? Number((Math.round(clamped / spec.step) * spec.step).toFixed(4)) : clamped;
        }
        if (typeof value === "string" && (value === "" || (spec.options && !spec.options.includes(value))))
            return undefined;
        return value;
    }

    function value(key) {
        const chosen = root._valid(key, root._lookup(root.user, key));
        if (chosen !== undefined)
            return chosen;
        const fromNix = root._valid(key, root._lookup(root.nix, key));
        return fromNix !== undefined ? fromNix : root.schema[key].default;
    }

    // Whether the user has chosen this one, so the window can offer to reset it.
    function isSet(key) {
        return root._valid(key, root._lookup(root.user, key)) !== undefined;
    }

    function set(key, value) {
        const checked = root._valid(key, value);
        if (checked === undefined)
            return;
        const user = JSON.parse(JSON.stringify(root.user));
        const parts = key.split(".");
        let node = user;
        for (const part of parts.slice(0, -1)) {
            if (node[part] === null || typeof node[part] !== "object")
                node[part] = {};
            node = node[part];
        }
        node[parts[parts.length - 1]] = checked;
        root.user = user;
        root._save();
    }

    function reset(key) {
        if (root._lookup(root.user, key) === undefined)
            return;
        const user = JSON.parse(JSON.stringify(root.user));
        const parts = key.split(".");
        const parents = [user];
        for (const part of parts.slice(0, -1))
            parents.push(parents[parents.length - 1][part]);
        delete parents[parents.length - 1][parts[parts.length - 1]];
        // Drop the sections left empty.
        for (let i = parts.length - 2; i >= 0; --i) {
            if (Object.keys(parents[i + 1]).length === 0)
                delete parents[i][parts[i]];
        }
        root.user = user;
        root._save();
    }

    // text() waits for the file (blockLoading), so the values are in force before
    // anything reads them; `loaded` would come too late, and the shell would start with
    // the defaults and then change.
    Component.onCompleted: {
        root._readNix(nixView.text());
        root._read(fileView.text());
    }

    function _save() {
        if (!root.broken)
            saveTimer.restart();
    }

    function _read(text) {
        if (text === root._written)
            return;
        root._written = "";
        if (text.trim() === "") {
            root.user = {};
            root.broken = false;
            return;
        }
        try {
            const parsed = JSON.parse(text);
            root.user = parsed !== null && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
            root.broken = false;
        } catch (e) {
            console.warn(`Settings: ${root.file} is not valid JSON (${e.message}); ignoring it`);
            root.user = {};
            root.broken = true;
        }
    }

    function _readNix(text) {
        try {
            const parsed = text.trim() === "" ? {} : JSON.parse(text);
            root.nix = parsed !== null && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (e) {
            console.warn(`Settings: ${root.nixFile} is not valid JSON (${e.message}); ignoring it`);
            root.nix = {};
        }
    }

    // A slider sends a value per step: save once it rests.
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: {
            root._written = JSON.stringify(root.user, null, 2) + "\n";
            fileView.setText(root._written);
        }
    }

    FileView {
        id: fileView
        path: root.file
        watchChanges: true
        atomicWrites: true
        printErrors: false
        blockLoading: true
        onLoaded: root._read(fileView.text())
        onLoadFailed: error => {
            // No file yet: everything is at its default.
            if (error === FileViewError.FileNotFound) {
                root._written = "";
                root.user = {};
                root.broken = false;
                if (!makeDirectory.done) {
                    makeDirectory.done = true;
                    makeDirectory.running = true;
                }
            }
        }
        // Not while a save is waiting: the file still holds the older values.
        onFileChanged: {
            if (!saveTimer.running)
                fileView.reload();
        }
        onSaveFailed: error => console.warn(`Settings: could not save ${root.file}: ${FileViewError.toString(error)}`)
    }

    // home-manager replaces its link on a rebuild, which the watch sees.
    FileView {
        id: nixView
        path: root.nixFile
        watchChanges: true
        printErrors: false
        blockLoading: true
        onLoaded: root._readNix(nixView.text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.nix = {};
        }
        onFileChanged: nixView.reload()
    }

    // FileView watches the file's directory, and only if it exists when it loads; so
    // that a file written later by hand is seen, make the directory and load again.
    // Once: the directory stays.
    Process {
        id: makeDirectory

        property bool done: false

        command: ["mkdir", "-p", root.directory]
        onExited: {
            fileView.reload();
            nixView.reload();
        }
    }
}
