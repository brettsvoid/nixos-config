import QtQuick
import Quickshell
import "../config"
import "../services"
import "fuzzy.js" as Fuzzy

// The launcher's default mode: installed apps (desktop entries), best match first, with
// frequently started apps ranked above rarely started ones of the same match quality
// (unless the settings turn that off).
QtObject {
    id: root

    readonly property string name: "apps"
    readonly property string prefix: ""
    readonly property string placeholder: `Search apps, or ${Settings.launcher.calculatorPrefix} to calculate, ${Settings.launcher.actionsPrefix} for actions, ${Settings.launcher.clipboardPrefix} for the clipboard`
    // Apps marked Terminal=true run in this (the settings' command, split at spaces).
    readonly property var terminal: Settings.launcher.terminal.trim().split(/\s+/)

    function results(query) {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const scored = [];
        for (const app of apps) {
            let match = 0;
            if (query.length > 0) {
                match = Math.max(Fuzzy.score(query, app.name), Fuzzy.score(query, app.genericName) * 0.7, ...app.keywords.map(k => Fuzzy.score(query, k) * 0.6));
                if (match < 0)
                    continue;
            }
            scored.push({
                app: app,
                rank: match + (Settings.launcher.rankByUse ? 4 * Math.log2(1 + AppUsage.count(app.id)) : 0)
            });
        }
        scored.sort((a, b) => b.rank - a.rank || a.app.name.localeCompare(b.app.name));
        return scored.map(s => ({
                    title: s.app.name,
                    subtitle: s.app.genericName || s.app.comment,
                    icon: s.app.icon,
                    app: s.app
                }));
    }

    function activate(item) {
        AppUsage.record(item.app.id);
        if (item.app.runInTerminal)
            Quickshell.execDetached(root.terminal.concat(item.app.command));
        else
            item.app.execute();
    }
}
