pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "../config"

// The shell's notification server. Every notification goes into the history, which
// a restart does not empty: dismissing one, Clear all, running one of its actions, or
// the app withdrawing it (as Caelestia does) takes it out. The history is saved in the
// shell's state and comes back after a restart, without the actions, as the apps can
// no longer be reached then, nor withdraw what they sent. A pop-up shows unless
// do-not-disturb or game mode is on, but critical ones always show. Pop-ups hide after
// the app's timeout, or the settings' when the app gives none or the settings say to
// ignore it, except critical and resident ones, which wait to be closed.
//
// The settings may limit the history by count and by age: the oldest go as if
// dismissed. They may also limit how many pop-ups show; the oldest of those hide.
//
// Only one program can own org.freedesktop.Notifications. If another has it (mako starts
// on demand when nothing owns it), the server takes over as soon as that one leaves.
Singleton {
    id: root

    // Every notification in the history (NotificationEntry), oldest first.
    property var history: []
    // Notifications showing as pop-ups (NotificationEntry), newest first.
    property var popups: []
    // The name of the screen the pop-ups show on: the focused one when the latest came.
    property string screen: ""
    readonly property bool doNotDisturb: state.doNotDisturb

    // Milliseconds a pop-up stays up when the app does not say.
    readonly property int defaultTimeout: Settings.notifications.timeout * 1000
    // Where images that apps send as data are saved (NotificationImages).
    readonly property string imageDirectory: Quickshell.statePath("notification-images")

    // The saved history has been read, so it may be written.
    property bool _loaded: false
    // Notifications a reload carried over, waiting for the saved history (_relink).
    property var _carried: []

    function timeoutOf(entry) {
        if (entry.urgency === NotificationUrgency.Critical || entry.resident)
            return 0;
        return entry.expireTimeout > 0 && Settings.notifications.appTimeout ? entry.expireTimeout : root.defaultTimeout;
    }

    // Takes out what is past the settings' limits: beyond the newest N, or older than
    // D days. 0 is no limit.
    function _trim() {
        if (!root._loaded)
            return;
        const count = Settings.notifications.historyCount;
        const days = Settings.notifications.historyDays;
        const since = Date.now() - days * 24 * 60 * 60 * 1000;
        const old = root.history.filter((e, i) => (count > 0 && i < root.history.length - count) || (days > 0 && e.time < since));
        if (old.length === 0)
            return;
        root._remove(old);
        for (const entry of old)
            entry.notification?.dismiss();
    }

    function hidePopup(entry) {
        root.popups = root.popups.filter(e => e !== entry);
    }

    function dismiss(entry) {
        root._remove([entry]);
        entry.notification?.dismiss();
    }

    function clearAll() {
        const all = root.history;
        root._remove(all);
        for (const entry of all)
            entry.notification?.dismiss();
    }

    function setDoNotDisturb(on) {
        state.doNotDisturb = on;
    }

    // The path a saved image of this entry goes to.
    function imagePath(entry) {
        return `${root.imageDirectory}/${Math.round(entry.time)}-${entry.notificationId}.png`;
    }

    function _remove(entries) {
        root.history = root.history.filter(e => !entries.includes(e));
        root.popups = root.popups.filter(e => !entries.includes(e));
        const files = entries.map(e => e.image).filter(image => image.startsWith("file://" + root.imageDirectory + "/")).map(image => image.slice("file://".length));
        if (files.length > 0)
            Quickshell.execDetached(["rm", "-f"].concat(files));
        root._save();
    }

    // Entries are owned by JavaScript (no parent), so one left out of history and
    // popups, and no longer shown, is collected.
    function _add(notification, saved) {
        const entry = entryComponent.createObject(null, Object.assign({
            notification: notification
        }, saved ?? {}));
        entry.updated.connect(root._save);
        entry.closed.connect(() => root._closed(entry));
        return entry;
    }

    // Any close takes it out: the shell's dismiss, an action that ran, or the app
    // withdrawing it.
    function _closed(entry) {
        entry.notification = null;
        if (root.history.includes(entry))
            root._remove([entry]);
    }

    // A reload hands the live notifications to the new server again (keepOnReload),
    // marked lastGeneration. Each goes back to its saved entry, once the file is read;
    // one not saved (transient) comes back as a new entry.
    function _relink() {
        if (!root._loaded)
            return;
        const added = [];
        for (const n of root._carried) {
            const entry = root.history.find(e => !e.notification && e.notificationId === n.id && e.appName === n.appName && e.summary === n.summary);
            if (entry)
                entry.notification = n;
            else
                added.push(root._add(n));
        }
        root._carried = [];
        if (added.length > 0) {
            root.history = root.history.concat(added);
            root._save();
        }
    }

    // `saved` is the adapter's list, which is array-like rather than an Array.
    function _restore(saved) {
        const restored = Array.from(saved ?? []).map(fields => root._add(null, fields));
        // Anything that came before the file was read is newer.
        root.history = restored.concat(root.history);
        root._loaded = true;
        root._relink();
        root._trim();
        root._save();
    }

    function _save() {
        if (root._loaded)
            saveTimer.restart();
    }

    // grabToImage cannot make the folder.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.imageDirectory])

    // A tighter limit applies at once; ageing is checked hourly.
    Connections {
        target: Settings.notifications

        function onHistoryCountChanged() {
            root._trim();
        }

        function onHistoryDaysChanged() {
            root._trim();
        }
    }

    Timer {
        interval: 60 * 60 * 1000
        running: Settings.notifications.historyDays > 0
        repeat: true
        onTriggered: root._trim()
    }

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    // Pop-ups and replaced notifications come in bursts: write once they settle.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: state.history = root.history.filter(e => !e.isTransient).map(e => e.toJson())
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
            // Carried over by a reload: it already showed.
            if (notification.lastGeneration) {
                root._carried = root._carried.concat([notification]);
                root._relink();
                return;
            }
            const entry = root._add(notification);
            root.history = root.history.concat([entry]);
            root._trim();
            root._save();
            const quiet = root.doNotDisturb || GameMode.on;
            if (!quiet || entry.urgency === NotificationUrgency.Critical) {
                root.screen = Hyprland.focusedMonitor?.name ?? "";
                const max = Settings.notifications.maxPopups;
                root.popups = [entry].concat(root.popups).slice(0, max > 0 ? max : undefined);
            }
        }
    }

    FileView {
        path: Quickshell.statePath("notifications.json")
        // A missing file is the first run: do-not-disturb starts off, the history empty.
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root._restore(state.history)
        onLoadFailed: root._restore([])

        JsonAdapter {
            id: state
            property bool doNotDisturb: false
            property var history: []
        }
    }
}
