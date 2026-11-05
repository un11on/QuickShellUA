import QtQuick

Rectangle {
    id: root

    property string icon
    property color iconColor: "#cdd6f4"
    property int iconSize: 17

    signal clicked()
    signal scrolled(real delta)

    implicitWidth: 30
    implicitHeight: 30
    radius: 15
    color: ma.containsMouse ? "#45475a" : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.iconSize
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