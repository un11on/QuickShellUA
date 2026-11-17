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

    Component.onCompleted: if (!root.previewMode) NetworkService.acquire()
    Component.onDestruction: if (!root.previewMode) NetworkService.release()

    function speedIcon(bytesPerSec) {
        if (bytesPerSec > 1048576) return "󰓅" // fast
        if (bytesPerSec > 1024) return "󰾆"    // medium
        return "󰾆"
    }

    function connectionIcon(type) {
        if (type === "wifi") return "󰤨"
        if (type === "vpn") return "󰦝"
        if (type === "ethernet") return "󰈀"
        if (type === "disconnected") return "󰤭"
        return "󰛳"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: connectionIcon(NetworkService.connectionType)
                color: NetworkService.connectionType === "disconnected" ? Theme.textMuted : Theme.accentSapphire
                font.family: Theme.fontMono
                font.pixelSize: 24
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "МЕРЕЖА"
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: NetworkService.activeInterface || "немає"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
            Rectangle {
                visible: NetworkService.vpnActive
                width: vpnLabel.implicitWidth + 12
                height: 20
                radius: 10
                color: Qt.rgba(Theme.accentGreen.r, Theme.accentGreen.g, Theme.accentGreen.b, 0.15)
                Text {
                    id: vpnLabel
                    anchors.centerIn: parent
                    text: "VPN"
                    color: Theme.accentGreen
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.glassBorder
        }

        // Download speed
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "↓"
                color: Theme.accentGreen
                font.pixelSize: 18
                font.bold: true
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Завантаження"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
                Text {
                    text: NetworkService.formatSpeed(NetworkService.downloadSpeed)
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    font.bold: true
                }
            }
        }

        // Upload speed
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "↑"
                color: Theme.accentPeach
                font.pixelSize: 18
                font.bold: true
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Відвантаження"
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
                Text {
                    text: NetworkService.formatSpeed(NetworkService.uploadSpeed)
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.glassBorder
        }

        // IP Address
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "IP:"; color: Theme.textMuted; font.pixelSize: 11 }
            Text {
                text: NetworkService.ipAddress || "—"
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }
    }
}
