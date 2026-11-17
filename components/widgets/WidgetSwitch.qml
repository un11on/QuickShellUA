import QtQuick
import QtQuick.Controls
import ".."

Switch {
    id: control

    implicitWidth: indicator.implicitWidth + (text.length > 0 ? contentItem.implicitWidth + spacing : 0)
    implicitHeight: 28
    spacing: 8
    hoverEnabled: true
    opacity: enabled ? 1 : 0.46

    indicator: Rectangle {
        id: indicator
        implicitWidth: 46
        implicitHeight: 25
        x: control.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: control.checked
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                         control.down ? 0.68 : 0.52)
               : (control.hovered ? Theme.glassCardHover : Theme.bgSurface)
        border.width: control.activeFocus ? 2 : 1
        border.color: control.checked ? Theme.accent
                    : control.activeFocus ? Theme.glassBorderFocus
                    : control.hovered ? Theme.glassBorderHover : Theme.glassBorder

        Rectangle {
            width: 19
            height: 19
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            radius: width / 2
            color: control.checked ? Theme.textDark : Theme.textSub
            border.color: control.checked ? Theme.accentHover : Theme.glassBorder
            border.width: 1
            Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? Theme.textSub : Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
    }

    background: Item { }
}
