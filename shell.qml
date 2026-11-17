//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "./components"
import "./components/widgets"

ShellRoot {
    id: root

    // Єдиний host-screen для shell. Довготривало зберігається лише ім'я:
    // ShellScreen після відключення стає dangling і не оживає при reconnect.
    readonly property int hostFailoverGraceMs: 250
    property string hostScreenName: ""
    readonly property var hostScreen: root.screenByName(root.hostScreenName)
    property bool hostTransitioning: true
    property bool hostGraceExpired: false
    property int hostTransitionGeneration: 0

    // Основний монітор із settings.json (лише для режиму декількох моніторів).
    // Порожній рядок = режим вимкнено або монітор ще не обрано: поведінка
    // залишається такою самою, як із одним дисплеєм.
    property string configuredPrimaryName: Config.monitorsMultiMonitorMode
        ? String(Config.monitorsPrimary || "") : ""

    onConfiguredPrimaryNameChanged: Qt.callLater(root.reconcileScreens)

    // Глобальне состояние видимості ІІ-панелі
    property bool aiSidebarVisible: false

    function screenByName(name) {
        if (!name)
            return null

        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; ++i) {
            var candidate = screens[i]
            if (candidate && candidate.name === name)
                return candidate
        }
        return null
    }

    function focusedAvailableScreen() {
        var focused = Hyprland.focusedMonitor
        return focused ? root.screenByName(focused.name) : null
    }

    function geometricFallbackScreen() {
        var screens = Quickshell.screens
        var best = null

        for (var i = 0; i < screens.length; ++i) {
            var candidate = screens[i]
            if (!candidate)
                continue
            if (!best
                    || candidate.x < best.x
                    || (candidate.x === best.x && candidate.y < best.y)
                    || (candidate.x === best.x && candidate.y === best.y
                        && candidate.name < best.name)) {
                best = candidate
            }
        }
        return best
    }

    function fallbackScreen() {
        return root.focusedAvailableScreen() || root.geometricFallbackScreen()
    }

    function scheduleHostReady(expectedName) {
        hostFailoverTimer.stop()
        root.hostGraceExpired = false
        root.hostTransitioning = true
        root.hostTransitionGeneration++
        Qt.callLater(root.finishHostTransition,
                     root.hostTransitionGeneration,
                     expectedName)
    }

    function assignHostScreen(screen) {
        if (!screen)
            return

        // Той самий connector уже host: не перезапускаємо transition, щоб
        // TopBar не ховався/показувався на кожному reconcile.
        if (root.hostScreenName === screen.name) {
            if (root.hostTransitioning)
                root.scheduleHostReady(screen.name)
            else {
                hostFailoverTimer.stop()
                root.hostGraceExpired = false
            }
            return
        }

        root.hostScreenName = screen.name
        root.scheduleHostReady(root.hostScreenName)
    }

    function finishHostTransition(generation, expectedName) {
        if (generation !== root.hostTransitionGeneration
                || expectedName !== root.hostScreenName)
            return

        if (!root.screenByName(expectedName)) {
            root.startHostGrace()
            return
        }

        root.hostGraceExpired = false
        root.hostTransitioning = false
    }

    function startHostGrace() {
        if (!root.hostScreenName) {
            root.hostTransitioning = true
            return
        }

        root.hostTransitioning = true
        root.hostGraceExpired = false
        root.hostTransitionGeneration++
        hostFailoverTimer.generation = root.hostTransitionGeneration
        hostFailoverTimer.missingName = root.hostScreenName
        hostFailoverTimer.restart()
    }

    function completeHostGrace(generation, missingName) {
        if (generation !== root.hostTransitionGeneration
                || missingName !== root.hostScreenName)
            return

        // Той самий connector повернувся до завершення grace period:
        // використовуємо новий живий ShellScreen і скасовуємо failover.
        if (root.screenByName(missingName)) {
            root.scheduleHostReady(missingName)
            return
        }

        root.hostGraceExpired = true
        var fallback = root.fallbackScreen()
        if (fallback)
            root.assignHostScreen(fallback)
    }

    function reconcileScreens() {
        // --- Режим декількох моніторів: TopBar лише на основному екрані ---
        if (root.configuredPrimaryName !== "") {
            var primary = root.screenByName(root.configuredPrimaryName)

            // Збережений основний підключений — він і є host. Ця ж гілка
            // повертає TopBar на нього після reconnect.
            if (primary) {
                root.assignHostScreen(primary)
                return
            }

            // Основний відключений: поточний живий host стає тимчасовим
            // fallback'ом і лишається ним до повернення збереженого монітора.
            var currentFallback = root.screenByName(root.hostScreenName)
            if (currentFallback) {
                if (root.hostTransitioning)
                    root.scheduleHostReady(root.hostScreenName)
                else {
                    hostFailoverTimer.stop()
                    root.hostGraceExpired = false
                }
                return
            }

            // Fallback ще не обрано — беремо будь-який доступний екран.
            var temporary = root.fallbackScreen()
            if (temporary)
                root.assignHostScreen(temporary)
            else
                root.hostTransitioning = true
            return
        }

        // --- Звичайна поведінка (один монітор / режим вимкнено) ---
        var current = root.screenByName(root.hostScreenName)

        if (current) {
            if (root.hostTransitioning)
                root.scheduleHostReady(root.hostScreenName)
            else {
                hostFailoverTimer.stop()
                root.hostGraceExpired = false
            }
            return
        }

        // Перший вибір після запуску або запуск без жодного екрана.
        if (!root.hostScreenName) {
            var initial = root.fallbackScreen()
            if (initial)
                root.assignHostScreen(initial)
            else
                root.hostTransitioning = true
            return
        }

        if (hostFailoverTimer.running)
            return

        // Grace уже минув без екранів. Перший доступний fallback вибираємо
        // відразу; якщо повернувся старий host, гілка current вище відновить його.
        if (root.hostGraceExpired) {
            var fallback = root.fallbackScreen()
            if (fallback)
                root.assignHostScreen(fallback)
            return
        }

        root.startHostGrace()
    }

    Timer {
        id: hostFailoverTimer
        interval: root.hostFailoverGraceMs
        repeat: false
        property int generation: -1
        property string missingName: ""
        onTriggered: root.completeHostGrace(generation, missingName)
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.reconcileScreens()
        }
    }

    Component.onCompleted: {
        Qt.callLater(root.reconcileScreens)
        WallpaperService.initialize()
    }

    // Desktop Widget Engine. It creates no fullscreen surfaces until at least
    // one enabled widget exists on a live screen or edit mode is requested.
    WidgetEngine {
        id: widgetEngine
        onOpenSettingsRequested: {
            controlCenter.currentPage = "widgets"
            controlCenter.open()
        }
    }

    // Публічний IPC для гарячих клавіш Quickshell.
    // Super + Z у hyprland.lua викликає `quickshell ipc call dashboard toggle`.
    // toggle() використовує той самий TopBar.togglePopup, що й клік по годиннику:
    // відкриває DashboardMenu.openPanel(), а при visible === true — closePanel().
    // Нові екземпляри вікна не створюються.
    IpcHandler {
        target: "dashboard"

        function open(): string {
            if (topBar.activePopup !== "dashboard")
                topBar.togglePopup("dashboard")
            return topBar.activePopup
        }

        function toggle(): string {
            topBar.togglePopup("dashboard")
            return topBar.activePopup
        }

        function close(): string {
            if (topBar.activePopup === "dashboard")
                topBar.togglePopup("dashboard")
            return topBar.activePopup
        }
    }

    // Верхня панель
    TopBar {
        id: topBar
        targetScreen: root.hostScreen
        targetScreenName: root.hostScreenName
        screenReady: !root.hostTransitioning && root.hostScreen !== null
        aiActive: aiSidebarVisible
        // Відкриття — миттєве; закриття — плавне (AiSidebar вміє анімувати свій виїзд)
    onToggleAiRequested: {
        if (aiSidebar.visible)
            aiSidebar.closeWithAnimation()
        else
            aiSidebarVisible = true
    }
        onOpenControlCenterRequested: controlCenter.toggle()
    }

    // Бокова панель ІІ-агента
    AiSidebar {
        id: aiSidebar
        visible: aiSidebarVisible
        onCloseRequested: aiSidebarVisible = false
    }

    // Control Center — вікно налаштувань
    ControlCenter {
        id: controlCenter
    }

    // Wallpaper Picker — окреме вікно (Super + A → IPC wallpaper toggle)
    WallpaperPicker {
        id: wallpaperPicker
        onSettingsRequested: {
            controlCenter.currentPage = "wallpaper"
            controlCenter.open()
        }
    }
}
