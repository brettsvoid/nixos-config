pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The shell's preferences, from three layers: each one's default in `schema`, then the
// Nix config's values in ~/.config/custom-shell/defaults.json (local.customShell.settings
// in custom-shell.nix, read only), then the user's own choices, from the settings window
// or a hand edit, in ~/.config/custom-shell/settings.json. That file holds only what the
// user changed, so resetting a setting returns it to the Nix value or the default.
// home-manager does not manage it, so the window can write it. A rebuild that changes a
// Nix value applies at once, unless the user has chosen that setting.
//
// A setting marked `perScreen` can also differ from screen to screen, under `screens` in
// either file: { "screens": { "<screen>": { "bar": { "edge": "left" } } } }. A screen is
// named by Hyprland's description of it, from its EDID (as the window writes it), or by
// its connector (DP-2). On a screen, the most specific value wins: the user's for that
// screen, Nix's for that screen, then the shared values as above. A setting that is not
// per screen is ignored there. ScreenSettings holds one screen's values in force.
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
    // default. `perScreen` lets a screen have its own value.
    readonly property var schema: ({
            "appearance.fontFamily": { default: "FiraCode Nerd Font" },
            "appearance.textScale": { default: 1, min: 0.8, max: 1.5, step: 0.05 },
            "appearance.cornerScale": { default: 1, min: 0, max: 1.5, step: 0.05 },
            "appearance.frameThickness": { default: 8, min: 2, max: 24, step: 1 },
            "appearance.animationSpeed": { default: 1, min: 0.5, max: 2, step: 0.1 },

            "clock.twelveHour": { default: false },

            "bar.edge": { perScreen: true, default: "top", options: ["top", "bottom", "left", "right"] },
            "bar.autoHide": { perScreen: true, default: false },
            // Screens by description or connector (`hyprctl monitors`), so a screen
            // plugged in later has one.
            "bar.hiddenScreens": { default: [] },
            "bar.clockSeconds": { perScreen: true, default: false },
            "bar.clockDate": { perScreen: true, default: true },
            "bar.workspaceCount": { perScreen: true, default: 10, min: 1, max: 20, step: 1 },
            "bar.showEmptyWorkspaces": { perScreen: true, default: true },
            "bar.workspacesPerMonitor": { perScreen: true, default: false },
            "bar.scrollWorkspaces": { default: false },
            "bar.showTray": { perScreen: true, default: true },
            "bar.showBluetooth": { perScreen: true, default: true },
            "bar.showNetwork": { perScreen: true, default: true },
            "bar.showAudio": { perScreen: true, default: true },
            "bar.showBattery": { perScreen: true, default: true },
            "bar.volumeLabel": { perScreen: true, default: true },
            // Percent.
            "bar.volumeStep": { default: 5, min: 1, max: 20, step: 1 },
            "bar.volumeMax": { default: 100, min: 100, max: 150, step: 5 },

            // Minutes.
            "pomodoro.workMinutes": { default: 25, min: 1, max: 90, step: 1 },
            "pomodoro.breakMinutes": { default: 5, min: 1, max: 30, step: 1 },
            "pomodoro.longBreakMinutes": { default: 15, min: 1, max: 60, step: 1 },
            // Work sessions between long breaks; 0 is never.
            "pomodoro.longBreakEvery": { default: 4, min: 0, max: 8, step: 1 },
            // The next phase starts by itself, without a click.
            "pomodoro.autoStart": { default: false },
            "pomodoro.sound": { default: true },

            "dashboard.showOverview": { default: true },
            "dashboard.showPerformance": { default: true },
            "dashboard.showWallpaper": { default: true },
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

            "launcher.rows": { perScreen: true, default: 8, min: 4, max: 16, step: 1 },
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
            "notifications.position": { perScreen: true, default: "top-right", options: ["top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"] },
            // 0 is no limit, for both.
            "notifications.historyCount": { default: 0, min: 0, max: 500, step: 10 },
            "notifications.historyDays": { default: 0, min: 0, max: 90, step: 1 },
            "notifications.popupBodyLines": { default: 4, min: 1, max: 12, step: 1 },

            // Seconds.
            "osd.timeout": { default: 1.5, min: 0.5, max: 5, step: 0.5 },
            "osd.showVolume": { default: true },
            "osd.showMicrophone": { default: true },
            "osd.showBrightness": { default: true },
            "osd.position": { perScreen: true, default: "bottom", options: ["bottom", "top", "left", "right"] },
            "osd.showInGameMode": { default: true },

            // 0 is a sharp wallpaper, 1 the most blur.
            "lock.blur": { default: 1, min: 0, max: 1, step: 0.1 },
            "lock.dim": { default: 0.5, min: 0, max: 0.9, step: 0.05 },
            "lock.media": { default: true },

            // Minutes without input; 0 is never.
            "idle.lockMinutes": { default: 0, min: 0, max: 120, step: 1 },
            "idle.screenOffMinutes": { default: 0, min: 0, max: 120, step: 1 },

            // ~ is the home folder. generate-theme reads this too, with jq.
            "wallpaper.folder": { default: "~/Pictures/Wallpapers" },
            "wallpaper.fill": { perScreen: true, default: "crop", options: ["crop", "fit"] },
            // 0 is never.
            "wallpaper.changeMinutes": { default: 0, min: 0, max: 240, step: 5 },

            // Log out, restart and shut down wait for a second press.
            "session.confirm": { default: false },
            "session.showSleep": { default: false }
        })

    // The shared values in force. The per-screen ones are in ScreenSettings.
    readonly property string fontFamily: root.value("appearance.fontFamily")
    readonly property real textScale: root.value("appearance.textScale")
    readonly property real cornerScale: root.value("appearance.cornerScale")
    readonly property int frameThickness: root.value("appearance.frameThickness")
    readonly property real animationSpeed: root.value("appearance.animationSpeed")

    readonly property QtObject clock: QtObject {
        readonly property bool twelveHour: root.value("clock.twelveHour")
    }

    readonly property QtObject bar: QtObject {
        readonly property var hiddenScreens: root.value("bar.hiddenScreens")
        readonly property bool scrollWorkspaces: root.value("bar.scrollWorkspaces")
        readonly property int volumeStep: root.value("bar.volumeStep")
        readonly property int volumeMax: root.value("bar.volumeMax")
    }

    readonly property QtObject pomodoro: QtObject {
        readonly property int workMinutes: root.value("pomodoro.workMinutes")
        readonly property int breakMinutes: root.value("pomodoro.breakMinutes")
        readonly property int longBreakMinutes: root.value("pomodoro.longBreakMinutes")
        readonly property int longBreakEvery: root.value("pomodoro.longBreakEvery")
        readonly property bool autoStart: root.value("pomodoro.autoStart")
        readonly property bool sound: root.value("pomodoro.sound")
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
        readonly property int historyCount: root.value("notifications.historyCount")
        readonly property int historyDays: root.value("notifications.historyDays")
        readonly property int popupBodyLines: root.value("notifications.popupBodyLines")
    }

    // The kinds are read by name (osd.show<Kind>) with value().
    readonly property QtObject osd: QtObject {
        readonly property real timeout: root.value("osd.timeout")
        readonly property bool showInGameMode: root.value("osd.showInGameMode")
    }

    readonly property QtObject lock: QtObject {
        readonly property real blur: root.value("lock.blur")
        readonly property real dim: root.value("lock.dim")
        readonly property bool media: root.value("lock.media")
    }

    readonly property QtObject idle: QtObject {
        readonly property int lockMinutes: root.value("idle.lockMinutes")
        readonly property int screenOffMinutes: root.value("idle.screenOffMinutes")
    }

    readonly property QtObject wallpaper: QtObject {
        readonly property string folder: root.value("wallpaper.folder")
        readonly property int changeMinutes: root.value("wallpaper.changeMinutes")
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

    // The shared value in force.
    function value(key) {
        const chosen = root._valid(key, root._lookup(root.user, key));
        if (chosen !== undefined)
            return chosen;
        const fromNix = root._valid(key, root._lookup(root.nix, key));
        return fromNix !== undefined ? fromNix : root.schema[key].default;
    }

    // The value in force on `screen` (any name namesOf() knows); for "", or a setting
    // that is not per screen, the shared one.
    function valueOn(screen, key) {
        const own = screen ? root._own(screen, key, [root.user, root.nix]) : undefined;
        return own !== undefined ? own : root.value(key);
    }

    // Hyprland's description of the screen on `connector`, or "" until it is known.
    function _description(connector) {
        return Hyprland.monitors.values.find(m => m.name === connector)?.description ?? "";
    }

    // The names `screen` goes by under `screens`, the one to write first: for a
    // connected screen, named either way, its description and its connector; for one
    // that is not connected, only the name given.
    function namesOf(screen) {
        const output = Quickshell.screens.find(s => s.name === screen || root._description(s.name) === screen);
        if (!output)
            return [screen];
        const description = root._description(output.name);
        return description === "" ? [output.name] : [description, output.name];
    }

    // The screen's own value in these files, under any of its names, or undefined.
    function _own(screen, key, files) {
        if (!root.schema[key]?.perScreen)
            return undefined;
        const names = root.namesOf(screen);
        for (const file of files) {
            for (const name of names) {
                const own = root._valid(key, root._lookup(file.screens?.[name], key));
                if (own !== undefined)
                    return own;
            }
        }
        return undefined;
    }

    readonly property var _perScreenKeys: Object.keys(root.schema).filter(key => root.schema[key].perScreen)

    // The screens the window offers, each { name, model, connected }: those connected,
    // by connector, then those that are not but have values of their own, by the name
    // they are stored under.
    readonly property var screens: {
        const connected = Quickshell.screens.map(s => ({
                    name: s.name,
                    model: s.model,
                    connected: true
                }));
        const taken = connected.reduce((names, s) => names.concat(root.namesOf(s.name)), []);
        const stored = [root.user, root.nix].reduce((names, file) => names.concat(file.screens !== null && typeof file.screens === "object" ? Object.keys(file.screens) : []), []);
        const others = stored.filter((name, i) => stored.indexOf(name) === i && !taken.includes(name) && root._perScreenKeys.some(key => root._own(name, key, [root.user, root.nix]) !== undefined));
        return connected.concat(others.map(name => ({
                        name: name,
                        model: "",
                        connected: false
                    })));
    }

    // The screens, by name as in `screens`, where `key` has a value of their own.
    function screensWithOwn(key) {
        return root.screens.filter(s => root._own(s.name, key, [root.user, root.nix]) !== undefined).map(s => s.name);
    }

    // Whether the user has chosen this one, for every screen or for `screen`, so the
    // window can offer to reset it.
    function isSet(key, screen) {
        if (screen)
            return root._own(screen, key, [root.user]) !== undefined;
        return root._valid(key, root._lookup(root.user, key)) !== undefined;
    }

    // Whether the user has chosen any value for `screen` alone.
    function hasChoicesOn(screen) {
        return root._perScreenKeys.some(key => root.isSet(key, screen));
    }

    // Whether the value was valid, and so applied: for every screen, or for `screen`
    // where the setting is per screen.
    function set(key, value, screen) {
        const checked = root._valid(key, value);
        if (checked === undefined || (screen && !root.schema[key].perScreen))
            return false;
        const user = JSON.parse(JSON.stringify(root.user));
        // A screen's name may hold dots, so the path is a list.
        const parts = (screen ? ["screens", root.namesOf(screen)[0]] : []).concat(key.split("."));
        let node = user;
        for (const part of parts.slice(0, -1)) {
            if (node[part] === null || typeof node[part] !== "object")
                node[part] = {};
            node = node[part];
        }
        node[parts[parts.length - 1]] = checked;
        root.user = user;
        root._save();
        return true;
    }

    // Back to the value underneath: Nix's or the default for every screen, or for
    // `screen` the shared one (or Nix's for that screen).
    function reset(key, screen) {
        const parts = key.split(".");
        root._remove(screen ? root.namesOf(screen).map(name => ["screens", name].concat(parts)) : [parts]);
    }

    // Drops all the user's values for `screen`, as for one no longer connected.
    function forgetScreen(screen) {
        root._remove(root.namesOf(screen).map(name => ["screens", name]));
    }

    // Removes each path from the user's file, and the sections that leaves empty.
    function _remove(paths) {
        const user = JSON.parse(JSON.stringify(root.user));
        let changed = false;
        for (const parts of paths) {
            const parents = [user];
            for (const part of parts.slice(0, -1)) {
                const node = parents[parents.length - 1][part];
                if (node === null || typeof node !== "object")
                    break;
                parents.push(node);
            }
            const last = parts[parts.length - 1];
            if (parents.length < parts.length || !(last in parents[parents.length - 1]))
                continue;
            delete parents[parents.length - 1][last];
            for (let i = parts.length - 2; i >= 0; --i) {
                if (Object.keys(parents[i + 1]).length === 0)
                    delete parents[i][parts[i]];
            }
            changed = true;
        }
        if (!changed)
            return;
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
