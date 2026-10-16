import QtQuick
import "../theme"

// A stand-in window for the effect previews (EffectPreview): a title line and a few
// lines of coloured "text", in the theme's colours, so an effect has something to work
// on and its direction shows.
Rectangle {
    id: root

    radius: Theme.cornerSmall
    color: Theme.surface
    border.width: 1
    border.color: Theme.primary

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 3

        Rectangle {
            width: parent.width * 0.4
            height: 5
            radius: 2
            color: Theme.primary
        }

        Repeater {
            model: [0.9, 0.6, 0.75, 0.45, 0.8, 0.55, 0.7, 0.35, 0.65]

            Rectangle {
                required property real modelData
                required property int index

                width: (root.width - 12) * modelData
                height: 3
                radius: 1.5
                color: index % 3 === 0 ? Theme.secondary : Theme.subtext
                opacity: 0.8
            }
        }
    }
}
