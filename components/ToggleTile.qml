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
    radius: 14
    color: active ? "#89b4fa" : (ma.containsMouse ? "#45475a" : "#313244")

    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        Text {
            text: root.icon
            color: root.active ? "#1e1e2e" : "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.title
                color: root.active ? "#1e1e2e" : "#cdd6f4"
                font.bold: true
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: root.subtitle
                color: root.active ? "#313244" : "#a6adc8"
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
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