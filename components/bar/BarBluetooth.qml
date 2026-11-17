import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell.Bluetooth
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "icon"

    readonly property int h: barWindow ? barWindow.btnSize : 28

    property var adapter: Bluetooth.defaultAdapter
    property bool isBtOn: adapter ? adapter.enabled : false
    property bool hasConnected: {
        if (!adapter || !adapter.devices || !adapter.devices.values) return false
        for (var i = 0; i < adapter.devices.values.length; i++) {
            if (adapter.devices.values[i].connected) return true
        }
        return false
    }

    implicitHeight: h
    implicitWidth: modDisplay === "icon" ? h : (btRow.implicitWidth + 14)

    Rectangle {
        id: btBtnCard
        anchors.fill: parent
        radius: height / 2
        color: btMa.containsMouse ? Theme.glassBgHover : "transparent"
        border.color: btMa.containsMouse ? Theme.glassBorderHover : "transparent"
        border.width: 1
        clip: true

        scale: btMa.pressed ? 0.90 : (btMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: btRow
            anchors.centerIn: parent
            spacing: 5

            Item {
                visible: root.modDisplay !== "text"
                width: Math.max(12, Math.round(root.h * 0.56))
                height: width
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰂯"
                    color: root.isBtOn ? Theme.accent : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: parent.width
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Rectangle {
                    visible: root.hasConnected
                    width: 6
                    height: 6
                    radius: 3
                    anchors.top: parent.top
                    anchors.right: parent.right
                    color: Theme.accentGreen
                    border.color: Theme.bgCrust
                    border.width: 1

                    SequentialAnimation on opacity {
                        running: root.hasConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 900 }
                        NumberAnimation { to: 1.0; duration: 900 }
                    }
                }
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.hasConnected ? "BT On" : (root.isBtOn ? "BT" : "BT Off")
                color: root.isBtOn ? Theme.text : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: btMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (barWindow) {
                    if (barWindow.wifiMenu && !barWindow.bluetoothMenu.visible)
                        barWindow.wifiMenu.visible = false
                    if (barWindow.bluetoothMenu)
                        barWindow.bluetoothMenu.visible = !barWindow.bluetoothMenu.visible
                }
            }
        }
    }

    onBarWindowChanged: {
        if (barWindow)
            barWindow.btAnchorItem = root
    }

    Component.onCompleted: {
        if (barWindow)
            barWindow.btAnchorItem = root
    }
}
