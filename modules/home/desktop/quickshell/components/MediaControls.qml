import QtQuick
import "../theme"

// Previous, play-pause and next for an MPRIS player, the middle one larger and filled.
// Each is dimmed and ignores clicks when the player cannot do it.
Row {
    id: root

    property var player: null

    spacing: Theme.spacingLarge

    Repeater {
        model: [
            {
                glyph: 0xF04AE, // md-skip_previous
                enabled: root.player?.canGoPrevious ?? false,
                run: () => root.player.previous()
            },
            {
                glyph: root.player?.isPlaying ? 0xF03E4 : 0xF040A, // md-pause, md-play
                enabled: root.player?.canTogglePlaying ?? false,
                run: () => root.player.togglePlaying()
            },
            {
                glyph: 0xF04AD, // md-skip_next
                enabled: root.player?.canGoNext ?? false,
                run: () => root.player.next()
            }
        ]

        Rectangle {
            id: control

            required property var modelData
            required property int index

            anchors.verticalCenter: parent.verticalCenter
            width: control.index === 1 ? 52 : 44
            height: width
            radius: width / 2
            opacity: control.modelData.enabled ? 1 : 0.4
            color: control.index === 1 ? Theme.primary : controlArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(control.modelData.glyph)
                color: control.index === 1 ? Theme.onPrimary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleLarge
            }

            MouseArea {
                id: controlArea
                anchors.fill: parent
                enabled: control.modelData.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: control.modelData.run()
            }
        }
    }
}
