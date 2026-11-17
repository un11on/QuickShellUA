import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    signal settingChanged(string key, var value)

    property real uptimeSeconds: 0
    property string bootTime: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            var parts = String(text()).split(" ")
            if (parts.length >= 1) {
                var secs = parseFloat(parts[0])
                if (!isNaN(secs))
                    root.uptimeSeconds = secs
            }
        }
    }

    Process {
        id: bootProc
        running: false
        command: ["sh", "-c", "uptime -s 2>/dev/null || echo ''"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var t = String(data).trim()
                if (t.length > 0)
                    root.bootTime = t
            }
        }
        onExited: function(exitCode, exitStatus) {}
    }

    Timer {
        interval: 15000
        repeat: true
        running: !root.previewMode
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    Component.onCompleted: {
        if (!root.previewMode) {
            uptimeFile.reload()
            bootProc.running = true
        }
    }

    function formatUptime(totalSec) {
        var days = Math.floor(totalSec / 86400)
        var hours = Math.floor((totalSec % 86400) / 3600)
        var minutes = Math.floor((totalSec % 3600) / 60)
        if (days > 0)
            return days + "д " + hours + "г " + minutes + "хв"
        if (hours > 0)
            return hours + "г " + minutes + "хв"
        return minutes + "хв"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰔛"
                color: Theme.accentTeal
                font.family: Theme.fontMono
                font.pixelSize: 24
            }
            Text {
                text: "АПТАЙМ"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 4 }

        Text {
            Layout.fillWidth: true
            text: root.formatUptime(root.uptimeSeconds)
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Math.max(22, Math.min(42, root.height * 0.22))
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.glassBorder
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 6

            Text { text: "Запуск:"; color: Theme.textMuted; font.pixelSize: 11 }
            Text {
                text: root.bootTime || "—"
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text { text: "Зараз:"; color: Theme.textMuted; font.pixelSize: 11 }
            Text {
                text: Qt.formatDateTime(clock.date, "dd.MM.yyyy HH:mm")
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }
    }
}
