import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "."
import "./bar"

PanelWindow {
    id: barWindow

    signal toggleAiRequested()
    signal openControlCenterRequested()

    // Активний стан AI-панелі (керується з shell.qml).
    property bool aiActive: false

    // Динамічні якоря модулів
    property var clockAnchorItem: null
    property var notifAnchorItem: null
    property var wifiAnchorItem: null
    property var btAnchorItem: null
    property var activeTray: null

    // Дані активного MPRIS-плеєра публікує єдиний LEGO-модуль BarMediaPlayer.
    // Якщо модуль відсутній у розкладці — ці поля лишаються порожніми,
    // і MediaPlayerPanel не може відкритися з неіснуючого модуля.
    property var mediaAnchorItem: null
    property var mediaPlayer: null
    property string mediaType: "music"

    // Аліаси випадаючих меню для модулів
    property alias systemMenu: systemMenu
    property alias notificationHistory: notificationHistory
    property alias mediaPanel: mediaPanel
    property alias wifiMenu: wifiMenu
    property alias bluetoothMenu: bluetoothMenu

    // Перемикання положення панелі (top ↔ bottom): відкриті popup закриваються.
    // Позиціонер popup перераховується коректно лише на нове відкриття — якщо
    // вікно лишається відкритим під час переїзду бару, воно опиняється в
    // транзитній геометрії (поза екраном або поверх панелі).
    // Для вертикальних положень (left/right) поведінку не змінюємо.
    Connections {
        target: PanelController
        function onPanelPositionChanged() {
            if (!PanelController.isHorizontal)
                return
            systemMenu.closePanel()
            notificationHistory.closeHistory()
            mediaPanel.closePanel()
            wifiMenu.visible = false
            bluetoothMenu.visible = false
        }
    }

    // Authoritative screen приходить з єдиного router у shell.qml. Логіка
    // компонента не зберігає ShellScreen після відключення монітора.
    property var targetScreen: null
    property string targetScreenName: ""
    property bool screenReady: false

    screen: targetScreen
    visible: screenReady

    // ---------------------------------------------------------------
    // Положение панели (единый источник: PanelController ↔ Config.Panel)
    // ---------------------------------------------------------------
    anchors.top:    PanelController.panelPosition === "top"
    anchors.bottom: PanelController.panelPosition === "bottom"
    anchors.left:   PanelController.panelPosition === "left"
    anchors.right:  PanelController.panelPosition === "right"

    margins {
        top: Config.panelMarginTop
        bottom: Config.panelMarginTop
        left: Config.panelMarginLeft
        right: Config.panelMarginRight
    }

    // Розмір вікна панелі по поперечній осі: для вертикального положення
    // ширина визначається найширишим вмістом (岛ков), щоб нічого не обрізало
    // clip-ом Island. Для горизонтального — ширина екрана.
    readonly property real panelContentWidth: {
        var w = Config.panelHeight
        if (leftZone) w = Math.max(w, leftZone.implicitWidth)
        if (centerZone) w = Math.max(w, centerZone.implicitWidth)
        if (rightZone) w = Math.max(w, rightZone.implicitWidth)
        return w
    }

    implicitWidth: PanelController.isHorizontal
        ? (barWindow.targetScreen && barWindow.targetScreen.width > 0 ? barWindow.targetScreen.width : Config.panelHeight * 40)
        : panelContentWidth
    implicitHeight: PanelController.isVertical
        ? (barWindow.targetScreen && barWindow.targetScreen.height > 0 ? barWindow.targetScreen.height : Config.panelHeight * 40)
        : Config.panelHeight
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    Binding {
        target: PanelController
        property: "panelScreen"
        value: barWindow.screenReady ? barWindow.targetScreen : null
    }
    // Живі розміри окна панелі — единый источник для толщины панели и
    // вертикальных попапов (ширина вертикальной панели зависит от контента).
    Binding {
        target: PanelController
        property: "panelWindowWidth"
        value: Math.max(Config.panelHeight, barWindow.width)
    }
    Binding {
        target: PanelController
        property: "panelWindowHeight"
        value: Math.max(Config.panelHeight, barWindow.height)
    }
    // Єдиний екземпляр MediaPlayerPanel публікується для сторінки налаштувань:
    // кнопка повторного пошуку текстів звертається до живого popup, не
    // створюючи другий екземпляр і не дублюючи MPRIS.
    Binding {
        target: PanelController
        property: "mediaPanel"
        value: mediaPanel
    }

    // --- Геометрія елементів ---
    readonly property int btnSize: Math.max(20, Math.min(32, Config.panelHeight - 8))
    readonly property int aiSize: Math.min(40, Config.panelHeight)

    // Позиція вікна панелі на екрані (для clamp попапів до меж монітора).
    readonly property var panelWindowPos: {
        var scr = barWindow.targetScreen
        if (!scr)
            return { x: 0, y: 0 }
        var x = scr.x
        var y = scr.y
        if (PanelController.panelPosition === "left")
            x = scr.x + Config.panelMarginLeft
        else if (PanelController.panelPosition === "right")
            x = scr.x + scr.width - barWindow.width - Config.panelMarginRight
        if (PanelController.panelPosition === "top")
            y = scr.y + Config.panelMarginTop
        else if (PanelController.panelPosition === "bottom")
            y = scr.y + scr.height - barWindow.height - Config.panelMarginTop
        return { x: x, y: y }
    }

    // popupOffset + утримання вікна в межах екрана. anchor.rect задається
    // відносно anchor.item, тому після clamp переводимо координати назад.
    // Все попапы панели используют эту функцию — она учитывает реальные
    // размеры окна панели (а не только высоту кнопки) и origin монитора.
    function popupAnchor(item, popupW, popupH, gap) {
        var off = PanelController.popupOffset(item, popupW, popupH, gap,
                                              barWindow.width, barWindow.height)
        var scr = barWindow.targetScreen
        if (!scr || !item)
            return off
        var p = PanelController.itemWindowPos(item)
        var baseX = barWindow.panelWindowPos.x + p.x
        var baseY = barWindow.panelWindowPos.y + p.y
        var minX = scr.x
        var maxX = Math.max(minX, scr.x + scr.width - popupW)
        var minY = scr.y
        var maxY = Math.max(minY, scr.y + scr.height - popupH)
        var cx = Math.max(minX, Math.min(maxX, baseX + off.x))
        var cy = Math.max(minY, Math.min(maxY, baseY + off.y))
        return { x: cx - baseX, y: cy - baseY }
    }

    // --- Звук ---
    property var sink: Pipewire.defaultAudioSink
    property real vol: sink && sink.audio ? sink.audio.volume : 0.0
    property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker { objects: [barWindow.sink] }

    // ============================================================
    // ЕДИНЫЙ КОНТРОЛЛЕР ВСПЛЫВАЮЩИХ ОКОН
    // ============================================================
    readonly property string activePopup:
        systemMenu.visible ? "dashboard"
        : (notificationHistory.visible ? "notifications"
        : (mediaPanel.visible ? "media" : "none"))

    function togglePopup(name) {
        if (name === "dashboard") {
            if (barWindow.activePopup === "dashboard") {
                systemMenu.closePanel()
            } else {
                notificationHistory.closeHistory()
                mediaPanel.closePanel()
                systemMenu.openPanel()
            }
        } else if (name === "notifications") {
            if (barWindow.activePopup === "notifications") {
                notificationHistory.closeHistory()
            } else {
                systemMenu.closePanel()
                mediaPanel.closePanel()
                notificationHistory.openHistory()
            }
        } else if (name === "media") {
            if (barWindow.activePopup === "media") {
                mediaPanel.closePanel()
            } else {
                systemMenu.closePanel()
                notificationHistory.closeHistory()
                mediaPanel.openPanel()
            }
        }
    }

    // ============================================================
    // АВТОСКРЫТИЕ ПАНЕЛИ
    // ============================================================
    property bool _autoHideShow: false
    readonly property bool autoHideVisible:
        !PanelController.autoHideEnabled
        || barWindow.activePopup !== "none"
        || barWindow._autoHideShow

    Timer {
        id: hideTimer
        interval: PanelController.autoHideDelay
        repeat: false
        onTriggered: if (barWindow.activePopup === "none") barWindow._autoHideShow = false
    }
    Timer {
        id: showTimer
        interval: PanelController.autoHideShowDelay
        repeat: false
        onTriggered: barWindow._autoHideShow = true
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (!PanelController.autoHideEnabled || barWindow.activePopup !== "none")
                return
            hideTimer.stop()
            if (barWindow.autoHideVisible) {
                barWindow._autoHideShow = true
                showTimer.stop()
            } else {
                showTimer.start()
            }
        }
        onExited: {
            if (!PanelController.autoHideEnabled || barWindow.activePopup !== "none")
                return
            showTimer.stop()
            if (barWindow.autoHideVisible)
                hideTimer.start()
        }
    }

    // --- Сама панель (фон) ---
    Rectangle {
        visible: Config.panelBackground
        opacity: barContent.opacity
        anchors.fill: parent
        radius: Math.min(Config.panelRadius, barWindow.height / 2)
        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg ? "transparent" : Theme.glassBg
        border.color: Theme.glassBorder
        border.width: 1

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
            intensity: Theme.cfgGradientIntensity
            target: "bg"
            solidColor: Theme.glassBg
            radius: Math.min(Config.panelRadius, barWindow.height / 2)
            clip: true
        }

        Behavior on radius {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
        }
    }

    // Root content container
    Item {
        id: barContent
        anchors.fill: parent
        opacity: barWindow.autoHideVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: PanelController.autoHideEnabled ? Theme.animNormal : 0
                easing.type: Theme.easingStandard
            }
        }

        // ============================================================
        // LOGICAL ZONES (LEGO Конструктор)
        // ============================================================

        // --- LeftZone ---
        BarZone {
            id: leftZone
            zoneName: "left"
            modules: Config.panelLayout.left
            barWindow: barWindow
            anchors.left: PanelController.isHorizontal ? parent.left : undefined
            anchors.top: PanelController.isVertical ? parent.top : undefined
            anchors.verticalCenter: PanelController.isHorizontal ? parent.verticalCenter : undefined
            anchors.horizontalCenter: PanelController.isVertical ? parent.horizontalCenter : undefined
        }

        // --- CenterZone ---
        BarZone {
            id: centerZone
            zoneName: "center"
            modules: Config.panelLayout.center
            barWindow: barWindow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: PanelController.isHorizontal ? parent.verticalCenter : undefined
            anchors.top: PanelController.isVertical ? leftZone.bottom : undefined
            anchors.topMargin: PanelController.isVertical ? Config.panelBlockSpacing : 0
        }

        // --- RightZone ---
        BarZone {
            id: rightZone
            zoneName: "right"
            modules: Config.panelLayout.right
            barWindow: barWindow
            anchors.right: PanelController.isHorizontal ? parent.right : undefined
            anchors.bottom: PanelController.isVertical ? parent.bottom : undefined
            anchors.verticalCenter: PanelController.isHorizontal ? parent.verticalCenter : undefined
            anchors.horizontalCenter: PanelController.isVertical ? parent.horizontalCenter : undefined
        }

        // --- Випадаючі вікна ---
        DashboardMenu {
            id: systemMenu
            readonly property var anchorTarget: barWindow.clockAnchorItem || centerZone
            anchor.window: barWindow
            anchor.item: anchorTarget
            anchor.rect.x: barWindow.popupAnchor(anchorTarget, systemMenu.implicitWidth, systemMenu.implicitHeight, 6).x
            anchor.rect.y: barWindow.popupAnchor(anchorTarget, systemMenu.implicitWidth, systemMenu.implicitHeight, 6).y
            onOpenControlCenter: barWindow.openControlCenterRequested()
        }

        NotificationHistory {
            id: notificationHistory
            dashboard: systemMenu
            readonly property var anchorTarget: barWindow.notifAnchorItem || rightZone
            anchor.window: barWindow
            anchor.item: anchorTarget
            anchor.rect.x: barWindow.popupAnchor(anchorTarget, notificationHistory.implicitWidth, notificationHistory.implicitHeight, 6).x
            anchor.rect.y: barWindow.popupAnchor(anchorTarget, notificationHistory.implicitWidth, notificationHistory.implicitHeight, 6).y
        }

        // Окрема панель медіаплеєра: відкривається лише з LEGO-модуля
        // BarMediaPlayer. Модуль публікує свій MPRIS-плеєр і якір у TopBar.
        MediaPlayerPanel {
            id: mediaPanel
            player: barWindow.mediaPlayer
            mediaType: barWindow.mediaType
            readonly property var anchorTarget: barWindow.mediaAnchorItem || centerZone
            anchor.window: barWindow
            anchor.item: anchorTarget
            anchor.rect.x: barWindow.popupAnchor(anchorTarget, mediaPanel.implicitWidth, mediaPanel.implicitHeight, 6).x
            anchor.rect.y: barWindow.popupAnchor(anchorTarget, mediaPanel.implicitWidth, mediaPanel.implicitHeight, 6).y
        }

        WifiMenu {
            id: wifiMenu
            readonly property var anchorTarget: barWindow.wifiAnchorItem || rightZone
            anchor.window: barWindow
            anchor.item: anchorTarget
            anchor.rect.x: barWindow.popupAnchor(anchorTarget, wifiMenu.implicitWidth, wifiMenu.implicitHeight, 6).x
            anchor.rect.y: barWindow.popupAnchor(anchorTarget, wifiMenu.implicitWidth, wifiMenu.implicitHeight, 6).y
        }

        BluetoothMenu {
            id: bluetoothMenu
            readonly property var anchorTarget: barWindow.btAnchorItem || rightZone
            anchor.window: barWindow
            anchor.item: anchorTarget
            anchor.rect.x: barWindow.popupAnchor(anchorTarget, bluetoothMenu.implicitWidth, bluetoothMenu.implicitHeight, 6).x
            anchor.rect.y: barWindow.popupAnchor(anchorTarget, bluetoothMenu.implicitWidth, bluetoothMenu.implicitHeight, 6).y
        }
    }
}
