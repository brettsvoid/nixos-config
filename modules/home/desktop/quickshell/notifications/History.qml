import QtQuick
import "../components"
import "../services"
import "../theme"
import "../components/navigation.js" as Navigation

// The notification history drawer's content: everything not yet dismissed, grouped by
// app (the app with the latest notification first), with do-not-disturb and clear all.
// Ctrl+D and Ctrl+U scroll half a page.
FocusScope {
    id: root

    readonly property var rows: {
        const all = Notifications.history.values.slice().reverse();
        const apps = [...new Set(all.map(n => n.appName))];
        // Plain loops: Qt's JavaScript engine has no Array.prototype.flatMap.
        const rows = [];
        for (const app of apps) {
            for (const n of all) {
                if (n.appName === app)
                    rows.push({
                        notification: n,
                        appName: app || "Unknown app"
                    });
            }
        }
        return rows;
    }

    implicitWidth: 420
    implicitHeight: 640

    Keys.onPressed: event => {
        const half = Navigation.halfPage(event);
        if (half === 0)
            return;
        scrollBar.halfPage(half, false);
        event.accepted = true;
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            HeaderButton {
                glyph: Notifications.doNotDisturb ? 0xF0A93 : 0xF009C // md-bell_sleep_outline, md-bell_outline
                label: "Do not disturb"
                active: Notifications.doNotDisturb
                onClicked: Notifications.setDoNotDisturb(!Notifications.doNotDisturb)
            }

            HeaderButton {
                glyph: 0xF039F // md-notification_clear_all
                label: "Clear all"
                enabled: root.rows.length > 0
                onClicked: Notifications.clearAll()
            }
        }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingSmall
        anchors.left: parent.left
        anchors.right: scrollBar.left
        anchors.rightMargin: Theme.spacingExtraSmall
        anchors.bottom: parent.bottom
        clip: true
        spacing: Theme.spacingSmall
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        section.property: "appName"
        section.delegate: Text {
            required property string section

            width: ListView.view.width
            topPadding: Theme.spacingSmall
            leftPadding: Theme.spacingExtraSmall
            text: section
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleSmall
            font.bold: true
        }

        delegate: NotificationCard {
            required property var modelData

            width: ListView.view.width
            notification: modelData.notification
        }

        Text {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: "No notifications"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
        }
    }

    ScrollBar {
        id: scrollBar
        anchors.top: list.top
        anchors.bottom: list.bottom
        anchors.right: parent.right
        flickable: list
    }
}
