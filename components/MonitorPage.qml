import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

// Сторінка системного моніторингу: CPU/RAM із /proc, GPU/VRAM — лише якщо
// доступний NVIDIA (nvidia-smi). Опитування запускається ТІЛЬКИ коли сторінка
// активна; для GPU додатково припиняється, якщо відеокарта не виявлена.
Item {
    id: root

    property bool active: false

    // ---------- CPU / RAM ----------
    property real cpuUsage: 0        // 0..1
    property real ramUsage: 0        // 0..1
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real prevIdle: 0
    property real prevTotal: 0

    // ---------- GPU (NVIDIA) ----------
    // 0 = ще не перевірено, 1 = доступно, 2 = недоступно
    property int gpuState: 0
    property bool gpuProbed: false
    property real gpuUtil: 0         // 0..100
    property real gpuVramUsedMb: 0
    property real gpuVramTotalMb: 0

    readonly property real gpuVramFrac: root.gpuVramTotalMb > 0
        ? Math.max(0, Math.min(1, root.gpuVramUsedMb / root.gpuVramTotalMb)) : 0
    readonly property string gpuVramText: root.gpuVramTotalMb > 0
        ? ((root.gpuVramUsedMb >= 1024
            ? (root.gpuVramUsedMb / 1024).toFixed(1) + " GB"
            : Math.round(root.gpuVramUsedMb) + " MB")
           + " / " + (root.gpuVramTotalMb / 1024).toFixed(1) + " GB")
        : "—"

    function parseStats(text) {
        var lines = text.split("\n")
        var memTotal = 0, memAvail = 0

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (l.startsWith("cpu ")) {
                var p = l.trim().split(/\s+/).slice(1, 9).map(Number)
                var idle = p[3] + p[4]
                var total = p.reduce(function(a, b) { return a + b }, 0)
                var dTotal = total - root.prevTotal
                var dIdle = idle - root.prevIdle
                if (root.prevTotal > 0 && dTotal > 0)
                    root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal))
                root.prevTotal = total
                root.prevIdle = idle
            } else if (l.startsWith("MemTotal:")) {
                memTotal = parseInt(l.split(/\s+/)[1])
            } else if (l.startsWith("MemAvailable:")) {
                memAvail = parseInt(l.split(/\s+/)[1])
            }
        }

        if (memTotal > 0) {
            root.ramTotalGb = memTotal / 1048576
            root.ramUsedGb = (memTotal - memAvail) / 1048576
            root.ramUsage = Math.max(0, Math.min(1, (memTotal - memAvail) / memTotal))
        }
    }

    function parseGpu(text) {
        root.gpuProbed = true
        var l = String(text || "").trim()
        if (l.length === 0) {
            root.gpuState = 2
            return
        }
        var p = l.split("\n")[0].split(",")
        if (p.length < 3) {
            root.gpuState = 2
            return
        }
        var used = parseFloat(p[0])
        var total = parseFloat(p[1])
        var util = parseFloat(p[2])
        if (isNaN(used) || isNaN(total) || total <= 0) {
            root.gpuState = 2
            return
        }
        root.gpuState = 1
        root.gpuVramUsedMb = Math.max(0, used)
        root.gpuVramTotalMb = total
        root.gpuUtil = isNaN(util) ? 0 : Math.max(0, Math.min(100, util))
    }

    // Повернення на вкладку — дозволяємо один повторний probe GPU
    onActiveChanged: {
        if (root.active)
            root.gpuProbed = false
    }

    Process {
        id: statProc
        command: ["sh", "-c",
                  "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStats(text)
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!statProc.running) statProc.running = true
    }

    Process {
        id: gpuProc
        // command -v не дає помилки запуску, якщо nvidia-smi відсутній:
        // порожній вивід = «GPU недоступний».
        command: ["sh", "-c",
                  "command -v nvidia-smi >/dev/null 2>&1 || exit 0; " +
                  "nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu " +
                  "--format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(text)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        // доступний GPU — оновлюємо; недоступний — більше не смикаємо процес
        running: root.active && (!root.gpuProbed || root.gpuState === 1)
        triggeredOnStart: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Text {
            text: "СИСТЕМА"
            color: Theme.textMuted
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.2
        }

        StatRow {
            label: "CPU"
            valueText: Math.round(root.cpuUsage * 100) + "%"
            fraction: root.cpuUsage
            barColor: root.cpuUsage > 0.85 ? Theme.accentRed
                    : (root.cpuUsage > 0.6 ? Theme.accentYellow : Theme.accent)
        }

        StatRow {
            label: "RAM"
            valueText: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
            fraction: root.ramUsage
            barColor: root.ramUsage > 0.85 ? Theme.accentRed
                    : (root.ramUsage > 0.6 ? Theme.accentYellow : Theme.accent)
        }

        StatRow {
            visible: root.gpuState === 1
            label: "GPU"
            valueText: Math.round(root.gpuUtil) + "%"
            fraction: root.gpuUtil / 100
            barColor: root.gpuUtil > 85 ? Theme.accentRed
                    : (root.gpuUtil > 60 ? Theme.accentYellow : Theme.accentTeal)
        }

        StatRow {
            visible: root.gpuState === 1
            label: "VRAM"
            valueText: root.gpuVramText
            fraction: root.gpuVramFrac
            barColor: root.gpuVramFrac > 0.85 ? Theme.accentRed
                    : (root.gpuVramFrac > 0.6 ? Theme.accentYellow : Theme.accentSapphire)
        }

        // Понятний стан замість помилки, якщо NVIDIA не виявлено
        Text {
            Layout.fillWidth: true
            visible: root.gpuState !== 1
            text: root.gpuState === 0
                  ? "GPU: перевірка доступності…"
                  : "GPU: дані недоступні — NVIDIA GPU або nvidia-smi не виявлено"
            color: Theme.textMuted
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}
