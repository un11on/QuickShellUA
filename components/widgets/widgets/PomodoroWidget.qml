import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    readonly property int workMinutes: Number(settings.workMinutes) || 25
    readonly property int breakMinutes: Number(settings.breakMinutes) || 5
    readonly property int longBreakMinutes: Number(settings.longBreakMinutes) || 15
    readonly property int sessionsBeforeLong: Number(settings.sessionsBeforeLong) || 4

    property bool isRunning: false
    property bool isBreak: false
    property int completedSessions: 0
    property int remainingSeconds: workMinutes * 60
    property int totalSeconds: workMinutes * 60

    onWorkMinutesChanged: if (!isRunning && !isBreak) { remainingSeconds = workMinutes * 60; totalSeconds = workMinutes * 60 }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds--
            } else {
                root.isRunning = false
                if (root.isBreak) {
                    root.isBreak = false
                    root.totalSeconds = root.workMinutes * 60
                    root.remainingSeconds = root.totalSeconds
                } else {
                    root.completedSessions++
                    root.isBreak = true
                    var isLong = (root.completedSessions % root.sessionsBeforeLong === 0)
                    root.totalSeconds = (isLong ? root.longBreakMinutes : root.breakMinutes) * 60
                    root.remainingSeconds = root.totalSeconds
                }
            }
        }
    }

    function startPause() {
        root.isRunning = !root.isRunning
    }

    function resetTimer() {
        root.isRunning = false
        root.isBreak = false
        root.totalSeconds = root.workMinutes * 60
        root.remainingSeconds = root.totalSeconds
    }

    function skipPhase() {
        root.remainingSeconds = 0
    }

    function formatTime(sec) {
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    readonly property real progress: root.totalSeconds > 0 ? 1 - root.remainingSeconds / root.totalSeconds : 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰔟"
                color: root.isBreak ? Theme.accentGreen : Theme.accentRed
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: root.isBreak ? "ПЕРЕРВА" : "ПОМОДОРО"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: sessionsLabel.implicitWidth + 14
                height: 22
                radius: 11
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                Text {
                    id: sessionsLabel
                    anchors.centerIn: parent
                    text: root.completedSessions + " 🍅"
                    color: Theme.accent
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 2 }

        // Circular progress
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(root.width - 40, root.height * 0.42, 160)
            Layout.preferredHeight: Layout.preferredWidth

            Canvas {
                id: progressCanvas
                anchors.fill: parent
                property real progressValue: root.progress
                property bool isBreakState: root.isBreak

                onProgressValueChanged: requestPaint()
                onIsBreakStateChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var w = width
                    var h = height
                    ctx.clearRect(0, 0, w, h)

                    var cx = w / 2
                    var cy = h / 2
                    var r = Math.min(cx, cy) - 6
                    var lineW = 5

                    // Background circle
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = Qt.rgba(Theme.bgSurface.r, Theme.bgSurface.g, Theme.bgSurface.b, 0.6)
                    ctx.lineWidth = lineW
                    ctx.stroke()

                    // Progress arc
                    if (progressValue > 0) {
                        ctx.beginPath()
                        var startAngle = -Math.PI / 2
                        var endAngle = startAngle + 2 * Math.PI * progressValue
                        ctx.arc(cx, cy, r, startAngle, endAngle)
                        ctx.strokeStyle = isBreakState
                            ? String(Theme.accentGreen)
                            : String(Theme.accentRed)
                        ctx.lineWidth = lineW
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTime(root.remainingSeconds)
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Math.max(18, Math.min(36, progressCanvas.width * 0.24))
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isBreak ? "відпочинок" : "фокус"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 2 }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            WidgetButton {
                text: root.isRunning ? "⏸" : "▶"
                tone: "accent"
                implicitWidth: 48
                onClicked: root.startPause()
            }
            WidgetButton {
                text: "⏭"
                enabled: root.isRunning || root.remainingSeconds < root.totalSeconds
                implicitWidth: 40
                onClicked: root.skipPhase()
            }
            WidgetButton {
                text: "⟲"
                implicitWidth: 40
                onClicked: root.resetTimer()
            }
        }
    }
}
