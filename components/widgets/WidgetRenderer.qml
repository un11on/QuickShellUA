import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    required property var targetScreen
    readonly property string screenKey: WidgetManager.screenKeyForScreen(targetScreen)
    readonly property bool editMode: WidgetManager.editScreenKey === screenKey
    readonly property var screenRecords: {
        WidgetManager.revision
        var result = []
        var model = WidgetManager.instanceModel
        for (var i = 0; i < model.count; ++i) {
            var record = model.get(i)
            if (record.screenKey === root.screenKey && record.instanceEnabled && !record.unknownWidget) {
                result.push({
                    instanceId: record.instanceId,
                    widgetId: record.widgetId,
                    posX: record.posX,
                    posY: record.posY,
                    widgetWidth: record.widgetWidth,
                    widgetHeight: record.widgetHeight,
                    instanceEnabled: record.instanceEnabled,
                    zOrder: record.zOrder,
                    instanceSettings: record.instanceSettings
                })
            }
        }
        result.sort(function(a, b) { return a.zOrder - b.zOrder })
        return result
    }
    property int removalAttempts: 0

    screen: targetScreen
    visible: targetScreen !== null
    color: Qt.rgba(0, 0, 0, 0)
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: root.editMode ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-widgets-" + (targetScreen ? targetScreen.name : "unknown")

    mask: root.editMode ? editRegion : widgetRegions

    Region { id: editRegion; item: root.contentItem }
    Region { id: widgetRegions }

    function refreshMaskAfterRemoval() {
        if (widgetRegions.regions.length > frameRepeater.count && root.removalAttempts < 4) {
            root.removalAttempts++
            removalTimer.restart()
            return
        }
        widgetRegions.changed()
    }

    Timer {
        id: removalTimer
        interval: 16
        repeat: false
        onTriggered: root.refreshMaskAfterRemoval()
    }

    Timer {
        id: geometryTimer
        interval: 250
        repeat: false
        onTriggered: WidgetManager.clampScreen(root.targetScreen)
    }

    onWidthChanged: geometryTimer.restart()
    onHeightChanged: geometryTimer.restart()

    WidgetEditor {
        anchors.fill: parent
        z: -1
        targetScreen: root.targetScreen
        active: root.editMode
    }

    Repeater {
        id: frameRepeater
        model: root.screenRecords

        onItemAdded: function(index, item) {
            widgetRegions.regions.push(item.inputRegion)
        }

        onItemRemoved: function(index, item) {
            root.removalAttempts = 0
            removalTimer.restart()
        }

        delegate: WidgetInstance {
            required property var modelData
            instanceId: modelData.instanceId
            widgetId: modelData.widgetId
            posX: modelData.posX
            posY: modelData.posY
            widgetWidth: modelData.widgetWidth
            widgetHeight: modelData.widgetHeight
            instanceEnabled: modelData.instanceEnabled
            zOrder: modelData.zOrder
            instanceSettings: modelData.instanceSettings
            editMode: root.editMode
        }
    }
}
