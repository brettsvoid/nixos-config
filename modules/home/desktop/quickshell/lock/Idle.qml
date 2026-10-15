import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config"
import "../services"

// What happens when nobody has touched the keyboard or pointer for a while, as the
// settings say: lock after N minutes, and turn the screens off after M (back on at the
// next input). Each is off at 0, which is the default: this desktop locks only before
// sleep otherwise (hypridle). Idle inhibitors, such as a playing video, hold both back,
// and so does game mode, as a game played with a controller sends no Wayland input.
//
// Each monitor is made afresh for each value: an IdleMonitor whose timeout changes after
// it is made never reports idle again (Quickshell 0.3; seen in qs-test), while one made
// with its timeout works.
Scope {
    id: root

    // The screens were turned off here, so input (or this going away) turns them on.
    property bool screensOff: false

    function screensOn() {
        if (!root.screensOff)
            return;
        root.screensOff = false;
        Hyprland.dispatch("dpms on");
    }

    Instantiator {
        model: Settings.idle.lockMinutes > 0 && !GameMode.on ? [Settings.idle.lockMinutes] : []

        IdleMonitor {
            required property int modelData

            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: {
                if (isIdle)
                    Lock.lock();
            }
        }
    }

    Instantiator {
        model: Settings.idle.screenOffMinutes > 0 && !GameMode.on ? [Settings.idle.screenOffMinutes] : []

        IdleMonitor {
            required property int modelData

            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: {
                if (isIdle) {
                    root.screensOff = true;
                    Hyprland.dispatch("dpms off");
                } else {
                    root.screensOn();
                }
            }
            // Hyprland does not turn the screens on for input by itself.
            Component.onDestruction: root.screensOn()
        }
    }
}
