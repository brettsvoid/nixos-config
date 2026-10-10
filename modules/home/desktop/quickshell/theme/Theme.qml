pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    property var colors: ({})

    readonly property var _colorsFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/qs-theme/colors.json"
        watchChanges: true
        onLoaded: {
            try {
                colors = JSON.parse(text())
            } catch (e) {
                colors = {}
            }
        }
        onFileChanged: reload()
    }

    function c(token, fallback) {
        return colors[token] || fallback
    }

    // Dynamic colors from matugen (wallpaper-derived), with Catppuccin Mocha fallbacks
    readonly property color base: c("background", "#1e1e2e")
    readonly property color _overBg: c("overBackground", "#cdd6f4")
    readonly property color surface: Qt.tint(base, Qt.rgba(_overBg.r, _overBg.g, _overBg.b, 0.1))
    readonly property color surfaceBright: Qt.tint(base, Qt.rgba(_overBg.r, _overBg.g, _overBg.b, 0.2))
    readonly property color surfaceDim: c("surfaceDim", "#181825")
    readonly property color surfaceContainer: c("surfaceContainer", "#313244")
    readonly property color surfaceContainerHigh: c("surfaceContainerHigh", "#45475a")
    readonly property color text: c("overBackground", "#cdd6f4")
    readonly property color subtext: c("overSurface", "#a6adc8")
    readonly property color primary: c("primary", "#89b4fa")
    readonly property color onPrimary: c("overPrimary", "#ffffff")
    readonly property color secondary: c("secondary", "#b4befe")
    readonly property color error: c("error", "#f38ba8")

    // Semantic aliases
    readonly property color barBg: base
    readonly property color barText: text
    readonly property color wsActive: primary
    readonly property color wsOccupied: subtext
    readonly property color wsEmpty: surfaceBright
    readonly property color batteryGood: c("green", "#a6e3a1")
    readonly property color batteryMid: c("yellow", "#f9e2af")
    readonly property color batteryLow: error

    // Shared design values (custom-shell issue 04): drawers and later panels take their
    // motion, corners, spacing and type from here.

    // Motion: the Material 3 Expressive springs (damping ratio, stiffness; mass 1), from
    // androidx's ExpressiveMotionTokens. The spec defines springs, not easing curves.
    // Spatial springs move and resize things and may overshoot; effects springs fade
    // and recolour without overshooting. See components/Spring.qml.
    readonly property var springFastSpatial: ({ damping: 0.6, stiffness: 800 })
    readonly property var springDefaultSpatial: ({ damping: 0.8, stiffness: 380 })
    readonly property var springSlowSpatial: ({ damping: 0.8, stiffness: 200 })
    readonly property var springFastEffects: ({ damping: 1, stiffness: 3800 })
    readonly property var springDefaultEffects: ({ damping: 1, stiffness: 1600 })
    readonly property var springSlowEffects: ({ damping: 1, stiffness: 800 })

    // Corners: the Material 3 corner scale (androidx ShapeTokens).
    readonly property int cornerExtraSmall: 4
    readonly property int cornerSmall: 8
    readonly property int cornerMedium: 12
    readonly property int cornerLarge: 16
    readonly property int cornerLargeIncreased: 20
    readonly property int cornerExtraLarge: 28
    readonly property int cornerExtraLargeIncreased: 32
    readonly property int cornerExtraExtraLarge: 48

    // Spacing: steps of a 4 px grid.
    readonly property int spacingExtraSmall: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingExtraLarge: 24

    // Type: the Material 3 type scale in px (androidx TypeScaleTokens). The bar keeps
    // its own smaller sizes below.
    readonly property int typeLabelSmall: 11
    readonly property int typeLabelMedium: 12
    readonly property int typeLabelLarge: 14
    readonly property int typeBodySmall: 12
    readonly property int typeBodyMedium: 14
    readonly property int typeBodyLarge: 16
    readonly property int typeTitleSmall: 14
    readonly property int typeTitleMedium: 16
    readonly property int typeTitleLarge: 22
    readonly property int typeHeadlineSmall: 24

    // Frame and bar. This shell's own values: docs/bar-spec.md covers edgebar only
    // since 2026-10-09 (.scratch/custom-shell/PRD.md). The bar is the frame's top
    // band, so barHeight is also the top edge's thickness.
    readonly property int barHeight: 32
    readonly property int frameThickness: 8
    readonly property color frameColor: base
    // Corner radius of the area inside the frame, seen at the bottom corners.
    readonly property int frameRounding: cornerLarge
    // Radius of the curve where the bar (and later each drawer) meets the frame.
    readonly property int frameFillet: cornerLarge
    // How far the frame's shadow reaches over the windows, and how dark it starts.
    readonly property int frameShadowSize: 12
    readonly property color frameShadowColor: Qt.rgba(0, 0, 0, 0.3)
    // The frame shrinking away for fullscreen, and growing back.
    readonly property int frameRevealDuration: 300
    // A new wallpaper fading in over the old one.
    readonly property int wallpaperFadeDuration: 600
    // Drawers: the corners away from the frame, the space around their content, and
    // the spring they open and close with.
    readonly property int drawerRadius: cornerExtraLarge
    readonly property int drawerPadding: spacingLarge
    readonly property var drawerSpring: springDefaultSpatial
    // Lock screen: a wrong password shakes the field. Not one of Material's springs:
    // damped lightly enough to swing three times, settling in about half a second.
    readonly property var lockShakeSpring: ({ damping: 0.3, stiffness: 800 })
    readonly property int barPadding: 12
    readonly property string fontFamily: "FiraCode Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: fontSize - 1
    readonly property int iconSize: 16
    readonly property int animDuration: 150
}
