import QtQuick
import "../services"
import "../theme"

// The pomodoro timer beside the clock, only while a session exists: an icon for the
// phase and the minutes left, rounded up. A click pauses or resumes it, or starts the
// phase that waits; a right-click stops the session.
StatusIcon {
    id: root

    readonly property bool available: Pomodoro.active
    // When the label was last worked out. The Timer below moves it on at each whole
    // minute left, and only while the bar shows (not in game mode), so the label
    // repaints once a minute and a hidden bar asks for nothing.
    property real now: Date.now()
    readonly property real msLeft: Pomodoro.running ? Math.max(0, Pomodoro.endsAt - root.now) : Pomodoro.pausedLeft
    readonly property int minutes: Math.ceil(root.msLeft / 60000)

    glyph: {
        if (Pomodoro.waiting)
            return 0xF040A; // md-play
        if (Pomodoro.paused)
            return 0xF03E4; // md-pause
        return Pomodoro.phase === "work" ? 0xF13AB : 0xF0176; // md-timer, md-coffee
    }
    label: root.vertical ? root.minutes + "m" : root.minutes + " min"
    color: {
        if (Pomodoro.waiting)
            return Theme.primary;
        if (Pomodoro.paused)
            return Theme.subtext;
        return Pomodoro.phase === "work" ? Theme.barText : Theme.batteryGood;
    }

    // A resume or the next phase moves the end time: work the label out at once.
    Connections {
        target: Pomodoro

        function onEndsAtChanged() {
            root.now = Date.now();
        }
    }

    Timer {
        running: root.visible && Pomodoro.running
        repeat: true
        triggeredOnStart: true
        // The time to the next whole minute left.
        interval: root.msLeft % 60000 || 60000
        onTriggered: root.now = Date.now()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Pomodoro.stop();
            else
                Pomodoro.toggle();
        }
    }
}
