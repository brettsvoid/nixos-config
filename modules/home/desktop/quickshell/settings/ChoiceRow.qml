import QtQuick
import "../components"
import "../config"
import "../theme"

// A setting with a few named values, as a row of pills; the chosen one is filled.
SettingRow {
    id: root

    // The values in order, each { value, label }.
    property var choices: []

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Repeater {
            model: root.choices

            Pill {
                required property var modelData

                text: modelData.label
                active: Settings.value(root.key) === modelData.value
                onClicked: Settings.set(root.key, modelData.value)
            }
        }
    }
}
