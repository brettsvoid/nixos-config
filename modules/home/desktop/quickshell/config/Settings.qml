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
    // kept within min..max and rounded to `step`; anything else must have the
    // default's type. A value that fails gives the default.
    readonly property var schema: ({
            "appearance.fontFamily": {
                default: "FiraCode Nerd Font"
            },
            "appearance.textScale": {
                default: 1,
                min: 0.8,
                max: 1.5,
                step: 0.05
            },
            "appearance.cornerScale": {
                default: 1,
                min: 0,
                max: 1.5,
                step: 0.05
            },
            "appearance.frameThickness": {
                default: 8,
                min: 2,
                max: 24,
                step: 1
            },
            "appearance.animationSpeed": {
                default: 1,
                min: 0.5,
                max: 2,
                step: 0.1
            }
        })

    // The values in force.
    readonly property string fontFamily: root.value("appearance.fontFamily")
    readonly property real textScale: root.value("appearance.textScale")
    readonly property real cornerScale: root.value("appearance.cornerScale")
    readonly property int frameThickness: root.value("appearance.frameThickness")
    readonly property real animationSpeed: root.value("appearance.animationSpeed")

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
        if (!spec || value === undefined || typeof value !== typeof spec.default)
            return undefined;
        if (typeof value === "number") {
            if (!isFinite(value))
                return undefined;
            const clamped = Math.min(Math.max(value, spec.min), spec.max);
            // toFixed: 23 steps of 0.05 make 1.1500000000000001.
            return spec.step ? Number((Math.round(clamped / spec.step) * spec.step).toFixed(4)) : clamped;
        }
        if (typeof value === "string" && value === "")
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
