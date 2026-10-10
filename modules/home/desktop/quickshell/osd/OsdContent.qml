import QtQuick
import "../components"
import "../services"
import "../theme"

// What the on-screen display shows: an icon, then a level bar and the percentage, or
// for the microphone whether it is muted.
Item {
    id: root

    readonly property bool microphone: Osd.kind === "microphone"
    readonly property real level: Osd.kind === "brightness" ? Osd.brightness : Osd.volume
    readonly property bool off: Osd.kind === "volume" ? Osd.muted : root.microphone && Osd.micMuted
    readonly property int glyph: {
        switch (Osd.kind) {
        case "microphone":
            return Osd.micMuted ? 0xF036D : 0xF036C; // md-microphone_off, md-microphone
        case "brightness":
            return 0xF00DF; // md-brightness_6
        default:
            if (Osd.muted)
                return 0xF075F; // md-volume_mute
            return root.level >= 0.66 ? 0xF057E : root.level >= 0.33 ? 0xF0580 : 0xF057F;
        }
    }

    implicitWidth: 280
    implicitHeight: 32

    // The bar slides between levels, so a held key gives one smooth motion.
    Spring {
        id: fill
        spec: Theme.springDefaultEffects
        target: root.level
        Component.onCompleted: value = root.level
    }

    Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.typeTitleLarge * 1.5
        text: String.fromCodePoint(root.glyph)
        color: root.off ? Theme.subtext : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleLarge
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        visible: root.microphone
        text: Osd.micMuted ? "Microphone off" : "Microphone on"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }

    Rectangle {
        id: track
        anchors.left: icon.right
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: percent.left
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.microphone
        height: 8
        radius: height / 2
        color: Theme.surfaceContainer

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, fill.value))
            height: parent.height
            radius: parent.radius
            color: root.off ? Qt.alpha(Theme.subtext, 0.35) : Theme.primary
        }
    }

    Text {
        id: percent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.microphone
        width: Theme.typeBodyLarge * 2.5
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.level * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }
}
