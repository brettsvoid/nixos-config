import QtQuick
import Quickshell.Services.Mpris
import "../theme"

// The active media player (the one playing, else the first): cover, title and artist,
// previous / play-pause / next, and a position bar you can click to seek. The position
// only updates once a second while it plays, and only while this card exists (the
// dashboard is open): MPRIS players do not send their position as it moves.
Rectangle {
    id: root

    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property real progress: root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    radius: Theme.cornerExtraLarge
    color: Theme.surfaceContainer

    Timer {
        interval: 1000
        repeat: true
        running: root.player?.isPlaying ?? false
        onTriggered: root.player.positionChanged()
    }

    Column {
        anchors.centerIn: parent
        visible: root.player === null
        spacing: Theme.spacingSmall

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String.fromCodePoint(0xF075B) // md-music_off
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeHeadlineSmall * 1.5
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyLarge
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        visible: root.player !== null

        Rectangle {
            id: cover
            anchors.left: parent.left
            anchors.top: parent.top
            width: 120
            height: 120
            radius: Theme.cornerLarge
            color: Theme.surfaceContainerHigh

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: String.fromCodePoint(0xF075A) // md-music
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeHeadlineSmall * 1.5
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(240, 240)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: Theme.spacingLarge
            anchors.right: parent.right
            anchors.verticalCenter: cover.verticalCenter
            spacing: Theme.spacingExtraSmall

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player?.identity ?? ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeLabelMedium
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                text: root.player?.trackTitle || "Unknown title"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleMedium
                font.bold: true
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player?.trackArtist ?? ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }

        Item {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cover.bottom
            anchors.topMargin: Theme.spacingLarge
            height: 20
            visible: root.player?.lengthSupported ?? false

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: height / 2
                color: Theme.surfaceContainerHigh

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canSeek ?? false
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.player.position = root.player.length * Math.max(0, Math.min(1, mouse.x / width))
            }
        }

        Text {
            anchors.left: parent.left
            anchors.top: bar.bottom
            visible: bar.visible
            text: root.time(root.player?.position ?? 0)
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabelMedium
        }

        Text {
            anchors.right: parent.right
            anchors.top: bar.bottom
            visible: bar.visible
            text: root.time(root.player?.length ?? 0)
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabelMedium
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
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
    }
}
