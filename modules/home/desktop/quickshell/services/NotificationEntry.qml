import QtQuick
import Quickshell.Services.Notifications

// One notification in the history: a copy of what it shows, which outlives the shell
// (Notifications saves it), and while the app can still be reached, the live
// notification, whose actions run. A replaced notification updates the copy.
QtObject {
    id: root

    // The live notification, or null for one restored after a restart, whose app can no
    // longer be reached.
    property Notification notification: null

    // The server's id, only to find the live one again after a reload.
    property int notificationId: 0
    // When it came, in milliseconds since the epoch; with the id, names its saved image.
    property real time: Date.now()
    property string appName: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string summary: ""
    property string body: ""
    // A file or icon URL, or while live, image data the server holds
    // (image://qsimage/...), which the shell saves to a file (NotificationImages).
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property bool resident: false
    // Not kept in the saved history, as the spec asks.
    property bool isTransient: false
    property real expireTimeout: -1

    readonly property var actions: root.notification?.actions ?? []
    readonly property bool imageIsData: root.image.startsWith("image://qsimage/")

    // The copy changed and should be saved.
    signal updated
    // The live notification closed, for whatever reason.
    signal closed

    function copy() {
        const n = root.notification;
        if (!n)
            return;
        root.notificationId = n.id;
        root.appName = n.appName;
        root.appIcon = n.appIcon;
        root.desktopEntry = n.desktopEntry;
        root.summary = n.summary;
        root.body = n.body;
        root.image = n.image;
        root.urgency = n.urgency;
        root.resident = n.resident;
        root.isTransient = n.transient;
        root.expireTimeout = n.expireTimeout;
        root.updated();
    }

    function toJson() {
        return {
            time: root.time,
            appName: root.appName,
            appIcon: root.appIcon,
            desktopEntry: root.desktopEntry,
            summary: root.summary,
            body: root.body,
            // Image data is gone after a restart; the app icon shows instead.
            image: root.imageIsData ? "" : root.image,
            urgency: root.urgency,
            notificationId: root.notificationId
        };
    }

    Component.onCompleted: root.copy()

    // Quickshell updates a replaced notification in place, all at once. Declared here,
    // not connected from JavaScript, so a reload, which keeps the notification but not
    // this entry, leaves nothing connected to it.
    readonly property Connections live: Connections {
        target: root.notification

        function onClosed() {
            root.closed();
        }

        function onSummaryChanged() {
            root.copy();
        }

        function onBodyChanged() {
            root.copy();
        }

        function onImageChanged() {
            root.copy();
        }

        function onAppIconChanged() {
            root.copy();
        }

        function onUrgencyChanged() {
            root.copy();
        }
    }
}
