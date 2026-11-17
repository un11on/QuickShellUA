import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Hyprland
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "both"

    readonly property string winTitle: {
        if (Hyprland.activeToplevel && Hyprland.activeToplevel.title)
            return Hyprland.activeToplevel.title
        return ""
    }

    readonly property string winAppId: {
        if (Hyprland.activeToplevel && Hyprland.activeToplevel.appId)
            return Hyprland.activeToplevel.appId
        return ""
    }

    readonly property string displayTitle: winTitle.length > 0 ? winTitle : (winAppId.length > 0 ? winAppId : "Hyprland")

    readonly property int maxW: {
        if (modSize === "compact") return 120
        if (modSize === "expanded") return 360
        return 220
    }

    readonly property int h: barWindow ? barWindow.btnSize : 28

    implicitHeight: h
    implicitWidth: Math.min(maxW, cardRow.implicitWidth + 16)

    Rectangle {
        id: winCard
        anchors.fill: parent
        radius: height / 2
        color: winMa.containsMouse ? Theme.glassBgHover : Theme.glassCard
        border.color: winMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: cardRow
            anchors.centerIn: parent
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                visible: root.modDisplay !== "text"
                text: "󰖲"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Math.max(11, Math.round(root.h * 0.5))
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.displayTitle
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: root.modSize === "compact" ? 11 : 12
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: winMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var name = event ? event.name : ""
            if (name === "activewindow" || name === "activewindowv2" || name === "windowtitle" || name === "windowtitlev2") {
                Hyprland.refreshToplevels()
            }
        }
    }
}
