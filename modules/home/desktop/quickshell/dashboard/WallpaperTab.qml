import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../components"
import "../services"
import "../theme"

// The dashboard's wallpaper tab: the images in ~/Pictures/Wallpapers as a grid, the
// current one outlined; choosing one sets it, and the theme follows. Above, matugen's
// light or dark and its scheme variant. Thumbnails come from wallpaper-thumbnails
// (custom-shell.nix), run once each time the tab opens; it only makes missing ones.
// Both folders are watched, so a new image, then its thumbnail, show while it is open.
FocusScope {
    id: root

    readonly property string thumbnails: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/custom-shell/wallpaper-thumbnails"
    // The thumbnail files there now, by name.
    readonly property var made: {
        const names = {};
        for (let i = 0; i < thumbs.count; ++i)
            names[thumbs.get(i, "fileName")] = true;
        return names;
    }

    // It says "ready" once the thumbnail folder exists, which is when it can be
    // watched: on the first run it does not exist before.
    Process {
        command: ["wallpaper-thumbnails"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line === "ready")
                    thumbs.folder = "file://" + root.thumbnails;
            }
        }
    }

    FolderListModel {
        id: images
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name

        onCountChanged: {
            for (let i = 0; i < images.count; ++i) {
                if (images.get(i, "filePath") === Wallpaper.path)
                    grid.currentIndex = i;
            }
        }
    }

    FolderListModel {
        id: thumbs
        nameFilters: ["*.jpg"]
        showDirs: false
    }

    Flow {
        id: controls
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingSmall

        Repeater {
            model: ["light", "dark"]

            Pill {
                required property string modelData

                text: modelData === "light" ? "Light" : "Dark"
                active: Wallpaper.mode === modelData
                onClicked: Wallpaper.setMode(modelData)
            }
        }

        Item {
            width: Theme.spacingMedium
            height: 32
        }

        Repeater {
            model: Wallpaper.schemes

            Pill {
                required property string modelData

                // "scheme-tonal-spot" → "Tonal spot"
                text: {
                    const words = modelData.replace("scheme-", "").replace("-", " ");
                    return words.charAt(0).toUpperCase() + words.slice(1);
                }
                active: Wallpaper.scheme === modelData
                onClicked: Wallpaper.setScheme(modelData)
            }
        }
    }

    GridView {
        id: grid
        anchors.top: controls.bottom
        anchors.topMargin: Theme.spacingMedium
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        cellWidth: width / 4
        cellHeight: cellWidth * 9 / 16
        clip: true
        focus: true
        model: images
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        Keys.onReturnPressed: Wallpaper.set(images.get(grid.currentIndex, "filePath"))
        Keys.onEnterPressed: Wallpaper.set(images.get(grid.currentIndex, "filePath"))

        delegate: Item {
            id: cell

            required property string fileName
            required property string filePath
            required property int fileSize
            required property int index
            readonly property string thumbName: cell.fileName + "." + cell.fileSize + ".jpg"
            readonly property bool chosen: cell.filePath === Wallpaper.path

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.spacingExtraSmall
                radius: Theme.cornerMedium
                color: cell.chosen ? Theme.primary : cell.GridView.isCurrentItem ? Theme.subtext : Theme.surfaceContainer

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: root.made[cell.thumbName] ? "file://" + root.thumbnails + "/" + cell.thumbName : ""
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: Wallpaper.set(cell.filePath)
            }
        }
    }
}
