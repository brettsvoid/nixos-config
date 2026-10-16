import QtQuick
import "../theme"

// A looping preview of one window effect (the effects page): a small screen with a
// sample window that opens, stays a moment, closes, and starts again. Each run uses the
// effect's shader for it (previews/<id>-<kind>.frag.qsb in the effect library,
// window-dissolve.nix), run over the sample as HyprWindowShade runs it, at half speed so
// it is easier to follow. An open shades the window's own box. A close shades a
// screen-sized snapshot with the window in window_rect, so an effect that spills outside
// the window shows that too. The shader is told the sizes of a window on a 1920x1080
// screen, as the effects are tuned in pixels. "none" plays Hyprland's own animations
// instead: a pop-in and fade on open, a slide down and fade on close. An effect with
// only one of the two plays just that one. It loops while it exists.
Item {
    id: root

    // The effect, as the library's index.json lists it, and the library's folder.
    property var effect: null
    property string library: ""
    // How many times longer than on the desktop a run takes.
    property real slowdown: 2

    // Where the window sits on the screen, as fractions of it.
    readonly property rect windowRect: Qt.rect(0.15, 0.15, 0.7, 0.7)

    // The run playing: its kind and how far through it is.
    property string kind: "open"
    property real progress: 0
    property real seed: 0.5

    readonly property bool opening: root.kind === "open"
    // Hyprland's own animation, drawn on the sample itself with OutCubic easing.
    readonly property bool plain: root.shaderOf(root.kind) === ""
    readonly property real eased: 1 - Math.pow(1 - root.progress, 3)

    // The .qsb to run for `kind`, "" for Hyprland's own animation, or undefined where the
    // effect has none.
    function shaderOf(kind) {
        if (!root.effect?.[kind])
            return undefined;
        if (root.effect.id === "none")
            return "";
        return `file://${root.library}/previews/${root.effect.id}-${kind}.frag.qsb`;
    }

    // Milliseconds for a run of `kind`, or 0 to skip it.
    function runTime(kind) {
        const shader = root.shaderOf(kind);
        if (shader === undefined)
            return 0;
        // Hyprland's windowsIn and windowsOut, which the index does not time.
        const seconds = shader === "" ? (kind === "open" ? 0.3 : 0.4) : root.effect[kind].duration ?? 0.5;
        return seconds * 1000 * root.slowdown;
    }

    function begin(kind) {
        if (root.shaderOf(kind) === undefined)
            return;
        root.kind = kind;
        root.progress = 0;
        root.seed = Math.random();
    }

    implicitWidth: 232
    implicitHeight: 130

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerSmall
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

            readonly property real restY: root.windowRect.y * root.height

            x: root.windowRect.x * root.width
            y: root.plain && !root.opening ? sample.restY + (root.height - sample.restY) * root.eased : sample.restY
            width: root.windowRect.width * root.width
            height: root.windowRect.height * root.height
            opacity: !root.plain ? 1 : root.opening ? root.eased : 1 - root.eased
            scale: root.plain && root.opening ? 0.85 + 0.15 * root.eased : 1
        }
    }

    ShaderEffectSource {
        id: snapshot
        sourceItem: root.plain ? null : root.opening ? sample : screen
        hideSource: true
    }

    // An effect for each kind, shown while its run plays, so a shader is not loaded
    // again at each switch. Only while there is a shader to run: without one,
    // ShaderEffect falls back to Qt's own, which wants a `source`.
    Repeater {
        model: ["open", "close"]

        Loader {
            id: pass

            required property string modelData
            readonly property bool opening: pass.modelData === "open"

            active: !!root.shaderOf(pass.modelData)
            visible: root.kind === pass.modelData
            x: pass.opening ? sample.x : 0
            y: pass.opening ? sample.y : 0
            width: pass.opening ? sample.width : root.width
            height: pass.opening ? sample.height : root.height

            sourceComponent: ShaderEffect {
                property variant tex: snapshot
                property real progress: root.progress
                property real seed: root.seed
                property vector4d window_rect: pass.opening ? Qt.vector4d(0, 0, 1, 1) : Qt.vector4d(root.windowRect.x, root.windowRect.y, root.windowRect.width, root.windowRect.height)
                property vector2d surface_size: pass.opening ? Qt.vector2d(1920 * root.windowRect.width, 1080 * root.windowRect.height) : Qt.vector2d(1920, 1080)

                fragmentShader: root.shaderOf(pass.modelData)
                blending: true
            }
        }
    }

    // Open, a pause with the window up, close, a pause with it gone. A kind the effect
    // lacks takes no time.
    SequentialAnimation {
        running: !!root.effect
        loops: Animation.Infinite

        ScriptAction {
            script: root.begin("open")
        }
        NumberAnimation {
            target: root
            property: "progress"
            from: 0
            to: 1
            duration: root.runTime("open")
        }
        PauseAnimation {
            duration: root.runTime("open") > 0 ? 800 : 0
        }
        ScriptAction {
            script: root.begin("close")
        }
        NumberAnimation {
            target: root
            property: "progress"
            from: 0
            to: 1
            duration: root.runTime("close")
        }
        PauseAnimation {
            duration: root.runTime("close") > 0 ? 600 : 0
        }
    }
}
