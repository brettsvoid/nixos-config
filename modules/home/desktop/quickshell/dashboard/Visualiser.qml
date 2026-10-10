import QtQuick
import CustomShell.Native
import "../theme"

// Spectrum bars for what is playing, from the shell-native plugin. It only captures
// while `active`, which the media card sets while it shows and the player plays.
// Plain rectangles, drawn by the scene graph on the GPU; they change only when a new
// set of heights arrives.
Item {
    id: root

    property bool active: false
    property color colour: Theme.primary
    readonly property int spacing: 3

    Spectrum {
        id: spectrum
        count: 32
        active: root.active
    }

    Repeater {
        model: spectrum.count

        Rectangle {
            required property int index

            x: index * (width + root.spacing)
            anchors.bottom: parent.bottom
            width: (root.width - (spectrum.count - 1) * root.spacing) / spectrum.count
            height: Math.max(2, root.height * (spectrum.bars[index] ?? 0))
            radius: Math.min(width / 2, 3)
            color: Qt.alpha(root.colour, 0.3)
        }
    }
}
