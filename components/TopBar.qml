import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

PanelWindow {
    id: barWindow

    signal toggleAiRequested()

    screen: Quickshell.screens.find(s => s.name === "HDMI-A-1")

    anchors {
        top: true
        left: true
        right: true
    }

    // Відступи від країв екрана, щоб острови "висіли" в повітрі
    margins {
        top: 6
        left: 10
        right: 10
    }

    implicitHeight: 40
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    // --- Звук ---
    property var sink: Pipewire.defaultAudioSink
    property real vol: sink && sink.audio ? sink.audio.volume : 0.0
    property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker { objects: [barWindow.sink] }

   
    

    // --- Сама панель ---
    Item {
        anchors.fill: parent

        // ЛІВИЙ ОСТРІВ: воркспейси
        Island {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Workspaces {}
        }

        // ЦЕНТРАЛЬНИЙ ОСТРІВ: годинник
        Island {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Button {
                id: clockButton
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: 30

                background: Rectangle {
                    color: clockButton.hovered ? "#313244" : "transparent"
                    radius: 15
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                contentItem: Text {
                    id: clockText
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss  |  ddd, d MMM")
                    }
                }

                onClicked: systemMenu.visible = !systemMenu.visible
            }
        }

        // ПРАВИЙ ОСТРІВ: гучність + bluetooth
        Island {
            id: rightIsland
            anchors.right: aiCircle.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            IconBtn {
                id: volBtn
                icon: barWindow.muted ? "󰖁"
                    : (barWindow.vol > 0.5 ? "󰕾"
                    : (barWindow.vol > 0 ? "󰖀" : "󰕿"))
                iconColor: barWindow.muted ? "#f38ba8" : "#89b4fa"

                onClicked: {
                    if (barWindow.sink && barWindow.sink.audio)
                        barWindow.sink.audio.muted = !barWindow.sink.audio.muted
                }
                onScrolled: delta => {
                    if (barWindow.sink && barWindow.sink.audio) {
                        var v = barWindow.vol + (delta > 0 ? 0.05 : -0.05)
                        barWindow.sink.audio.volume = Math.max(0, Math.min(1, v))
                    }
                }
            }

            IconBtn {
                id: btBtn
                icon: "ᛒ"
                iconSize: 19
                iconColor: Bluetooth.defaultAdapter?.enabled ? "#89b4fa" : "#6c7086"

                onClicked: bluetoothMenu.visible = !bluetoothMenu.visible
            }
        }

        // КРУГЛА КНОПКА AI
        Rectangle {
            id: aiCircle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            color: aiMouse.containsMouse ? "#45475a" : "#1e1e2e"
            border.color: "#313244"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "󰚩"
                color: "#89b4fa"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
            }

            MouseArea {
                id: aiMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: barWindow.toggleAiRequested()
            }
        }

        // --- Випадаючі вікна ---
                DashboardMenu {
            id: systemMenu
            anchor.window: barWindow
            anchor.item: clockButton
            anchor.rect.x: (clockButton.width / 2) - (implicitWidth / 2)
            anchor.rect.y: clockButton.height + 10
        }

        BluetoothMenu {
            id: bluetoothMenu
            anchor.window: barWindow
            anchor.item: btBtn
            anchor.rect.x: btBtn.width - implicitWidth + 10
            anchor.rect.y: btBtn.height + 10
        }
    }
}