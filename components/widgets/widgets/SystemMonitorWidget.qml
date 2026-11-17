import QtQuick
import QtQuick.Layouts
import ".."
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    signal settingChanged(string key, var value)

    Component.onCompleted: if (!root.previewMode) SystemMetricsService.acquire()
    Component.onDestruction: if (!root.previewMode) SystemMetricsService.release()

    component MetricRow: RowLayout {
        id: metric
        property string label: ""
        property real fraction: 0
        property string valueText: ""
        property color barColor: Theme.accent

        Layout.fillWidth: true
        spacing: 8
        Text { text: parent.label; color: Theme.textSub; Layout.preferredWidth: 42; font.bold: true }
        Rectangle {
            Layout.fillWidth: true
            height: 9
            radius: 4.5
            color: Theme.bgSurface
            Rectangle {
                width: Math.max(0, Math.min(1, metric.fraction)) * parent.width
                height: parent.height
                radius: parent.radius
                color: metric.barColor
            }
        }
        Text {
            text: parent.valueText
            color: Theme.text
            font.family: Theme.fontMono
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 70
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰍛"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 24 }
            Text { text: "СИСТЕМА"; color: Theme.text; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
        }

        MetricRow {
            visible: root.settings.showCpu !== false
            label: "CPU"
            fraction: SystemMetricsService.cpuUsage
            valueText: Math.round(SystemMetricsService.cpuUsage * 100) + "%"
            barColor: fraction > 0.85 ? Theme.accentRed : Theme.accent
        }

        MetricRow {
            visible: root.settings.showRam !== false
            label: "RAM"
            fraction: SystemMetricsService.ramUsage
            valueText: SystemMetricsService.ramUsedGiB.toFixed(1) + "G"
            barColor: fraction > 0.85 ? Theme.accentRed : Theme.accentGreen
        }

        MetricRow {
            visible: root.settings.showGpu !== false
            label: "GPU"
            fraction: SystemMetricsService.gpuAvailable ? SystemMetricsService.gpuUsage : 0
            valueText: SystemMetricsService.gpuAvailable
                       ? Math.round(SystemMetricsService.gpuUsage * 100) + "%" : "N/A"
            barColor: Theme.accentSecondary
        }

        Text {
            visible: root.settings.showGpu !== false && !SystemMetricsService.gpuAvailable
            Layout.fillWidth: true
            text: SystemMetricsService.gpuError
            color: Theme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.fillHeight: true }
    }
}
