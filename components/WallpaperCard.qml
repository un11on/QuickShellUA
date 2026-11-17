import QtQuick
import "."

Rectangle {
    id: card

    property string path: ""
    property string name: ""
    property bool isCurrent: false
    property bool isSelected: false

    signal activated()

    readonly property bool hovered: cardMa.containsMouse
    readonly property bool failed: thumb.status === Image.Error

    radius: Theme.radiusMd
    color: card.isSelected ? Theme.wpSurfaceActive
         : card.hovered ? Theme.wpSurfaceHover
         : Theme.wpSurface
    border.width: card.isSelected || card.isCurrent ? 2 : 1
    border.color: card.isSelected ? Theme.wpIce
                : card.isCurrent ? Theme.wpIceDim
                : card.hovered ? Theme.wpBorderHover
                : Theme.wpBorder
    clip: true

    scale: card.hovered && !card.isSelected ? 1.015 : 1

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    Image {
        id: thumb
        anchors.fill: parent
        anchors.margins: 3
        source: card.path ? "file://" + card.path : ""
        sourceSize.width: 420
        sourceSize.height: 300
        asynchronous: true
        cache: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
        visible: source !== "" && status !== Image.Error
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.max(1, card.radius - 3)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
    }

    // Затемнення під підписом
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(58, card.height * 0.42)
        radius: card.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.04, 0.07, 0.92) }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 8
        spacing: 1

        Text {
            width: parent.width
            text: card.name
            color: Theme.wpText
            font.family: Theme.fontMono
            font.pixelSize: 10
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            text: card.isCurrent ? "ПОТОЧНІ ОБОЇ" : (card.isSelected ? "ВИБРАНО" : " ")
            color: card.isCurrent ? Theme.wpSuccess
                 : card.isSelected ? Theme.wpIce
                 : "transparent"
            font.family: Theme.fontMono
            font.pixelSize: 8
            font.bold: true
            elide: Text.ElideRight
        }
    }

    // Індикатор поточних обоїв
    Rectangle {
        visible: card.isCurrent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 20
        height: 20
        radius: 10
        color: Qt.rgba(0.37, 0.95, 0.75, 0.18)
        border.width: 1
        border.color: Theme.wpSuccess

        Text {
            anchors.centerIn: parent
            text: "󰄬"
            color: Theme.wpSuccess
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }

    // Маркер вибору
    Rectangle {
        visible: card.isSelected
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 8
        width: 20
        height: 20
        radius: 10
        color: Qt.rgba(0.55, 0.91, 1.0, 0.22)
        border.width: 1
        border.color: Theme.wpIce

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: 4
            color: Theme.wpIce
        }
    }

    // Помилка декодування
    Column {
        visible: card.failed
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰋩"
            color: Theme.wpTextMuted
            font.family: Theme.fontMono
            font.pixelSize: 26
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Немає прев'ю"
            color: Theme.wpTextMuted
            font.pixelSize: 9
        }
    }

    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
