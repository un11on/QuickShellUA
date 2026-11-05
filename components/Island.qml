import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    default property alias content: islandRow.data

    implicitWidth: islandRow.implicitWidth + 20
    implicitHeight: 40
    radius: height / 2
    color: "#1e1e2e"
    border.color: "#313244"
    border.width: 1

    RowLayout {
        id: islandRow
        anchors.centerIn: parent
        spacing: 6
    }
}