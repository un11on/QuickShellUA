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

    readonly property bool animEnabled: settings.animEnabled !== false
    readonly property int barCount: Number(settings.barCount) || 24
    property var levels: []
    property bool cavaAvailable: true

    readonly property string cavaConfigPath: Quickshell.shellDir + "/widget-cava-" + instanceId + ".conf"

    // Generate per-instance cava config
    Component.onCompleted: {
        if (!root.previewMode)
            writeCavaConfig()
    }

    function writeCavaConfig() {
        cavaConfigFile.setText(
            "[general]\n" +
            "bars = " + root.barCount + "\n" +
            "framerate = 30\n" +
            "sensitivity = 140\n\n" +
            "[input]\n" +
            "method = pipewire\n" +
            "source = auto\n\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 100\n" +
            "channels = mono\n"
        )
    }

    FileView {
        id: cavaConfigFile
        path: root.cavaConfigPath
        atomicWrites: true
        printErrors: false
    }

    function applyFrame(line) {
        var parts = String(line).split(";")
        var next = []
        for (var i = 0; i < root.barCount; ++i) {
            var raw = Number(parts[i])
            var v = isNaN(raw) ? 0 : Math.max(0, Math.min(100, raw)) / 100
            next.push(Math.min(1, v * 1.8))
        }
        levels = next
    }

    Process {
        id: cavaProc
        running: root.animEnabled && !root.previewMode
        command: ["cava", "-p", root.cavaConfigPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.applyFrame(data)
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 127 || exitCode === -1) {
                root.cavaAvailable = false
            } else if (root.animEnabled && !root.previewMode) {
                restartTimer.restart()
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.animEnabled && !root.previewMode)
                cavaProc.running = true
        }
    }

    function barColor(level) {
        if (level > 0.8) return Theme.accentRed
        if (level > 0.5) return Theme.accentYellow
        return Theme.accent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰎆"
                color: Theme.accentPink
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: "АУДІО"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                visible: !root.cavaAvailable
                width: noLabel.implicitWidth + 12
                height: 20
                radius: 10
                color: Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.15)
                Text {
                    id: noLabel
                    anchors.centerIn: parent
                    text: "cava ?"
                    color: Theme.accentRed
                    font.pixelSize: 9
                    font.bold: true
                }
            }
            WidgetButton {
                text: root.animEnabled ? "⏸" : "▶"
                implicitWidth: 34
                leftPadding: 0; rightPadding: 0
                onClicked: root.settingChanged("animEnabled", !root.animEnabled)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Visualizer bars
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 4
                spacing: Math.max(1, (parent.width - root.barCount * barWidth) / Math.max(1, root.barCount - 1))

                readonly property real barWidth: Math.max(2, Math.min(8, (parent.width - 20) / root.barCount * 0.7))
                readonly property real maxH: parent.height - 8

                Repeater {
                    model: root.barCount
                    delegate: Item {
                        id: barSlot
                        required property int index
                        width: parent.barWidth
                        height: parent.maxH

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            radius: width / 2

                            readonly property real level:
                                (root.levels && root.levels.length > barSlot.index)
                                    ? root.levels[barSlot.index] : 0

                            height: Math.max(parent.height * 0.04, level * parent.height)
                            color: root.barColor(level)

                            Behavior on height {
                                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            // Not available overlay
            ColumnLayout {
                visible: !root.cavaAvailable
                anchors.centerIn: parent
                spacing: 8
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cava не знайдено"
                    color: Theme.textMuted
                    font.pixelSize: 12
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Встановіть cava для аудіовізуалізації"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }

            // Paused overlay
            Text {
                visible: !root.animEnabled && root.cavaAvailable
                anchors.centerIn: parent
                text: "⏸ Призупинено"
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }
    }
}
