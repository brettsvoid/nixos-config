pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../services"

// The lock screen: Wayland's session lock covers every screen (LockSurface), and PAM
// checks the password against /etc/pam.d/custom-shell
// (modules/system/nixos/hyprland.nix). Super+L, the session menu and hypridle before
// the machine sleeps all come here (custom-shell.nix).
//
// If the shell dies while locked, the session stays locked: that is the protocol's
// promise, and Hyprland shows its "lockscreen app died" screen. `lock-recover`, run
// from a text console, starts the shell again and locks with it, so the password gets
// you back in (docs/lock-screen.md).
Singleton {
    id: root

    // True once Hyprland has every screen covered. Not WlSessionLock.locked, which tells
    // nobody when it turns on (Quickshell 0.3.0 signals that change only on unlock).
    readonly property bool locked: sessionLock.secure
    // The password typed so far. Every screen shows it as dots and takes the typing, so
    // it does not matter which one Hyprland gives the keyboard.
    property string password: ""
    // A check is running: PAM answers at once when it is right and two seconds after it
    // is wrong (pam_unix's delay). It runs in its own process, so nothing freezes.
    readonly property bool checking: pam.active
    // Why the last attempt failed, until typing starts again.
    property string message: ""
    // Counts failed attempts, so each screen shakes its field on the next one.
    property int failures: 0

    readonly property string pamConfig: "custom-shell"

    function lock() {
        if (sessionLock.locked)
            return;
        // Without the PAM service no password would unlock, and only a text console would
        // get you back in, so refuse. It comes with the system generation; it is missing
        // only while this shell runs ahead of a switch.
        pamFile.reload();
        pamFile.waitForJob();
        if (!pamFile.loaded) {
            console.error("Not locking: /etc/pam.d/" + root.pamConfig + " is missing");
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Lock screen", "Not locked", "/etc/pam.d/" + root.pamConfig + " is missing, so no password could unlock it. Switch to the new system generation first."]);
            return;
        }
        Drawers.close();
        root.password = "";
        root.message = "";
        sessionLock.locked = true;
    }

    function type(text) {
        if (root.checking)
            return;
        root.message = "";
        root.password += text;
    }

    function erase() {
        if (!root.checking)
            root.password = root.password.slice(0, -1);
    }

    function clear() {
        if (!root.checking)
            root.password = "";
    }

    function submit() {
        if (root.checking || root.password === "")
            return;
        root.message = "";
        if (!pam.start()) {
            root.message = "Could not start the password check";
            root.failures++;
        }
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {}
    }

    PamContext {
        id: pam

        config: root.pamConfig

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.password);
        }

        onCompleted: result => {
            root.password = "";
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                return;
            }
            root.message = result === PamResult.Failed ? "Wrong password" : result === PamResult.MaxTries ? "Too many attempts" : "Could not check the password";
            root.failures++;
        }
    }

    FileView {
        id: pamFile

        path: "/etc/pam.d/" + root.pamConfig
        blockLoading: true
        printErrors: false
    }
}
