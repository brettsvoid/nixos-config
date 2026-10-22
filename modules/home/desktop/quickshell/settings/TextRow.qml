import QtQuick
import "../config"
import "../theme"

// A text setting. It is saved on Enter or when the field loses focus; an empty field
// is put back to the value in force.
SettingRow {
    id: root

    // The field's width; the rest of the row stays empty.
    property real fieldWidth: 240

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width, root.fieldWidth)
        height: 36
        radius: height / 2
        color: Theme.surfaceContainer
        border.width: field.activeFocus ? 2 : 0
        border.color: Theme.primary

        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingLarge
            anchors.rightMargin: Theme.spacingLarge
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: Settings.valueOn(root.screen, root.key)
            color: Theme.text
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyMedium

            function save() {
                const value = field.text.trim();
                if (value !== "" && value !== Settings.valueOn(root.screen, root.key))
                    Settings.set(root.key, value, root.screen);
                // Back to a binding, so a reset or a hand edit shows.
                field.text = Qt.binding(() => Settings.valueOn(root.screen, root.key));
            }

            onEditingFinished: field.save()
            Keys.onEscapePressed: event => {
                // The first Escape gives up the edit; the next closes the window.
                if (field.text !== Settings.valueOn(root.screen, root.key)) {
                    field.text = Qt.binding(() => Settings.valueOn(root.screen, root.key));
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
        }
    }
}
