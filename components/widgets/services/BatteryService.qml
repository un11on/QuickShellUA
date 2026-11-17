pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int subscriberCount: 0

    // Public properties
    property int percentage: 0
    property string status: "Unknown"
    property real powerWatts: 0.0
    property bool acOnline: false
    property bool hasBattery: false
    property string timeRemaining: ""

    // Internal: detected device names
    property string _batName: ""
    property string _acName: ""
    property bool _detected: false

    function acquire() {
        root.subscriberCount++
        if (root.subscriberCount === 1) {
            if (!root._detected)
                detectProcess.running = true
            else
                root.refresh()
        }
    }

    function release() {
        root.subscriberCount = Math.max(0, root.subscriberCount - 1)
    }

    function refresh() {
        if (root._batName !== "") {
            capacityFile.reload()
            statusFile.reload()
            powerNowFile.reload()
            energyNowFile.reload()
            energyFullFile.reload()
        }
        if (root._acName !== "")
            acOnlineFile.reload()
    }

    function parseDetect(text) {
        var names = String(text || "").trim().split(/\s+/)
        for (var i = 0; i < names.length; ++i) {
            var n = names[i]
            if (root._batName === "" && (n === "BAT0" || n === "BAT1" || n.indexOf("BAT") === 0))
                root._batName = n
            if (root._acName === "" && (n === "AC0" || n === "ADP0" || n === "ACAD" || n.indexOf("AC") === 0 || n.indexOf("ADP") === 0))
                root._acName = n
        }
        root.hasBattery = root._batName !== ""
        root._detected = true

        if (root.hasBattery) {
            capacityFile.path = "/sys/class/power_supply/" + root._batName + "/capacity"
            statusFile.path = "/sys/class/power_supply/" + root._batName + "/status"
            powerNowFile.path = "/sys/class/power_supply/" + root._batName + "/power_now"
            energyNowFile.path = "/sys/class/power_supply/" + root._batName + "/energy_now"
            energyFullFile.path = "/sys/class/power_supply/" + root._batName + "/energy_full"
        }
        if (root._acName !== "")
            acOnlineFile.path = "/sys/class/power_supply/" + root._acName + "/online"

        if (root.subscriberCount > 0)
            root.refresh()
    }

    function updateTimeRemaining() {
        var energyNow = parseFloat(energyNowFile.text()) || 0
        var energyFull = parseFloat(energyFullFile.text()) || 0
        var power = parseFloat(powerNowFile.text()) || 0

        // Convert from microwatts to watts
        root.powerWatts = power / 1000000

        if (power <= 0 || root.status === "Full" || root.status === "Not charging") {
            root.timeRemaining = ""
            return
        }

        var hours = 0
        if (root.status === "Discharging")
            hours = energyNow / power
        else if (root.status === "Charging")
            hours = (energyFull - energyNow) / power
        else {
            root.timeRemaining = ""
            return
        }

        if (hours < 0 || hours > 100 || isNaN(hours)) {
            root.timeRemaining = ""
            return
        }

        var h = Math.floor(hours)
        var m = Math.round((hours - h) * 60)
        if (m === 60) { h++; m = 0 }
        root.timeRemaining = h + "h " + (m < 10 ? "0" : "") + m + "m"
    }

    // Detection process
    property Process detectProcess: Process {
        id: detectProcess
        command: ["ls", "/sys/class/power_supply/"]
        stdout: StdioCollector { id: detectOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.parseDetect(detectOutput.text)
            else {
                root.hasBattery = false
                root._detected = true
            }
        }
    }

    // FileViews for battery data
    property FileView capacityFile: FileView {
        id: capacityFile
        path: ""
        onLoaded: {
            var val = parseInt(text(), 10)
            if (!isNaN(val))
                root.percentage = Math.max(0, Math.min(100, val))
        }
    }

    property FileView statusFile: FileView {
        id: statusFile
        path: ""
        onLoaded: {
            var s = String(text() || "").trim()
            if (s.length > 0)
                root.status = s
            root.updateTimeRemaining()
        }
    }

    property FileView powerNowFile: FileView {
        id: powerNowFile
        path: ""
        onLoaded: root.updateTimeRemaining()
    }

    property FileView energyNowFile: FileView {
        id: energyNowFile
        path: ""
        onLoaded: root.updateTimeRemaining()
    }

    property FileView energyFullFile: FileView {
        id: energyFullFile
        path: ""
        onLoaded: root.updateTimeRemaining()
    }

    property FileView acOnlineFile: FileView {
        id: acOnlineFile
        path: ""
        onLoaded: {
            var val = String(text() || "").trim()
            root.acOnline = (val === "1")
        }
    }

    // Poll timer
    property Timer pollTimer: Timer {
        interval: 10000
        repeat: true
        running: root.subscriberCount > 0 && root._detected
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
