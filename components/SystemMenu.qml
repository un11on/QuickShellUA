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

    // --- Гучність ---
    property var audioNode: Pipewire.defaultAudioSink
    property real currentVolume: audioNode && audioNode.audio ? audioNode.audio.volume : 0.0
    property bool isMuted: audioNode && audioNode.audio ? audioNode.audio.muted : false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // --- Навантаження ---
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

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        transform: Translate {
            y: root.visible ? 0 : -10
            Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ---------- Гучність ----------
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.isMuted ? "󰖁" : (root.currentVolume > 0.5 ? "󰕾" : (root.currentVolume > 0 ? "󰖀" : "󰕿"))
                    color: root.isMuted ? Theme.accentRed : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 22

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    text: "System Volume"
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(root.currentVolume * 100) + "%"
                    color: Theme.textSub
                    font.pixelSize: 13
                    font.bold: true
                    font.family: Theme.fontMono
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    id: muteBtn
                    implicitWidth: 36
                    implicitHeight: 36

                    scale: muteBtn.pressed ? 0.9 : (muteBtn.hovered ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }

                    contentItem: Text {
                        text: root.isMuted ? "󰝟" : "󰕾"
                        color: root.isMuted ? Theme.textDark : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: Theme.radiusSm
                        color: root.isMuted ? Theme.accentRed : (muteBtn.hovered ? Theme.glassCardHover : Theme.glassCard)
                        border.color: root.isMuted ? Theme.accentRed : Theme.glassBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
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
                        color: Theme.glassCard
                        border.color: Theme.glassBorder
                        border.width: 1

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            color: Theme.accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: volSlider.pressed ? 18 : 14
                        implicitHeight: volSlider.pressed ? 18 : 14
                        radius: height / 2
                        color: volSlider.pressed ? Theme.accentHover : Theme.text
                        border.color: Theme.accent
                        border.width: 2

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.glassBorder
            }

            // ---------- Навантаження ----------
            Text {
                text: "SYSTEM LOAD"
                color: Theme.textSub
                font.pixelSize: 11
                font.bold: true
            }

            StatRow {
                label: "CPU"
                valueText: Math.round(root.cpuUsage * 100) + "%"
                fraction: root.cpuUsage
                barColor: root.cpuUsage > 0.85 ? Theme.accentRed : (root.cpuUsage > 0.6 ? Theme.accentYellow : Theme.accentGreen)
            }

            StatRow {
                label: "RAM"
                valueText: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                fraction: root.ramUsage
                barColor: root.ramUsage > 0.85 ? Theme.accentRed : (root.ramUsage > 0.6 ? Theme.accentYellow : Theme.accent)
            }

            Item { Layout.fillHeight: true }
        }
    }
}
