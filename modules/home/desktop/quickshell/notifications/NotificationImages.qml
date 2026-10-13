import QtQuick
import "../services"

// Saves the images apps send as data, rather than as a file, to the shell's state, so a
// notification keeps its image after a restart: the server only holds that data while
// the notification is live. Each is drawn here until it is saved, as only an item in a
// window can be grabbed. One screen's wallpaper window holds this. It has no size and
// clips, so nothing shows; a grab draws the item itself, without its parent's clip.
Item {
    clip: true

    Repeater {
        model: Notifications.history.filter(e => e.imageIsData)

        Image {
            id: image

            required property var modelData

            source: image.modelData.image
            sourceSize: Qt.size(256, 256)
            asynchronous: true
            cache: false
            onStatusChanged: {
                if (image.status !== Image.Ready)
                    return;
                const entry = image.modelData;
                const path = Notifications.imagePath(entry);
                image.grabToImage(result => {
                    if (result.saveToFile(path))
                        entry.image = "file://" + path;
                    else
                        console.warn(`Notifications: could not save an image to ${path}`);
                });
            }
        }
    }
}
