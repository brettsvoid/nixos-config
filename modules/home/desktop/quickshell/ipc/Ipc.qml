import Quickshell
import Quickshell.Io
import "../config"
import "../lock"
import "../services"

// What `custom-shell <target> <function> [argument...]` (custom-shell.nix) and
// `qs ipc call` reach: one handler per target, each function a line or two into the
// service the shortcuts and the launcher's actions use too. A function that takes a
// name or a value returns "" when it is done, or `error: ...` when it was refused. The
// types are required: Quickshell only lists a function whose arguments and return are
// typed, and calls it only when the argument count matches. The IPC socket sits idle
// until a call, so this costs nothing at rest or in game mode.
//
// Not here: signals (`qs ipc listen`) and properties (`qs ipc prop get`).
Scope {
    id: root

    // The entry of `names` that `given` spells, whatever its case.
    function match(names, given) {
        return names.find(name => name.toLowerCase() === given.trim().toLowerCase());
    }

    function unknown(what, given, names) {
        return `error: unknown ${what} "${given}" (${names.join(", ")})`;
    }

    function isSetting(key) {
        return Object.prototype.hasOwnProperty.call(Settings.schema, key);
    }

    // What a setting takes, for the error that refuses a value.
    function takes(spec) {
        if (spec.options)
            return "one of " + spec.options.join(", ");
        if (Array.isArray(spec.default))
            return "a list of strings";
        switch (typeof spec.default) {
        case "boolean":
            return "true or false";
        case "number":
            return `a number from ${spec.min} to ${spec.max}`;
        default:
            return "a string that is not empty";
        }
    }

    IpcHandler {
        target: "drawers"

        function toggle(name: string): string {
            const drawer = root.match(Drawers.names, name);
            if (!drawer)
                return root.unknown("drawer", name, Drawers.names);
            Drawers.toggle(drawer);
            return "";
        }

        function open(name: string): string {
            const drawer = root.match(Drawers.names, name);
            if (!drawer)
                return root.unknown("drawer", name, Drawers.names);
            Drawers.openOn(drawer, Drawers.focusedScreen());
            return "";
        }

        // For scripts and qs-test, whose fake Hyprland has no focused monitor.
        function openOn(name: string, screen: string): string {
            const drawer = root.match(Drawers.names, name);
            if (!drawer)
                return root.unknown("drawer", name, Drawers.names);
            const screens = Quickshell.screens.map(s => s.name);
            if (!screens.includes(screen))
                return root.unknown("screen", screen, screens);
            Drawers.openOn(drawer, screen);
            return "";
        }

        function close(): void {
            Drawers.close();
        }

        function current(): string {
            return Drawers.open;
        }

        // Opens the dashboard on `tab`, or changes to it if it is open.
        function dashboard(tab: string): string {
            const name = root.match(Drawers.dashboardTabs, tab);
            if (!name)
                return root.unknown("dashboard tab", tab, Drawers.dashboardTabs);
            Drawers.dashboardTab = name;
            if (Drawers.open !== "dashboard")
                Drawers.openOn("dashboard", Drawers.focusedScreen());
            return "";
        }

        // Opens the launcher with the mode's prefix typed.
        function launcher(mode: string): string {
            const name = root.match(Drawers.launcherModes, mode);
            if (!name)
                return root.unknown("launcher mode", mode, Drawers.launcherModes);
            Drawers.launcherMode = name;
            if (Drawers.open !== "launcher")
                Drawers.openOn("launcher", Drawers.focusedScreen());
            return "";
        }
    }

    IpcHandler {
        target: "settings"

        // "" for the page it showed last.
        function open(page: string): string {
            if (page.trim() === "") {
                Windows.showSettings();
                return "";
            }
            const name = root.match(Windows.settingsPages, page);
            if (!name)
                return root.unknown("settings page", page, Windows.settingsPages);
            Windows.showSettings(name);
            return "";
        }

        function close(): void {
            Windows.settings = false;
        }

        // The value as JSON.
        function get(key: string): string {
            if (!root.isSetting(key))
                return `error: unknown setting "${key}"`;
            return JSON.stringify(Settings.value(key));
        }

        function set(key: string, json: string): string {
            if (!root.isSetting(key))
                return `error: unknown setting "${key}"`;
            let value;
            try {
                value = JSON.parse(json);
            } catch (e) {
                return `error: not JSON: ${json}`;
            }
            return Settings.set(key, value) ? "" : `error: ${key} takes ${root.takes(Settings.schema[key])}`;
        }

        function reset(key: string): string {
            if (!root.isSetting(key))
                return `error: unknown setting "${key}"`;
            Settings.reset(key);
            return "";
        }
    }

    // There is no unlock: only the password unlocks.
    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }

        function isLocked(): bool {
            return Lock.locked;
        }
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            Notifications.clearAll();
        }

        function getDnd(): bool {
            return Notifications.doNotDisturb;
        }

        function setDnd(on: bool): string {
            Notifications.setDoNotDisturb(on);
            return "";
        }

        function toggleDnd(): void {
            Notifications.setDoNotDisturb(!Notifications.doNotDisturb);
        }

        function count(): int {
            return Notifications.history.length;
        }
    }

    // The media card's player (Players.active). Quickshell reads the players on first
    // use and is not warmed up at start (that would run at rest), so the first call after
    // the shell starts, before the dashboard or lock screen has used it, finds none.
    IpcHandler {
        target: "media"

        function playPause(): void {
            if (Players.active?.canTogglePlaying)
                Players.active.togglePlaying();
        }

        function next(): void {
            if (Players.active?.canGoNext)
                Players.active.next();
        }

        function previous(): void {
            if (Players.active?.canGoPrevious)
                Players.active.previous();
        }

        function stop(): void {
            if (Players.active?.canControl)
                Players.active.stop();
        }

        // JSON: the player, whether it plays, and the track; null with no player.
        function current(): string {
            const player = Players.active;
            return JSON.stringify(player ? {
                player: player.identity,
                playing: player.isPlaying,
                title: player.trackTitle,
                artist: player.trackArtist,
                album: player.trackAlbum
            } : null);
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            if (!Wallpaper.isFile(path))
                return `error: not a file: "${path}" (give a full path)`;
            Wallpaper.set(path);
            return "";
        }

        function random(): void {
            Wallpaper.random();
        }

        function get(): string {
            return Wallpaper.path;
        }
    }

    // The mode and scheme change when generate-theme has written them, so a get just
    // after a set may still give the old one.
    IpcHandler {
        target: "theme"

        function getMode(): string {
            return Wallpaper.mode;
        }

        function setMode(mode: string): string {
            const name = root.match(["light", "dark"], mode);
            if (!name)
                return root.unknown("mode", mode, ["light", "dark"]);
            Wallpaper.setMode(name);
            return "";
        }

        function toggleMode(): void {
            Wallpaper.setMode(Wallpaper.mode === "dark" ? "light" : "dark");
        }

        function getScheme(): string {
            return Wallpaper.scheme;
        }

        // With or without the "scheme-" that getScheme gives.
        function setScheme(scheme: string): string {
            const names = Wallpaper.schemes.map(s => s.replace(/^scheme-/, ""));
            const name = root.match(names, scheme.trim().replace(/^scheme-/i, ""));
            if (!name)
                return root.unknown("scheme", scheme, names);
            Wallpaper.setScheme("scheme-" + name);
            return "";
        }
    }

    // Through the game-mode command, as the keybind does; the state the shell reads
    // changes once it has run, so a get just after a set may still say the old one.
    IpcHandler {
        target: "gameMode"

        function get(): bool {
            return GameMode.on;
        }

        function set(on: bool): string {
            Quickshell.execDetached(["game-mode", on ? "on" : "off"]);
            return "";
        }

        function toggle(): void {
            Quickshell.execDetached(["game-mode", "toggle"]);
        }
    }

    // `qs ipc call` needs `--` before the function name `show` (docs/quickshell-notes.md);
    // `custom-shell` adds it.
    IpcHandler {
        target: "osd"

        function show(kind: string): string {
            const names = ["volume", "microphone", "brightness"];
            const name = root.match(names, kind);
            if (!name)
                return root.unknown("kind", kind, names);
            if (name === "brightness")
                Osd.showBrightness();
            else
                Osd.show(name);
            return "";
        }
    }
}
