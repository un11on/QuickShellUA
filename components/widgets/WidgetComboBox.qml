import QtQuick
import QtQuick.Controls
import ".."

ComboBox {
    id: control

    implicitHeight: 36
    implicitWidth: 160
    leftPadding: 12
    rightPadding: 36
    hoverEnabled: true
    opacity: enabled ? 1 : 0.46

    contentItem: Text {
        leftPadding: 0
        rightPadding: 0
        text: control.displayText
        color: control.enabled ? Theme.text : Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅀"
        color: control.popup.visible || control.hovered ? Theme.accent : Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: 14
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.animFast } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.down ? Theme.glassCardActive
             : control.hovered ? Theme.glassCardHover : Theme.glassCard
        border.width: control.activeFocus || control.popup.visible ? 2 : 1
        border.color: control.activeFocus || control.popup.visible ? Theme.glassBorderFocus
                    : control.hovered ? Theme.glassBorderHover : Theme.glassBorder
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    delegate: ItemDelegate {
        id: option
        width: control.popup.width - 8
        implicitHeight: 34
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: modelData
            color: option.highlighted ? Theme.accent : Theme.textSub
            font.family: Theme.fontMono
            font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSm
            color: option.highlighted ? Theme.glassCardHover : "transparent"
        }
    }

    popup: Popup {
        y: control.height + 5
        width: control.width
        implicitHeight: Math.min(250, contentItem.implicitHeight + 8)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.glassPopupSolid
            border.color: Theme.glassBorderHover
            border.width: 1
        }
    }
}
