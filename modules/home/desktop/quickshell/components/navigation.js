.pragma library

// The keys that move through the shell's lists and menus: Up and Down, and Ctrl+P and
// Ctrl+N, as in Emacs, readline and most terminal menus. Returns 1 for the next item,
// -1 for the previous one and 0 for any other key.
function step(event) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N))
        return 1;
    if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P))
        return -1;
    return 0;
}
