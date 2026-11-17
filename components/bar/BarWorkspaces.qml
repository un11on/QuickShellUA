import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "both"

    implicitWidth: wsItem.implicitWidth * (modSize === "compact" ? 0.88 : 1.0)
    implicitHeight: wsItem.implicitHeight * (modSize === "compact" ? 0.88 : 1.0)

    Workspaces {
        id: wsItem
        anchors.centerIn: parent
        scale: root.modSize === "compact" ? 0.88 : (root.modSize === "expanded" ? 1.05 : 1.0)
        iconsVisible: root.modDisplay !== "text"
        transformOrigin: Item.Center
    }
}
