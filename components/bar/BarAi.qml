import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "icon"

    readonly property int h: barWindow ? barWindow.btnSize : 28
    readonly property bool aiActive: barWindow ? barWindow.aiActive : false

    implicitHeight: h
    implicitWidth: modDisplay === "icon" ? h : (aiRow.implicitWidth + 16)

    Rectangle {
        id: aiBtnCard
        anchors.fill: parent
        radius: height / 2
        clip: true

        border.color: root.aiActive ? Theme.glassBorderFocus
            : (aiMa.containsMouse ? Theme.glassBorderHover : "transparent")
        border.width: 1

        scale: aiMa.pressed ? 0.88 : (aiMa.containsMouse ? 1.08 : 1.0)
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.15 }
        }

        color: root.aiActive
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18 * Theme.glassOpacity)
            : (aiMa.containsMouse ? Theme.glassBgHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: aiRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: root.modDisplay !== "text"
                text: "󰚩"
                color: root.aiActive ? Theme.accentSecondary
                    : (aiMa.containsMouse ? Theme.accentSecondary : Theme.accent)
                font.family: Theme.fontMono
                font.pixelSize: Math.max(14, Math.round(root.h * 0.52))
                rotation: aiMa.containsMouse || root.aiActive ? 15 : 0
                Behavior on rotation {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingSpring }
                }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.modSize === "expanded" ? "AI Assistant" : "AI"
                color: root.aiActive ? Theme.accentSecondary : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: aiMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (barWindow)
                    barWindow.toggleAiRequested()
            }
        }
    }
}
