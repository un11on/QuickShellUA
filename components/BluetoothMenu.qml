import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

PopupWindow {
    id: root

    implicitWidth: 370
    implicitHeight: 440

    visible: false
    grabFocus: true
    color: "transparent"

    onVisibleChanged: {
        if (!visible && Bluetooth.defaultAdapter
                && Bluetooth.defaultAdapter.discovering) {
            Bluetooth.defaultAdapter.discovering = false
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

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Bluetooth"
                        color: "#cdd6f4"
                        font.pixelSize: 21
                        font.bold: true
                    }

                    Text {
                        text: Bluetooth.defaultAdapter?.enabled
                              ? "Manage your devices"
                              : "Bluetooth is disabled"
                        color: "#a6adc8"
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "ᛒ"
                    color: "#89b4fa"
                    font.pixelSize: 32
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 76
                radius: 12
                color: "#313244"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    ColumnLayout {
                        spacing: 3

                        Text {
                            text: "Bluetooth adapter"
                            color: "#cdd6f4"
                            font.bold: true
                            font.pixelSize: 13
                        }

                        Text {
                            text: Bluetooth.defaultAdapter?.enabled
                                  ? "On · Ready to connect"
                                  : "Off · Disabled"
                            color: "#a6adc8"
                            font.pixelSize: 11
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        implicitWidth: 76
                        implicitHeight: 34

                        contentItem: Text {
                            text: Bluetooth.defaultAdapter?.enabled ? "ON" : "OFF"
                            color: "#1e1e2e"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 8
                            color: Bluetooth.defaultAdapter?.enabled ? "#89b4fa" : "#6c7086"
                        }

                        onClicked: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled =
                                    !Bluetooth.defaultAdapter.enabled
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "YOUR DEVICES"
                    color: "#a6adc8"
                    font.pixelSize: 11
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    implicitWidth: 90
                    implicitHeight: 29
                    enabled: Bluetooth.defaultAdapter?.enabled ?? false

                    contentItem: Text {
                        text: Bluetooth.defaultAdapter?.discovering ? "■ Stop" : "↻ Scan"
                        color: "#89b4fa"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 7
                        color: "#313244"
                    }

                    onClicked: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.discovering =
                                !Bluetooth.defaultAdapter.discovering
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Bluetooth.defaultAdapter
                               ? Bluetooth.defaultAdapter.devices : []

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 66
                            radius: 10
                            color: deviceMouse.containsMouse ? "#45475a" : "#313244"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: "ᛒ"
                                    color: modelData.connected ? "#a6e3a1" : "#89b4fa"
                                    font.pixelSize: 23
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: modelData.name
                                        color: "#cdd6f4"
                                        font.bold: true
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.connected
                                              ? "● Connected"
                                              : modelData.pairing
                                                ? "Pairing..."
                                                : modelData.paired
                                                  ? "Paired"
                                                  : "Not paired"
                                        color: modelData.connected ? "#a6e3a1" : "#a6adc8"
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    visible: modelData.batteryAvailable
                                    text: Math.round(modelData.battery * 100) + "%"
                                    color: "#a6e3a1"
                                    font.pixelSize: 11
                                }

                                Button {
                                    implicitWidth: 82
                                    implicitHeight: 30
                                    enabled: !modelData.pairing

                                    contentItem: Text {
                                        text: modelData.connected
                                              ? "Disconnect"
                                              : modelData.paired ? "Connect" : "Pair"
                                        color: "#1e1e2e"
                                        font.bold: true
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: 7
                                        color: "#89b4fa"
                                    }

                                    onClicked: {
                                        if (!modelData.paired)
                                            modelData.pair()
                                        else if (modelData.connected)
                                            modelData.disconnect()
                                        else
                                            modelData.connect()
                                    }
                                }
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Powered by BlueZ · Quickshell"
                color: "#585b70"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}