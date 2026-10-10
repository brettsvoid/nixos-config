import QtQuick
import Quickshell.Services.Mpris
import "../components"
import "../theme"

// The playing track on the lock screen: cover, title and artist, previous / play-pause /
// next. Shown while something plays; a player paused from here keeps its card, so it can
// be started again. No position bar, which would have to tick every second.
Rectangle {
    id: root

    property MprisPlayer player: null
    readonly property MprisPlayer playing: Mpris.players.values.find(p => p.isPlaying) ?? null

    onPlayingChanged: {
        if (root.playing)
            root.player = root.playing;
    }
    Component.onCompleted: root.player = root.playing

    visible: root.player !== null && root.player.playbackState !== MprisPlaybackState.Stopped
    width: 480
    height: 88
    radius: Theme.cornerExtraLarge
    color: Theme.surfaceContainer

    Rectangle {
        id: cover
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 64
        radius: Theme.cornerLarge
        color: Theme.surfaceContainerHigh

        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: String.fromCodePoint(0xF075A) // md-music
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeHeadlineSmall
        }

        Image {
            id: art
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: Theme.spacingMedium
        anchors.right: controls.left
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingExtraSmall

        Text {
            width: parent.width
            elide: Text.ElideRight
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
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyMedium
        }
    }

    MediaControls {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall
        player: root.player
    }
}
