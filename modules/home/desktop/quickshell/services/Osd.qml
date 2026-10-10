pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

// The on-screen display: what it shows, whether it shows, on which screen, and the
// levels. Volume and the microphone's mute come from PipeWire, so a change from any
// source shows it. Brightness comes from the brightness keys (custom-shell:brightness),
// because the backlight sends no change events.
Singleton {
    id: root

    // "volume", "microphone" or "brightness": the last thing shown. It stays set while
    // the display hides, so its content does not change on the way out.
    property string kind: "volume"
    property bool shown: false
    // The name of the screen it shows on: the focused one when it last changed.
    property string screen: ""
    // 0 to 1.
    property real brightness: 0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    // Changes in the first second are the shell reading the current values.
    property bool armed: false

    function show(kind) {
        if (!root.armed)
            return;
        root.screen = Hyprland.focusedMonitor?.name ?? "";
        root.kind = kind;
        root.shown = true;
        hideTimer.restart();
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.show("volume");
        }

        function onMutedChanged() {
            root.show("volume");
        }
    }

    Connections {
        target: root.source?.audio ?? null

        function onMutedChanged() {
            root.show("microphone");
        }
    }

    // The brightness keys run brightnessctl themselves (so they work under any shell)
    // and also fire this. Read the level once the change has landed.
    GlobalShortcut {
        appid: "custom-shell"
        name: "brightness"
        description: "Show the brightness level"
        // Not restarted on each key repeat, so holding the key still updates it about
        // ten times a second.
        onPressed: {
            if (!brightnessDelay.running)
                brightnessDelay.start();
        }
    }

    Timer {
        id: brightnessDelay
        interval: 100
        onTriggered: brightnessRead.running = true
    }

    // Backlights only: without the class, brightnessctl falls back to a keyboard LED.
    Process {
        id: brightnessRead
        command: ["brightnessctl", "--machine-readable", "--class=backlight", "info"]
        stdout: StdioCollector {
            // device,class,current,percent,max
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 5 || Number(fields[4]) <= 0)
                    return;
                root.brightness = Number(fields[2]) / Number(fields[4]);
                root.show("brightness");
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: root.armed = true
    }
}
