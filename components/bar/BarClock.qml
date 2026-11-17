import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "both"

    readonly property int h: barWindow ? barWindow.btnSize : 28

    implicitHeight: h
    implicitWidth: clockButton.implicitWidth

    Button {
        id: clockButton
        anchors.fill: parent
        implicitHeight: root.h
        implicitWidth: clockContentRow.implicitWidth + (Config.panelIslandPadH * 2)

        scale: clockButton.pressed ? 0.94 : (clockButton.hovered ? 1.04 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animUseSpring ? Theme.animNormal : Theme.animFast
                easing.type: Theme.animUseSpring ? Theme.easingSpring : Theme.easingStandard
                easing.overshoot: Theme.easingOvershoot
            }
        }

        background: Rectangle {
            color: "transparent"
            border.color: "transparent"
            border.width: 0
            radius: height / 2
        }

        contentItem: RowLayout {
            id: clockContentRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: root.modDisplay !== "text"
                text: "󰥔"
                color: clockButton.hovered ? Theme.accent : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(root.h * 0.52))
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                id: clockText
                visible: root.modDisplay !== "icon"
                color: clockButton.hovered ? Theme.accent : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: root.modSize === "compact" ? 11 : 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        var d = new Date()
                        if (root.modSize === "compact")
                            clockText.text = Qt.formatDateTime(d, "hh:mm")
                        else if (root.modSize === "expanded")
                            clockText.text = Qt.formatDateTime(d, "hh:mm:ss  |  ddd, d MMM")
                        else
                            clockText.text = Qt.formatDateTime(d, "hh:mm:ss  |  ddd, d MMM")
                    }
                }
            }
        }

        onClicked: {
            if (barWindow)
                barWindow.togglePopup("dashboard")
        }
    }

    onBarWindowChanged: {
        if (barWindow)
            barWindow.clockAnchorItem = clockButton
    }

    Component.onCompleted: {
        if (barWindow)
            barWindow.clockAnchorItem = clockButton
    }
}
