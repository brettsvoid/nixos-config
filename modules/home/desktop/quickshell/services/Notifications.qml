pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The shell's notification server. Every notification goes into the history; a pop-up
// shows unless do-not-disturb is on, but critical ones always show. Pop-ups hide after
// the app's timeout (5 s if it gives none), except critical ones, which wait to be
// closed; the history keeps everything until it is dismissed.
//
// Only one program can own org.freedesktop.Notifications. If another has it (mako starts
// on demand when nothing owns it), the server takes over as soon as that one leaves.
Singleton {
    id: root

    // Every notification not yet dismissed (an ObjectModel), oldest first.
    readonly property var history: server.trackedNotifications
    // Notifications showing as pop-ups, newest first.
    property var popups: []
    // The name of the screen the pop-ups show on: the focused one when the latest came.
    property string screen: ""
    readonly property bool doNotDisturb: settings.doNotDisturb

    // Milliseconds a pop-up stays up when the app does not say; 0 means it stays.
    readonly property int defaultTimeout: 5000

    function timeoutOf(notification) {
        if (notification.urgency === NotificationUrgency.Critical || notification.resident)
            return 0;
        return notification.expireTimeout > 0 ? notification.expireTimeout : root.defaultTimeout;
    }

    function hidePopup(notification) {
        root.popups = root.popups.filter(n => n !== notification);
    }

    function dismiss(notification) {
        root.hidePopup(notification);
        notification.dismiss();
    }

    function clearAll() {
        for (const n of root.history.values.slice())
            root.dismiss(n);
    }

    function setDoNotDisturb(on) {
        settings.doNotDisturb = on;
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            // An app closing it, or a dismiss, takes it off the screen too.
            notification.closed.connect(() => root.hidePopup(notification));
            if (!root.doNotDisturb || notification.urgency === NotificationUrgency.Critical) {
                root.screen = Hyprland.focusedMonitor?.name ?? "";
                root.popups = [notification].concat(root.popups);
            }
        }
    }

    FileView {
        path: Quickshell.statePath("notifications.json")
        // A missing file is the first run: do-not-disturb starts off.
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool doNotDisturb: false
        }
    }
}
