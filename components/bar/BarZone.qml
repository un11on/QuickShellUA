import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    property string zoneName: "left"
    property var modules: []
    property var barWindow: null

    readonly property var activeModules: {
        var list = []
        if (modules && Array.isArray(modules)) {
            for (var i = 0; i < modules.length; i++) {
                var m = modules[i]
                if (m && m.enabled !== false && m.id)
                    list.push(m)
            }
        }
        return list
    }

    readonly property bool hasActive: activeModules.length > 0
    visible: hasActive

    implicitWidth: hasActive ? island.implicitWidth : 0
    implicitHeight: hasActive ? island.implicitHeight : 0

    Island {
        id: island
        anchors.fill: parent
        direction: PanelController.isHorizontal ? "row" : "column"
        visible: root.hasActive

        implicitWidth: PanelController.isVertical
            ? (zoneGrid.implicitWidth + Config.panelIslandPadH * 2)
            : (zoneGrid.implicitWidth + Config.panelIslandPadH * 2)
        implicitHeight: PanelController.isVertical
            ? (zoneGrid.implicitHeight + Config.panelIslandPadH * 2)
            : Config.panelHeight

        GridLayout {
            id: zoneGrid
            anchors.centerIn: parent
            columns: island.direction === "row" ? 999 : 1
            columnSpacing: Config.panelIslandSpacing
            rowSpacing: Config.panelIslandSpacing

            Component.onCompleted: island.contentItem = zoneGrid

            Repeater {
                model: root.activeModules

                delegate: Loader {
                    id: modLoader
                    required property var modelData
                    required property int index

                    Layout.alignment: Qt.AlignVCenter

                    sourceComponent: {
                        var id = modelData.id
                        if (id === "workspaces")    return compWorkspaces
                        if (id === "activewindow")  return compActiveWindow
                        if (id === "clock")         return compClock
                        if (id === "wifi")          return compWifi
                        if (id === "bluetooth")     return compBluetooth
                        if (id === "volume")        return compVolume
                        if (id === "notifications") return compNotifications
                        if (id === "tray")          return compTray
                        if (id === "ai")            return compAi
                        if (id === "mediaplayer")   return compMediaPlayer
                        return null
                    }

                    property var modConfig: modelData
                    property var modBarWindow: root.barWindow

                    onLoaded: {
                        if (item) {
                            item.config = modConfig
                            item.barWindow = modBarWindow
                        }
                    }
                }
            }
        }
    }

    Component { id: compWorkspaces; BarWorkspaces {} }
    Component { id: compActiveWindow; BarActiveWindow {} }
    Component { id: compClock; BarClock {} }
    Component { id: compWifi; BarWifi {} }
    Component { id: compBluetooth; BarBluetooth {} }
    Component { id: compVolume; BarVolume {} }
    Component { id: compNotifications; BarNotifications {} }
    Component { id: compTray; BarTray {} }
    Component { id: compAi; BarAi {} }
    Component { id: compMediaPlayer; BarMediaPlayer {} }
}
