pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

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

    // Dynamic colours from matugen (wallpaper-derived), with Catppuccin Mocha fallbacks
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

    // Shared design values: drawers and panels take their motion, corners, spacing and
    // type from here.

    // The user's settings (config/Settings.qml) scale the values below: text, corners
    // and the speed of motion. Each value here is the one at the default of 1.
    readonly property real _text: Settings.textScale
    readonly property real _corner: Settings.cornerScale
    readonly property real _speed: Settings.animationSpeed

    function _type(px) {
        return Math.round(px * _text);
    }

    function _round(px) {
        return Math.round(px * _corner);
    }

    // A spring settles in a time proportional to 1/sqrt(stiffness), so k times the
    // speed is k² times the stiffness.
    function _spring(damping, stiffness) {
        return {
            damping: damping,
            stiffness: stiffness * _speed * _speed
        };
    }

    function _time(ms) {
        return Math.round(ms / _speed);
    }

    // Motion: the Material 3 Expressive springs (damping ratio, stiffness; mass 1), from
    // androidx's ExpressiveMotionTokens. The spec defines springs, not easing curves.
    // Spatial springs move and resize things and may overshoot; effects springs fade
    // and recolour without overshooting. See components/Spring.qml.
    readonly property var springFastSpatial: _spring(0.6, 800)
    readonly property var springDefaultSpatial: _spring(0.8, 380)
    readonly property var springSlowSpatial: _spring(0.8, 200)
    readonly property var springFastEffects: _spring(1, 3800)
    readonly property var springDefaultEffects: _spring(1, 1600)
    readonly property var springSlowEffects: _spring(1, 800)

    // Corners: the Material 3 corner scale (androidx ShapeTokens).
    readonly property int cornerExtraSmall: _round(4)
    readonly property int cornerSmall: _round(8)
    readonly property int cornerMedium: _round(12)
    readonly property int cornerLarge: _round(16)
    readonly property int cornerLargeIncreased: _round(20)
    readonly property int cornerExtraLarge: _round(28)
    readonly property int cornerExtraLargeIncreased: _round(32)
    readonly property int cornerExtraExtraLarge: _round(48)

    // Spacing: steps of a 4 px grid.
    readonly property int spacingExtraSmall: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingExtraLarge: 24

    // Type: the Material 3 type scale in px (androidx TypeScaleTokens). The bar keeps
    // its own smaller sizes below.
    readonly property int typeLabelSmall: _type(11)
    readonly property int typeLabelMedium: _type(12)
    readonly property int typeLabelLarge: _type(14)
    readonly property int typeBodySmall: _type(12)
    readonly property int typeBodyMedium: _type(14)
    readonly property int typeBodyLarge: _type(16)
    readonly property int typeTitleSmall: _type(14)
    readonly property int typeTitleMedium: _type(16)
    readonly property int typeTitleLarge: _type(22)
    readonly property int typeHeadlineSmall: _type(24)

    // Frame and bar: this shell's own values (docs/bar-spec.md is edgebar's only). The
    // bar is the frame's top band, so barHeight is also the top edge's thickness.
    readonly property int barHeight: 32
    readonly property int frameThickness: Settings.frameThickness
    readonly property color frameColor: base
    // Corner radius of the area inside the frame, seen at the bottom corners.
    readonly property int frameRounding: cornerLarge
    // Radius of the curve where the bar and each drawer meet the frame.
    readonly property int frameFillet: cornerLarge
    // How far the frame's shadow reaches over the windows, and how dark it starts.
    readonly property int frameShadowSize: 12
    readonly property color frameShadowColor: Qt.rgba(0, 0, 0, 0.3)
    // The frame shrinking away for fullscreen, and growing back.
    readonly property int frameRevealDuration: _time(300)
    // A new wallpaper fading in over the old one.
    readonly property int wallpaperFadeDuration: _time(600)
    // Drawers: the corners away from the frame, the space around their content, and
    // the spring they open and close with.
    readonly property int drawerRadius: cornerExtraLarge
    readonly property int drawerPadding: spacingLarge
    readonly property var drawerSpring: springDefaultSpatial
    // Lock screen: a wrong password shakes the field. Not one of Material's springs:
    // damped lightly enough to swing three times, settling in about half a second.
    readonly property var lockShakeSpring: _spring(0.3, 800)
    readonly property int barPadding: 12
    readonly property string fontFamily: Settings.fontFamily
    readonly property int fontSize: _type(13)
    readonly property int fontSizeSmall: fontSize - 1
    readonly property int iconSize: _type(16)
    readonly property int animDuration: _time(150)
}
