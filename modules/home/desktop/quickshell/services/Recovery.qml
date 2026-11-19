pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Restarts the shell when one of its windows loses its graphics resources. That most
// often means VRAM was full when the window was made, as when a monitor comes back
// while something else fills the GPU. Quickshell then hides the window and does not
// try again, so only a new shell brings it back. The windows report it with
// resourcesLost; a lock surface has no such signal.
//
// The restarts back off (2 s, 4 s, 8 s ... up to 5 minutes), as a shell started while
// VRAM is still full loses its windows again. The count is kept in the runtime folder,
// so it carries over to the next shell, and a shell that runs 10 minutes with no loss
// sets it back to zero. toggle-shell refuses while the session is locked; the next
// attempt tries again.
Singleton {
    id: root

    property int attempts: 0
    readonly property int delay: Math.min(2000 * Math.pow(2, root.attempts), 300000)

    function lost(window) {
        console.info(`${window} lost its graphics resources; restarting the shell in ${root.delay / 1000} s`);
        if (!retry.running)
            retry.start();
    }

    FileView {
        id: file

        path: Quickshell.env("XDG_RUNTIME_DIR") + "/custom-shell-restarts"
        blockLoading: true
        // Written before toggle-shell stops this shell.
        blockWrites: true
        printErrors: false
        onLoaded: root.attempts = parseInt(file.text()) || 0
    }

    Timer {
        id: retry

        interval: root.delay
        onTriggered: {
            root.attempts += 1;
            file.setText(String(root.attempts));
            Quickshell.execDetached(["toggle-shell", "restart"]);
            // Still here if toggle-shell refused.
            retry.restart();
        }
    }

    Timer {
        interval: 600000
        running: root.attempts > 0 && !retry.running
        onTriggered: {
            root.attempts = 0;
            file.setText("0");
        }
    }
}
