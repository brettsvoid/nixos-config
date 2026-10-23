import QtQuick
import Quickshell.Services.Pipewire
import "../config"
import "../theme"

// The output volume. The icon follows the level and mute from any source; scrolling
// over it changes the volume, by the settings' step and up to their maximum, and a
// click toggles mute.
StatusIcon {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property bool available: root.sink !== null
    // The percentage beside the icon.
    property bool showLabel: true

    glyph: {
        if (root.muted)
            return 0xF075F; // md-volume_mute
        if (root.volume >= 0.66)
            return 0xF057E; // md-volume_high
        if (root.volume >= 0.33)
            return 0xF0580; // md-volume_medium
        return 0xF057F; // md-volume_low
    }
    label: root.showLabel ? Math.round(root.volume * 100) + "%" : ""
    widestGlyph: String.fromCodePoint(0xF075F)
    widestLabel: root.showLabel ? "100%" : ""
    color: root.muted ? Qt.alpha(Theme.barText, 0.5) : Theme.barText

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

        // The step per wheel notch; touchpads send smaller steps. A volume already over
        // the maximum (set elsewhere) can still be turned down.
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const now = root.sink.audio.volume;
            const next = now + Settings.bar.volumeStep / 100 * wheel.angleDelta.y / 120;
            const max = Math.max(Settings.bar.volumeMax / 100, Math.min(now, next));
            root.sink.audio.volume = Math.round(Math.max(0, Math.min(max, next)) * 100) / 100;
        }
    }
}
