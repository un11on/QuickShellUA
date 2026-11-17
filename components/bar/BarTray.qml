import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "icon"

    readonly property int h: barWindow ? barWindow.btnSize : 28
    readonly property int iconSize: modSize === "compact" ? 14 : (modSize === "expanded" ? 20 : 16)
    readonly property int iconItemSize: iconSize + 4

    property bool pinned: false
    property bool _hovered: false
    property int _openMenus: 0
    readonly property bool trayExpanded: pinned || _hovered || _openMenus > 0

    readonly property int itemCount: trayRepeater.count
    readonly property bool hasItems: itemCount > 0

    readonly property real trayRowWidth: itemCount > 0
        ? itemCount * iconItemSize + (itemCount - 1) * 2
        : 0
    readonly property real slotWidth: (trayExpanded && hasItems)
        ? (trayRowWidth + 6)
        : 0

    implicitHeight: h
    implicitWidth: (hasItems ? (arrowBtn.width + slotWidth) : 0)

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                hoverCloseTimer.stop()
                if (PanelController.isHorizontal)
                    root._hovered = true
            } else {
                hoverCloseTimer.restart()
            }
        }
    }

    Timer {
        id: hoverCloseTimer
        interval: Math.max(60, Theme.animFast)
        repeat: false
        onTriggered: root._hovered = false
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Slot for tray icons
        Item {
            id: traySlot
            height: root.h
            clip: true
            width: root.slotWidth
            opacity: root.trayExpanded ? 1 : 0

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            Row {
                id: trayRow
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    id: trayRepeater
                    model: SystemTray.items

                    delegate: Item {
                        id: iconItem
                        required property SystemTrayItem modelData

                        width: root.iconItemSize
                        height: root.iconItemSize

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: iconMouse.containsMouse ? Theme.glassBgHover : "transparent"
                            border.color: iconMouse.containsMouse ? Theme.glassBorderHover : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: root.iconSize
                            source: iconItem.modelData.icon
                            asynchronous: true
                            mipmap: true
                        }

                        Rectangle {
                            visible: iconItem.modelData.status === Status.NeedsAttention
                            width: 6
                            height: 6
                            radius: 3
                            anchors.top: parent.top
                            anchors.right: parent.right
                            color: Theme.accentTeal
                            border.color: Theme.bgCrust
                            border.width: 1
                        }

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: iconItem.modelData.menu
                            anchor.window: root.barWindow
                            anchor.item: iconItem

                            readonly property var edgePos: root.barWindow
                                ? PanelController.panelEdgeOffset(iconItem, 6,
                                      root.barWindow.width, root.barWindow.height)
                                : ({ x: 0, y: 0 })
                            anchor.rect.x: edgePos.x
                            anchor.rect.y: edgePos.y
                            anchor.edges: PanelController.panelPosition === "bottom"
                                ? (Edges.Bottom | Edges.Left)
                                : (PanelController.panelPosition === "right"
                                    ? (Edges.Top | Edges.Right)
                                    : (Edges.Top | Edges.Left))
                            anchor.gravity: PanelController.panelPosition === "bottom"
                                ? (Edges.Top | Edges.Right)
                                : (PanelController.panelPosition === "right"
                                    ? (Edges.Bottom | Edges.Left)
                                    : (Edges.Bottom | Edges.Right))

                            onOpened: root._openMenus++
                            onClosed: root._openMenus = Math.max(0, root._openMenus - 1)
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onClicked: (mouse) => {
                                var item = iconItem.modelData
                                if (mouse.button === Qt.LeftButton) {
                                    if (item.onlyMenu && item.hasMenu)
                                        menuAnchor.open()
                                    else
                                        item.activate()
                                } else if (mouse.button === Qt.RightButton) {
                                    if (item.hasMenu)
                                        menuAnchor.open()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    item.secondaryActivate()
                                }
                            }

                            onWheel: (wheel) => {
                                var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                                var delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
                                iconItem.modelData.scroll(delta, horizontal)
                            }
                        }
                    }
                }
            }
        }

        // Arrow / pin button
        Rectangle {
            id: arrowBtn
            width: root.hasItems ? root.h : 0
            height: root.h
            opacity: root.hasItems ? 1 : 0
            radius: height / 2
            clip: true

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            color: arrowMa.containsMouse ? Theme.glassBgHover : "transparent"
            border.color: arrowMa.containsMouse ? Theme.glassBorderHover : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.pinned || arrowMa.containsMouse ? Theme.accent : Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(arrowBtn.height * 0.5))
                rotation: root.trayExpanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
                }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: arrowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pinned = !root.pinned
            }
        }
    }

    onBarWindowChanged: {
        if (barWindow)
            barWindow.activeTray = root
    }

    Component.onCompleted: {
        if (barWindow) {
            barWindow.activeTray = root
        }
    }
}
