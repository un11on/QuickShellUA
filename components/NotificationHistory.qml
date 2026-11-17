import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "."

// Окремоє компактне вікно історії сповіщень.
// Відкривається кнопкою-колокольчиком у TopBar; ЄДИНА система отримання/зберігання
// живе в DashboardMenu (NotificationServer + trackedNotifications) — тут лише відображення.
// Наповнення через властивість dashboard (екземпляр DashboardMenu).
PopupWindow {
    id: history

    // DashboardMenu: notifModel, notifTimes, notifTimeText(), clearNotifications(), unreadCount
    property var dashboard: null

    readonly property int listWidth: 430
    // Максимум списка: 3 карточки целиком (худший случай ~3×99+16=313px) + запас
    readonly property int maxListHeight: 410
    readonly property int count: dashboard && dashboard.notifModel ? dashboard.notifModel.values.length : 0

    // Не выходить за нижнюю границу экрана: резерв ~160px (бар + отступы).
    // screen.height — device-independent px (QScreen::size), как координаты QML.
    readonly property int screenCap: screen ? Math.max(280, screen.height - 160) : 512
    readonly property int listCap: Math.max(140, Math.min(maxListHeight, screenCap - headerRow.implicitHeight - 32))

    implicitWidth: listWidth
    implicitHeight: contentCol.implicitHeight + 24

    // ---------- Пряме керування видимістю (як у DashboardMenu) ----------
    // Стара (стабільна) механіка: visible керується імперативно, похідних станів
    // немає. Wayland може закрити grab-попап зовні (popup_done) — QuickShell
    // синхронізує visible; розсинхрон неможливий. Анімація — лише поява.
    visible: false
    grabFocus: true
    color: "transparent"

    function openHistory() {
        if (history.visible)
            return
        // Початковий зсув залежить від напрямку відкриття popup (PanelController).
        var dir = PanelController.popupDirection
        if (dir === "down") { histTranslate.y = -history.implicitHeight; histTranslate.x = 0 }
        else if (dir === "up") { histTranslate.y = history.implicitHeight; histTranslate.x = 0 }
        else if (dir === "right") { histTranslate.x = -history.implicitWidth; histTranslate.y = 0 }
        else { histTranslate.x = history.implicitWidth; histTranslate.y = 0 }
        panel.opacity = 0.4
        panel.scale = 0.96
        history.visible = true
        // Відкриття історії = усе прочитано
        if (dashboard)
            dashboard.unreadCount = 0
        openAnim.restart()
    }

    function closeHistory() {
        openAnim.stop()
        history.visible = false
        histTranslate.y = 0
        histTranslate.x = 12
        panel.opacity = 0
        panel.scale = 0.96
    }

    Shortcut {
        sequence: "Escape"
        enabled: history.visible
        onActivated: history.closeHistory()
    }

    // Поява: виїжджає у бік popupDirection + легкі opacity/scale; жодних станів не змінює.
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: histTranslate; property: "x"; to: 0; duration: Theme.animNormal; easing.type: Theme.easingStandard }
        NumberAnimation { target: histTranslate; property: "y"; to: 0; duration: Theme.animNormal; easing.type: Theme.easingStandard }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Theme.easingStandard }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.05 }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg ? "transparent" : Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
            intensity: Theme.cfgGradientIntensity
            target: "bg"
            solidColor: Theme.glassPopupSolid
            radius: Theme.radiusXl
            clip: true
        }

        // Стан керує openAnim (поява); стартові значення ставляться
        // імперативно в openHistory (без биндингів — конфлікт з анімаціями виключений).
        opacity: 0
        scale: 0.96
        transform: Translate {
            id: histTranslate
            x: 12
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // ----- Заголовок -----
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂚"
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
                Text {
                    text: "Історія сповіщень"
                    color: Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }
                Rectangle {
                    visible: history.count > 0
                    implicitWidth: histCountText.implicitWidth + 12
                    implicitHeight: 15
                    radius: Theme.radiusRound
                    color: Theme.accent

                    Text {
                        id: histCountText
                        anchors.centerIn: parent
                        text: history.count
                        color: Theme.textDark
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Очистити"
                    color: histClearMa.containsMouse ? Theme.accentHover : Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                    visible: history.count > 0

                    MouseArea {
                        id: histClearMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (history.dashboard) history.dashboard.clearNotifications()
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Theme.radiusRound
                    color: histCloseMa.containsMouse
                           ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.2)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: histCloseMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: histCloseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: history.closeHistory()
                    }
                }
            }

            // ----- Список / порожній стан -----
            Item {
                id: listArea
                Layout.fillWidth: true
                clip: true
                // Фіксована висота вьюпорта (listCap уже враховує screenCap):
                // окно всегда полной высоты — 0/1/2/3 карточки и Empty State
                // центрируются/прижаты к верху, при 4+ работает прокрутка.
                height: history.listCap

                Column {
                    id: emptyHist
                    anchors.centerIn: parent
                    spacing: 8
                    visible: history.count === 0

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        radius: Theme.radiusRound
                        color: Theme.glassCard
                        border.color: Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰂛"
                            color: Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 20
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Немає сповіщень"
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }
                }

                ListView {
                    id: histList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    // Фіксований вьюпорт = listCap: висота вью не залежить від
                    // contentHeight — прокрутка при 4+, немає циклів і ресайзів.
                    height: history.listCap
                    clip: true
                    spacing: 8
                    model: history.dashboard ? history.dashboard.notifModel : null
                    // TopToBottom: вью якорится к верху (под заголовком) — позиции
                    // карточек относительно окна стабильны, ресайз окна при удалении
                    // уходит вниз и не двигает их. removeDisplaced полностью
                    // управляет анимацией смещения (без скачка).
                    verticalLayoutDirection: ListView.TopToBottom
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollIndicator.vertical: ScrollIndicator {}

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast }
                    }
                    addDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: Theme.animNormal; easing.type: Theme.easingStandard }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: Theme.animFast }
                    }
                    removeDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: Theme.animNormal; easing.type: Theme.easingStandard }
                    }

                    delegate: Rectangle {
                        id: histChip
                        required property var modelData

                        // Иконка приложения: appIcon или desktopEntry из темы значков;
                        // iconPath(name, true) вернёт "", если значка нет → fallback-буква.
                        readonly property string appIconSource: {
                            var n = modelData.appIcon || modelData.desktopEntry || ""
                            if (n.length === 0) return ""
                            if (n.charAt(0) === "/") return "file://" + n
                            return Quickshell.iconPath(n, true)
                        }

                        width: ListView.view.width
                        height: histCol.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: histMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                        border.color: histMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                        border.width: 1
                        clip: true

                        // Підтримка градієнтів теми — як у Card/QuickTile
                        GradientBg {
                            anchors.fill: parent
                            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
                            intensity: Theme.cfgGradientIntensity
                            target: "surf"
                            solidColor: histMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                            radius: Theme.radiusMd
                            clip: true
                        }

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

                        // Hover-область карточки (кнопка ✕ ниже по z и остаётся кликабельной)
                        MouseArea {
                            id: histMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            id: histCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            anchors.rightMargin: 30
                            spacing: 10

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Theme.radiusSm
                                color: Theme.bgSurface
                                border.color: Theme.glassBorder
                                border.width: 1

                                // Реальна іконка програми (якщо є в темі значків)
                                IconImage {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    visible: histChip.appIconSource.length > 0
                                    source: histChip.appIconSource
                                    asynchronous: true
                                }

                                // Fallback: перша літера назви програми (патерн медіа-картки)
                                Text {
                                    anchors.centerIn: parent
                                    visible: histChip.appIconSource.length === 0
                                    text: histChip.modelData.appName.length > 0
                                          ? histChip.modelData.appName.charAt(0).toUpperCase() : "󰂚"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: histChip.modelData.appName
                                        color: Theme.accent
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: history.dashboard
                                              ? history.dashboard.notifTimeText(histChip.modelData.id) : ""
                                        color: Theme.textMuted
                                        font.family: Theme.fontMono
                                        font.pixelSize: 9
                                        visible: text.length > 0
                                    }
                                }
                                Text {
                                    text: histChip.modelData.summary
                                    color: Theme.text
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: histChip.modelData.body
                                    color: Theme.textSub
                                    font.pixelSize: 11
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            width: 22
                            height: 22
                            radius: Theme.radiusRound
                            color: histDismissMa.containsMouse
                                   ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.22)
                                   : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: histDismissMa.containsMouse ? Theme.accentRed : Theme.textMuted
                                font.pixelSize: 9
                                font.bold: true

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            MouseArea {
                                id: histDismissMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: histChip.modelData.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
