import QtQuick
import "."
import ".."

Item {
    id: root

    required property var targetScreen
    property bool active: false
    property int gridSize: WidgetManager.gridSize

    visible: active

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.35
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
            ctx.lineWidth = 1
            for (var x = root.gridSize; x < width; x += root.gridSize) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = root.gridSize; y < height; y += root.gridSize) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WidgetManager.selectedInstanceId = ""
    }

    Rectangle {
        z: 1000
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        width: controls.implicitWidth + 24
        height: 46
        radius: Theme.radiusLg
        color: Theme.glassPopupSolid
        border.color: Theme.glassBorderFocus

        Row {
            id: controls
            anchors.centerIn: parent
            spacing: 8

            WidgetButton {
                text: "Скинути розташування"
                onClicked: WidgetManager.resetLayout(root.targetScreen)
            }
            WidgetButton {
                text: "Готово"
                tone: "accent"
                onClicked: WidgetManager.endEdit()
            }
        }
    }
}
