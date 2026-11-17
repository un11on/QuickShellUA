import QtQuick
import QtQuick.Controls
import Quickshell
import "."
import ".."

Item {
    id: root

    required property string instanceId
    required property string widgetId
    required property real posX
    required property real posY
    required property real widgetWidth
    required property real widgetHeight
    required property bool instanceEnabled
    required property int zOrder
    required property var instanceSettings

    property bool editMode: false
    property bool moving: false
    property bool resizing: false
    property real displayX: posX
    property real displayY: posY
    property real displayWidth: widgetWidth
    property real displayHeight: widgetHeight
    property real moveOriginX: 0
    property real moveOriginY: 0
    property real resizeOriginWidth: 0
    property real resizeOriginHeight: 0
    readonly property var definition: WidgetRegistry.get(widgetId)
    readonly property bool selected: WidgetManager.selectedInstanceId === instanceId
    readonly property alias inputRegion: inputRegion

    x: displayX
    y: displayY
    width: displayWidth
    height: displayHeight
    z: zOrder
    visible: instanceEnabled

    onPosXChanged: if (!moving) displayX = posX
    onPosYChanged: if (!moving) displayY = posY
    onWidgetWidthChanged: if (!resizing) displayWidth = widgetWidth
    onWidgetHeightChanged: if (!resizing) displayHeight = widgetHeight

    Region {
        id: inputRegion
        item: root
        radius: Theme.radiusLg
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: root.instanceSettings && root.instanceSettings.transparent
               ? "transparent" : Theme.glassPopupSolid
        border.color: root.editMode
                ? (root.selected ? Theme.accent : Theme.glassBorderHover)
                : Theme.glassBorder
        border.width: root.editMode ? (root.selected ? 3 : 2) : 1
        clip: true

        Loader {
            id: widgetLoader
            anchors.fill: parent
            anchors.margins: root.editMode ? 24 : 0
            source: root.definition ? root.definition.component : ""

            onStatusChanged: {
                if (status === Loader.Error)
                    console.error("Widget load failed:", root.widgetId, source)
            }
        }

        Binding {
            target: widgetLoader.item
            property: "instanceId"
            value: root.instanceId
            when: widgetLoader.item !== null
        }

        Binding {
            target: widgetLoader.item
            property: "settings"
            value: root.instanceSettings
            when: widgetLoader.item !== null
        }

        Binding {
            target: widgetLoader.item
            property: "previewMode"
            value: false
            when: widgetLoader.item !== null
        }

        Connections {
            target: widgetLoader.item
            ignoreUnknownSignals: true
            function onSettingChanged(key, value) {
                WidgetManager.updateSetting(root.instanceId, key, value)
            }
        }

        Rectangle {
            visible: root.editMode
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 24
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.definition ? root.definition.name : root.widgetId
                color: Theme.text
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 4
                width: 18
                height: 18
                radius: 9
                color: removeMouse.containsMouse ? Theme.accentRed : "transparent"
                Text { anchors.centerIn: parent; text: "×"; color: Theme.text; font.pixelSize: 12 }
                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: WidgetManager.removeWidget(root.instanceId)
                }
            }
        }
    }

    TapHandler {
        enabled: root.editMode
        acceptedButtons: Qt.LeftButton
        onTapped: WidgetManager.selectedInstanceId = root.instanceId
    }

    DragHandler {
        id: moveHandler
        enabled: root.editMode && !resizeHandler.active
        target: null
        cursorShape: Qt.SizeAllCursor
        onActiveChanged: {
            root.moving = active
            if (active) {
                WidgetManager.selectedInstanceId = root.instanceId
                root.moveOriginX = root.displayX
                root.moveOriginY = root.displayY
            } else {
                WidgetManager.setGeometry(root.instanceId,
                                          root.displayX, root.displayY,
                                          root.displayWidth, root.displayHeight, true)
            }
        }
        onTranslationChanged: {
            if (active) {
                root.displayX = Math.max(0, root.moveOriginX + activeTranslation.x)
                root.displayY = Math.max(0, root.moveOriginY + activeTranslation.y)
            }
        }
    }

    Rectangle {
        visible: root.editMode && root.selected
        z: 100
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -7
        anchors.bottomMargin: -7
        width: 18
        height: 18
        radius: 5
        color: Theme.accent
        border.color: Theme.text
        border.width: 1

        DragHandler {
            id: resizeHandler
            target: null
            cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: {
                root.resizing = active
                if (active) {
                    WidgetManager.selectedInstanceId = root.instanceId
                    root.resizeOriginWidth = root.displayWidth
                    root.resizeOriginHeight = root.displayHeight
                } else {
                    WidgetManager.setGeometry(root.instanceId,
                                              root.displayX, root.displayY,
                                              root.displayWidth, root.displayHeight, true)
                }
            }
            onTranslationChanged: {
                if (active && root.definition) {
                    root.displayWidth = Math.max(root.definition.minWidth,
                                                 root.resizeOriginWidth + activeTranslation.x)
                    root.displayHeight = Math.max(root.definition.minHeight,
                                                  root.resizeOriginHeight + activeTranslation.y)
                }
            }
        }
    }
}
