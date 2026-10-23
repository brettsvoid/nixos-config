import QtQuick
import Quickshell.Services.Pipewire
import "../config"
import "../theme"

// The default microphone. The icon follows its mute from any source, and shows in the
// error colour while an app records. A click toggles mute, and scrolling changes the
// input volume, by the settings' step and up to 100 %. Muted wins over recording: an app
// that is attached hears nothing.
StatusIcon {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: root.source?.audio?.muted ?? false
    readonly property bool available: root.source !== null

    // A capture is a link from a source device to an app's capture stream. The visualiser
    // and other captures of an output's monitor link from the sink, so they never match.
    // Only looked for while shown: a hidden bar (game mode) follows no links.
    readonly property var captures: root.visible ? Pipewire.linkGroups.values.filter(g => g.source?.type === PwNodeType.AudioSource && g.target?.type === PwNodeType.AudioInStream) : []
    // A link only runs while the app's stream does, so an app that has paused its
    // capture does not count.
    readonly property bool recording: root.captures.some(g => g.state === PwLinkState.Active)

    glyph: root.muted ? 0xF036D : 0xF036C // md-microphone_off, md-microphone
    color: root.muted ? Theme.subtext : root.recording ? Theme.error : Theme.barText

    // The source's mute and volume, and the links' state, are only kept up to date
    // while something tracks them.
    PwObjectTracker {
        objects: [root.source]
    }

    PwObjectTracker {
        objects: root.captures
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.source?.audio)
                root.source.audio.muted = !root.source.audio.muted;
        }

        // As the volume icon's wheel, with 100 % as the top. A volume already over it
        // (set elsewhere) can still be turned down.
        onWheel: wheel => {
            if (!root.source?.audio)
                return;
            const now = root.source.audio.volume;
            const next = now + Settings.bar.volumeStep / 100 * wheel.angleDelta.y / 120;
            const max = Math.max(1, Math.min(now, next));
            root.source.audio.volume = Math.round(Math.max(0, Math.min(max, next)) * 100) / 100;
        }
    }
}
