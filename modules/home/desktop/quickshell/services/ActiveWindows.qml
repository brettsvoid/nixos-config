pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// The window last focused on each screen, for the bar's title. Hyprland.activeToplevel
// is the one focused window of all screens; this keeps the one each screen had when
// focus left it. Only bindings on the Hyprland module's data: no process, no timer.
Singleton {
    id: root

    // Toplevels by monitor name.
    property var lastFocused: ({})

    // The window to show for `monitor`: the one last focused there, while it is still on
    // the monitor's active workspace, otherwise that workspace's first window. Null when
    // it has none.
    function on(monitor) {
        const workspace = monitor?.activeWorkspace;
        if (!workspace)
            return null;
        const windows = workspace.toplevels.values;
        const last = root.lastFocused[monitor.name];
        // Membership, not last.workspace: that kept a closed window (null by then), as
        // nothing changed again to look the workspace up afresh.
        return windows.includes(last) ? last : windows[0] ?? null;
    }

    function record() {
        const toplevel = Hyprland.activeToplevel;
        const monitor = toplevel?.monitor;
        if (monitor)
            root.lastFocused = Object.assign({}, root.lastFocused, {
                [monitor.name]: toplevel
            });
    }

    Component.onCompleted: root.record()

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            root.record();
        }
    }

    // A window can be focused before its workspace is known.
    Connections {
        target: Hyprland.activeToplevel

        function onMonitorChanged() {
            root.record();
        }
    }
}
