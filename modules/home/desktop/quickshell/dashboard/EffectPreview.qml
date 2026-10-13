import QtQuick
import "../theme"

// A looping preview of one window effect (the effects tab): a small screen with a sample
// window, and the effect's shader (previews/<id>-<kind>.frag.qsb in the effect library,
// window-dissolve.nix) run over it as HyprWindowShade runs it. An open shades the
// window's own box. A close shades a screen-sized snapshot with the window in
// window_rect, so an effect that spills outside the window shows that too. The shader
// is told the sizes of a window on a 1920x1080 screen, as the effects are tuned in
// pixels. "none" plays Hyprland's own animations instead: a pop-in and fade on open, a
// slide down and fade on close. It loops while it exists, and the tab only exists while
// it shows.
Item {
    id: root

    // The .qsb to run, or "" for none.
    property string shader: ""
    // "open" or "close".
    property string kind: "open"
    // Seconds per run.
    property real duration: 0.5

    // Where the window sits on the screen, as fractions of it.
    readonly property rect windowRect: Qt.rect(0.15, 0.15, 0.7, 0.7)
    readonly property bool opening: root.kind === "open"

    implicitWidth: 232
    implicitHeight: 130

    // Back to the plain window, as "none" leaves it mid-animation.
    onShaderChanged: {
        sample.opacity = 1;
        sample.scale = 1;
        sample.y = root.windowRect.y * root.height;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerMedium
        color: Theme.surfaceDim
    }

    // What the shader samples: the window alone for an open, the screen with the
    // window on it for a close. Only drawn through the effect.
    Item {
        id: screen
        width: root.width
        height: root.height

        SampleWindow {
            id: sample
            x: root.windowRect.x * root.width
            y: root.windowRect.y * root.height
            width: root.windowRect.width * root.width
            height: root.windowRect.height * root.height
        }
    }

    ShaderEffectSource {
        id: snapshot
        sourceItem: root.opening ? sample : screen
        hideSource: root.shader !== ""
    }

    // Only while there is a shader to run: without one, ShaderEffect falls back to
    // Qt's own, which wants a `source`.
    Loader {
        active: root.shader !== ""
        x: root.opening ? sample.x : 0
        y: root.opening ? sample.y : 0
        width: root.opening ? sample.width : root.width
        height: root.opening ? sample.height : root.height

        sourceComponent: ShaderEffect {
            id: effect

            property variant tex: snapshot
            property real progress: 0
            property real seed: 0.5
            property vector4d window_rect: root.opening ? Qt.vector4d(0, 0, 1, 1) : Qt.vector4d(root.windowRect.x, root.windowRect.y, root.windowRect.width, root.windowRect.height)
            property vector2d surface_size: root.opening ? Qt.vector2d(1920 * root.windowRect.width, 1080 * root.windowRect.height) : Qt.vector2d(1920, 1080)

            fragmentShader: root.shader
            blending: true

            SequentialAnimation {
                running: true
                loops: Animation.Infinite

                ScriptAction {
                    script: effect.seed = Math.random()
                }
                NumberAnimation {
                    target: effect
                    property: "progress"
                    from: 0
                    to: 1
                    duration: root.duration * 1000
                }
                PauseAnimation {
                    duration: 800
                }
            }
        }
    }

    // None: Hyprland's windowsIn (pop-in from 85%) and fadeIn, or windowsOut (a slide
    // down) and fadeOut, on the sample itself.
    SequentialAnimation {
        running: root.shader === ""
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: sample
                property: "opacity"
                from: root.opening ? 0 : 1
                to: root.opening ? 1 : 0
                duration: root.opening ? 300 : 400
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: sample
                property: root.opening ? "scale" : "y"
                from: root.opening ? 0.85 : root.windowRect.y * root.height
                to: root.opening ? 1 : root.height
                duration: root.opening ? 300 : 400
                easing.type: Easing.OutCubic
            }
        }
        PauseAnimation {
            duration: 800
        }
        ScriptAction {
            script: {
                sample.opacity = 1;
                sample.scale = 1;
                sample.y = root.windowRect.y * root.height;
            }
        }
    }
}
