import QtQuick
import "../config"
import "../dashboard"
import "../theme"

// The shell's look: font, text size, corners, the frame and the speed of motion, then
// the wallpaper's folder, fill and timed change, and the wallpaper and its colours (the
// dashboard's Wallpaper tab, so both show the same state).
FocusScope {
    id: root

    property bool pickingFont: false

    component Heading: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleSmall
        font.bold: true
        topPadding: Theme.spacingSmall
        bottomPadding: Theme.spacingSmall
    }

    Column {
        id: rows
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Heading {
            text: "Text and shape"
        }

        SettingRow {
            label: "Font"
            key: "appearance.fontFamily"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width, fontName.implicitWidth + Theme.spacingLarge * 2)
                height: 36
                radius: height / 2
                color: fontArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                Text {
                    id: fontName
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Theme.spacingLarge * 2)
                    elide: Text.ElideRight
                    text: Settings.fontFamily
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyMedium
                }

                MouseArea {
                    id: fontArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickingFont = true
                }
            }
        }

        SliderRow {
            label: "Text size"
            key: "appearance.textScale"
            format: value => Math.round(value * 100) + "%"
        }

        SliderRow {
            label: "Corner rounding"
            key: "appearance.cornerScale"
            format: value => Math.round(value * 100) + "%"
        }

        SliderRow {
            label: "Frame thickness"
            key: "appearance.frameThickness"
            format: value => value + " px"
        }

        SliderRow {
            label: "Animation speed"
            key: "appearance.animationSpeed"
            format: value => value.toFixed(1) + "×"
        }

        Heading {
            text: "Wallpaper and colours"
            topPadding: Theme.spacingLarge
        }

        // ~ is the home folder.
        TextRow {
            label: "Folder"
            key: "wallpaper.folder"
            fieldWidth: 360
        }

        ChoiceRow {
            label: "Fill"
            key: "wallpaper.fill"
            choices: [
                {
                    value: "crop",
                    label: "Fill, cropped"
                },
                {
                    value: "fit",
                    label: "Fit, whole"
                }
            ]
        }

        SliderRow {
            label: "Change every"
            key: "wallpaper.changeMinutes"
            format: value => value === 0 ? "Never" : value < 60 ? value + " min" : (value / 60).toFixed(value % 60 === 0 ? 0 : 1) + " h"
        }
    }

    WallpaperTab {
        anchors.top: rows.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        focus: !root.pickingFont
    }

    // Over the page while open, so the list has room.
    Loader {
        anchors.fill: parent
        active: root.pickingFont
        z: 1

        sourceComponent: FontPicker {
            onDone: root.pickingFont = false
        }
    }
}
