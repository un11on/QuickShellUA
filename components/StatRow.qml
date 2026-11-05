import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label
    property string valueText
    property real fraction
    property color barColor: "#89b4fa"

    Layout.fillWidth: true
    spacing: 5

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.label
            color: "#cdd6f4"
            font.bold: true
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Text {
            text: root.valueText
            color: "#a6adc8"
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: "#313244"

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.fraction))
            height: parent.height
            radius: 3
            color: root.barColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }
}