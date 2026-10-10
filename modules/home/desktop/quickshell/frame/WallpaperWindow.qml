import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../theme"

// The wallpaper for one screen, on the background layer: no input, no exclusive zone.
// A new image is decoded at the screen's size, off the main thread, and fades in over
// the old one, which is then let go, so at rest only one screen-sized image is held.
PanelWindow {
    id: root

    // Which of the two images is on top.
    property Image front: first

    function show(path) {
        const incoming = root.front === first ? second : first;
        incoming.z = 1;
        root.front.z = 0;
        incoming.opacity = 0;
        incoming.source = path === "" ? "" : "file://" + path;
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: Theme.base
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "custom-shell-wallpaper"

    Component.onCompleted: root.show(Wallpaper.path)

    Connections {
        target: Wallpaper

        function onPathChanged() {
            root.show(Wallpaper.path);
        }
    }

    Image {
        id: first
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * root.devicePixelRatio, root.height * root.devicePixelRatio)
        asynchronous: true
        cache: false
        onStatusChanged: if (status === Image.Ready && z === 1) fadeIn.start(first)
    }

    Image {
        id: second
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * root.devicePixelRatio, root.height * root.devicePixelRatio)
        asynchronous: true
        cache: false
        onStatusChanged: if (status === Image.Ready && z === 1) fadeIn.start(second)
    }

    NumberAnimation {
        id: fadeIn

        property Image image

        function start(image) {
            fadeIn.stop();
            fadeIn.image = image;
            fadeIn.target = image;
            fadeIn.restart();
        }

        property: "opacity"
        from: 0
        to: 1
        duration: Theme.wallpaperFadeDuration
        easing.type: Easing.InOutQuad

        onFinished: {
            const old = fadeIn.image === first ? second : first;
            old.source = "";
            root.front = fadeIn.image;
        }
    }
}
