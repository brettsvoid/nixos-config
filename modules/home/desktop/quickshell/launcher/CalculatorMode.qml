import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's calculator mode: type "=" first. qalc (libqalculate, as Caelestia
// uses) works out the rest of the query, so units, currencies and bases work too:
// "= 5 km to mi", "= 0x1f to dec". It runs once typing pauses (a run takes about
// 50 ms), and only in this mode: the launcher gives it the query only while it is the
// mode. Choosing the result copies it.
QtObject {
    id: root

    readonly property string prefix: "="
    readonly property string placeholder: "Calculate"
    // The query, from the launcher while this is the mode, else "".
    property string query: ""
    // The expression last worked out, and what qalc made of it.
    property string expression: ""
    property string answer: ""
    property bool failed: false

    onQueryChanged: {
        if (root.query !== "")
            root.pause.restart();
    }

    // One run at a time: a query typed while qalc runs is worked out once it is done.
    function run() {
        if (root.qalc.running || root.query === "")
            return;
        root.qalc.command = ["qalc", "-t", "-s", "unicode off", "--", root.query];
        root.qalc.running = true;
    }

    function results(query) {
        if (query === "")
            return [
                {
                    title: "Type a sum",
                    subtitle: "Units, currencies and bases work too: 5 km to mi, 0x1f to dec",
                    icon: "accessories-calculator",
                    hint: true
                }
            ];
        if (root.expression === "")
            return [];
        if (root.failed)
            return [
                {
                    title: "qalc cannot work this out",
                    subtitle: root.expression,
                    icon: "dialog-error",
                    hint: true
                }
            ];
        return [
            {
                title: root.answer,
                subtitle: root.expression + "  (Enter copies the result)",
                icon: "accessories-calculator"
            }
        ];
    }

    // Copies what qalc makes of the query now, so Enter straight after typing copies
    // that, not the result still showing.
    function activate(item) {
        if (item.hint)
            return;
        if (root.expression === root.query)
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", root.answer]);
        else
            Quickshell.execDetached(["sh", "-c", "qalc -t -s 'unicode off' -- \"$1\" | head -n 1 | tr -d '\\n' | wl-copy", "sh", root.query]);
    }

    property Timer pause: Timer {
        interval: 120
        onTriggered: root.run()
    }

    // ASCII, so a copied minus sign is "-". qalc exits non-zero when it could not read
    // the expression, though it still prints a guess. The output is complete by the
    // time it exits.
    property Process qalc: Process {
        stdout: StdioCollector {
            id: output
        }
        onExited: code => {
            root.expression = root.qalc.command[root.qalc.command.length - 1];
            root.answer = output.text.trim().split("\n")[0];
            root.failed = code !== 0 || root.answer === "";
            if (root.expression !== root.query)
                root.run();
        }
    }
}
