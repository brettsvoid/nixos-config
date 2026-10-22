pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// The wallpaper's path, from the state `generate-theme` keeps (custom-shell.nix):
// ~/.local/state/custom-shell/wallpaper.json, watched, so a change from the command or
// the picker shows at once. `set()` changes it the same way: the command saves the
// choice and regenerates the theme, which the Theme singleton watches in turn. The
// settings choose the folder images come from, and may change the wallpaper to a
// random one every N minutes (not in game mode, where the new theme would cost).
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/custom-shell/wallpaper.json"
    readonly property string path: state.path
    // matugen's scheme variant and light or dark.
    readonly property string scheme: state.scheme
    readonly property string mode: state.mode
    readonly property var schemes: ["scheme-neutral", "scheme-tonal-spot", "scheme-content", "scheme-fidelity", "scheme-expressive", "scheme-fruit-salad", "scheme-monochrome", "scheme-rainbow"]
    // The settings' folder, with ~ for the home folder, and no slash at the end.
    readonly property string folder: Settings.wallpaper.folder.replace(/^~(?=\/|$)/, Quickshell.env("HOME")).replace(/(.)\/+$/, "$1")
    // Set while isFile() reads a path that is not a file.
    property bool probeFailed: false

    function set(path) {
        Quickshell.execDetached(["generate-theme", path]);
    }

    function setScheme(scheme) {
        Quickshell.execDetached(["generate-theme", "--scheme", scheme]);
    }

    function setMode(mode) {
        Quickshell.execDetached(["generate-theme", "--mode", mode]);
    }

    // Whether `path` is an existing file, which generate-theme needs: it takes the
    // folder's first image for anything else. A full path: the shell's own working
    // folder is no use to a caller. FileView reports a folder or a missing file as a
    // failed load (`loaded` is true for a folder), and is let go of straight after.
    function isFile(path) {
        if (!path.startsWith("/"))
            return false;
        root.probeFailed = false;
        probe.path = path;
        probe.waitForJob();
        probe.path = "";
        return !root.probeFailed;
    }

    FileView {
        id: probe
        printErrors: false
        onLoadFailed: root.probeFailed = true
    }

    // An image from the folder other than the one showing. They are links into the
    // store (home-manager), hence -L.
    function random() {
        Quickshell.execDetached(["sh", "-c", "f=$(find -L \"$2\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) ! -path \"$1\" | shuf -n 1); [ -n \"$f\" ] && exec generate-theme \"$f\"", "sh", root.path, root.folder]);
    }

    Timer {
        interval: Settings.wallpaper.changeMinutes * 60 * 1000
        running: Settings.wallpaper.changeMinutes > 0 && !GameMode.on
        repeat: true
        onTriggered: root.random()
    }

    FileView {
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // Nothing chosen yet (the shell started before the first activation): let the
        // command pick the default.
        onLoadFailed: Quickshell.execDetached(["generate-theme"])

        JsonAdapter {
            id: state
            property string path: ""
            property string scheme: ""
            property string mode: ""
        }
    }
}
