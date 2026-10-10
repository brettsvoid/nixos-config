pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper's path, from the state `generate-theme` keeps (custom-shell.nix):
// ~/.local/state/custom-shell/wallpaper.json, watched, so a change from the command or
// the picker shows at once. `set()` changes it the same way: the command saves the
// choice and regenerates the theme, which the Theme singleton watches in turn.
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/custom-shell/wallpaper.json"
    readonly property string path: state.path

    function set(path) {
        Quickshell.execDetached(["generate-theme", path]);
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
