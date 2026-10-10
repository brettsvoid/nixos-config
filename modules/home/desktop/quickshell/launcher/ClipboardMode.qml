import QtQuick
import Quickshell
import Quickshell.Io
import "fuzzy.js" as Fuzzy

// The launcher's clipboard mode: type "cc" first (as in ambxst). It lists the history
// cliphist keeps, newest first, filtered by the rest of the query. Choosing an entry
// puts it back on the clipboard; the last row clears the history. Recording happens
// outside the shell (`wl-paste --watch cliphist store`, custom-shell.nix), so copies
// are kept under any shell; this only reads the list, once each time the mode opens.
QtObject {
    id: root

    readonly property string prefix: "cc"
    readonly property string placeholder: "Search clipboard history"
    // { id, text, image } per entry, newest first.
    property var entries: []

    function refresh() {
        list.running = true;
    }

    function results(query) {
        const matches = query === "" ? root.entries : root.entries.filter(e => Fuzzy.score(query, e.text) >= 0);
        const rows = matches.map(e => ({
                    title: e.text,
                    subtitle: e.image ? "Image" : "",
                    icon: e.image ? "image-x-generic" : "edit-paste",
                    entry: e
                }));
        if (query === "" && root.entries.length > 0)
            rows.push({
                title: "Clear clipboard history",
                subtitle: root.entries.length === 1 ? "1 entry" : root.entries.length + " entries",
                icon: "edit-clear-all",
                clear: true
            });
        return rows;
    }

    function activate(item) {
        if (item.clear)
            Quickshell.execDetached(["cliphist", "wipe"]);
        else
            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", item.entry.id]);
    }

    // `cliphist list` prints "<id>\t<preview>" per entry, newest first.
    property Process list: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = text.split("\n").filter(line => line !== "").map(line => {
                const tab = line.indexOf("\t");
                const preview = line.slice(tab + 1);
                return {
                    id: line.slice(0, tab),
                    text: preview,
                    image: preview.startsWith("[[ binary data")
                };
            })
        }
    }
}
