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
    readonly property real vol: barWindow ? barWindow.vol : 0.0
    readonly property bool muted: barWindow ? barWindow.muted : false

    readonly property string volIcon: muted ? "󰖁"
        : (vol > 0.5 ? "󰕾"
        : (vol > 0 ? "󰖀" : "󰕿"))

    implicitHeight: h
    implicitWidth: modDisplay === "icon" ? h : (volRow.implicitWidth + 14)

    Rectangle {
        id: volBtnCard
        anchors.fill: parent
        radius: height / 2
        color: volMa.containsMouse ? Theme.glassBgHover : "transparent"
        border.color: volMa.containsMouse ? Theme.glassBorderHover : "transparent"
        border.width: 1
        clip: true

        scale: volMa.pressed ? 0.90 : (volMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: volRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: root.modDisplay !== "text"
                text: root.volIcon
                color: root.muted ? Theme.accentRed : Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(root.h * 0.53))
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.muted ? "Mute" : (Math.round(root.vol * 100) + "%")
                color: root.muted ? Theme.accentRed : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: volMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (barWindow && barWindow.sink && barWindow.sink.audio)
                    barWindow.sink.audio.muted = !barWindow.sink.audio.muted
            }

            onWheel: (wheel) => {
                if (barWindow && barWindow.sink && barWindow.sink.audio) {
                    var delta = wheel.angleDelta.y
                    var v = root.vol + (delta > 0 ? 0.05 : -0.05)
                    barWindow.sink.audio.volume = Math.max(0, Math.min(1, v))
                }
            }
        }
    }
}
