import QtQuick
import "../services"

// A bar icon that opens a drawer, or closes it, on this bar's screen (not the focused
// one, which a click on the other screen's bar might not have moved to yet).
StatusIcon {
    id: root

    required property var screen
    // The drawer's name (Drawers.names).
    property string drawer

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Drawers.toggle(root.drawer, root.screen.name)
    }
}
