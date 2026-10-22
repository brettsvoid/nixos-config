import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../bar"
import "../cheatsheet"
import "../config"
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
    // nothing. ScreenShell animates it for fullscreen and game mode.
    property real reveal: 1
    // This screen's settings, from ScreenShell.
    required property ScreenSettings settings

    readonly property string screenName: root.screen?.name ?? ""
    // The edge the bar is on, and whether this screen has one.
    readonly property string barEdge: root.settings.bar.edge
    readonly property bool barHere: root.settings.hasBar
    // An auto-hidden bar is a band as thin as the rest of the frame until the pointer
    // reaches it. It then grows over the windows, and goes again shortly after the
    // pointer leaves. It stays while a drawer is open here, so the drawers hanging from
    // it do not move.
    readonly property bool barRaised: root.barHere && (!root.settings.bar.autoHide || barHover.hovered || hideDelay.running || root.drawerOpen)
    property real barReveal: root.barRaised ? 1 : 0

    Behavior on barReveal {
        NumberAnimation {
            duration: Theme.frameRevealDuration
            easing.type: Easing.InOutCubic
        }
    }

    readonly property real thickness: Theme.frameThickness * reveal
    // How deep the frame is along the bar's edge.
    readonly property real barSize: thickness + (Theme.barHeight * reveal - thickness) * barReveal
    readonly property real rounding: Theme.frameRounding * reveal
    readonly property real fillet: Theme.frameFillet * reveal
    // The area inside the frame.
    readonly property rect inside: {
        const left = root.barEdge === "left" ? root.barSize : root.thickness;
        const right = root.barEdge === "right" ? root.barSize : root.thickness;
        const top = root.barEdge === "top" ? root.barSize : root.thickness;
        const bottom = root.barEdge === "bottom" ? root.barSize : root.thickness;
        return Qt.rect(left, top, root.width - left - right, root.height - top - bottom);
    }
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
    // other corners), plus whatever the drawers cover.
    mask: Region {
        width: root.width
        height: root.height

        Region {
            x: root.inside.x
            y: root.inside.y
            width: root.inside.width
            height: root.inside.height
            topLeftRadius: root.barEdge === "top" || root.barEdge === "left" ? root.fillet : root.rounding
            topRightRadius: root.barEdge === "top" || root.barEdge === "right" ? root.fillet : root.rounding
            bottomLeftRadius: root.barEdge === "bottom" || root.barEdge === "left" ? root.fillet : root.rounding
            bottomRightRadius: root.barEdge === "bottom" || root.barEdge === "right" ? root.fillet : root.rounding
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

        // The shader's hole runs off the screen at the bar's edge: the bar draws that
        // edge, joined to the sides with fillets.
        hole: {
            const t = root.thickness;
            const w = root.width;
            const h = root.height;
            switch (root.barEdge) {
            case "bottom":
                return Qt.rect(t, t, w - t * 2, h * 2);
            case "left":
                return Qt.rect(-w, t, w * 2 - t, h - t * 2);
            case "right":
                return Qt.rect(t, t, w * 2, h - t * 2);
            default:
                return Qt.rect(t, -h, w - t * 2, h * 2 - t);
            }
        }
        holeRadius: root.rounding
        shapes: [
            {
                x: root.barEdge === "right" ? root.width - root.barSize : -Theme.frameFillet,
                y: root.barEdge === "bottom" ? root.height - root.barSize : -Theme.frameFillet,
                width: root.settings.bar.vertical ? root.barSize + Theme.frameFillet : root.width + Theme.frameFillet * 2,
                height: root.settings.bar.vertical ? root.height + Theme.frameFillet * 2 : root.barSize + Theme.frameFillet,
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

    // The launcher, cheatsheet and dashboard hang from the bar.
    Drawer {
        id: launcherDrawer
        anchors.fill: parent
        edge: root.barEdge
        inside: root.inside
        open: Drawers.isOpen("launcher", root.screenName)
        content: Component {
            Launcher {
                rows: root.settings.launcher.rows
            }
        }
    }

    Drawer {
        id: cheatsheetDrawer
        anchors.fill: parent
        edge: root.barEdge
        inside: root.inside
        open: Drawers.isOpen("cheatsheet", root.screenName)
        content: Component {
            Cheatsheet {}
        }
    }

    Drawer {
        id: dashboardDrawer
        anchors.fill: parent
        edge: root.barEdge
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

    // Notification pop-ups, from the corner or edge the settings choose (the top right
    // unless they say otherwise). They wait while another drawer is open here: on the
    // portrait screen the launcher would overlap them.
    Drawer {
        id: popupsDrawer

        readonly property var place: root.settings.notifications.position.split("-")

        anchors.fill: parent
        edge: popupsDrawer.place[0]
        align: ({
                "left": "start",
                "right": "end"
            })[popupsDrawer.place[1]] ?? "centre"
        inside: root.inside
        open: Notifications.popups.length > 0 && Notifications.screen === root.screenName && !root.drawerOpen
        takesFocus: false
        content: Component {
            Popups {
                fromBottom: popupsDrawer.place[0] === "bottom"
            }
        }
    }

    // The on-screen display. It takes no input: it is not in the mask, and leaves the
    // keyboard alone.
    Drawer {
        id: osdDrawer
        anchors.fill: parent
        edge: root.settings.osd.position
        inside: root.inside
        open: Osd.shown && Osd.screen === root.screenName
        takesFocus: false
        content: Component {
            OsdContent {}
        }
    }

    // The bar keeps its full size and slides with the frame's edge as that grows or
    // shrinks.
    Bar {
        x: root.barEdge === "left" ? root.barSize - Theme.barHeight : root.barEdge === "right" ? root.width - root.barSize : 0
        y: root.barEdge === "top" ? root.barSize - Theme.barHeight : root.barEdge === "bottom" ? root.height - root.barSize : 0
        width: root.settings.bar.vertical ? Theme.barHeight : root.width
        height: root.settings.bar.vertical ? root.height : Theme.barHeight
        opacity: root.reveal * root.barReveal
        // Hidden, its clock and icons no longer ask for redraws.
        visible: opacity > 0
        screen: root.screen
        settings: root.settings
    }

    // The frame's band along the bar's edge, where the pointer raises an auto-hidden
    // bar. A HoverHandler does not take the hover from the bar's own items.
    Item {
        x: root.barEdge === "right" ? root.width - root.barSize : 0
        y: root.barEdge === "bottom" ? root.height - root.barSize : 0
        width: root.settings.bar.vertical ? root.barSize : root.width
        height: root.settings.bar.vertical ? root.height : root.barSize

        HoverHandler {
            id: barHover
            enabled: root.barHere && root.settings.bar.autoHide
            onHoveredChanged: {
                if (!barHover.hovered)
                    hideDelay.restart();
            }
        }
    }

    Timer {
        id: hideDelay
        interval: 400
    }
}
