pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The media player the shell's media controls act on: the one playing, else the first.
Singleton {
    id: root

    readonly property var active: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
}
