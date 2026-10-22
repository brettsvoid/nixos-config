pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Whether Caps Lock and Num Lock are on. Hyprland sends no event for them, so a bind on
// each key (custom-shell.nix: not swallowed, any modifiers, also while locked) fires
// this shortcut when the key comes up, and the shell asks `hyprctl devices -j` once. A
// key is on when any keyboard says so: Hyprland's `main` keyboard may be a mouse's
// system-control device. Read at start and when game mode ends, never in game mode.
Singleton {
    id: root

    property bool caps: false
    property bool num: false

    // Not before game mode's state is known, or a start in game mode would read once.
    readonly property bool active: GameMode.loaded && !GameMode.on

    onActiveChanged: root.refresh()

    function refresh() {
        if (root.active)
            read.running = true;
    }

    Component.onCompleted: root.refresh()

    GlobalShortcut {
        appid: "custom-shell"
        name: "lockkeys"
        description: "Re-read Caps Lock and Num Lock"
        onReleased: root.refresh()
    }

    Process {
        id: read
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboards = JSON.parse(text).keyboards ?? [];
                root.caps = keyboards.some(k => k.capsLock);
                root.num = keyboards.some(k => k.numLock);
            }
        }
    }
}
