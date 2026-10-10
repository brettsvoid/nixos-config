import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

// The output volume. The icon follows the level and mute from any source; scrolling
// over it changes the volume, a click toggles mute.
StatusIcon {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false

    visible: root.sink !== null
    glyph: {
        if (root.muted)
            return 0xF075F; // md-volume_mute
        if (root.volume >= 0.66)
            return 0xF057E; // md-volume_high
        if (root.volume >= 0.33)
            return 0xF0580; // md-volume_medium
        return 0xF057F; // md-volume_low
    }
    label: Math.round(root.volume * 100) + "%"
    widestGlyph: String.fromCodePoint(0xF075F)
    widestLabel: "100%"
    color: root.muted ? Theme.subtext : Theme.barText

    // The sink's volume and mute are only kept up to date while something tracks it.
    PwObjectTracker {
        objects: [root.sink]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }

        // 5% per wheel notch; touchpads send smaller steps.
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const next = root.sink.audio.volume + 0.05 * wheel.angleDelta.y / 120;
            root.sink.audio.volume = Math.round(Math.max(0, Math.min(1, next)) * 100) / 100;
        }
    }
}
