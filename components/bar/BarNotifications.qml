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
    readonly property int unread: (barWindow && barWindow.systemMenu) ? barWindow.systemMenu.unreadCount : 0
    readonly property bool hasUnread: unread > 0

    implicitHeight: h
    implicitWidth: modDisplay === "icon" ? h : (notifRow.implicitWidth + 14)

    Rectangle {
        id: bellBtn
        anchors.fill: parent
        radius: height / 2
        clip: true

        color: root.hasUnread
            ? Qt.rgba(Theme.accentTeal.r, Theme.accentTeal.g, Theme.accentTeal.b, 0.16)
            : (bellMa.containsMouse ? Theme.glassBgHover : "transparent")
        border.color: root.hasUnread
            ? Qt.rgba(Theme.accentTeal.r, Theme.accentTeal.g, Theme.accentTeal.b, 0.55)
            : (bellMa.containsMouse ? Theme.glassBorderHover : "transparent")
        border.width: 1

        scale: bellMa.pressed ? 0.90 : (bellMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        // Pulsing ring when unread > 0
        Rectangle {
            visible: root.hasUnread
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Theme.accentTeal
            border.width: 2

            SequentialAnimation on opacity {
                running: root.hasUnread
                loops: Animation.Infinite
                NumberAnimation { to: 0.12; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
            }
        }

        RowLayout {
            id: notifRow
            anchors.centerIn: parent
            spacing: 5

            Item {
                visible: root.modDisplay !== "text"
                width: Math.max(12, Math.round(root.h * 0.53))
                height: width
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: parent.width
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                // Unread badge for icon-only mode
                Rectangle {
                    visible: root.hasUnread && root.modDisplay === "icon"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -2
                    implicitWidth: Math.max(12, unreadBadgeText.implicitWidth + 4)
                    implicitHeight: 12
                    radius: 6
                    color: Theme.accent
                    border.color: Theme.bgCrust
                    border.width: 1

                    Text {
                        id: unreadBadgeText
                        anchors.centerIn: parent
                        text: root.unread > 9 ? "9+" : String(root.unread)
                        color: Theme.textDark
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
            }

            Text {
                visible: root.modDisplay !== "icon"
                text: root.hasUnread ? (root.unread + " new") : "0"
                color: root.hasUnread ? Theme.accent : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: bellMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (barWindow)
                    barWindow.togglePopup("notifications")
            }
        }
    }

    onBarWindowChanged: {
        if (barWindow)
            barWindow.notifAnchorItem = bellBtn
    }

    Component.onCompleted: {
        if (barWindow)
            barWindow.notifAnchorItem = bellBtn
    }
}
