import QtQuick
import Quickshell
import "bar"

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = true

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
