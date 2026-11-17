import QtQuick
import QtQuick.Layouts

// Плитка швидкого налаштування: іконка в контейнері + два рівні тексту.
// Ввімк/вимк стан однозначно розрізняється: акцентний тінт + акцентна рамка і іконка.
Rectangle {
    id: tile

    property string icon
    property string title
    property string subtitle
    property bool active: false

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 66
    radius: Theme.radiusLg

    color: tile.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15 * Theme.glassOpacity)
         : (tileMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
    border.color: tile.active ? Theme.glassBorderFocus
         : (tileMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
    border.width: 1
    scale: tileMa.pressed ? 0.97 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 12

            color: tile.active ? Theme.accent : Theme.bgSurface
            border.color: tile.active ? Theme.accentHover : Theme.glassBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Theme.textDark : (tileMa.containsMouse ? Theme.text : Theme.textSub)
                font.family: Theme.fontMono
                font.pixelSize: 17

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: tile.title
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: tile.subtitle
                color: tile.active ? Theme.accent : Theme.textMuted
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }
    }

    MouseArea {
        id: tileMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
