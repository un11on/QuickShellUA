pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int subscriberCount: 0
    property var mounts: []
    property bool ready: false

    function acquire() {
        root.subscriberCount++
        if (root.subscriberCount === 1)
            root.refresh()
    }

    function release() {
        root.subscriberCount = Math.max(0, root.subscriberCount - 1)
    }

    function refresh() {
        if (!dfProcess.running)
            dfProcess.running = true
    }

    function formatBytes(bytes) {
        var b = Number(bytes) || 0
        if (b < 0) b = 0
        var units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var i = 0
        var v = b
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024
            i++
        }
        if (i === 0)
            return Math.round(v) + " " + units[i]
        return v.toFixed(1) + " " + units[i]
    }

    function parseOutput(text) {
        var lines = String(text || "").split("\n")
        var result = []
        // Skip the header line (index 0)
        for (var i = 1; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line.length === 0)
                continue
            // Format: target size used avail pcent
            // pcent ends with '%'
            var parts = line.split(/\s+/)
            if (parts.length < 5)
                continue
            var pct = parseInt(parts[parts.length - 1].replace("%", ""), 10) || 0
            var avail = parseInt(parts[parts.length - 2], 10) || 0
            var used = parseInt(parts[parts.length - 3], 10) || 0
            var size = parseInt(parts[parts.length - 4], 10) || 0
            // Mount point may contain spaces, rejoin everything before the numeric columns
            var mount = parts.slice(0, parts.length - 4).join(" ")
            result.push({
                mountPoint: mount,
                totalBytes: size,
                usedBytes: used,
                availBytes: avail,
                usedPercent: pct
            })
        }
        return result
    }

    property Process dfProcess: Process {
        id: dfProcess
        command: ["df", "-B1", "--output=target,size,used,avail,pcent",
                  "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay"]
        stdout: StdioCollector { id: dfOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.mounts = root.parseOutput(dfOutput.text)
                root.ready = true
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 30000
        repeat: true
        running: root.subscriberCount > 0
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
