import QtQuick
import "../components"
import "../config"

// An on/off setting.
SettingRow {
    id: root

    Switch {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        checked: Settings.value(root.key)
        onToggled: checked => Settings.set(root.key, checked)
    }
}
