import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../components"
import "../config"
import "../services"
import "../theme"

// One screen of the lock: the wallpaper blurred and dimmed (as much as the settings
// say), the time and date, the password field, and media controls while something
// plays (unless the settings hide them). Every screen shows the same field, and
// whichever has the keyboard takes the typing. Nothing moves at rest: the content rises
// in once, and the field shakes only after a wrong password.
WlSessionLockSurface {
    id: root

    readonly property bool blurred: Settings.lock.blur > 0

    // Opaque from the first frame, before the wallpaper has loaded.
    color: Theme.base

    // Decoded small when blurred, which blurs cheaply; at the screen's width, and shown
    // as it is, with no effect pass, when not.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Wallpaper.path === "" ? "" : "file://" + Wallpaper.path
        sourceSize.width: root.blurred ? 640 : root.width
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: !root.blurred
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: root.blurred && wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: root.blurred
        blur: Settings.lock.blur
        blurMax: 48
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, Settings.lock.dim)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // From 0 to 1 once, as the lock appears.
    Spring {
        id: entrance
        spec: Theme.springDefaultSpatial
        Component.onCompleted: entrance.target = 1
    }

    Spring {
        id: shake
        spec: Theme.lockShakeSpring
    }

    Connections {
        target: Lock

        function onFailuresChanged() {
            shake.velocity = 1200;
            shake.running = true;
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            event.accepted = true;
            const ctrl = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Lock.submit();
            else if (event.key === Qt.Key_Backspace)
                ctrl ? Lock.clear() : Lock.erase();
            else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_U))
                Lock.clear();
            else if (!ctrl && event.text.length > 0 && event.text >= " " && event.text !== "\u007f")
                Lock.type(event.text);
            else
                event.accepted = false;
        }
    }

    Column {
        anchors.centerIn: parent
        // Rises 48 px into place.
        anchors.verticalCenterOffset: (1 - entrance.value) * 48
        opacity: Math.min(1, entrance.value)
        spacing: Theme.spacingSmall

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // 12- or 24-hour, as the bar's clock.
            text: Qt.formatDateTime(clock.date, Settings.clock.twelveHour ? "h:mm AP" : "hh:mm")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 112
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleLarge
        }

        Item {
            width: 1
            height: Theme.spacingExtraLarge * 2
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 56
            radius: height / 2
            color: Theme.surfaceContainer
            border.width: 2
            border.color: Lock.message !== "" ? Theme.error : keys.activeFocus ? Theme.primary : "transparent"
            transform: Translate {
                x: shake.value
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingExtraLarge
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xF033E) // md-lock
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleLarge
            }

            Text {
                anchors.centerIn: parent
                visible: Lock.password === "" || Lock.checking
                text: Lock.checking ? "Checking…" : "Password"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyLarge
            }

            Row {
                anchors.centerIn: parent
                visible: Lock.password !== "" && !Lock.checking
                spacing: Theme.spacingSmall

                Repeater {
                    // As many dots as characters, up to what fits.
                    model: Math.min(Lock.password.length, 16)

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.text
                    }
                }
            }
        }

        // Keeps its line while empty, so a message does not move the field.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Theme.typeBodyMedium * 2
            verticalAlignment: Text.AlignVCenter
            text: Lock.message
            color: Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyMedium
        }
    }

    LockMedia {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingExtraLarge * 2
        opacity: Math.min(1, entrance.value)
    }
}
