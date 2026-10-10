pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How often each app has been started from the launcher, so frequent ones rank higher.
// Kept in the shell's state directory as { counts: { "<desktop entry id>": n } }.
Singleton {
    id: root

    readonly property var counts: usage.counts

    function count(id) {
        return usage.counts[id] ?? 0;
    }

    function record(id) {
        const next = Object.assign({}, usage.counts);
        next[id] = (next[id] ?? 0) + 1;
        usage.counts = next;
    }

    FileView {
        path: Quickshell.statePath("app-usage.json")
        // A missing file is the first run: the counts start empty.
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }
}
