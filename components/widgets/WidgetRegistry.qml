pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int apiVersion: 1

    // Adding a built-in widget only requires one descriptor and one component.
    readonly property var definitions: [
        {
            id: "clock",
            name: "Годинник",
            description: "Цифровий час, дата та день тижня",
            category: "Productivity",
            icon: "󰥔",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/ClockWidget.qml"),
            minWidth: 180, minHeight: 90,
            defaultWidth: 300, defaultHeight: 150,
            resizable: true,
            multiple: true,
            defaults: {
                use24Hour: true,
                showSeconds: true,
                showDate: true,
                dateFormat: "long",
                transparent: false
            },
            settings: [
                { key: "use24Hour", type: "bool", label: "24-годинний формат" },
                { key: "showSeconds", type: "bool", label: "Показувати секунди" },
                { key: "showDate", type: "bool", label: "Показувати дату" },
                { key: "dateFormat", type: "choice", label: "Формат дати", options: ["long", "short", "iso"] },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "calendar",
            name: "Календар",
            description: "Місячний календар із навігацією",
            category: "Productivity",
            icon: "󰃭",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/CalendarWidget.qml"),
            minWidth: 300, minHeight: 280,
            defaultWidth: 380, defaultHeight: 360,
            resizable: true,
            multiple: true,
            defaults: {
                weekStartsMonday: true,
                showOutsideDays: true,
                transparent: false
            },
            settings: [
                { key: "weekStartsMonday", type: "bool", label: "Тиждень починається з понеділка" },
                { key: "showOutsideDays", type: "bool", label: "Дні сусідніх місяців" },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "weather",
            name: "Погода",
            description: "Поточна погода через Open-Meteo без API-ключа",
            category: "Weather",
            icon: "󰖐",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/WeatherWidget.qml"),
            minWidth: 240, minHeight: 140,
            defaultWidth: 340, defaultHeight: 200,
            resizable: true,
            multiple: true,
            defaults: {
                locationMode: "city",
                city: "",
                latitude: "",
                longitude: "",
                temperatureUnit: "celsius",
                transparent: false
            },
            settings: [
                { key: "locationMode", type: "choice", label: "Режим локації", options: ["city", "coordinates"] },
                { key: "city", type: "string", label: "Місто" },
                { key: "latitude", type: "string", label: "Широта" },
                { key: "longitude", type: "string", label: "Довгота" },
                { key: "temperatureUnit", type: "choice", label: "Одиниці", options: ["celsius", "fahrenheit"] },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "system-monitor",
            name: "Системний монітор",
            description: "CPU, GPU та оперативна пам'ять",
            category: "System",
            icon: "󰍛",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/SystemMonitorWidget.qml"),
            minWidth: 260, minHeight: 180,
            defaultWidth: 360, defaultHeight: 260,
            resizable: true,
            multiple: true,
            defaults: {
                showCpu: true,
                showRam: true,
                showGpu: true,
                transparent: false
            },
            settings: [
                { key: "showCpu", type: "bool", label: "CPU" },
                { key: "showRam", type: "bool", label: "RAM" },
                { key: "showGpu", type: "bool", label: "GPU" },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "network-monitor",
            name: "Мережевий монітор",
            description: "Швидкість мережі, IP-адреса, інтерфейс та VPN",
            category: "System",
            icon: "󰈀",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/NetworkMonitorWidget.qml"),
            minWidth: 240, minHeight: 200,
            defaultWidth: 320, defaultHeight: 300,
            resizable: true,
            multiple: false,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "battery",
            name: "Батарея та живлення",
            description: "Заряд батареї, стан зарядки та потужність",
            category: "System",
            icon: "󰂄",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/BatteryWidget.qml"),
            minWidth: 220, minHeight: 180,
            defaultWidth: 300, defaultHeight: 280,
            resizable: true,
            multiple: false,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "storage-monitor",
            name: "Монітор дисків",
            description: "Використання дисків та вільне місце",
            category: "System",
            icon: "󰋊",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/StorageMonitorWidget.qml"),
            minWidth: 240, minHeight: 180,
            defaultWidth: 320, defaultHeight: 300,
            resizable: true,
            multiple: false,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "system-uptime",
            name: "Аптайм системи",
            description: "Час роботи системи, дата запуску та поточний час",
            category: "System",
            icon: "󰔛",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/SystemUptimeWidget.qml"),
            minWidth: 200, minHeight: 150,
            defaultWidth: 300, defaultHeight: 220,
            resizable: true,
            multiple: false,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "workspace-overview",
            name: "Робочі столи",
            description: "Огляд та перемикання робочих столів Hyprland",
            category: "System",
            icon: "󰍹",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/WorkspaceOverviewWidget.qml"),
            minWidth: 200, minHeight: 140,
            defaultWidth: 340, defaultHeight: 220,
            resizable: true,
            multiple: false,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "pomodoro",
            name: "Помодоро",
            description: "Таймер роботи та відпочинку з відстеженням сесій",
            category: "Productivity",
            icon: "󰔟",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/PomodoroWidget.qml"),
            minWidth: 200, minHeight: 240,
            defaultWidth: 280, defaultHeight: 340,
            resizable: true,
            multiple: true,
            defaults: {
                workMinutes: 25,
                breakMinutes: 5,
                longBreakMinutes: 15,
                sessionsBeforeLong: 4,
                transparent: false
            },
            settings: [
                { key: "workMinutes", type: "string", label: "Робота (хв)" },
                { key: "breakMinutes", type: "string", label: "Перерва (хв)" },
                { key: "longBreakMinutes", type: "string", label: "Довга перерва (хв)" },
                { key: "sessionsBeforeLong", type: "string", label: "Сесій до довгої перерви" },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "quick-notes",
            name: "Нотатки",
            description: "Швидкі нотатки з автозбереженням",
            category: "Productivity",
            icon: "󰏪",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/QuickNotesWidget.qml"),
            minWidth: 200, minHeight: 160,
            defaultWidth: 300, defaultHeight: 280,
            resizable: true,
            multiple: true,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "tasks",
            name: "Задачі",
            description: "Список задач з пріоритетами та збереженням",
            category: "Productivity",
            icon: "󰄬",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/TasksWidget.qml"),
            minWidth: 220, minHeight: 200,
            defaultWidth: 320, defaultHeight: 360,
            resizable: true,
            multiple: true,
            defaults: {
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "audio-visualizer",
            name: "Аудіо візуалізатор",
            description: "Реальна візуалізація аудіосигналу через CAVA",
            category: "Productivity",
            icon: "󰎆",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/AudioVisualizerWidget.qml"),
            minWidth: 200, minHeight: 140,
            defaultWidth: 360, defaultHeight: 220,
            resizable: true,
            multiple: true,
            defaults: {
                animEnabled: true,
                barCount: 24,
                transparent: false
            },
            settings: [
                { key: "animEnabled", type: "bool", label: "Анімація" },
                { key: "barCount", type: "string", label: "Кількість смуг" },
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        },
        {
            id: "quick-launcher",
            name: "Швидкий запуск",
            description: "Запуск додатків із пошуком та обраним",
            category: "Productivity",
            icon: "󰀻",
            version: "1.0.0",
            component: Qt.resolvedUrl("widgets/QuickLauncherWidget.qml"),
            minWidth: 220, minHeight: 200,
            defaultWidth: 300, defaultHeight: 380,
            resizable: true,
            multiple: false,
            defaults: {
                favorites: [],
                transparent: false
            },
            settings: [
                { key: "transparent", type: "bool", label: "Прозорий фон" }
            ]
        }
    ]

    function get(widgetId) {
        for (var i = 0; i < root.definitions.length; ++i) {
            if (root.definitions[i].id === widgetId)
                return root.definitions[i]
        }
        return null
    }

    function cloneDefaults(widgetId) {
        var definition = root.get(widgetId)
        return definition ? JSON.parse(JSON.stringify(definition.defaults || {})) : ({})
    }

    function categories() {
        var result = ["All"]
        for (var i = 0; i < root.definitions.length; ++i) {
            var category = root.definitions[i].category
            if (result.indexOf(category) < 0)
                result.push(category)
        }
        return result
    }
}
