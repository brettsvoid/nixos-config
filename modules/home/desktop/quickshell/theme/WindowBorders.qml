import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland's window borders in the theme's colours, in Crimson Ronin's shape: the
// focused window's edge runs from the surface through the primary colour and back, and
// the others get a faint surface edge. Set with `hyprctl keyword` rather than written
// to a file the config sources: Hyprland reloads its whole config when a sourced file
// changes, and a reload would undo game mode. A reload (a rebuild, toggle-shell) puts
// the config's colours back, so they are set again after each.
Scope {
    id: root

    // Not before the theme's colours have loaded, which would set the fallbacks first.
    readonly property bool ready: Object.keys(Theme.colors).length > 0
    readonly property string active: [root.rgba(Theme.surfaceContainer, "dd"), root.rgba(Theme.primaryContainer, "ee"), root.rgba(Theme.primary, "ff"), root.rgba(Theme.surfaceContainer, "dd"), "32deg"].join(" ")
    readonly property string inactive: root.rgba(Theme.surfaceContainer, "66")

    // Hyprland's colour syntax, rgba(rrggbbaa), with the alpha given in hex.
    function rgba(colour, alpha) {
        const hex = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return `rgba(${hex(colour.r)}${hex(colour.g)}${hex(colour.b)}${alpha})`;
    }

    Component.onCompleted: apply.restart()
    onReadyChanged: apply.restart()
    onActiveChanged: apply.restart()
    onInactiveChanged: apply.restart()

    // Once for a theme change, which changes several colours in turn.
    Timer {
        id: apply

        interval: 100
        onTriggered: {
            if (root.ready)
                Quickshell.execDetached(["hyprctl", "--batch", `keyword general:col.active_border ${root.active}; keyword general:col.inactive_border ${root.inactive}`]);
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                apply.restart();
        }
    }
}
