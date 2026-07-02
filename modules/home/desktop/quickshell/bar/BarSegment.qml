import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

Item {
    id: root

    default property alias content: contentContainer.data

    Layout.preferredHeight: Theme.barHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.barRadius
        color: Theme.barBg
        opacity: Theme.barOpacity

        layer.enabled: Theme.barOpacity > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadowColor
            shadowOpacity: Theme.shadowOpacity
            shadowBlur: Theme.shadowBlur
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
