import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../bar"
import "../cheatsheet"
import "../dashboard"
import "../launcher"
import "../notifications"
import "../osd"
import "../services"
import "../session"
import "../theme"

// The frame, bar and drawers for one screen, in one window that covers the whole
// screen. It ignores exclusive zones (EdgeReservation makes those) and takes input only
// on the frame, the bar and open drawers, so clicks inside the frame reach the windows
// underneath. Top layer, never Overlay: an always-mapped Overlay surface stops Hyprland
// sending a fullscreen game straight to the display.
PanelWindow {
    id: root

    // 1 shows the frame in full; towards 0 its thickness, rounding and bar shrink to
    // nothing. ScreenShell animates it around fullscreen.
    property real reveal: 1

    readonly property real thickness: Theme.frameThickness * reveal
    readonly property real barHeight: Theme.barHeight * reveal
    readonly property real rounding: Theme.frameRounding * reveal
    readonly property real fillet: Theme.frameFillet * reveal
    // The area inside the frame, below the bar.
    readonly property rect inside: Qt.rect(thickness, barHeight, width - thickness * 2, height - barHeight - thickness)
    readonly property string screenName: root.screen?.name ?? ""
    readonly property bool drawerOpen: sessionDrawer.open || launcherDrawer.open || cheatsheetDrawer.open || historyDrawer.open || dashboardDrawer.open

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "custom-shell-frame"
    // Keyboard input only while a drawer is open, through the focus grab below.
    WlrLayershell.keyboardFocus: root.drawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // While a drawer is open it has the keyboard, and a click outside this window
    // closes it.
    HyprlandFocusGrab {
        active: root.drawerOpen
        windows: [root]
        onCleared: Drawers.close()
    }

    // The whole window minus the area inside the frame, with the same corners as the
    // drawn shape (the fillet where the bar meets the sides, the rounding at the
    // bottom), plus whatever the drawers cover.
    mask: Region {
        width: root.width
        height: root.height

        Region {
            x: root.inside.x
            y: root.inside.y
            width: root.inside.width
            height: root.inside.height
            topLeftRadius: root.fillet
            topRightRadius: root.fillet
            bottomLeftRadius: root.rounding
            bottomRightRadius: root.rounding
            intersection: Intersection.Subtract
        }

        Region {
            item: sessionDrawer.hitArea
        }

        Region {
            item: launcherDrawer.hitArea
        }

        Region {
            item: cheatsheetDrawer.hitArea
        }

        Region {
            item: historyDrawer.hitArea
        }

        Region {
            item: dashboardDrawer.hitArea
        }

        Region {
            item: popupsDrawer.hitArea
        }
    }

    FrameShape {
        anchors.fill: parent

        // The shader's hole runs off the top of the screen: the bar is the top edge.
        hole: Qt.rect(root.thickness, -root.height, root.width - root.thickness * 2, root.height * 2 - root.thickness)
        holeRadius: root.rounding
        shapes: [
            {
                x: -Theme.frameFillet,
                y: -Theme.frameFillet,
                width: root.width + Theme.frameFillet * 2,
                height: root.barHeight + Theme.frameFillet,
                radius: 0
            },
            sessionDrawer.shape,
            launcherDrawer.shape,
            cheatsheetDrawer.shape,
            historyDrawer.shape,
            dashboardDrawer.shape,
            popupsDrawer.shape,
            osdDrawer.shape
        ]
        fillet: root.fillet
        shadowSize: Theme.frameShadowSize * root.reveal
        fillColor: Theme.frameColor
        shadowColor: Theme.frameShadowColor
    }

    Drawer {
        id: sessionDrawer
        anchors.fill: parent
        edge: "right"
        inside: root.inside
        open: Drawers.isOpen("session", root.screenName)
        content: Component {
            SessionMenu {}
        }
    }

    Drawer {
        id: launcherDrawer
        anchors.fill: parent
        edge: "top"
        inside: root.inside
        open: Drawers.isOpen("launcher", root.screenName)
        content: Component {
            Launcher {}
        }
    }

    Drawer {
        id: cheatsheetDrawer
        anchors.fill: parent
        edge: "top"
        inside: root.inside
        open: Drawers.isOpen("cheatsheet", root.screenName)
        content: Component {
            Cheatsheet {}
        }
    }

    Drawer {
        id: dashboardDrawer
        anchors.fill: parent
        edge: "top"
        inside: root.inside
        open: Drawers.isOpen("dashboard", root.screenName)
        content: Component {
            Dashboard {}
        }
    }

    Drawer {
        id: historyDrawer
        anchors.fill: parent
        edge: "right"
        inside: root.inside
        open: Drawers.isOpen("notifications", root.screenName)
        content: Component {
            History {}
        }
    }

    // Notification pop-ups, from the right end of the bar. They wait while another
    // drawer is open here: on the portrait screen the launcher would overlap them.
    Drawer {
        id: popupsDrawer
        anchors.fill: parent
        edge: "top"
        align: "end"
        inside: root.inside
        open: Notifications.popups.length > 0 && Notifications.screen === root.screenName && !root.drawerOpen
        takesFocus: false
        content: Component {
            Popups {}
        }
    }

    // The on-screen display. It takes no input: it is not in the mask, and leaves the
    // keyboard alone.
    Drawer {
        id: osdDrawer
        anchors.fill: parent
        edge: "bottom"
        inside: root.inside
        open: Osd.shown && Osd.screen === root.screenName
        takesFocus: false
        content: Component {
            OsdContent {}
        }
    }

    Bar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.barHeight
        opacity: root.reveal
        screen: root.screen
    }
}
