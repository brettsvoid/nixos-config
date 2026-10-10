import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../services"
import "../theme"

// One notification: its image or app icon, the app's name, the summary, the body (with
// the simple markup apps send) and its action buttons. Clicking the card runs its
// default action. As a pop-up, the × only takes it off the screen and it hides itself
// after its timeout, paused while the pointer is on it; in the history, the × dismisses it.
Rectangle {
    id: root

    required property Notification notification
    property bool popup: false

    readonly property bool critical: root.notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: root.notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: root.notification.actions.filter(a => a.identifier !== "default")
    // An icon name goes through the icon theme; paths and image URLs are used as they are.
    readonly property string iconSource: {
        const icon = root.notification.appIcon || (DesktopEntries.byId(root.notification.desktopEntry)?.icon ?? "");
        if (icon === "")
            return "";
        return icon.includes("/") || icon.includes(":") ? icon : Quickshell.iconPath(icon, true);
    }
    readonly property string imageSource: root.notification.image || root.iconSource

    function close() {
        if (root.popup)
            Notifications.hidePopup(root.notification);
        else
            Notifications.dismiss(root.notification);
    }

    implicitWidth: 360
    implicitHeight: content.implicitHeight + Theme.spacingMedium * 2
    radius: Theme.cornerLarge
    color: Theme.surfaceContainer
    border.width: root.critical ? 2 : 0
    border.color: Theme.error

    Timer {
        interval: Notifications.timeoutOf(root.notification)
        running: root.popup && interval > 0 && !hover.containsMouse
        onTriggered: Notifications.hidePopup(root.notification)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction)
                root.defaultAction.invoke();
        }
    }

    Row {
        id: content
        x: Theme.spacingMedium
        y: Theme.spacingMedium
        width: parent.width - Theme.spacingMedium * 2
        spacing: Theme.spacingMedium

        Item {
            width: 40
            height: 40
            visible: root.imageSource !== ""

            Image {
                anchors.fill: parent
                source: root.imageSource
                sourceSize: Qt.size(80, 80)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Column {
            width: parent.width - (root.imageSource !== "" ? 40 + parent.spacing : 0)
            spacing: Theme.spacingExtraSmall

            Item {
                width: parent.width
                height: appName.implicitHeight

                Text {
                    id: appName
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    elide: Text.ElideRight
                    text: root.notification.appName
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeLabelMedium
                }

                Text {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0156) // md-close
                    color: closeArea.containsMouse ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyLarge

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -Theme.spacingExtraSmall
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.notification.summary
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleSmall
                font.bold: true
            }

            Text {
                width: parent.width
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: root.notification.body
                color: Theme.text
                linkColor: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                visible: root.buttons.length > 0
                spacing: Theme.spacingSmall
                topPadding: Theme.spacingExtraSmall

                Repeater {
                    model: root.buttons

                    Rectangle {
                        id: button

                        required property var modelData

                        width: label.implicitWidth + Theme.spacingLarge * 2
                        height: 32
                        radius: height / 2
                        color: buttonArea.containsMouse ? Theme.primary : Theme.surfaceContainerHigh

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: button.modelData.text
                            color: buttonArea.containsMouse ? Theme.onPrimary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeLabelLarge
                        }

                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: button.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
