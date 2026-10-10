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

const directions = { l: "left", r: "right", u: "up", d: "down" };

// For binds without a description.
function describe(bind) {
    switch (bind.dispatcher) {
    case "exec":
    case "global":
        return bind.arg;
    case "workspace":
        return "Switch to workspace " + bind.arg;
    case "movetoworkspace":
        return "Move window to workspace " + bind.arg;
    case "movefocus":
        return "Focus window " + (directions[bind.arg] ?? bind.arg);
    case "swapwindow":
        return "Swap window " + (directions[bind.arg] ?? bind.arg);
    default:
        return bind.dispatcher + (bind.arg ? " " + bind.arg : "");
    }
}

function group(bind) {
    if (bind.key.startsWith("XF86"))
        return "Media";
    if (bind.key === "Print")
        return "Screenshots";
    switch (bind.dispatcher) {
    case "exec":
        return "Apps";
    case "global":
        return "Shell";
    case "killactive":
    case "fullscreen":
    case "togglefloating":
    case "movefocus":
    case "swapwindow":
    case "movewindow":
    case "resizewindow":
    case "mouse":
    case "pin":
    case "pseudo":
    case "togglesplit":
    case "centerwindow":
        return "Windows";
    case "workspace":
    case "movetoworkspace":
    case "movetoworkspacesilent":
    case "togglespecialworkspace":
        return "Workspaces";
    case "exit":
        return "Session";
    default:
        return "Other";
    }
}

// Rows sorted by group, keeping the config's order within each.
function rows(binds) {
    const out = binds.map((bind, i) => ({
                keys: modifiers(bind.modmask).concat([keyName(bind.key)]),
                description: bind.description || describe(bind),
                group: group(bind),
                order: i
            }));
    out.sort((a, b) => groups.indexOf(a.group) - groups.indexOf(b.group) || a.order - b.order);
    return out;
}
