.pragma library

// Turns `hyprctl binds -j` entries into rows for the cheatsheet: the keys to press, a
// description and a group. Binds carry no purpose, so the group comes from what the
// bind does (its dispatcher) and, for media and screenshot keys, the key itself.

const groups = ["Apps", "Shell", "Windows", "Workspaces", "Media", "Screenshots", "Session", "Other"];

function modifiers(mask) {
    const names = [];
    if (mask & 64)
        names.push("Super");
    if (mask & 4)
        names.push("Ctrl");
    if (mask & 8)
        names.push("Alt");
    if (mask & 1)
        names.push("Shift");
    return names;
}

const keyNames = {
    "mouse:272": "Left click",
    "mouse:273": "Right click",
    "mouse_down": "Scroll down",
    "mouse_up": "Scroll up",
    "slash": "/",
    "XF86AudioRaiseVolume": "Volume up",
    "XF86AudioLowerVolume": "Volume down",
    "XF86AudioMute": "Mute",
    "XF86AudioPlay": "Play",
    "XF86AudioNext": "Next",
    "XF86AudioPrev": "Previous",
    "XF86MonBrightnessUp": "Brightness up",
    "XF86MonBrightnessDown": "Brightness down"
};

// Single letters in capitals; names like SPACE or Caps_Lock as "Space", "Caps Lock".
function keyName(key) {
    if (keyNames[key])
        return keyNames[key];
    if (key.length === 1)
        return key.toUpperCase();
    return key.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(" ");
}

// A Lua bind reports its dispatcher as "HL.Dispatcher(exec_cmd)", and its arg is an
// internal reference rather than the dispatcher's argument.
function dispatcher(bind) {
    const match = /^HL\.Dispatcher\((.*)\)$/.exec(bind.dispatcher);
    return match ? match[1] : bind.dispatcher;
}

function group(bind) {
    if (bind.key.startsWith("XF86"))
        return "Media";
    if (bind.key === "Print")
        return "Screenshots";
    switch (dispatcher(bind)) {
    case "exec_cmd":
        return "Apps";
    case "global":
        return "Shell";
    case "focus":
    case "move":
        // Both take a direction, a window or a workspace; only the description tells.
        return /workspace|scratchpad/i.test(bind.description) ? "Workspaces" : "Windows";
    case "close":
    case "kill":
    case "fullscreen":
    case "float":
    case "swap":
    case "drag":
    case "resize":
    case "pin":
    case "pseudo":
    case "layout":
    case "center":
        return "Windows";
    case "toggle_special":
        return "Workspaces";
    case "exit":
        return "Session";
    default:
        return "Other";
    }
}

// Binds that only tell the shell something, with no keys of their own to show: the lock
// keys' (services/LockKeys.qml).
function hidden(bind) {
    return dispatcher(bind) === "global" && (bind.key === "Caps_Lock" || bind.key === "Num_Lock");
}

// Rows sorted by group, keeping the config's order within each.
function rows(binds) {
    const out = binds.filter(bind => !hidden(bind)).map((bind, i) => ({
                keys: modifiers(bind.modmask).concat([keyName(bind.key)]),
                description: bind.description || dispatcher(bind),
                group: group(bind),
                order: i
            }));
    out.sort((a, b) => groups.indexOf(a.group) - groups.indexOf(b.group) || a.order - b.order);
    return out;
}
