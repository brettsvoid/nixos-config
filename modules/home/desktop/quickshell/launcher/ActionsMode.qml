import QtQuick
import Quickshell
import "../lock"
import "../services"
import "fuzzy.js" as Fuzzy

// The launcher's actions mode: type ">" first (as in Caelestia). It lists what the
// shell can do, best match first: the session (as the session menu does it), the
// shell's windows and drawers, the look, and the toggles, each named for what it will
// do. The launcher closes before an action runs, so one that opens a drawer keeps it.
QtObject {
    id: root

    readonly property string prefix: ">"
    readonly property string placeholder: "Run an action"

    readonly property var actions: {
        const list = [
            {
                title: "Lock",
                icon: "system-lock-screen",
                run: () => Lock.lock()
            },
            {
                title: "Log out",
                subtitle: "Open apps come back at the next login",
                icon: "system-log-out",
                command: ["session-exit", "logout"]
            },
            {
                title: "Restart",
                subtitle: "Open apps come back at the next login",
                icon: "system-reboot",
                keywords: ["reboot"],
                command: ["session-exit", "reboot"]
            },
            {
                title: "Shut down",
                subtitle: "Open apps come back at the next login",
                icon: "system-shutdown",
                keywords: ["power off"],
                command: ["session-exit", "poweroff"]
            },
            {
                title: "Sleep",
                subtitle: "Locks first",
                icon: "system-suspend",
                keywords: ["suspend"],
                command: ["systemctl", "suspend"]
            },
            {
                title: "Settings",
                icon: "preferences-system",
                run: () => Windows.showSettings()
            },
            {
                title: "Keybinds",
                subtitle: "The keybind cheatsheet",
                icon: "input-keyboard",
                keywords: ["shortcuts", "cheatsheet"],
                run: () => Drawers.toggle("cheatsheet")
            },
            {
                title: "Notifications",
                subtitle: "The notification history",
                icon: "preferences-system-notifications",
                run: () => Drawers.toggle("notifications")
            },
            {
                title: "Dashboard",
                icon: "utilities-system-monitor",
                run: () => Drawers.toggle("dashboard")
            },
            {
                title: "Wallpaper",
                subtitle: "Choose a wallpaper",
                icon: "preferences-desktop-wallpaper",
                run: () => {
                    Drawers.dashboardTab = "Wallpaper";
                    Drawers.toggle("dashboard");
                }
            },
            {
                title: "Window effects",
                subtitle: "Choose how windows open and close",
                icon: "preferences-desktop-effects",
                keywords: ["animation", "dissolve"],
                run: () => {
                    Drawers.dashboardTab = "Effects";
                    Drawers.toggle("dashboard");
                }
            },
            {
                title: "Random wallpaper",
                icon: "media-playlist-shuffle",
                // The picker's images (dashboard/WallpaperTab.qml), not the one showing. They
                // are links into the store (home-manager), hence -L.
                command: ["sh", "-c", "f=$(find -L \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\) ! -path \"$1\" | shuf -n 1); [ -n \"$f\" ] && exec generate-theme \"$f\"", "sh", Wallpaper.path]
            },
            {
                title: "Light mode",
                subtitle: Wallpaper.mode === "light" ? "In use" : "",
                icon: "weather-clear",
                keywords: ["theme"],
                run: () => Wallpaper.setMode("light")
            },
            {
                title: "Dark mode",
                subtitle: Wallpaper.mode === "dark" ? "In use" : "",
                icon: "weather-clear-night",
                keywords: ["theme"],
                run: () => Wallpaper.setMode("dark")
            },
            {
                title: GameMode.on ? "Turn game mode off" : "Turn game mode on",
                icon: "input-gaming",
                command: ["game-mode", GameMode.on ? "off" : "on"]
            },
            {
                title: Notifications.doNotDisturb ? "Turn do not disturb off" : "Turn do not disturb on",
                icon: "notifications-disabled",
                keywords: ["dnd"],
                run: () => Notifications.setDoNotDisturb(!Notifications.doNotDisturb)
            }
        ];
        // "scheme-tonal-spot" is "Colour scheme: tonal spot".
        for (const scheme of Wallpaper.schemes)
            list.push({
                title: "Colour scheme: " + scheme.replace(/^scheme-/, "").replace(/-/g, " "),
                subtitle: scheme === Wallpaper.scheme ? "In use" : "",
                icon: "preferences-desktop-color",
                keywords: ["theme", "variant"],
                run: () => Wallpaper.setScheme(scheme)
            });
        return list;
    }

    function results(query) {
        const scored = [];
        root.actions.forEach((action, index) => {
            const match = query === "" ? 0 : Math.max(Fuzzy.score(query, action.title), ...(action.keywords ?? []).map(k => Fuzzy.score(query, k) * 0.8));
            if (match >= 0)
                scored.push({
                    action: action,
                    match: match,
                    index: index
                });
        });
        // Equal matches keep the list's order: Qt's sort is not stable.
        scored.sort((a, b) => b.match - a.match || a.index - b.index);
        return scored.map(s => ({
                    title: s.action.title,
                    subtitle: s.action.subtitle ?? "",
                    icon: s.action.icon,
                    action: s.action
                }));
    }

    function activate(item) {
        if (item.action.run)
            item.action.run();
        else
            Quickshell.execDetached(item.action.command);
    }
}
