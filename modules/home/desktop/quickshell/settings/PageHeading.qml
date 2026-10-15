import QtQuick
import "../theme"

// A section's title on a page of settings. The first on a page sets topPadding to 0.
Text {
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.typeTitleSmall
    font.bold: true
    topPadding: Theme.spacingLarge
    bottomPadding: Theme.spacingSmall
}
