import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."
import ".."

Item {
    id: root
    anchors.fill: parent
    Layout.fillWidth: true
    Layout.fillHeight: true

    property var manager: MonitorManager {}
    property bool multi: manager && manager.monitors ? manager.monitors.length > 1 : false

    // -------- Primary monitor (multi-monitor mode) --------
    // Основний вибирається за реальним ім'ям connector'а, не за індексом.
    readonly property string primaryName: Config.monitorsPrimary || ""
    readonly property var primaryMonitor: primaryName && manager
        ? manager.getMonitor(primaryName) : null
    readonly property bool primaryMissing: primaryName !== ""
        && (!primaryMonitor || primaryMonitor.disabled)

    readonly property var activeMonitors: {
        var list = []
        if (!manager || !manager.monitors)
            return list
        for (var i = 0; i < manager.monitors.length; ++i) {
            if (!manager.monitors[i].disabled)
                list.push(manager.monitors[i])
        }
        return list
    }

    function setMultiMode(enabled) {
        // При першому вмиканні обираємо поточний сфокусований (або перший
        // доступний) монітор. Уже збережений вибір не перезаписуємо, навіть
        // якщо цей монітор тимчасово відключений — інакше зламається
        // відновлення після reconnect.
        if (enabled && root.primaryName === "") {
            var pick = null
            for (var i = 0; i < root.activeMonitors.length; ++i) {
                if (root.activeMonitors[i].focused) {
                    pick = root.activeMonitors[i]
                    break
                }
            }
            if (!pick && root.activeMonitors.length > 0)
                pick = root.activeMonitors[0]
            if (pick)
                Config.setProp("Monitors.primary", pick.name)
        }
        Config.setProp("Monitors.multiMonitorMode", enabled)
    }

    function setPrimaryMonitor(name) {
        if (!name || name === root.primaryName)
            return
        Config.setProp("Monitors.primary", name)
    }

    // -------- Scrollable page --------
    Flickable {


        id: pageFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds


        WheelHandler {
            target: pageFlick
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                pageFlick.flick(0, event.angleDelta.y * 6)
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.textMuted
                opacity: 0.4
            }
        }

        ColumnLayout {
            id: pageColumn
            x: 20
            y: 20
            width: pageFlick.width - 40
            spacing: 16

            // -------- Header --------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Дисплеї"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                        text: {
                            if (!manager) return ""
                            if (manager.loading) return "Завантаження даних про монітори…"
                            var count = manager.monitors ? manager.monitors.length : 0
                            return count === 1 ? "1 активний дисплей" : (count + " активних дисплеїв")
                        }
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.family: Theme.fontMono
                    }
                }

                // Identify button in header
                Rectangle {
                    implicitWidth: identRow.implicitWidth + 18
                    implicitHeight: 30
                    radius: Theme.radiusSm
                    color: identMa.containsMouse ? Theme.accentHover : Theme.accent

                    RowLayout {
                        id: identRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰤉"
                            color: Theme.textDark
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                        Text {
                            text: "Ідентифікувати"
                            color: Theme.textDark
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: identMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.manager.identify()
                    }
                }
            }

            // -------- Multi-monitor mode --------
            // Показується лише коли реально виявлено 2+ монітори; з одним
            // дисплеєм інтерфейс сторінки лишається без змін.
            Rectangle {
                id: multiModeCard
                visible: root.multi
                Layout.fillWidth: true
                implicitHeight: multiModeCol.implicitHeight + 24
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Config.monitorsMultiMonitorMode ? Theme.accent : Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: multiModeCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ToggleTile {
                            Layout.fillWidth: true
                            icon: "󰍹"
                            title: "Режим декількох моніторів"
                            subtitle: "Закріпити TopBar за обраним основним дисплеєм"
                            active: Config.monitorsMultiMonitorMode
                            onClicked: root.setMultiMode(!Config.monitorsMultiMonitorMode)
                        }

                        Text {
                            text: Config.monitorsMultiMonitorMode ? "УВІМКНО" : "ВИМКНО"
                            color: Config.monitorsMultiMonitorMode ? Theme.accent : Theme.textMuted
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }
                    }

                    // Список виявлених моніторів з вибором основного.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: Config.monitorsMultiMonitorMode

                        Text {
                            text: "ОСНОВНИЙ МОНІТОР"
                            color: Theme.textMuted
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        Repeater {
                            model: root.manager ? root.manager.monitors : []

                            delegate: Rectangle {
                                id: primaryRow

                                readonly property bool isPrimary: root.primaryName === modelData.name
                                readonly property bool isAvailable: !modelData.disabled

                                Layout.fillWidth: true
                                implicitHeight: primaryRowContent.implicitHeight + 16
                                radius: Theme.radiusSm
                                color: isPrimary
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                    : (primaryRowMa.containsMouse && isAvailable
                                        ? Theme.glassCardHover : Theme.glassCard)
                                border.color: isPrimary ? Theme.accent : Theme.glassBorder
                                border.width: isPrimary ? 2 : 1
                                opacity: isAvailable ? 1.0 : 0.55

                                RowLayout {
                                    id: primaryRowContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 10

                                    Text {
                                        text: "󰍹"
                                        color: primaryRow.isPrimary ? Theme.accent : Theme.textSub
                                        font.family: Theme.fontMono
                                        font.pixelSize: 16
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fontMono
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                if (modelData.disabled)
                                                    return "Дисконектнуто / вимкнено"
                                                return modelData.description || modelData.name
                                            }
                                            color: modelData.disabled ? Theme.textMuted : Theme.textSub
                                            font.family: Theme.fontMono
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        visible: modelData.focused && !modelData.disabled
                                        text: "АКТИВНИЙ"
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    // Радіо-індикатор вибору основного.
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "transparent"
                                        border.color: primaryRow.isPrimary ? Theme.accent : Theme.textMuted
                                        border.width: 2

                                        Rectangle {
                                            visible: primaryRow.isPrimary
                                            anchors.centerIn: parent
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: Theme.accent
                                        }
                                    }
                                }

                                MouseArea {
                                    id: primaryRowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: primaryRow.isAvailable
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (primaryRow.isAvailable)
                                            root.setPrimaryMonitor(modelData.name)
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.primaryMissing
                            text: "Збережений основний монітор недоступний — TopBar тимчасово показано на іншому дисплеї. Після reconnect вибір відновиться автоматично."
                            color: Theme.accentYellow
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // -------- No monitors / Loading states --------
            Text {
                visible: manager && manager.monitors && manager.monitors.length === 0 && !manager.loading
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Монітори не виявлено"
                color: Theme.textMuted
                font.pixelSize: 14
                font.family: Theme.fontMono
            }

            // -------- Monitor cards (adaptive wrapping row) --------
            Item {
                id: cardsContainer
                Layout.fillWidth: true

                readonly property real cardGap: 12
                readonly property real cardMinWidth: 220
                readonly property real cardMaxWidth: 900
                readonly property real cardHeight: 150

                readonly property real availW: width > 0 ? width : (pageColumn.width > 0 ? pageColumn.width : 400)
                readonly property int numCards: root.manager && root.manager.monitors ? root.manager.monitors.length : 0
                readonly property int cols: Math.max(1, Math.min(numCards > 0 ? numCards : 1, Math.floor((availW + cardGap) / (cardMinWidth + cardGap))))
                readonly property real calcCardWidth: cols > 0 ? Math.min(cardMaxWidth, (availW - (cols - 1) * cardGap) / cols) : cardMinWidth
                readonly property int rows: cols > 0 ? Math.ceil(numCards / cols) : 0

                implicitHeight: rows === 0 ? 0 : (rows * cardHeight + Math.max(0, rows - 1) * cardGap)

                Flow {
                    id: cardsFlow
                    anchors.fill: parent
                    spacing: cardsContainer.cardGap

                    Repeater {
                        model: root.manager ? root.manager.monitors : []
                        delegate: MonitorCard {
                            manager: root.manager
                            monitor: modelData
                            cardWidth: cardsContainer.calcCardWidth
                            cardHeight: cardsContainer.cardHeight
                            selected: (root.manager && root.manager.selectedMonitor && modelData.name === root.manager.selectedMonitor.name)
                            multi: root.multi
                        }
                    }
                }
            }

            // -------- Settings panel --------
            MonitorSettings {
                id: settingsPanel
                Layout.fillWidth: true
                manager: root.manager
                monitor: root.manager ? root.manager.selectedMonitor : null
                multi: root.multi
            }
        }
    }
}
