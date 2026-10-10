import QtQuick
import Quickshell.Io
import "../theme"

// The dashboard's performance tab. shell-stats (Rust, custom-shell.nix) prints a sample
// a second; it runs only while this tab exists, since Quickshell kills a Process that
// is destroyed. CPU and GPU keep a minute of history for their graphs.
Item {
    id: root

    property var sample: null
    property var cpuHistory: []
    property var gpuHistory: []
    readonly property int historyLength: 60
    readonly property var gpu: root.sample?.gpu ?? { state: "absent" }

    function bytes(n) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            ++i;
        }
        return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i];
    }

    Process {
        command: ["shell-stats"]
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

    Text {
        anchors.centerIn: parent
        visible: root.sample === null
        text: "Reading…"
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyLarge
    }

    Row {
        anchors.fill: parent
        visible: root.sample !== null
        spacing: Theme.spacingLarge

        Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Theme.spacingMedium

            GraphCard {
                width: parent.width
                title: "CPU"
                value: (root.sample?.cpu.usage ?? 0).toFixed(0) + "%"
                detail: root.sample?.cpu.temp != null ? root.sample.cpu.temp.toFixed(0) + " °C" : ""
                values: root.cpuHistory
                capacity: root.historyLength
            }

            GraphCard {
                width: parent.width
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
                detail: root.gpu.state !== "awake" ? "" : [root.bytes(root.gpu.memoryUsed) + " / " + root.bytes(root.gpu.memoryTotal), root.gpu.temp != null ? root.gpu.temp.toFixed(0) + " °C" : "", root.gpu.power != null ? root.gpu.power.toFixed(0) + " W" : ""].filter(s => s !== "").join("  ·  ")
                values: root.gpuHistory
                capacity: root.historyLength
            }
        }

        Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Theme.spacingMedium

            UsageBar {
                width: parent.width
                label: "Memory"
                used: root.sample?.memory.used ?? 0
                total: root.sample?.memory.total ?? 0
                format: root.bytes
            }

            UsageBar {
                width: parent.width
                visible: (root.sample?.swap.total ?? 0) > 0
                label: "Swap"
                used: root.sample?.swap.used ?? 0
                total: root.sample?.swap.total ?? 0
                format: root.bytes
            }

            Repeater {
                model: root.sample?.disks ?? []

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
                text: "Network  ↓ " + root.bytes(root.sample?.network.rx ?? 0) + "/s   ↑ " + root.bytes(root.sample?.network.tx ?? 0) + "/s"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }
        }
    }
}
