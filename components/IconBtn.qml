import QtQuick

Rectangle {
    id: root

    property string icon
    property color iconColor: Theme.text
    property int iconSize: 17

    signal clicked()
    signal scrolled(real delta)

    implicitWidth: 32
    implicitHeight: 32
    radius: height / 2
    clip: true

    color: ma.containsMouse ? Theme.glassBgHover : "transparent"
    border.color: ma.containsMouse ? Theme.glassBorderHover : "transparent"
    border.width: 1

    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.08 : 1.0)

    Behavior on color {
        ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font.family: Theme.fontMono
        font.pixelSize: root.iconSize

        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: (wheel) => root.scrolled(wheel.angleDelta.y)
    }
}
