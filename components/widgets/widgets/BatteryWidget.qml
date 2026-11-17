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

    Component.onCompleted: if (!root.previewMode) BatteryService.acquire()
    Component.onDestruction: if (!root.previewMode) BatteryService.release()

    function batteryIcon(pct, charging) {
        if (charging) return "󰂄"
        if (pct >= 90) return "󰁹"
        if (pct >= 70) return "󰂁"
        if (pct >= 50) return "󰁿"
        if (pct >= 30) return "󰁽"
        if (pct >= 10) return "󰁻"
        return "󰂃"
    }

    function statusText(status) {
        if (status === "Charging") return "Заряджається"
        if (status === "Discharging") return "Розряджається"
        if (status === "Full") return "Повний заряд"
        if (status === "Not charging") return "Не заряджається"
        return status || "Невідомо"
    }

    function batteryColor(pct, charging) {
        if (charging) return Theme.accentGreen
        if (pct <= 15) return Theme.accentRed
        if (pct <= 30) return Theme.accentYellow
        return Theme.accentGreen
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: BatteryService.hasBattery
                    ? root.batteryIcon(BatteryService.percentage, BatteryService.status === "Charging")
                    : "󰚥"
                color: BatteryService.hasBattery
                    ? root.batteryColor(BatteryService.percentage, BatteryService.status === "Charging")
                    : Theme.accentSapphire
                font.family: Theme.fontMono
                font.pixelSize: 28
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: BatteryService.hasBattery ? "БАТАРЕЯ" : "ЖИВЛЕННЯ"
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: BatteryService.hasBattery
                        ? root.statusText(BatteryService.status)
                        : "Мережеве живлення"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }

        // Battery percentage (if available)
        ColumnLayout {
            visible: BatteryService.hasBattery
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: BatteryService.percentage + "%"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Math.max(28, Math.min(52, root.height * 0.25))
                font.bold: true
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: Theme.bgSurface

                Rectangle {
                    width: Math.max(0, Math.min(1, BatteryService.percentage / 100)) * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: root.batteryColor(BatteryService.percentage, BatteryService.status === "Charging")

                    Behavior on width {
                        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                    }
                }
            }
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
            rowSpacing: 5

            // Power
            Text {
                visible: BatteryService.hasBattery && BatteryService.powerWatts > 0
                text: "Потужність:"; color: Theme.textMuted; font.pixelSize: 11
            }
            Text {
                visible: BatteryService.hasBattery && BatteryService.powerWatts > 0
                text: BatteryService.powerWatts.toFixed(1) + " W"
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            // Time remaining
            Text {
                visible: BatteryService.hasBattery && BatteryService.timeRemaining.length > 0
                text: BatteryService.status === "Charging" ? "До повного:" : "Залишилось:"
                color: Theme.textMuted; font.pixelSize: 11
            }
            Text {
                visible: BatteryService.hasBattery && BatteryService.timeRemaining.length > 0
                text: BatteryService.timeRemaining
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            // AC
            Text { text: "Мережа:"; color: Theme.textMuted; font.pixelSize: 11 }
            Text {
                text: BatteryService.acOnline ? "підключено" : "відключено"
                color: BatteryService.acOnline ? Theme.accentGreen : Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
            }
        }

        // No battery message
        ColumnLayout {
            visible: !BatteryService.hasBattery
            Layout.fillWidth: true
            spacing: 6

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰚥"
                color: Theme.accentSapphire
                font.family: Theme.fontMono
                font.pixelSize: 48
            }
            Text {
                Layout.fillWidth: true
                text: "Живлення від мережі"
                color: Theme.textSub
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Item { Layout.fillHeight: true }
    }
}
