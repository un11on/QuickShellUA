import QtQuick 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: root

    // -------- Properties --------
    property var monitor          // {name, description, x, y, width, height, scale, refreshRate, transform, focused, disabled, logicalWidth, logicalHeight}
    property bool selected: false
    property bool multi: false
    property var manager

    property real cardWidth: 200
    property real cardHeight: 140

    width: cardWidth
    height: cardHeight
    implicitWidth: cardWidth
    implicitHeight: cardHeight

    // -------- Icon helper --------
    property string displayIcon: {
        if (!monitor) return "󰍹"
        var desc = (monitor.description || "").toLowerCase()
        var name = (monitor.name || "").toLowerCase()
        if (desc.indexOf("built-in") >= 0 || desc.indexOf("builtin") >= 0 ||
            desc.indexOf("laptop") >= 0 || desc.indexOf("edp") >= 0 ||
            name.indexOf("edp") >= 0 || name.indexOf("laptop") >= 0) {
            return "󰍹"   // laptop/display icon
        }
        return "󰨾"   // external display icon
    }

    // -------- Visual Card --------
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radiusMd
        color: root.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Theme.glassCard
        border.color: root.selected ? Theme.accent : (ma.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
        border.width: root.selected ? 2 : 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            // --- Top row: icon + name + badge ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.displayIcon
                    color: root.selected ? Theme.accent : Theme.textSub
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                }

                Text {
                    text: monitor ? monitor.name : ""
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Focused / active indicator
                Rectangle {
                    visible: monitor !== null && (monitor.focused || monitor.disabled)
                    implicitWidth: badgeLabel.implicitWidth + 10
                    implicitHeight: 20
                    radius: 10
                    color: monitor && monitor.disabled
                        ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.2)
                        : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)

                    Text {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: monitor && monitor.disabled ? "Вимкнено" : "Активний"
                        color: monitor && monitor.disabled ? Theme.accentRed : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }

            // --- Model / description ---
            Text {
                text: monitor && monitor.description && monitor.description !== monitor.name
                    ? monitor.description
                    : ""
                color: Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text.length > 0
            }

            Item { Layout.fillHeight: true }

            // --- Resolution + refresh ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: monitor ? (monitor.width + "×" + monitor.height) : ""
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: monitor && monitor.refreshRate ? ("@" + Math.round(monitor.refreshRate) + " Hz") : ""
                    color: Theme.textSub
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }
            }

            // --- Scale ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Масштаб: " + (monitor && monitor.scale !== undefined ? (monitor.scale * 100).toFixed(0) + "%" : "100%")
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }
            }

            // --- Disabled indicator bar ---
            Rectangle {
                visible: monitor !== null && monitor.disabled
                Layout.fillWidth: true
                height: 2
                radius: 1
                color: Theme.accentRed
            }
        }
    }

    // -------- Interaction --------
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (manager && monitor) {
                manager.selectMonitor(monitor.name)
            }
        }
    }
}
