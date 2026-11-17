import QtQuick
import Quickshell
import Quickshell.Io
import "."

// ============================================================================
// CavaBars — тонкий реальний CAVA-візуалізатор для Music Island.
//
// Один Process на весь застосунок: запускається лише коли active == true
// (трек реально відтворюється), зупиняється на паузі та при зникненні плеєра.
// Значення беруться з raw-виводу CAVA, жодної випадкової імітації спектра.
// ============================================================================
Item {
    id: root

    // Чи має зараз працювати CAVA (трек грає і капсула видима).
    property bool active: false
    // Кількість смуг і геометрія — узгоджені з розмірами Music Island.
    property int barCount: 10
    property real barWidth: 2
    property real barGap: 1
    property real maxBarHeight: 16
    property color barColor: Theme.accent
    // Нормалізовані рівні 0..1 з останнього кадру CAVA.
    property var levels: []

    // Легкий підсилювач для компактної висоти смуг (дані лишаються реальними).
    readonly property real gain: 2.0

    implicitWidth: barCount * barWidth + Math.max(0, barCount - 1) * barGap
    implicitHeight: maxBarHeight

    function _applyFrame(line) {
        var parts = String(line).split(";")
        var next = []
        for (var i = 0; i < barCount; ++i) {
            var raw = Number(parts[i])
            var v = isNaN(raw) ? 0 : Math.max(0, Math.min(100, raw)) / 100
            next.push(Math.min(1, v * gain))
        }
        levels = next
    }

    Process {
        id: cavaProc
        running: root.active
        command: ["cava", "-p", Quickshell.shellDir + "/components/music-cava.conf"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root._applyFrame(data)
        }

        // Якщо процес завершився не з нашої волі — один плавний перезапуск.
        onExited: (exitCode, exitStatus) => {
            if (root.active)
                restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 1200
        repeat: false
        onTriggered: if (root.active) cavaProc.running = true
    }

    Row {
        anchors.centerIn: parent
        spacing: root.barGap

        Repeater {
            model: root.barCount

            delegate: Item {
                id: barSlot
                required property int index

                width: root.barWidth
                height: root.maxBarHeight

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    radius: width / 2
                    color: root.barColor

                    readonly property real level:
                        (root.levels && root.levels.length > barSlot.index)
                            ? root.levels[barSlot.index] : 0

                    height: Math.max(root.maxBarHeight * 0.10, level * root.maxBarHeight)

                    Behavior on height {
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }
                }
            }
        }
    }
}
