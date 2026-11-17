pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int subscriberCount: 0
    property real cpuUsage: 0
    property real ramUsage: 0
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0
    property real gpuUsage: 0
    property bool gpuAvailable: false
    property string gpuError: ""
    property real previousIdle: 0
    property real previousTotal: 0

    function acquire() {
        root.subscriberCount++
        if (root.subscriberCount === 1) {
            root.refresh()
            root.refreshGpu()
        }
    }

    function release() {
        root.subscriberCount = Math.max(0, root.subscriberCount - 1)
    }

    function refresh() {
        statFile.reload()
        memFile.reload()
    }

    function refreshGpu() {
        if (!gpuProcess.running)
            gpuProcess.running = true
    }

    function parseStat(text) {
        var line = String(text || "").split("\n")[0]
        if (line.indexOf("cpu ") !== 0)
            return
        var p = line.trim().split(/\s+/).slice(1).map(Number)
        if (p.length < 4)
            return
        var idle = p[3] + (p.length > 4 ? p[4] : 0)
        var total = p.reduce(function(a, b) { return a + b }, 0)
        var deltaTotal = total - root.previousTotal
        var deltaIdle = idle - root.previousIdle
        if (root.previousTotal > 0 && deltaTotal > 0)
            root.cpuUsage = Math.max(0, Math.min(1, 1 - deltaIdle / deltaTotal))
        root.previousIdle = idle
        root.previousTotal = total
    }

    function parseMem(text) {
        var lines = String(text || "").split("\n")
        var total = 0
        var available = 0
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf("MemTotal:") === 0)
                total = parseInt(lines[i].split(/\s+/)[1], 10) || 0
            else if (lines[i].indexOf("MemAvailable:") === 0)
                available = parseInt(lines[i].split(/\s+/)[1], 10) || 0
        }
        if (total > 0) {
            root.ramTotalGiB = total / 1048576
            root.ramUsedGiB = (total - available) / 1048576
            root.ramUsage = Math.max(0, Math.min(1, (total - available) / total))
        }
    }

    property FileView statFile: FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parseStat(text())
    }

    property FileView memFile: FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    property Process gpuProcess: Process {
        id: gpuProcess
        command: ["sh", "-c",
                  "command -v nvidia-smi >/dev/null 2>&1 || exit 127; "
                  + "nvidia-smi --query-gpu=utilization.gpu "
                  + "--format=csv,noheader,nounits 2>/dev/null | head -n1"]
        stdout: StdioCollector { id: gpuOutput }
        onExited: function(exitCode, exitStatus) {
            var value = parseFloat(gpuOutput.text.trim())
            if (exitCode === 0 && !isNaN(value)) {
                root.gpuUsage = Math.max(0, Math.min(100, value)) / 100
                root.gpuAvailable = true
                root.gpuError = ""
            } else {
                // NVIDIA недоступний: зберігаємо сумісний текст помилки
                // і пробуємо AMDGPU. gpuAvailable вирішить AMD-проба,
                // щоб не було хибного "N/A" між двома перевірками.
                root.gpuError = exitCode === 127 ? "nvidia-smi недоступний" : "Немає даних GPU"
                root.refreshAmdGpu()
            }
        }
    }

    function refreshAmdGpu() {
        if (!amdGpuProcess.running)
            amdGpuProcess.running = true
    }

    // Fallback для AMDGPU: /sys/class/drm/cardN/device/gpu_busy_percent.
    // Карта вважається AMDGPU лише за vendor 0x1002 + драйвером amdgpu.
    // Береться перша карта з числовим значенням 0–100; інакше — без даних.
    property Process amdGpuProcess: Process {
        id: amdGpuProcess
        command: ["sh", "-c",
                  "found=0; "
                  + "for c in /sys/class/drm/card*; do "
                  + "case \"${c##*/}\" in card[0-9]*-*) continue ;; card[0-9]*) ;; *) continue ;; esac; "
                  + "d=\"$c/device\"; "
                  + "[ -r \"$d/vendor\" ] || continue; "
                  + "[ \"$(cat \"$d/vendor\" 2>/dev/null)\" = \"0x1002\" ] || continue; "
                  + "[ \"$(basename \"$(readlink -f \"$d/driver\" 2>/dev/null)\")\" = \"amdgpu\" ] || continue; "
                  + "found=1; "
                  + "[ -r \"$d/gpu_busy_percent\" ] || continue; "
                  + "v=$(cat \"$d/gpu_busy_percent\" 2>/dev/null) || continue; "
                  + "case \"$v\" in ''|*[!0-9]*) continue ;; esac; "
                  + "if [ \"$v\" -lt 0 ] 2>/dev/null || [ \"$v\" -gt 100 ] 2>/dev/null; then continue; fi; "
                  + "printf '%s\\n' \"$v\"; exit 0; "
                  + "done; "
                  + "[ \"$found\" = \"1\" ] && exit 2; exit 1"]
        stdout: StdioCollector { id: amdGpuOutput }
        onExited: function(exitCode, exitStatus) {
            var text = amdGpuOutput.text.trim()
            var value = Number(text)
            if (exitCode === 0 && text !== "" && isFinite(value) && value >= 0 && value <= 100) {
                root.gpuUsage = Math.max(0, Math.min(100, value)) / 100
                root.gpuAvailable = true
                root.gpuError = ""
            } else {
                root.gpuAvailable = false
                if (exitCode !== 1)
                    root.gpuError = "Немає даних GPU"
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: root.subscriberCount > 0
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    property Timer gpuTimer: Timer {
        interval: 5000
        repeat: true
        running: root.subscriberCount > 0
        triggeredOnStart: true
        onTriggered: root.refreshGpu()
    }
}
