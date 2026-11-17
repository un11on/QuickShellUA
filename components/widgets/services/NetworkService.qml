pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int subscriberCount: 0
    property string activeInterface: ""
    property string ipAddress: ""
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property bool vpnActive: false
    property string connectionType: "disconnected"

    property real previousRx: 0
    property real previousTx: 0
    property real previousTimestamp: 0
    property int slowTickCount: 0

    function acquire() {
        root.subscriberCount++
        if (root.subscriberCount === 1) {
            root.previousRx = 0
            root.previousTx = 0
            root.previousTimestamp = 0
            root.slowTickCount = 0
            root.refreshNet()
            root.refreshInfo()
        }
    }

    function release() {
        root.subscriberCount = Math.max(0, root.subscriberCount - 1)
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 0 || isNaN(bytesPerSec))
            return "0 B/s"
        if (bytesPerSec < 1024)
            return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1048576)
            return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        if (bytesPerSec < 1073741824)
            return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
        return (bytesPerSec / 1073741824).toFixed(2) + " GB/s"
    }

    function refreshNet() {
        netDevFile.reload()
    }

    function refreshInfo() {
        if (!routeProcess.running)
            routeProcess.running = true
        if (!ipProcess.running)
            ipProcess.running = true
    }

    function parseNetDev(text) {
        var lines = String(text || "").split("\n")
        var iface = root.activeInterface
        if (!iface)
            return
        var totalRx = 0
        var totalTx = 0
        var found = false
        for (var i = 2; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (!line)
                continue
            var colonIdx = line.indexOf(":")
            if (colonIdx < 0)
                continue
            var name = line.substring(0, colonIdx).trim()
            if (name === "lo")
                continue
            if (name === iface) {
                var parts = line.substring(colonIdx + 1).trim().split(/\s+/)
                if (parts.length >= 10) {
                    totalRx = parseInt(parts[0], 10) || 0
                    totalTx = parseInt(parts[8], 10) || 0
                    found = true
                }
                break
            }
        }
        if (!found)
            return

        var now = Date.now() / 1000.0
        if (root.previousTimestamp > 0 && root.previousRx > 0) {
            var dt = now - root.previousTimestamp
            if (dt > 0.5) {
                var dRx = totalRx - root.previousRx
                var dTx = totalTx - root.previousTx
                if (dRx >= 0 && dTx >= 0) {
                    root.downloadSpeed = dRx / dt
                    root.uploadSpeed = dTx / dt
                } else {
                    root.downloadSpeed = 0
                    root.uploadSpeed = 0
                }
            }
        }
        root.previousRx = totalRx
        root.previousTx = totalTx
        root.previousTimestamp = now
    }

    function parseRoute(text) {
        var str = String(text || "").trim()
        if (!str)
            return

        // Try JSON format first
        try {
            var routes = JSON.parse(str)
            if (routes.length > 0) {
                var r = routes[0]
                root.activeInterface = r.dev || ""
                classifyInterface(root.activeInterface)
                return
            }
        } catch (e) {
            // Fall back to plain text
        }

        // Plain text: "1.0.0.0 via 192.168.1.1 dev wlan0 src 192.168.1.100 uid 1000"
        var devIdx = str.indexOf("dev ")
        if (devIdx >= 0) {
            var rest = str.substring(devIdx + 4).trim()
            root.activeInterface = rest.split(/\s+/)[0] || ""
            classifyInterface(root.activeInterface)
        }
    }

    function classifyInterface(iface) {
        if (!iface) {
            root.connectionType = "disconnected"
            root.vpnActive = false
            return
        }
        var lower = iface.toLowerCase()
        if (lower.indexOf("tun") === 0 || lower.indexOf("tap") === 0
            || lower.indexOf("wg") === 0 || lower.indexOf("vpn") >= 0) {
            root.vpnActive = true
            root.connectionType = "vpn"
        } else if (lower.indexOf("wl") === 0 || lower.indexOf("wifi") >= 0
                   || lower.indexOf("wlan") === 0) {
            root.vpnActive = false
            root.connectionType = "wifi"
        } else if (lower.indexOf("eth") === 0 || lower.indexOf("en") === 0) {
            root.vpnActive = false
            root.connectionType = "ethernet"
        } else {
            root.vpnActive = false
            root.connectionType = "other"
        }
    }

    property FileView netDevFile: FileView {
        id: netDevFile
        path: "/proc/net/dev"
        onLoaded: root.parseNetDev(text())
    }

    property Process routeProcess: Process {
        id: routeProcess
        command: ["ip", "-j", "route", "get", "1"]
        stdout: StdioCollector { id: routeOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.parseRoute(routeOutput.text)
            else
                routeFallback.running = true
        }
    }

    property Process routeFallback: Process {
        id: routeFallback
        command: ["ip", "route", "get", "1"]
        stdout: StdioCollector { id: routeFallbackOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.parseRoute(routeFallbackOutput.text)
        }
    }

    property Process ipProcess: Process {
        id: ipProcess
        command: ["hostname", "-I"]
        stdout: StdioCollector { id: ipOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                var addr = String(ipOutput.text || "").trim().split(/\s+/)[0] || ""
                root.ipAddress = addr
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 3000
        repeat: true
        running: root.subscriberCount > 0
        triggeredOnStart: true
        onTriggered: root.refreshNet()
    }

    property Timer infoTimer: Timer {
        interval: 10000
        repeat: true
        running: root.subscriberCount > 0
        triggeredOnStart: true
        onTriggered: root.refreshInfo()
    }
}
