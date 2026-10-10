import QtQuick
import "../components"
import "../config"
import "../theme"

// A numeric setting: a slider over its range in config/Settings.qml, and its value.
SettingRow {
    id: root

    // How the value reads, for example as a percentage.
    property var format: value => String(value)

    readonly property var spec: Settings.schema[root.key]

    Slider {
        anchors.left: parent.left
        anchors.right: shown.left
        anchors.rightMargin: Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        from: root.spec.min
        to: root.spec.max
        stepSize: root.spec.step
        value: Settings.value(root.key)
        onMoved: value => Settings.set(root.key, value)
    }

    Text {
        id: shown
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        horizontalAlignment: Text.AlignRight
        text: root.format(Settings.value(root.key))
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyMedium
    }
}
