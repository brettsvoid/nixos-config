import QtQuick
import QtQml.Models
import Quickshell.Io
import "../config"
import "../theme"

// The dashboard's performance tab. shell-stats (Rust, custom-shell.nix) prints a sample
// every interval the settings choose; it runs only while this tab exists, since
// Quickshell kills a Process that is destroyed. CPU and GPU keep the settings' length of
// history for their graphs. The settings also choose which cards show and the units.
Item {
    id: root

    property var sample: null
    property var cpuHistory: []
    property var gpuHistory: []
    readonly property int historyLength: Math.max(2, Math.round(Settings.dashboard.graphSeconds / Settings.dashboard.sampleInterval))
    readonly property var gpu: root.sample?.gpu ?? { state: "absent" }

    function bytes(n) {
        const binary = Settings.dashboard.byteUnits === "binary";
        const units = binary ? ["B", "KiB", "MiB", "GiB", "TiB"] : ["B", "kB", "MB", "GB", "TB"];
        const base = binary ? 1024 : 1000;
        let i = 0;
        while (n >= base && i < units.length - 1) {
            n /= base;
            ++i;
        }
        return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i];
    }

    function temperature(celsius) {
        return Settings.dashboard.fahrenheit ? (celsius * 9 / 5 + 32).toFixed(0) + " °F" : celsius.toFixed(0) + " °C";
    }

    // A new interval makes a new Process, and the old one is killed with its object.
    Instantiator {
        model: [Settings.dashboard.sampleInterval]

        Process {
            required property real modelData

            command: ["shell-stats", "--interval", String(Math.round(modelData * 1000))]
            running: true
            stdout: SplitParser {
                onRead: line => {
                    let s;
                    try {
                        s = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    root.sample = s;
                    root.cpuHistory = root.cpuHistory.concat([s.cpu.usage]).slice(-root.historyLength);
                    root.gpuHistory = root.gpuHistory.concat([s.gpu.state === "awake" ? s.gpu.usage : 0]).slice(-root.historyLength);
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.sample === null
        text: "Reading…"
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }

    // The graphs on the left, the rest on the right; either takes the whole width when
    // the other has nothing to show.
    Row {
        id: columns

        readonly property bool graphs: Settings.dashboard.showCpu || Settings.dashboard.showGpu
        readonly property bool usage: Settings.dashboard.showMemory || Settings.dashboard.showSwap || Settings.dashboard.showDisks || Settings.dashboard.showNetwork
        readonly property real columnWidth: columns.graphs && columns.usage ? (width - spacing) / 2 : width

        anchors.fill: parent
        visible: root.sample !== null
        spacing: Theme.spacingLarge

        Column {
            visible: columns.graphs
            width: columns.columnWidth
            spacing: Theme.spacingMedium

            GraphCard {
                width: parent.width
                visible: Settings.dashboard.showCpu
                title: "CPU"
                value: (root.sample?.cpu.usage ?? 0).toFixed(0) + "%"
                detail: root.sample?.cpu.temp != null ? root.temperature(root.sample.cpu.temp) : ""
                values: root.cpuHistory
                capacity: root.historyLength
            }

            GraphCard {
                width: parent.width
                visible: Settings.dashboard.showGpu
                title: root.gpu.state === "awake" ? root.gpu.name : "GPU"
                value: {
                    switch (root.gpu.state) {
                    case "awake":
                        return root.gpu.usage.toFixed(0) + "%";
                    case "asleep":
                        return "Asleep";
                    case "unavailable":
                        return "No driver";
                    default:
                        return "None";
                    }
                }
                detail: root.gpu.state !== "awake" ? "" : [root.bytes(root.gpu.memoryUsed) + " / " + root.bytes(root.gpu.memoryTotal), root.gpu.temp != null ? root.temperature(root.gpu.temp) : "", root.gpu.power != null ? root.gpu.power.toFixed(0) + " W" : ""].filter(s => s !== "").join("  ·  ")
                values: root.gpuHistory
                capacity: root.historyLength
            }
        }

        Column {
            visible: columns.usage
            width: columns.columnWidth
            spacing: Theme.spacingMedium

            UsageBar {
                width: parent.width
                visible: Settings.dashboard.showMemory
                label: "Memory"
                used: root.sample?.memory.used ?? 0
                total: root.sample?.memory.total ?? 0
                format: root.bytes
            }

            UsageBar {
                width: parent.width
                visible: Settings.dashboard.showSwap && (root.sample?.swap.total ?? 0) > 0
                label: "Swap"
                used: root.sample?.swap.used ?? 0
                total: root.sample?.swap.total ?? 0
                format: root.bytes
            }

            Repeater {
                model: Settings.dashboard.showDisks ? root.sample?.disks ?? [] : []

                UsageBar {
                    required property var modelData

                    width: parent.width
                    label: modelData.mount
                    used: modelData.used
                    total: modelData.total
                    format: root.bytes
                }
            }

            Text {
                visible: Settings.dashboard.showNetwork
                text: "Network  ↓ " + root.bytes(root.sample?.network.rx ?? 0) + "/s   ↑ " + root.bytes(root.sample?.network.tx ?? 0) + "/s"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }
    }
}
