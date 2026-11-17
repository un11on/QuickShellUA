import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: control

    property string tone: "normal" // normal | accent | danger
    property int controlHeight: 36

    implicitHeight: controlHeight
    implicitWidth: Math.max(72, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: 14
    rightPadding: 14
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true

    scale: down ? 0.97 : 1
    opacity: enabled ? 1 : 0.46

    contentItem: Text {
        text: control.text
        color: !control.enabled ? Theme.textMuted
             : control.tone === "accent" ? Theme.accent
             : control.tone === "danger" && control.hovered ? Theme.text
             : (control.hovered || control.activeFocus ? Theme.text : Theme.textSub)
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.bold: control.tone === "accent"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: {
            if (control.tone === "accent")
                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                               control.down ? 0.28 : control.hovered ? 0.22 : 0.14)
            if (control.tone === "danger")
                return control.down || control.hovered
                        ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.30)
                        : Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.13)
            return control.down ? Theme.glassCardActive
                 : control.hovered ? Theme.glassCardHover
                 : Theme.glassCard
        }
        border.width: control.activeFocus ? 2 : 1
        border.color: control.tone === "accent" ? Theme.accent
                    : control.tone === "danger" ? Theme.accentRed
                    : control.activeFocus ? Theme.glassBorderFocus
                    : control.hovered ? Theme.glassBorderHover
                    : Theme.glassBorder
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
}
