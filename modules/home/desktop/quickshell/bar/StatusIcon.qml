import QtQuick
import QtQuick.Layouts
import "../theme"

// A Nerd Font glyph with an optional label, for the bar's status area. On a side bar
// (`vertical`) the label goes under the glyph, in smaller type.
Item {
    id: root

    // The glyph's codepoint.
    property int glyph
    property string label: ""
    property color color: Theme.barText
    property bool vertical: false
    // The widest glyph and label this icon shows, so a changing value does not shift
    // the icons beside it. Empty means use the current one's width.
    property string widestGlyph: ""
    property string widestLabel: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // A GridLayout, not a Grid, which leaves room for a hidden label (see Bar.qml).
    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 0
        columnSpacing: Theme.spacingExtraSmall

        Text {
            id: glyphText
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Math.max(implicitWidth, widestGlyphText.implicitWidth)
            horizontalAlignment: Text.AlignHCenter
            text: String.fromCodePoint(root.glyph)
            color: root.color
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            id: labelText
            Layout.alignment: Qt.AlignCenter
            visible: root.label !== ""
            Layout.preferredWidth: Math.max(implicitWidth, widestLabelText.implicitWidth)
            horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignRight
            text: root.label
            color: Theme.barText
            font.family: Theme.fontFamily
            font.pixelSize: root.vertical ? Theme.fontSizeSmall - 2 : Theme.fontSizeSmall
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
