import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: sidebar

    signal pageRequested(string pageName)
    property string currentPage: "overview"

    Layout.preferredWidth: 200
    Layout.fillHeight: true
    radius: Theme.radiusLg
    color: Theme.glassCard
    border.color: Theme.glassBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        // --- Логотип ---
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 8

            Text {
                text: "󰒓"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: "Налаштування"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
            }
        }

        // --- Навігація ---
        Repeater {
            model: [
                { key: "overview",    icon: "󰋜", label: "Огляд" },
                { key: "appearance",  icon: "󰏘", label: "Зовнішній вигляд" },
                { key: "panel",       icon: "󰠳", label: "Панель" },
                { key: "media",       icon: "󰎆", label: "Медіаплеєр" },
                { key: "monitors",    icon: "󰍹", label: "Дисплеї" },
                { key: "wallpaper",   icon: "󰸉", label: "Шпалери" },
                { key: "widgets",     icon: "󰘦", label: "Віджети" },
                { key: "animations",  icon: "󰑮", label: "Анімації" },
                { key: "about",       icon: "󰋗", label: "Про оболонку" }
            ]

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: 36
                radius: Theme.radiusSm
                color: sidebar.currentPage === modelData.key
                    ? Qt.rgba(0.54, 0.71, 0.98, 0.15)
                    : (navMa.containsMouse ? Theme.glassBgHover : "transparent")
                border.color: sidebar.currentPage === modelData.key
                    ? Qt.rgba(0.54, 0.71, 0.98, 0.3)
                    : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: modelData.icon
                        color: sidebar.currentPage === modelData.key ? Theme.accent : Theme.textSub
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }
                    Text {
                        text: modelData.label
                        color: sidebar.currentPage === modelData.key ? Theme.text : Theme.textSub
                        font.pixelSize: 12
                        font.bold: sidebar.currentPage === modelData.key
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sidebar.currentPage = modelData.key
                        sidebar.pageRequested(modelData.key)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // --- Версія ---
        Text {
            text: "Quickshell v0.3.2"
            color: Theme.textMuted
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
