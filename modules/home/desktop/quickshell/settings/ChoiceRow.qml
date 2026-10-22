import QtQuick
import "../components"
import "../config"
import "../theme"

// A setting with a few named values, as pills; the chosen one is filled. They wrap onto
// more lines when they do not fit, and the row grows to hold them.
SettingRow {
    id: root

    // The values in order, each { value, label }.
    property var choices: []

    implicitHeight: Math.max(48, pills.implicitHeight + Theme.spacingMedium * 2)

    Flow {
        id: pills
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Repeater {
            model: root.choices

            Pill {
                required property var modelData

                text: modelData.label
                active: Settings.valueOn(root.screen, root.key) === modelData.value
                onClicked: Settings.set(root.key, modelData.value, root.screen)
            }
        }
    }
}
