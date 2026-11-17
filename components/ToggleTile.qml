import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool active: false

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 54
    radius: Theme.radiusMd

    color: active ? Theme.accent : (ma.containsMouse ? Theme.glassCardHover : Theme.glassCard)
    border.color: active ? Theme.accentSecondary : (ma.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
    border.width: 1

    scale: ma.pressed ? 0.96 : (ma.containsMouse ? 1.02 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 10

        Text {
            text: root.icon
            color: root.active ? Theme.textDark : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 20

            scale: root.active ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingSpring } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.title
                color: root.active ? Theme.textDark : Theme.text
                font.bold: true
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            Text {
                text: root.subtitle
                color: root.active ? Qt.rgba(0.1, 0.1, 0.15, 0.8) : Theme.textSub
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
