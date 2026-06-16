pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    property var colors: ({})

    readonly property var _colorsFile: FileView {
        path: "/home/brett/.cache/qs-theme/colors.json"
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

    // Styling
    readonly property int roundness: 16
    function radius(offset) {
        return roundness > 0 ? Math.max(roundness + offset, 0) : 0
    }

    // Bar config
    readonly property int barHeight: 36
    readonly property int barMargin: 4
    readonly property int barRadius: radius(0)
    readonly property real barOpacity: 1.0
    readonly property string fontFamily: "FiraCode Nerd Font"
    readonly property int fontSize: 14
}
