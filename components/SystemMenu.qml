import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

PopupWindow {
    id: root

    implicitWidth: 320
    implicitHeight: 290
    visible: false
    grabFocus: true
    color: "transparent"

    // --- Громкость ---
    property var audioNode: Pipewire.defaultAudioSink
    property real currentVolume: audioNode && audioNode.audio ? audioNode.audio.volume : 0.0
    property bool isMuted: audioNode && audioNode.audio ? audioNode.audio.muted : false

    // Без трекера свойства audio у узла не работают
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // --- Нагрузка ---
    property real cpuUsage: 0
    property real ramUsage: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real prevIdle: 0
    property real prevTotal: 0

    function parseStats(text) {
        var lines = text.split("\n");
        var memTotal = 0, memAvail = 0;

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (l.startsWith("cpu ")) {
                var p = l.trim().split(/\s+/).slice(1, 9).map(Number);
                var idle = p[3] + p[4];
                var total = p.reduce(function(a, b) { return a + b; }, 0);
                var dTotal = total - prevTotal;
                var dIdle = idle - prevIdle;
                if (prevTotal > 0 && dTotal > 0)
                    cpuUsage = 1 - dIdle / dTotal;
                prevTotal = total;
                prevIdle = idle;
            } else if (l.startsWith("MemTotal:")) {
                memTotal = parseInt(l.split(/\s+/)[1]);
            } else if (l.startsWith("MemAvailable:")) {
                memAvail = parseInt(l.split(/\s+/)[1]);
            }
        }

        if (memTotal > 0) {
            ramTotalGb = memTotal / 1048576;
            ramUsedGb = (memTotal - memAvail) / 1048576;
            ramUsage = (memTotal - memAvail) / memTotal;
        }
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStats(text)
        }
    }

    // Опрашиваем только пока окно открыто
    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // Строка с прогресс-баром
    component StatRow: ColumnLayout {
        id: row
        property string label
        property string valueText
        property real fraction
        property color barColor: "#89b4fa"

        Layout.fillWidth: true
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: row.label
                color: "#cdd6f4"
                font.bold: true
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Text {
                text: row.valueText
                color: "#a6adc8"
                font.pixelSize: 12
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: "#313244"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, row.fraction))
                height: parent.height
                radius: 3
                color: row.barColor
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#181825"
        border.color: "#45475a"
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ---------- Громкость ----------
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.isMuted ? "󰖁" : (root.currentVolume > 0.5 ? "󰕾" : (root.currentVolume > 0 ? "󰖀" : "󰕿"))
                    color: root.isMuted ? "#f38ba8" : "#89b4fa"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                }
                Text {
                    text: "System Volume"
                    color: "#cdd6f4"
                    font.bold: true
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(root.currentVolume * 100) + "%"
                    color: "#a6adc8"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    id: muteBtn
                    implicitWidth: 36
                    implicitHeight: 36
                    contentItem: Text {
                        text: root.isMuted ? "󰝟" : "󰕾"
                        color: root.isMuted ? "#1e1e2e" : "#cdd6f4"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 8
                        color: root.isMuted ? "#f38ba8" : (muteBtn.hovered ? "#45475a" : "#313244")
                    }
                    onClicked: {
                        if (root.audioNode && root.audioNode.audio)
                            root.audioNode.audio.muted = !root.audioNode.audio.muted
                    }
                }

                Slider {
                    id: volSlider
                    Layout.fillWidth: true
                    from: 0.0
                    to: 1.0

                    // Binding не ломается после перетаскивания
                    Binding {
                        target: volSlider
                        property: "value"
                        value: root.currentVolume
                        when: !volSlider.pressed
                    }

                    onMoved: {
                        if (root.audioNode && root.audioNode.audio)
                            root.audioNode.audio.volume = value
                    }

                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: volSlider.availableWidth
                        height: 6
                        radius: 3
                        color: "#313244"

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#89b4fa"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: volSlider.pressed ? "#b4befe" : "#cdd6f4"
                        border.color: "#89b4fa"
                        border.width: 2
                    }
                }
            }

            // Разделитель
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ---------- Нагрузка ----------
            Text {
                text: "SYSTEM LOAD"
                color: "#a6adc8"
                font.pixelSize: 11
                font.bold: true
            }

            StatRow {
                label: "CPU"
                valueText: Math.round(root.cpuUsage * 100) + "%"
                fraction: root.cpuUsage
                barColor: root.cpuUsage > 0.85 ? "#f38ba8" : (root.cpuUsage > 0.6 ? "#f9e2af" : "#a6e3a1")
            }

            StatRow {
                label: "RAM"
                valueText: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                fraction: root.ramUsage
                barColor: root.ramUsage > 0.85 ? "#f38ba8" : (root.ramUsage > 0.6 ? "#f9e2af" : "#89b4fa")
            }

            Item { Layout.fillHeight: true }
        }
    }
}