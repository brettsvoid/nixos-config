import QtQuick
import "../theme"

// A Nerd Font glyph with an optional label, for the bar's status area.
Item {
    id: root

    // The glyph's codepoint.
    property int glyph
    property string label: ""
    property color color: Theme.barText
    // The widest glyph and label this icon shows, so a changing value does not shift
    // the icons beside it. Empty means use the current one's width.
    property string widestGlyph: ""
    property string widestLabel: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingExtraSmall

        Text {
            id: glyphText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, widestGlyphText.implicitWidth)
            horizontalAlignment: Text.AlignHCenter
            text: String.fromCodePoint(root.glyph)
            color: root.color
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            width: Math.max(implicitWidth, widestLabelText.implicitWidth)
            horizontalAlignment: Text.AlignRight
            text: root.label
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // Laid out like the visible text, but never shown, to measure the widest values.
    Text {
        id: widestGlyphText
        visible: false
        text: root.widestGlyph
        font: glyphText.font
    }

    Text {
        id: widestLabelText
        visible: false
        text: root.widestLabel
        font: labelText.font
    }
}
