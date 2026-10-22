import QtQuick
import "../config"
import "../dashboard"
import "../services"
import "../theme"
import "index.js" as Index

// The shell's look: font, text size, corners, the frame and the speed of motion, then
// the wallpaper's folder, fill and timed change, and the wallpaper and its colours (the
// dashboard's Wallpaper tab, so both show the same state).
FocusScope {
    id: root

    property bool pickingFont: false

    // Lights up the row with `key` (a search result). The rows all fit, so none scrolls.
    function reveal(key) {
        Index.rowFor(rows.children, key)?.flash();
    }

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
            key: "appearance.textScale"
            format: value => Math.round(value * 100) + "%"
        }

        SliderRow {
            key: "appearance.cornerScale"
            format: value => Math.round(value * 100) + "%"
        }

        SliderRow {
            key: "appearance.frameThickness"
            format: value => value + " px"
        }

        SliderRow {
            key: "appearance.animationSpeed"
            format: value => value.toFixed(1) + "×"
        }

        Heading {
            text: "Wallpaper and colours"
            topPadding: Theme.spacingLarge
        }

        // ~ is the home folder.
        TextRow {
            key: "wallpaper.folder"
            fieldWidth: 360
        }

        ChoiceRow {
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
            key: "wallpaper.changeMinutes"
            format: value => value === 0 ? "Never" : value < 60 ? value + " min" : (value / 60).toFixed(value % 60 === 0 ? 0 : 1) + " h"
        }
    }

    // The same on every screen, so faded while one is picked, as the shared rows are.
    WallpaperTab {
        anchors.top: rows.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        focus: !root.pickingFont
        enabled: Windows.settingsScreen === ""
        opacity: enabled ? 1 : 0.4
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
