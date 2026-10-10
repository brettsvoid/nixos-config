pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether game mode is on, from the state the game-mode command keeps
// ($XDG_RUNTIME_DIR/game-mode, desktop-game-mode). While it is on the shell steps
// aside: open drawers close, the frame and bar shrink away and the edges are released
// (ScreenShell), and notifications wait in the history unless critical (Notifications).
Singleton {
    id: root

    property bool on: false

    onOnChanged: {
        if (root.on)
            Drawers.close();
    }

    FileView {
        id: file
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/game-mode"
        // Watched with its directory, so it is seen when game-mode first creates it.
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.on = file.text().trim() === "on"
        onLoadFailed: root.on = false
    }
}
