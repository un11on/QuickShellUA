import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "."

// ============================================================================
// NotificationTrayCapsule — единая выдвижная капсула верхней панели (bell + tray + arrow + divider).
//
// Свёрнуто:   [ 🔔 ] │ [ › ]
// Раскрыто:   [ 🔔 ] │ [ иконки трея … ] [ ‹ ]
//
// • Колокольчик — прежняя кнопка уведомлений: счётчик, бейдж, пульс сохранены.
//   Клик → сигнал notificationsClicked() (TopBar вызывает тот же
//   barWindow.togglePopup("notifications")).
// • Стрелочка → клик закрепляет / освобождает раскрытое состояние (pin).
//   Наведение раскрывает трей автоматически, уход курсора плавно сворачивает;
//   закреплённый трей остаётся раскрытым. Hover-состояние общее для всей
//   капсулы, поэтому переход между колокольчиком, иконками и стрелочкой
//   не вызывает случайного сворачивания.
// • Трей — настоящий SNI (SystemTray.items), без фиктивных списков.
// • Пустой трей: разделитель и стрелка скрыты, капсула = только колокольчик.
// ============================================================================
Rectangle {
    id: root

    // Окно панели (PanelWindow) — для QsMenuAnchor (контекстные меню трея).
    property var barWindow: null
    // Счётчик непрочитанных (прокидывается из systemMenu.unreadCount).
    property int unreadCount: 0
    // Кнопка-колокольчик для якоря NotificationHistory.
    property alias bellButton: bellBtn
    // Раскрытие: наведение (авто), ручное закрепление (pin) или открытое
    // контекстное меню иконки трея. Клик по стрелочке переключает pin.
    property bool pinned: false
    property bool _hovered: false
    property int _openMenus: 0
    readonly property bool trayExpanded: pinned || _hovered || _openMenus > 0
    // Встроен в общую карточку (TopBar): без собственного фона/рамки
    // и без внутренних боковых отступов — их даёт общая карточка.
    property bool embedded: false

    signal notificationsClicked()

    // --- Геометрия (в стиле Island) ---
    readonly property int padH: root.embedded ? 0 : Config.panelIslandPadH
    readonly property int btnSize: Math.max(20, Math.min(32, Config.panelHeight - 8))
    readonly property int iconSize: Math.max(16, Math.round(Config.panelHeight * 0.52))
    readonly property int iconGap: 4
    readonly property int dividerGap: 4
    // Ширина разделителя вместе с боковыми зазорами.
    readonly property int dividerWidth: 1 + dividerGap * 2

    readonly property int itemCount: trayRepeater.count
    readonly property bool hasItems: itemCount > 0
    // Пустой трей не может быть закреплён — сбрасываем невидимое состояние.
    onHasItemsChanged: {
        if (!hasItems) {
            pinned = false
            _openMenus = 0
        }
    }
    // Размер одного слота иконки и суммарная ширина ряда (без боковых зазоров).
    // Считаем явно: Row.implicitWidth не обновляется при динамическом добавлении
    // детей через Repeater (как и при смене visible).
    readonly property real iconItemSize: iconSize + 4
    readonly property real trayRowWidth: itemCount > 0
        ? itemCount * iconItemSize + (itemCount - 1) * 2
        : 0
    // Целевая ширина слота иконок (0, когда трей свёрнут/пуст).
    readonly property real slotWidth: (trayExpanded && hasItems)
        ? (trayRowWidth + iconGap * 2)
        : 0

    readonly property bool flat: Config.panelBackground || root.embedded

    implicitHeight: Config.panelHeight
    height: implicitHeight
    // Ширина = скалярные размеры (без ссылок на дочерние id: корневой binding
    // вычисляется раньше создания детей). Анимация — Behavior on width ниже.
    width: padH * 2 + btnSize + (hasItems ? dividerWidth + btnSize : 0) + slotWidth
    radius: root.embedded ? 0 : Math.min(Config.panelIslandRadius, height / 2)
    clip: true
    antialiasing: true

    // Матовое стекло — как у Island (с поддержкой flat/градиента).
    color: flat ? "transparent"
        : (Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf ? "transparent" : Theme.glassBg)
    border.color: flat ? "transparent" : Theme.glassBorder
    border.width: 1

    // Фон капсулы нужен только когда она рисует собственное стекло.
    // В embedded/flat режиме фон уже даёт общая карточка (Island),
    // поэтому слой полностью скрыт — иначе его прямоугольная заливка
    // (radius = 0) проступает поверх скруглённых углов карточки.
    GradientBg {
        anchors.fill: parent
        radius: root.radius
        visible: !root.flat
        enabled: !root.flat && Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
        intensity: Theme.cfgGradientIntensity
        target: "surf"
        solidColor: Theme.glassBg
        clip: true
    }

    Behavior on width {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on radius {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }

    // Автораскрытие по наведению. HoverHandler видит курсор над всей
    // капсулой, включая промежутки и дочерние кнопки, поэтому переход
    // между детьми не даёт ложного «mouse leave». Небольшая задержка
    // сглаживает сворачивание при выходе за границу.
    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hovered) {
                hoverCloseTimer.stop()
                // В вертикальной панели капсула растёт вдоль панели и
                // вышла бы за её приделы — там остаётся кликовое управление.
                if (PanelController.isHorizontal)
                    root._hovered = true
            } else {
                hoverCloseTimer.restart()
            }
        }
    }

    Timer {
        id: hoverCloseTimer
        interval: Math.max(60, Theme.animFast)
        repeat: false
        onTriggered: root._hovered = false
    }

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.leftMargin: root.padH
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // ==================== Колокольчик уведомлений ====================
        Rectangle {
            id: bellBtn
            // Непрочитанные — из единой системы уведомлений (systemMenu.unreadCount).
            readonly property int unread: root.unreadCount
            readonly property bool hasUnread: unread > 0

            implicitWidth: root.btnSize
            implicitHeight: root.btnSize
            radius: height / 2
            clip: true

            // Подсветка при непрочитанных: мягкий бирюзовый тинт + рамка.
            color: hasUnread
                ? Qt.rgba(Theme.accentTeal.r, Theme.accentTeal.g, Theme.accentTeal.b, 0.16)
                : (bellMa.containsMouse ? Theme.glassBgHover : "transparent")
            border.color: hasUnread
                ? Qt.rgba(Theme.accentTeal.r, Theme.accentTeal.g, Theme.accentTeal.b, 0.55)
                : (bellMa.containsMouse ? Theme.glassBorderHover : "transparent")
            border.width: 1

            scale: bellMa.pressed ? 0.90 : (bellMa.containsMouse ? 1.06 : 1.0)

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
            }

            // Мягкое пульсирующее кольцо при непрочитанных.
            Rectangle {
                visible: bellBtn.hasUnread
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: Theme.accentTeal
                border.width: 2

                SequentialAnimation on opacity {
                    running: bellBtn.hasUnread
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.12; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
                }

                Behavior on opacity { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                anchors.centerIn: parent
                text: "󰂚"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(bellBtn.height * 0.53))

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Бейдж количества непрочитанных.
            Rectangle {
                visible: bellBtn.unread > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.rightMargin: 1
                implicitWidth: Math.max(14, unreadText.implicitWidth + 6)
                implicitHeight: 14
                radius: 7
                color: Theme.accent
                border.color: Theme.bgCrust
                border.width: 1.5

                Text {
                    id: unreadText
                    anchors.centerIn: parent
                    text: bellBtn.unread > 9 ? "9+" : bellBtn.unread
                    color: Theme.textDark
                    font.family: Theme.fontMono
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            MouseArea {
                id: bellMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.notificationsClicked()
            }
        }

        // ==================== Тонкий вертикальный разделитель ====================
        Item {
            id: dividerItem
            // Не используем visible: Row не пересчитывает implicitWidth при смене
            // видимости; ширина 0↔целевая корректно анимируется.
            width: root.hasItems ? root.dividerWidth : 0
            opacity: root.hasItems ? 1 : 0
            height: root.btnSize
            clip: true

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: Math.round(root.btnSize * 0.55)
                radius: 0.5
                color: Theme.glassBorderHover
            }
        }

        // ==================== Слот иконок системного трея ====================
        Item {
            id: traySlot
            height: root.btnSize
            clip: true
            // Плавное расширение/сжатие слота — за ним тянется ширина капсулы.
            width: root.slotWidth
            opacity: root.trayExpanded ? 1 : 0

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            Row {
                id: trayRow
                anchors.left: parent.left
                anchors.leftMargin: root.iconGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    id: trayRepeater
                    model: SystemTray.items

                    delegate: Item {
                        id: iconItem
                        required property SystemTrayItem modelData

                        width: root.iconItemSize
                        height: root.iconItemSize

                        // Подсветка под курсором.
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: iconMouse.containsMouse ? Theme.glassBgHover : "transparent"
                            border.color: iconMouse.containsMouse ? Theme.glassBorderHover : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                        }

                        // Реальная иконка приложения из трея.
                        IconImage {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: root.iconSize
                            source: iconItem.modelData.icon
                            asynchronous: true
                            mipmap: true
                        }

                        // Индикатор «требует внимания» (Status.NeedsAttention).
                        Rectangle {
                            visible: iconItem.modelData.status === Status.NeedsAttention
                            width: 6
                            height: 6
                            radius: 3
                            anchors.top: parent.top
                            anchors.right: parent.right
                            color: Theme.accentTeal
                            border.color: Theme.bgCrust
                            border.width: 1
                        }

                        // Контекстное меню приложения (DBusMenu).
                        QsMenuAnchor {
                            id: menuAnchor
                            menu: iconItem.modelData.menu
                            anchor.window: root.barWindow
                            anchor.item: iconItem

                            // Меню открывается от края панели в сторону экрана,
                            // а не поверх самой панели (как раньше для bottom/right).
                            readonly property var edgePos: root.barWindow
                                ? PanelController.panelEdgeOffset(iconItem, 6,
                                      root.barWindow.width, root.barWindow.height)
                                : ({ x: 0, y: 0 })
                            anchor.rect.x: edgePos.x
                            anchor.rect.y: edgePos.y
                            anchor.edges: PanelController.panelPosition === "bottom"
                                ? (Edges.Bottom | Edges.Left)
                                : (PanelController.panelPosition === "right"
                                    ? (Edges.Top | Edges.Right)
                                    : (Edges.Top | Edges.Left))
                            anchor.gravity: PanelController.panelPosition === "bottom"
                                ? (Edges.Top | Edges.Right)
                                : (PanelController.panelPosition === "right"
                                    ? (Edges.Bottom | Edges.Left)
                                    : (Edges.Bottom | Edges.Right))

                            // Пока меню открыто, капсула не сворачивается,
                            // даже если курсор ушёл в само меню.
                            onOpened: root._openMenus++
                            onClosed: root._openMenus = Math.max(0, root._openMenus - 1)
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onClicked: (mouse) => {
                                var item = iconItem.modelData
                                if (mouse.button === Qt.LeftButton) {
                                    // onlyMenu: нет основного действия — показываем меню.
                                    if (item.onlyMenu && item.hasMenu)
                                        menuAnchor.open()
                                    else
                                        item.activate()
                                } else if (mouse.button === Qt.RightButton) {
                                    if (item.hasMenu)
                                        menuAnchor.open()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    item.secondaryActivate()
                                }
                            }

                            onWheel: (wheel) => {
                                var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                                var delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
                                iconItem.modelData.scroll(delta, horizontal)
                            }
                        }
                    }
                }
            }
        }

        // ==================== Стрелочка раскрытия ====================
        Rectangle {
            id: arrowBtn
            // Как и разделитель: width 0 вместо visible (см. комментарий выше).
            width: root.hasItems ? root.btnSize : 0
            height: root.btnSize
            opacity: root.hasItems ? 1 : 0
            radius: height / 2
            clip: true

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            color: arrowMa.containsMouse ? Theme.glassBgHover : "transparent"
            border.color: arrowMa.containsMouse ? Theme.glassBorderHover : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.pinned || arrowMa.containsMouse ? Theme.accent : Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: Math.max(12, Math.round(arrowBtn.height * 0.5))
                // Стрелочка меняет направление: › (свёрнуто) ↔ ‹ (раскрыто).
                rotation: root.trayExpanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
                }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: arrowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Клик закрепляет раскрытое состояние; повторный клик снимает pin.
                onClicked: root.pinned = !root.pinned
            }
        }
    }
}
