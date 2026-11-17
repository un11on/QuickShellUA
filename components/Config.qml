pragma Singleton
import QtQuick 2.15
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Absolute path to the JSON config file
    property string configPath: Quickshell.shellDir + "/settings.json"

    // ----- Default configuration structure -----
    property var defaults: ({
        "Panel": {
            "height": 40,
            "margin": 6,
            "marginTop": 6,
            "marginLeft": 10,
            "marginRight": 10,
            "radius": 20,
            "islandRadius": 20,
            "background": false,
            "blockSpacing": 8,
            "islandPadH": 10,
            "islandSpacing": 6,
            "maxWidth": 0,
            "density": "normal",
            // Положение панели: top | bottom | left | right
            "position": "top",
            // Автоскрытие панели
            "autoHide": false,
            "autoHideDelay": 300,
            "autoHideShowDelay": 150,
            "autoHideEdgeZone": 10,
            // Активный пресет оформления панели ("Default" … "Custom" = ручные настройки)
            "preset": "Default",
            // Стиль індикатора робочих столів:
            // smart | dots | segments | blocks | bars
            "workspaceStyle": "smart",
            // Визуальные дополнения пресетов
            "shadow": true,
            "blur": true,
            // Раскладка конструктора панели: левая, центральная, правая зоны и отключённые
            "layout": {
                "left": [
                    { "id": "workspaces", "size": "normal", "display": "both" }
                ],
                "center": [
                    { "id": "clock", "size": "normal", "display": "both" }
                ],
                "right": [
                    { "id": "wifi", "size": "normal", "display": "icon" },
                    { "id": "bluetooth", "size": "normal", "display": "icon" },
                    { "id": "volume", "size": "normal", "display": "icon" },
                    { "id": "notifications", "size": "normal", "display": "icon" },
                    { "id": "tray", "size": "normal", "display": "icon" },
                    { "id": "ai", "size": "normal", "display": "icon" }
                ],
                "disabled": [
                    { "id": "activewindow", "size": "normal", "display": "both" },
                    { "id": "mediaplayer", "size": "normal", "display": "both",
                      "showArt": true, "showArtist": true, "showTitle": true,
                      "showControls": true, "maxTitleLength": 28,
                      "titleWidth": 0, "coverSize": 0 }
                ]
            }
        },
        "Theme": {
            "background": "#11111b",
            "surface": "#313244",
            "accent": "#89b4fa",
            "secondaryAccent": "#cba6f7",
            "text": "#cdd6f4",
            "secondaryText": "#a6adc8",
            "border": "#45475a",
            "success": "#a6e3a1",
            "warning": "#f9e2af",
            "error": "#f38ba8",
            "opacity": 0.8,
            "gradientEnabled": false,
            "gradientColor1": "#11111b",
            "gradientColor2": "#313244",
            "gradientColor3": "",
            "gradientDirection": "horizontal",
            "gradientIntensity": 1.0,
            "gradientApplyBg": false,
            "gradientApplySurf": false,
            "customThemes": {}
        },
        "Animations": {
            "enabled": true,
            "duration": 140,
            "springEnabled": false,
            "springStiffness": 150,
            "springDamping": 18,
            "overshoot": 1.2,
            "window": 1.0,
            "popup": 1.0,
            "element": 1.0,
            "tab": 1.0,
            "hover": 1.0,
            "panel": 1.0
        },
        "Notifications": {
            "dnd": false
        },
        "Widgets": {
            "workspaces": true,
            "clock": true,
            "volume": true,
            "bluetooth": true,
            "ai": true,
            "dashboard": true
        },
        "Monitors": {
            // Режим декількох моніторів: TopBar закріплюється за основним.
            "multiMonitorMode": false,
            // Ім'я connector'а (реальний ідентифікатор, наприклад "HDMI-A-1").
            // Порожній рядок = основний ще не обрано.
            "primary": ""
        },
        // Налаштування медіаплеєра (вкладка «Медіаплеєр»).
        // TopBar-блок (розмір, обкладинка, назва, кнопки) живе у Panel.layout
        // як звичайний LEGO-модуль; тут — лише Lyrics і поведінка.
        // Геометрія popup фіксована в MediaPlayerPanel і не дублюється тут.
        "MediaPlayer": {
            // ---- Lyrics ----
            "lyricsEnabled": true,
            "lyricsAutoFetch": true,
            "lyricsHeight": 112,
            // ---- Lyrics Presets: оформлення тексту ----
            // Активний пресет (classic | karaoke | minimal | glass) та його
            // параметри: користувач може відійти від пресета — тоді значення
            // відрізняються від дефолтів пресета (стан «custom»).
            "lyricsPreset": "classic",
            "lyricsFontSize": 11,
            "lyricsTextColor": "",
            "lyricsActiveColor": "",
            "lyricsBgOpacity": 0.6,
            "lyricsAlign": "center",
            "lyricsLineSpacing": 1.25,
            // ---- Поведінка ----
            "openOnClick": true,
            "closeOnEscape": true
        },
        "Wallpaper": {
            // Папка колекції (лише вона сканується, maxdepth 1)
            "folder": "~/Pictures",
            // "All" або ім'я конкретного виходу Hyprland
            "monitor": "All",
            // fill | fit | stretch | center
            "fillMode": "fill",
            // Останні успішно застосовані обої (для відновлення після запуску)
            "currentPath": "",
            "currentMonitor": "All",
            "restoreOnStartup": true,
            "openOnStartup": false
        }
    })

    // Live configuration (starts with defaults, will be merged with saved values)
    property var settings: defaults

    // Внутренняя защита: true, если UI уже менял настройки раньше,
    // чем асинхронная подгрузка файла завершилась (не даём load-моменту
    // перетереть живые изменения)
    property bool _dirty: false

    // ----- FileView for atomic read/write -----
    property FileView cfgFile: FileView {
        path: root.configPath
        blockLoading: true
        onLoaded: {
            var raw = text()
            if (!raw || raw.trim() === "") {
                if (root._dirty) {
                    console.warn("Config: file empty but live changes exist – keeping them")
                } else {
                    setText(JSON.stringify(root.defaults, null, 4))
                    root.settings = root.defaults
                }
            } else {
                try {
                    var parsed = JSON.parse(raw)
                    if (root._dirty) {
                        console.warn("Config: file loaded after live changes – keeping live state")
                    } else {
                        root.settings = root.mergeDefaults(root._migrateLegacy(parsed), root.defaults)
                    }
                } catch (e) {
                    console.warn("Config: malformed JSON – " + e + ", using defaults")
                    if (!root._dirty)
                        root.settings = root.defaults
                }
            }
        }
        onLoadFailed: {
            console.warn("Config: loadFailed, using defaults")
            if (root._dirty) {
                console.warn("Config: keeping live changes despite load failure")
                return
            }
            setText(JSON.stringify(root.defaults, null, 4))
            root.settings = root.defaults
        }
        onSaved: {
            console.log("Config: saved successfully")
        }
        onSaveFailed: {
            console.error("Config: saveFailed")
        }
    }

    // ----- Auto-save debounce timer -----
    property Timer saveTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: root.save()
    }

    // ----- One-time migration of old semantics -----
    // islandRadius: 0 раньше означало "як Panel.radius"; после разделения радиусов
    // 0 = квадратные углы. Пользовательское 0 пришло из дефолта прошлой версии,
    // поэтому поднимаем его до дефолтного радиуса, НО только для файлов старого
    // поколения (без ключа background): как только любые изменения сохранят файл
    // (в нём появится background), повторная миграция не сработает и
    // осознанное значение 0 сохранится.
    function _migrateLegacy(parsed) {
        if (parsed && parsed.Panel
                && !("background" in parsed.Panel)
                && "islandRadius" in parsed.Panel
                && parsed.Panel.islandRadius === 0) {
            parsed.Panel.islandRadius = defaults.Panel.islandRadius
        }
        // Нові кольори палітри: для старих файлів без них підбираємо
        // контрастні text/border для світлого фону, не ламаючи старі теми.
        if (parsed && parsed.Theme) {
            var bg = String(parsed.Theme.background || "")
            if (!("text" in parsed.Theme) || !("secondaryText" in parsed.Theme)
                    || !("border" in parsed.Theme)) {
                var light = false
                if (/^#[0-9A-Fa-f]{6}$/.test(bg)) {
                    var r = parseInt(bg.substr(1, 2), 16) / 255
                    var g = parseInt(bg.substr(3, 2), 16) / 255
                    var b = parseInt(bg.substr(5, 2), 16) / 255
                    light = (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.5
                }
                if (!("text" in parsed.Theme))
                    parsed.Theme.text = light ? "#1e1e2e" : defaults.Theme.text
                if (!("secondaryText" in parsed.Theme))
                    parsed.Theme.secondaryText = light ? "#5c5f77" : defaults.Theme.secondaryText
                if (!("border" in parsed.Theme))
                    parsed.Theme.border = light ? "#ccd0da" : defaults.Theme.border
            }
        }
        // Раскладка конструктора панели: если в старом файле нет layout
        if (parsed && parsed.Panel && !parsed.Panel.layout) {
            var defLayout = root.getPresetLayout("Classic")
            if (parsed.Widgets) {
                var znList = ["left", "center", "right"]
                var widMap = {
                    "workspaces": parsed.Widgets.workspaces,
                    "clock": parsed.Widgets.clock,
                    "volume": parsed.Widgets.volume,
                    "bluetooth": parsed.Widgets.bluetooth,
                    "ai": parsed.Widgets.ai
                }
                for (var z = 0; z < znList.length; z++) {
                    var zn = znList[z]
                    var kept = []
                    for (var m = 0; m < defLayout[zn].length; m++) {
                        var it = defLayout[zn][m]
                        if (widMap[it.id] === false) {
                            it.enabled = false
                            defLayout.disabled.push(it)
                        } else {
                            kept.push(it)
                        }
                    }
                    defLayout[zn] = kept
                }
            }
            parsed.Panel.layout = defLayout
        }
        return parsed
    }

    // ----- Пресеты конструктора панели -----
    function getPresetLayout(name) {
        if (name === "Minimal") {
            return {
                "left": [
                    { "id": "workspaces", "size": "compact", "display": "icon", "enabled": true }
                ],
                "center": [
                    { "id": "clock", "size": "compact", "display": "text", "enabled": true }
                ],
                "right": [
                    { "id": "volume", "size": "compact", "display": "icon", "enabled": true },
                    { "id": "notifications", "size": "compact", "display": "icon", "enabled": true },
                    { "id": "tray", "size": "compact", "display": "icon", "enabled": true }
                ],
                "disabled": [
                    { "id": "activewindow", "size": "compact", "display": "both", "enabled": false },
                    { "id": "wifi", "size": "compact", "display": "icon", "enabled": false },
                    { "id": "bluetooth", "size": "compact", "display": "icon", "enabled": false },
                    { "id": "ai", "size": "compact", "display": "icon", "enabled": false }
                ]
            }
        } else if (name === "Cyber") {
            return {
                "left": [
                    { "id": "workspaces", "size": "expanded", "display": "both", "enabled": true },
                    { "id": "activewindow", "size": "normal", "display": "both", "enabled": true }
                ],
                "center": [
                    { "id": "clock", "size": "expanded", "display": "both", "enabled": true }
                ],
                "right": [
                    { "id": "wifi", "size": "normal", "display": "both", "enabled": true },
                    { "id": "volume", "size": "normal", "display": "both", "enabled": true },
                    { "id": "bluetooth", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "notifications", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "tray", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "ai", "size": "expanded", "display": "both", "enabled": true }
                ],
                "disabled": []
            }
        } else if (name === "Full Control") {
            return {
                "left": [
                    { "id": "workspaces", "size": "normal", "display": "both", "enabled": true },
                    { "id": "activewindow", "size": "expanded", "display": "both", "enabled": true }
                ],
                "center": [
                    { "id": "clock", "size": "normal", "display": "both", "enabled": true },
                    { "id": "notifications", "size": "normal", "display": "both", "enabled": true }
                ],
                "right": [
                    { "id": "wifi", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "bluetooth", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "volume", "size": "normal", "display": "both", "enabled": true },
                    { "id": "tray", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "ai", "size": "normal", "display": "icon", "enabled": true }
                ],
                "disabled": []
            }
        } else { // "Classic" or default
            return {
                "left": [
                    { "id": "workspaces", "size": "normal", "display": "both", "enabled": true }
                ],
                "center": [
                    { "id": "clock", "size": "normal", "display": "both", "enabled": true }
                ],
                "right": [
                    { "id": "wifi", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "bluetooth", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "volume", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "notifications", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "tray", "size": "normal", "display": "icon", "enabled": true },
                    { "id": "ai", "size": "normal", "display": "icon", "enabled": true }
                ],
                "disabled": [
                    { "id": "activewindow", "size": "normal", "display": "both", "enabled": false }
                ]
            }
        }
    }

    function normalizeLayout(layout) {
        var allIds = ["workspaces", "activewindow", "clock", "wifi", "bluetooth", "volume", "notifications", "tray", "ai", "mediaplayer"]
        var res = {
            left: (layout && Array.isArray(layout.left)) ? JSON.parse(JSON.stringify(layout.left)) : [],
            center: (layout && Array.isArray(layout.center)) ? JSON.parse(JSON.stringify(layout.center)) : [],
            right: (layout && Array.isArray(layout.right)) ? JSON.parse(JSON.stringify(layout.right)) : [],
            disabled: (layout && Array.isArray(layout.disabled)) ? JSON.parse(JSON.stringify(layout.disabled)) : []
        }
        var found = {}
        var zones = ["left", "center", "right", "disabled"]
        for (var z = 0; z < zones.length; z++) {
            var zone = zones[z]
            var filtered = []
            for (var i = 0; i < res[zone].length; i++) {
                var mod = res[zone][i]
                if (mod && mod.id && allIds.indexOf(mod.id) >= 0 && !found[mod.id]) {
                    found[mod.id] = true
                    if (!mod.size) mod.size = "normal"
                    if (!mod.display) mod.display = (mod.id === "wifi" || mod.id === "bluetooth" || mod.id === "volume" || mod.id === "tray" || mod.id === "notifications" || mod.id === "ai") ? "icon" : "both"
                    if (mod.id === "mediaplayer") {
                        if (mod.showArt === undefined) mod.showArt = true
                        if (mod.showArtist === undefined) mod.showArtist = true
                        if (mod.showTitle === undefined) mod.showTitle = true
                        if (mod.showControls === undefined) mod.showControls = true
                        if (mod.maxTitleLength === undefined) mod.maxTitleLength = 28
                        // 0 = автоматично за режимом compact/normal/expanded.
                        if (mod.titleWidth === undefined) mod.titleWidth = 0
                        if (mod.coverSize === undefined) mod.coverSize = 0
                    }
                    mod.enabled = (zone !== "disabled")
                    filtered.push(mod)
                }
            }
            res[zone] = filtered
        }
        for (var k = 0; k < allIds.length; k++) {
            var mid = allIds[k]
            if (!found[mid]) {
                var disabledMod = {
                    id: mid,
                    size: "normal",
                    display: (mid === "wifi" || mid === "bluetooth" || mid === "volume" || mid === "tray" || mid === "notifications" || mid === "ai") ? "icon" : "both",
                    enabled: false
                }
                if (mid === "mediaplayer") {
                    disabledMod.showArt = true
                    disabledMod.showArtist = true
                    disabledMod.showTitle = true
                    disabledMod.showControls = true
                    disabledMod.maxTitleLength = 28
                    disabledMod.titleWidth = 0
                    disabledMod.coverSize = 0
                }
                res.disabled.push(disabledMod)
            }
        }
        return res
    }

    function setPanelLayout(layout) {
        var updated = JSON.parse(JSON.stringify(settings))
        if (!updated.Panel) updated.Panel = {}
        var norm = normalizeLayout(layout)
        updated.Panel.layout = norm
        _syncWidgetsFromLayout(norm, updated)
        _dirty = true
        settings = updated
        saveTimer.restart()
    }

    // Зміна властивості конкретного LEGO-модуля (наприклад mediaplayer).
    // Використовується і конструктором панелі, і вкладкою «Медіаплеєр»,
    // щоб не дублювати логіку пошуку модуля по зонах.
    function setLayoutModuleProp(id, prop, value) {
        var cur = normalizeLayout(panelLayout)
        var zones = ["left", "center", "right", "disabled"]
        for (var z = 0; z < zones.length; z++) {
            var list = cur[zones[z]]
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === id) {
                    list[i][prop] = value
                    setPanelLayout(cur)
                    return true
                }
            }
        }
        return false
    }

    function applyPanelPreset(name) {
        var preset = getPresetLayout(name)
        if (preset) {
            var updated = JSON.parse(JSON.stringify(settings))
            if (!updated.Panel) updated.Panel = {}
            var norm = normalizeLayout(preset)
            updated.Panel.layout = norm
            updated.Panel.preset = name
            _syncWidgetsFromLayout(norm, updated)
            _dirty = true
            settings = updated
            saveTimer.restart()
        }
    }

    function _syncWidgetsFromLayout(layout, updated) {
        if (!updated.Widgets) updated.Widgets = {}
        var activeIds = {}
        var activeZones = ["left", "center", "right"]
        for (var z = 0; z < activeZones.length; z++) {
            var list = layout[activeZones[z]] || []
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].enabled !== false)
                    activeIds[list[i].id] = true
            }
        }
        updated.Widgets.workspaces = !!activeIds["workspaces"]
        updated.Widgets.clock = !!activeIds["clock"]
        updated.Widgets.volume = !!activeIds["volume"]
        updated.Widgets.bluetooth = !!activeIds["bluetooth"]
        updated.Widgets.ai = !!activeIds["ai"]
        updated.Widgets.dashboard = !!activeIds["clock"]
    }

    // ----- Helper: deep merge -----
    function mergeDefaults(source, def) {
        var result = {}
        // 1. Сохраняем все существующие ключи из source (пользовательские данные не теряются)
        if (source) {
            for (var key in source) {
                if (!source.hasOwnProperty(key)) continue
                result[key] = source[key]
            }
        }
        // 2. Дополняем отсутствующие ключи из defaults; рекурсивно объединяем вложенные объекты
        for (var key in def) {
            if (!def.hasOwnProperty(key)) continue
            if (!(key in result)) {
                result[key] = def[key]
            } else if (typeof def[key] === "object" && def[key] !== null && !Array.isArray(def[key])
                       && typeof result[key] === "object" && result[key] !== null && !Array.isArray(result[key])) {
                result[key] = mergeDefaults(result[key], def[key])
            }
        }
        return result
    }

    // ----- Save configuration using FileView -----
    function save() {
        cfgFile.setText(JSON.stringify(settings, null, 4))
    }

    // ----- Reset to defaults (deep clone) -----
    function reset() {
        settings = JSON.parse(JSON.stringify(defaults))
        save()
    }

    // ----- Helper to retrieve default value for a path -----
    function _defaultForPath(path) {
        var parts = path.split(".")
        var node = defaults
        for (var i = 0; i < parts.length; ++i) {
            if (node && node.hasOwnProperty(parts[i])) {
                node = node[parts[i]]
            } else {
                return undefined
            }
        }
        return node
    }

    // ----- Safe generic setter -----
    function setProp(path, value) {
        if (typeof path !== "string" || path.length === 0) {
            console.warn("Config: setProp called with empty path")
            return
        }
        var parts = path.split(".")
        var defVal = _defaultForPath(path)
        if (defVal === undefined) {
            console.warn("Config: setProp unknown path '" + path + "', ignoring")
            return
        }
        if (typeof defVal !== typeof value) {
            if (typeof defVal === "number" && typeof value === "string") {
                var num = Number(value)
                if (!isNaN(num)) value = num
                else {
                    console.warn("Config: setProp cannot convert '" + value + "' to number")
                    return
                }
            } else {
                console.warn("Config: setProp type mismatch for '" + path + "', expected " + typeof defVal)
                return
            }
        }
        // Клонируем ДО мутации (чтобы чистые defaults не загрязнялись и reset работал корректно),
        // но присваиваем ПОСЛЕ мутации — тогда сигнал смены settings сообщит binding'ам уже новые значения
        var updated = JSON.parse(JSON.stringify(settings))
        var obj = updated
        for (var i = 0; i < parts.length - 1; ++i) {
            if (!obj.hasOwnProperty(parts[i])) {
                console.warn("Config: setProp missing intermediate object for '" + path + "'")
                return
            }
            obj = obj[parts[i]]
        }
        obj[parts[parts.length - 1]] = value
        _dirty = true
        settings = updated
        saveTimer.restart()
    }

    // ----- Expose leaf properties for direct binding -----
    // Panel
    property int panelHeight: settings.Panel.height
    property int panelMargin: settings.Panel.margin
    property int panelRadius: settings.Panel.radius
    property int panelMarginTop: settings.Panel.marginTop
    property int panelMarginLeft: settings.Panel.marginLeft
    property int panelMarginRight: settings.Panel.marginRight
    property int panelIslandRadius: settings.Panel.islandRadius
    property bool panelBackground: settings.Panel.background
    property int panelBlockSpacing: settings.Panel.blockSpacing
    property int panelIslandPadH: settings.Panel.islandPadH
    property int panelIslandSpacing: settings.Panel.islandSpacing
    property int panelMaxWidth: settings.Panel.maxWidth
    property string panelDensity: settings.Panel.density
    // Положение панели и автоскрытие
    property string panelPosition: settings.Panel.position
    property bool panelAutoHide: settings.Panel.autoHide
    property int panelAutoHideDelay: settings.Panel.autoHideDelay
    property int panelAutoHideShowDelay: settings.Panel.autoHideShowDelay
    property int panelAutoHideEdgeZone: settings.Panel.autoHideEdgeZone
    // Активный пресет оформления панели
    property string panelPreset: settings.Panel.preset
    // Стиль індикатора робочих столів у TopBar
    property string panelWorkspaceStyle: settings.Panel.workspaceStyle
    // Визуальные дополнения пресета
    property bool panelShadow: settings.Panel.shadow
    property bool panelBlur: settings.Panel.blur
    // Конструктор панели (раскладка зон и модулей)
    property var panelLayout: (settings && settings.Panel && settings.Panel.layout) ? settings.Panel.layout : defaults.Panel.layout
    // Theme
    property string themeBackground: settings.Theme.background
    property string themeSurface: settings.Theme.surface
    property string themeAccent: settings.Theme.accent
    property string themeSecondaryAccent: settings.Theme.secondaryAccent
    property string themeText: settings.Theme.text
    property string themeSecondaryText: settings.Theme.secondaryText
    property string themeBorder: settings.Theme.border
    property string themeSuccess: settings.Theme.success
    property string themeWarning: settings.Theme.warning
    property string themeError: settings.Theme.error
    property real   themeOpacity: settings.Theme.opacity
    // Gradient Studio
    property bool   themeGradientEnabled: settings.Theme.gradientEnabled
    property string themeGradientColor1: settings.Theme.gradientColor1
    property string themeGradientColor2: settings.Theme.gradientColor2
    property string themeGradientColor3: settings.Theme.gradientColor3
    property string themeGradientDirection: settings.Theme.gradientDirection
    property real   themeGradientIntensity: settings.Theme.gradientIntensity
    property bool   themeGradientApplyBg: settings.Theme.gradientApplyBg
    property bool   themeGradientApplySurf: settings.Theme.gradientApplySurf
    property var    themeCustomThemes: settings.Theme.customThemes
    // Animations
    property bool   animationsEnabled: settings.Animations.enabled
    property int    animationsDuration: settings.Animations.duration
    property bool   animationsSpringEnabled: settings.Animations.springEnabled
    property int    animationsSpringStiffness: settings.Animations.springStiffness
    property int    animationsSpringDamping: settings.Animations.springDamping
    property real   animationsOvershoot: settings.Animations.overshoot
    property real   animationsWindow: settings.Animations.window
    property real   animationsPopup: settings.Animations.popup
    property real   animationsElement: settings.Animations.element
    property real   animationsTab: settings.Animations.tab
    property real   animationsHover: settings.Animations.hover
    property real   animationsPanel: settings.Animations.panel
    // Notifications
    property bool   notificationsDnd: settings.Notifications.dnd
    // Widgets
    property bool   widgetWorkspaces: settings.Widgets.workspaces
    property bool   widgetClock: settings.Widgets.clock
    property bool   widgetVolume: settings.Widgets.volume
    property bool   widgetBluetooth: settings.Widgets.bluetooth
    property bool   widgetAI: settings.Widgets.ai
    property bool   widgetDashboard: settings.Widgets.dashboard
    // Monitors
    property bool   monitorsMultiMonitorMode: settings.Monitors.multiMonitorMode
    property string monitorsPrimary: settings.Monitors.primary
    // Media Player Studio (popup geometry is fixed in MediaPlayerPanel)
    property bool   mediaPlayerLyricsEnabled: settings.MediaPlayer.lyricsEnabled
    property bool   mediaPlayerLyricsAutoFetch: settings.MediaPlayer.lyricsAutoFetch
    property int    mediaPlayerLyricsHeight: settings.MediaPlayer.lyricsHeight
    // Lyrics Presets (оформлення тексту)
    property string mediaPlayerLyricsPreset: settings.MediaPlayer.lyricsPreset
    property int    mediaPlayerLyricsFontSize: settings.MediaPlayer.lyricsFontSize
    property string mediaPlayerLyricsTextColor: settings.MediaPlayer.lyricsTextColor
    property string mediaPlayerLyricsActiveColor: settings.MediaPlayer.lyricsActiveColor
    property real   mediaPlayerLyricsBgOpacity: settings.MediaPlayer.lyricsBgOpacity
    property string mediaPlayerLyricsAlign: settings.MediaPlayer.lyricsAlign
    property real   mediaPlayerLyricsLineSpacing: settings.MediaPlayer.lyricsLineSpacing
    property bool   mediaPlayerOpenOnClick: settings.MediaPlayer.openOnClick
    property bool   mediaPlayerCloseOnEscape: settings.MediaPlayer.closeOnEscape
    // Wallpaper Studio
    property string wallpaperFolder: settings.Wallpaper.folder
    property string wallpaperMonitor: settings.Wallpaper.monitor
    property string wallpaperFillMode: settings.Wallpaper.fillMode
    property string wallpaperCurrentPath: settings.Wallpaper.currentPath
    property string wallpaperCurrentMonitor: settings.Wallpaper.currentMonitor
    property bool   wallpaperRestoreOnStartup: settings.Wallpaper.restoreOnStartup
    property bool   wallpaperOpenOnStartup: settings.Wallpaper.openOnStartup

    property var _dummy: settings
}
