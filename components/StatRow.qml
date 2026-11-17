import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label
    property string valueText
    property real fraction
    property color barColor: Theme.accent

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.label
            color: Theme.text
            font.bold: true
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Text {
            text: root.valueText
            color: Theme.textSub
            font.pixelSize: 12
            font.bold: true
            font.family: Theme.fontMono
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 7
        radius: height / 2
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        Rectangle {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.fraction)))
            height: parent.height
            radius: height / 2
            color: root.barColor

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }
        }
    }
}
