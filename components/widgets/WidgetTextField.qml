import QtQuick
import QtQuick.Controls
import ".."

TextField {
    id: control

    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accent
    selectedTextColor: Theme.textDark
    font.family: Theme.fontMono
    font.pixelSize: 11
    selectByMouse: true
    opacity: enabled ? 1 : 0.46

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.activeFocus ? Theme.glassCardActive
             : control.hovered ? Theme.glassCardHover : Theme.glassCard
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.glassBorderFocus
                    : control.hovered ? Theme.glassBorderHover : Theme.glassBorder
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }
}
