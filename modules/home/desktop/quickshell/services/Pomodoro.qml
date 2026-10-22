pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// The pomodoro timer: work, a break, and a long break after every few work sessions
// (the settings' times). It is saved in the shell's state, so a restart (a rebuild)
// keeps a running timer. Running, it holds the time the phase ends; paused, the time
// left. The phase end is one single-shot Timer: nothing ticks for it. The bar's entry
// repaints its label once a minute (bar/PomodoroStatus.qml), only while it shows.
//
// The next phase starts by itself with the settings' auto-start, and otherwise waits
// for a click (`waiting`). Each phase end sends a notification and plays a sound, which
// the shell's own rules hold back in game mode and do not disturb.
Singleton {
    id: root

    // Change these through the functions below, which save them.
    // "idle", "work", "break" or "longBreak". A waiting phase has not started yet.
    property string phase: "idle"
    // When the running phase ends, in milliseconds since the epoch; 0 when it is not
    // running.
    property real endsAt: 0
    // Milliseconds left while it is not running.
    property real pausedLeft: 0
    property bool waiting: false
    // Work sessions since the last long break.
    property int done: 0

    readonly property bool active: root.phase !== "idle"
    readonly property bool running: root.endsAt > 0
    readonly property bool paused: root.active && !root.running

    // The sound to play at a phase end: its path, from the environment that
    // toggle-shell and qs-test set (custom-shell.nix).
    readonly property string alarm: Quickshell.env("CUSTOM_SHELL_ALARM_SOUND")

    function minutesOf(phase) {
        switch (phase) {
        case "work":
            return Settings.pomodoro.workMinutes;
        case "break":
            return Settings.pomodoro.breakMinutes;
        default:
            return Settings.pomodoro.longBreakMinutes;
        }
    }

    // The phase after `phase`, given the work sessions done so far.
    function _after(phase, done) {
        if (phase !== "work")
            return "work";
        const every = Settings.pomodoro.longBreakEvery;
        return every > 0 && done >= every ? "longBreak" : "break";
    }

    // Moves to `phase`, running or waiting for a click.
    function _enter(phase, run) {
        root.phase = phase;
        root.waiting = !run;
        root.endsAt = run ? Date.now() + root.minutesOf(phase) * 60000 : 0;
        root.pausedLeft = run ? 0 : root.minutesOf(phase) * 60000;
        root._arm();
        root._save();
    }

    function _arm() {
        phaseEnd.stop();
        if (root.endsAt > 0) {
            phaseEnd.interval = Math.max(0, root.endsAt - Date.now());
            phaseEnd.start();
        }
    }

    // Counts the phase that has ended and moves on, to run or to wait. A phase that
    // never started is not counted.
    function _advance(run) {
        if (root.phase === "work" && !root.waiting)
            root.done += 1;
        const next = root._after(root.phase, root.done);
        if (next === "longBreak")
            root.done = 0;
        root._enter(next, run);
    }

    function _end() {
        root._advance(Settings.pomodoro.autoStart);
        const names = {
            work: "Work",
            break: "Break",
            longBreak: "Long break"
        };
        const minutes = root.minutesOf(root.phase);
        Quickshell.execDetached(["notify-send", "-a", "Pomodoro", `${names[root.phase]}: ${minutes} ${minutes === 1 ? "minute" : "minutes"}`, root.waiting ? "Click the timer in the bar to start" : ""]);
        if (Settings.pomodoro.sound && root.alarm !== "" && !GameMode.on && !Notifications.doNotDisturb)
            Quickshell.execDetached(["pw-play", root.alarm]);
    }

    // Starts the work phase, or runs a paused or waiting one.
    function start() {
        if (!root.active) {
            root.done = 0;
            root._enter("work", true);
        } else if (root.paused) {
            root.endsAt = Date.now() + root.pausedLeft;
            root.pausedLeft = 0;
            root.waiting = false;
            root._arm();
            root._save();
        }
    }

    function pause() {
        if (!root.running)
            return;
        root.pausedLeft = Math.max(0, root.endsAt - Date.now());
        root.endsAt = 0;
        root._arm();
        root._save();
    }

    // A click on the bar's entry.
    function toggle() {
        if (root.running)
            root.pause();
        else
            root.start();
    }

    // Ends the phase early and starts the next one, without a notification.
    function skip() {
        if (root.active)
            root._advance(true);
    }

    function stop() {
        root.phase = "idle";
        root.endsAt = 0;
        root.pausedLeft = 0;
        root.waiting = false;
        root.done = 0;
        root._arm();
        root._save();
    }

    // Single-shot, set to the phase's end time. It also fires at once for an end that
    // passed while the shell was not running.
    Timer {
        id: phaseEnd
        onTriggered: root._end()
    }

    // One property for all of it, written in one go: JsonAdapter reads the file back
    // over its properties when a write finishes, so a second property set before then
    // would be undone for a moment.
    function _save() {
        state.session = {
            phase: root.phase,
            endsAt: root.endsAt,
            pausedLeft: root.pausedLeft,
            waiting: root.waiting,
            done: root.done
        };
    }

    // The saved session, if it makes sense. Only read here: the properties above are the
    // live state.
    function _restore(saved) {
        if (!["work", "break", "longBreak"].includes(saved?.phase))
            return;
        root.phase = saved.phase;
        root.endsAt = Number(saved.endsAt) || 0;
        root.pausedLeft = Number(saved.pausedLeft) || 0;
        root.waiting = saved.waiting === true;
        root.done = Number(saved.done) || 0;
        root._arm();
    }

    FileView {
        path: Quickshell.statePath("pomodoro.json")
        // A missing file is the first run: no session.
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root._restore(state.session)

        JsonAdapter {
            id: state
            property var session: ({})
        }
    }
}
