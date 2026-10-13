import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../services"
import "../theme"

// One notification (a NotificationEntry): its image or app icon, the app's name, the
// summary, the body (with the simple markup apps send) and its action buttons. Clicking
// the card runs its default action. As a pop-up, the × only takes it off the screen and
// it hides itself after its timeout, paused while the pointer is on it; in the history,
// the × dismisses it. A notification restored after a restart has no actions.
Rectangle {
    id: root

    required property var entry
    property bool popup: false

    readonly property bool critical: root.entry.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: root.entry.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: root.entry.actions.filter(a => a.identifier !== "default")
    // An icon name goes through the icon theme; paths and image URLs are used as they are.
    readonly property string iconSource: {
        const icon = root.entry.appIcon || (DesktopEntries.byId(root.entry.desktopEntry)?.icon ?? "");
        if (icon === "")
            return "";
        return icon.includes("/") || icon.includes(":") ? icon : Quickshell.iconPath(icon, true);
    }
    readonly property string imageSource: root.entry.image || root.iconSource

    function close() {
        if (root.popup)
            Notifications.hidePopup(root.entry);
        else
            Notifications.dismiss(root.entry);
    }

    implicitWidth: 360
    implicitHeight: content.implicitHeight + Theme.spacingMedium * 2
    radius: Theme.cornerLarge
    color: Theme.surfaceContainer
    border.width: root.critical ? 2 : 0
    border.color: Theme.error

    Timer {
        interval: Notifications.timeoutOf(root.entry)
        running: root.popup && interval > 0 && !hover.containsMouse
        onTriggered: Notifications.hidePopup(root.entry)
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
                    text: root.entry.appName
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
                text: root.entry.summary
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
                text: root.entry.body
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
