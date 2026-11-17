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

    Component.onCompleted: if (!root.previewMode) StorageService.acquire()
    Component.onDestruction: if (!root.previewMode) StorageService.release()

    readonly property var visibleMounts: {
        var all = (StorageService && StorageService.mounts) || []
        var show = settings.showMounts
        if (!show || !Array.isArray(show) || show.length === 0)
            return all
        var result = []
        for (var i = 0; i < all.length; i++) {
            if (show.indexOf(all[i].mountPoint) >= 0)
                result.push(all[i])
        }
        return result.length > 0 ? result : all
    }

    function usageColor(pct) {
        if (pct >= 90) return Theme.accentRed
        if (pct >= 75) return Theme.accentYellow
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
                text: "󰋊"
                color: Theme.accentSecondary
                font.family: Theme.fontMono
                font.pixelSize: 24
            }
            Text {
                text: "ДИСКИ"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                visible: root.visibleMounts.length > 0
                text: root.visibleMounts.length + " розділ" + (root.visibleMounts.length > 1 ? "ів" : "")
                color: Theme.textMuted
                font.pixelSize: 9
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: disksCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: disksCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.visibleMounts
                    delegate: ColumnLayout {
                        id: diskItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: diskItem.modelData.mountPoint
                                color: Theme.text
                                font.pixelSize: 12
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }
                            Text {
                                text: diskItem.modelData.usedPercent + "%"
                                color: root.usageColor(diskItem.modelData.usedPercent)
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 8
                            radius: 4
                            color: Theme.bgSurface

                            Rectangle {
                                width: Math.max(0, Math.min(1, diskItem.modelData.usedPercent / 100)) * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: root.usageColor(diskItem.modelData.usedPercent)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: StorageService.formatBytes(diskItem.modelData.usedBytes) + " / " +
                                      StorageService.formatBytes(diskItem.modelData.totalBytes)
                                color: Theme.textMuted
                                font.pixelSize: 10
                                font.family: Theme.fontMono
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: StorageService.formatBytes(diskItem.modelData.availBytes) + " вільно"
                                color: Theme.textMuted
                                font.pixelSize: 10
                                font.family: Theme.fontMono
                            }
                        }

                        Rectangle {
                            visible: index < root.visibleMounts.length - 1
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            height: 1
                            color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 0.4)
                        }
                    }
                }

                Text {
                    visible: root.visibleMounts.length === 0
                    Layout.fillWidth: true
                    text: StorageService.ready ? "Немає даних про диски" : "Завантаження…"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    padding: 16
                }
            }
        }
    }
}
