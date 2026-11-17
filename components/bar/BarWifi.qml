import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "icon"

    readonly property int h: barWindow ? barWindow.btnSize : 28
    readonly property var menu: barWindow && barWindow.wifiMenu ? barWindow.wifiMenu : null
    readonly property bool isConnected: menu ? menu.connected : false
    readonly property string barIcon: menu ? menu.barIcon : "󰤨"

    implicitHeight: h
    implicitWidth: modDisplay === "icon" ? h : (wifiRow.implicitWidth + 14)

    Rectangle {
        id: wifiBtnCard
        anchors.fill: parent
        radius: height / 2
        color: wifiMa.containsMouse ? Theme.glassBgHover : "transparent"
        border.color: wifiMa.containsMouse ? Theme.glassBorderHover : "transparent"
        border.width: 1
        clip: true

        scale: wifiMa.pressed ? 0.90 : (wifiMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: wifiRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: root.modDisplay !== "text"
                text: root.barIcon
                color: root.isConnected ? Theme.accent : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(root.h * 0.53))
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.isConnected ? "Wi-Fi" : "Offline"
                color: root.isConnected ? Theme.text : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: wifiMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (barWindow) {
                    if (barWindow.bluetoothMenu && !barWindow.wifiMenu.visible)
                        barWindow.bluetoothMenu.visible = false
                    if (barWindow.wifiMenu)
                        barWindow.wifiMenu.visible = !barWindow.wifiMenu.visible
                }
            }
        }
    }

    onBarWindowChanged: {
        if (barWindow)
            barWindow.wifiAnchorItem = root
    }

    Component.onCompleted: {
        if (barWindow)
            barWindow.wifiAnchorItem = root
    }
}
