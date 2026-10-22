.pragma library
.import "../launcher/fuzzy.js" as Fuzzy

// What the settings window's search finds, by hand: one entry for each row of a
// settings page, and one for each page that lists devices or effects instead. A row
// takes its label from here by its key (SettingRow), so each label is written once. The
// rest (`page`, `heading`, `keywords`) is what the search matches and shows: `page` and
// `heading` must be the page's name and the heading above the row. A new row needs an
// entry here with its schema key, or shell.qml warns at start and the load check fails.
//
// `key` is the row's key in config/Settings.qml ("" for a page), or, for a row that is
// not a setting, a name of its own. `keywords` are what a person might type that the
// label does not say.
const entries = [
    // Pages that list devices or effects.
    { key: "", page: "Window effects", heading: "", label: "Window effects", keywords: ["dissolve", "burn", "animation", "open", "close", "shader", "preview", "transition"] },
    { key: "", page: "Audio", heading: "", label: "Audio", keywords: ["sound", "speakers", "headphones", "microphone", "mic", "output", "input", "volume", "mute", "pipewire", "apps"] },
    { key: "", page: "Network", heading: "", label: "Network", keywords: ["wifi", "wi-fi", "wireless", "internet", "ethernet", "password", "join", "connect", "ssid", "online"] },
    { key: "", page: "Bluetooth", heading: "", label: "Bluetooth", keywords: ["pair", "headphones", "devices", "connect", "nearby", "wireless", "adapter", "discovery"] },

    { key: "appearance.fontFamily", page: "Appearance", heading: "Text and shape", label: "Font", keywords: ["typeface", "family", "nerd font"] },
    { key: "appearance.textScale", page: "Appearance", heading: "Text and shape", label: "Text size", keywords: ["scale", "zoom", "bigger", "smaller", "font size"] },
    { key: "appearance.cornerScale", page: "Appearance", heading: "Text and shape", label: "Corner rounding", keywords: ["radius", "round", "square", "sharp"] },
    { key: "appearance.frameThickness", page: "Appearance", heading: "Text and shape", label: "Frame thickness", keywords: ["border", "edge", "width", "screen"] },
    { key: "appearance.animationSpeed", page: "Appearance", heading: "Text and shape", label: "Animation speed", keywords: ["motion", "faster", "slower", "transition"] },
    { key: "wallpaper.folder", page: "Appearance", heading: "Wallpaper and colours", label: "Folder", keywords: ["wallpaper", "pictures", "images", "directory", "path"] },
    { key: "wallpaper.fill", page: "Appearance", heading: "Wallpaper and colours", label: "Fill", keywords: ["wallpaper", "crop", "fit", "scale", "stretch"] },
    { key: "wallpaper.changeMinutes", page: "Appearance", heading: "Wallpaper and colours", label: "Change every", keywords: ["wallpaper", "rotate", "slideshow", "timer", "random", "interval"] },

    { key: "bar.edge", page: "Bar", heading: "Position", label: "Edge", keywords: ["top", "bottom", "left", "right", "side", "vertical", "horizontal", "place"] },
    { key: "bar.autoHide", page: "Bar", heading: "Position", label: "Auto-hide", keywords: ["hide", "reveal", "slide", "away"] },
    { key: "bar.hiddenScreens", page: "Bar", heading: "Position", label: "Screens", keywords: ["monitor", "display", "output", "hide", "show", "which"] },
    { key: "clock.twelveHour", page: "Bar", heading: "Clock", label: "12-hour", keywords: ["am pm", "24 hour", "time", "lock screen"] },
    { key: "bar.clockSeconds", page: "Bar", heading: "Clock", label: "Seconds", keywords: ["time", "tick"] },
    { key: "bar.clockDate", page: "Bar", heading: "Clock", label: "Date", keywords: ["day", "month", "calendar"] },
    { key: "bar.workspacesPerMonitor", page: "Bar", heading: "Workspaces", label: "Per screen", keywords: ["monitor", "display", "each", "separate"] },
    { key: "bar.workspaceCount", page: "Bar", heading: "Workspaces", label: "How many", keywords: ["number", "amount", "desktops"] },
    { key: "bar.showEmptyWorkspaces", page: "Bar", heading: "Workspaces", label: "Empty ones", keywords: ["unused", "hide", "show"] },
    { key: "bar.scrollWorkspaces", page: "Bar", heading: "Workspaces", label: "Scroll to switch", keywords: ["mouse wheel", "change", "desktops"] },
    { key: "bar.showLogo", page: "Bar", heading: "Status icons", label: "OS logo", keywords: ["nixos", "snowflake", "launcher", "start", "menu", "icon"] },
    { key: "bar.showLockKeys", page: "Bar", heading: "Status icons", label: "Caps and Num Lock", keywords: ["caps lock", "num lock", "keyboard", "capital", "numpad", "indicator", "icon"] },
    { key: "bar.showTray", page: "Bar", heading: "Status icons", label: "Tray", keywords: ["system tray", "indicators", "applets", "icons"] },
    { key: "bar.showBluetooth", page: "Bar", heading: "Status icons", label: "Bluetooth", keywords: ["wireless", "icon"] },
    { key: "bar.showNetwork", page: "Bar", heading: "Status icons", label: "Network", keywords: ["wifi", "wi-fi", "ethernet", "internet", "icon"] },
    { key: "bar.showMicrophone", page: "Bar", heading: "Status icons", label: "Microphone", keywords: ["mic", "input", "mute", "recording", "icon"] },
    { key: "bar.showAudio", page: "Bar", heading: "Status icons", label: "Volume", keywords: ["sound", "speaker", "icon"] },
    { key: "bar.showBattery", page: "Bar", heading: "Status icons", label: "Battery", keywords: ["power", "charge", "laptop", "icon"] },
    { key: "bar.showPower", page: "Bar", heading: "Status icons", label: "Power button", keywords: ["session", "shut down", "shutdown", "restart", "reboot", "log out", "sleep", "suspend", "icon"] },
    { key: "bar.volumeLabel", page: "Bar", heading: "Volume", label: "Percentage", keywords: ["number", "text", "level", "sound"] },
    { key: "bar.volumeStep", page: "Bar", heading: "Volume", label: "Scroll step", keywords: ["mouse wheel", "increment", "sound"] },
    { key: "bar.volumeMax", page: "Bar", heading: "Volume", label: "Scroll up to", keywords: ["limit", "maximum", "boost", "overdrive", "sound"] },
    { key: "pomodoro.workMinutes", page: "Bar", heading: "Pomodoro", label: "Work", keywords: ["timer", "focus", "session", "minutes", "length"] },
    { key: "pomodoro.breakMinutes", page: "Bar", heading: "Pomodoro", label: "Break", keywords: ["timer", "rest", "short", "minutes", "length"] },
    { key: "pomodoro.longBreakMinutes", page: "Bar", heading: "Pomodoro", label: "Long break", keywords: ["timer", "rest", "minutes", "length"] },
    { key: "pomodoro.longBreakEvery", page: "Bar", heading: "Pomodoro", label: "Long break every", keywords: ["timer", "sessions", "cycle", "never"] },
    { key: "pomodoro.autoStart", page: "Bar", heading: "Pomodoro", label: "Auto-start", keywords: ["timer", "automatic", "next", "continue"] },
    { key: "pomodoro.sound", page: "Bar", heading: "Pomodoro", label: "Sound", keywords: ["timer", "alarm", "chime", "ding", "mute", "audio"] },

    { key: "dashboard.showOverview", page: "Dashboard", heading: "Tabs", label: "Overview", keywords: ["tab", "show", "hide"] },
    { key: "dashboard.showPerformance", page: "Dashboard", heading: "Tabs", label: "Performance", keywords: ["tab", "show", "hide", "stats"] },
    { key: "dashboard.showWallpaper", page: "Dashboard", heading: "Tabs", label: "Wallpaper", keywords: ["tab", "show", "hide", "colours"] },
    { key: "dashboard.rememberTab", page: "Dashboard", heading: "Tabs", label: "Open on last", keywords: ["remember", "tab", "previous", "start"] },
    { key: "dashboard.weekStart", page: "Dashboard", heading: "Overview", label: "Week starts", keywords: ["monday", "sunday", "saturday", "calendar", "first day"] },
    { key: "dashboard.visualiser", page: "Dashboard", heading: "Overview", label: "Visualiser", keywords: ["music", "audio", "spectrum", "cava", "bars"] },
    { key: "dashboard.visualiserBars", page: "Dashboard", heading: "Overview", label: "Its bars", keywords: ["visualiser", "music", "spectrum", "count", "number"] },
    { key: "dashboard.showCpu", page: "Dashboard", heading: "Performance", label: "CPU", keywords: ["processor", "usage", "load", "temperature"] },
    { key: "dashboard.showGpu", page: "Dashboard", heading: "Performance", label: "GPU", keywords: ["graphics", "nvidia", "vram", "usage", "temperature"] },
    { key: "dashboard.showMemory", page: "Dashboard", heading: "Performance", label: "Memory", keywords: ["ram", "usage"] },
    { key: "dashboard.showSwap", page: "Dashboard", heading: "Performance", label: "Swap", keywords: ["memory", "usage"] },
    { key: "dashboard.showDisks", page: "Dashboard", heading: "Performance", label: "Disks", keywords: ["storage", "drives", "space", "usage"] },
    { key: "dashboard.showNetwork", page: "Dashboard", heading: "Performance", label: "Network", keywords: ["traffic", "download", "upload", "speed"] },
    { key: "dashboard.byteUnits", page: "Dashboard", heading: "Performance", label: "Sizes", keywords: ["bytes", "units", "gib", "gb", "binary", "decimal"] },
    { key: "dashboard.fahrenheit", page: "Dashboard", heading: "Performance", label: "Fahrenheit", keywords: ["temperature", "celsius", "degrees", "units"] },
    { key: "dashboard.graphSeconds", page: "Dashboard", heading: "Performance", label: "Graph length", keywords: ["history", "time", "window", "duration"] },
    { key: "dashboard.sampleInterval", page: "Dashboard", heading: "Performance", label: "Sample every", keywords: ["refresh", "rate", "interval", "frequency", "cpu use"] },

    { key: "launcher.rows", page: "Launcher", heading: "Results", label: "Rows", keywords: ["results", "height", "size", "how many", "lines"] },
    { key: "launcher.rankByUse", page: "Launcher", heading: "Results", label: "Rank by use", keywords: ["frequent", "recent", "order", "sort", "most used"] },
    { key: "launcher.useSoFar", page: "Launcher", heading: "Results", label: "Use so far", keywords: ["forget", "reset", "clear", "history", "counts", "usage"] },
    { key: "launcher.terminal", page: "Launcher", heading: "Apps", label: "Terminal", keywords: ["kitty", "foot", "wezterm", "command", "emulator"] },
    { key: "launcher.clipboardPrefix", page: "Launcher", heading: "Prefixes", label: "Clipboard", keywords: ["history", "paste", "copy", "mode"] },
    { key: "launcher.calculatorPrefix", page: "Launcher", heading: "Prefixes", label: "Calculator", keywords: ["maths", "calc", "qalc", "mode", "sums"] },
    { key: "launcher.actionsPrefix", page: "Launcher", heading: "Prefixes", label: "Actions", keywords: ["commands", "mode", "pomodoro", "session"] },

    { key: "notifications.position", page: "Notifications", heading: "Pop-ups", label: "Where", keywords: ["corner", "top", "bottom", "left", "right", "place"] },
    { key: "notifications.timeout", page: "Notifications", heading: "Pop-ups", label: "Timeout", keywords: ["seconds", "duration", "dismiss", "how long"] },
    { key: "notifications.appTimeout", page: "Notifications", heading: "Pop-ups", label: "App's timeout", keywords: ["respect", "own", "duration", "dismiss"] },
    { key: "notifications.maxPopups", page: "Notifications", heading: "Pop-ups", label: "At most", keywords: ["limit", "maximum", "count", "stack", "number"] },
    { key: "notifications.popupBodyLines", page: "Notifications", heading: "Pop-ups", label: "Body lines", keywords: ["text", "length", "truncate", "message"] },
    { key: "notifications.historyCount", page: "Notifications", heading: "History", label: "Keep the last", keywords: ["limit", "maximum", "number", "past", "log"] },
    { key: "notifications.historyDays", page: "Notifications", heading: "History", label: "Keep for", keywords: ["days", "expire", "delete", "old", "log"] },
    { key: "osd.position", page: "Notifications", heading: "On-screen display", label: "Where", keywords: ["osd", "volume", "brightness", "bottom", "top", "left", "right", "place"] },
    { key: "osd.timeout", page: "Notifications", heading: "On-screen display", label: "Stays for", keywords: ["osd", "seconds", "duration", "how long"] },
    { key: "osd.showVolume", page: "Notifications", heading: "On-screen display", label: "Volume", keywords: ["osd", "sound", "show"] },
    { key: "osd.showMicrophone", page: "Notifications", heading: "On-screen display", label: "Microphone", keywords: ["osd", "mic", "mute", "show"] },
    { key: "osd.showBrightness", page: "Notifications", heading: "On-screen display", label: "Brightness", keywords: ["osd", "backlight", "screen", "show"] },
    { key: "osd.showInGameMode", page: "Notifications", heading: "On-screen display", label: "In game mode", keywords: ["osd", "gaming", "show", "hide"] },

    { key: "lock.blur", page: "Session", heading: "Lock screen", label: "Blur", keywords: ["wallpaper", "background", "soften"] },
    { key: "lock.dim", page: "Session", heading: "Lock screen", label: "Dim", keywords: ["wallpaper", "background", "darken", "brightness"] },
    { key: "lock.media", page: "Session", heading: "Lock screen", label: "Media", keywords: ["music", "player", "controls", "now playing"] },
    { key: "idle.lockMinutes", page: "Session", heading: "When idle", label: "Lock after", keywords: ["timeout", "inactive", "minutes", "automatic", "never"] },
    { key: "idle.screenOffMinutes", page: "Session", heading: "When idle", label: "Screens off", keywords: ["blank", "dpms", "sleep", "monitor", "display", "timeout", "inactive", "minutes", "never"] },
    { key: "session.confirm", page: "Session", heading: "Session menu", label: "Confirm", keywords: ["log out", "restart", "shut down", "reboot", "power", "sure", "second press"] },
    { key: "session.showSleep", page: "Session", heading: "Session menu", label: "Sleep", keywords: ["suspend", "power", "show"] }
];

const byKey = {};
for (const entry of entries) {
    if (entry.key)
        byKey[entry.key] = entry;
}

// The label of the row with `key`; the key itself where there is no entry.
function label(key) {
    return byKey[key]?.label ?? key;
}

// The keys among `keys` that have no entry.
function missing(keys) {
    return keys.filter(key => !byKey[key]);
}

// How well `entry` matches `words`, the query's words: each must match something, and
// the label counts most. Below 0 is no match.
function rank(words, entry) {
    let total = 0;
    for (const word of words) {
        let best = Math.max(Fuzzy.score(word, entry.heading) * 0.5, Fuzzy.score(word, entry.page) * 0.5, Fuzzy.score(word, entry.label));
        for (const keyword of entry.keywords)
            best = Math.max(best, Fuzzy.score(word, keyword) * 0.8);
        if (best < 0)
            return -1;
        total += best;
    }
    return total;
}

// The entries that match `query`, best first; equal matches keep the order above.
function search(query) {
    const words = query.trim().split(/\s+/).filter(word => word !== "");
    const found = [];
    entries.forEach((entry, index) => {
        const score = words.length === 0 ? -1 : rank(words, entry);
        if (score >= 0)
            found.push({ entry, score, index });
    });
    found.sort((a, b) => b.score - a.score || a.index - b.index);
    return found.map(match => match.entry);
}

// The row of `items` (an Item's children) with `key`, or null.
function rowFor(items, key) {
    for (let i = 0; i < items.length; ++i) {
        if (items[i].key === key)
            return items[i];
    }
    return null;
}
