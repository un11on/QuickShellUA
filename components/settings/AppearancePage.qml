import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."
import "."  // явный импорт: ColorPickerPopup из qmldir текущего каталога
import "ThemePresets.js" as ThemePresets

Item {
    id: appearanceRoot

    function _updateGradientTargets() {
        // Background і Surface — незалежні перемикачі, не блокують один одного
    }

    // Кольори для live-preview градієнта: валідація + інтенсивність як у Theme
    function _previewGradColor(hex) {
        var s = String(hex || "")
        if (!/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(s))
            s = "#11111b"
        var c = Qt.color(s)
        var factor = 1.0 + (Config.themeGradientIntensity - 1.0) * 0.2
        return Qt.rgba(
            Math.min(1, Math.max(0, c.r * factor)),
            Math.min(1, Math.max(0, c.g * factor)),
            Math.min(1, Math.max(0, c.b * factor)), 1
        )
    }

    // --- Кастомні теми: збереження / застосування / видалення ---
    // Валідація hex: зіпсоване значення (не-колір) ніколи не потрапляє
    // ні в збережену тему, ні назад у Config — інакше Theme._safeColor
    // підставляє темний fallback і фон стає «чорним».
    function _safeHex(value, fallback) {
        var s = String(value === undefined || value === null ? "" : value)
        if (/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(s))
            return s
        return fallback
    }

    function _safeNum(value, fallback, min, max) {
        var v = Number(value)
        return (!isNaN(v) && v >= min && v <= max) ? v : fallback
    }

    function _saveCustomThemeNamed(rawName) {
        var name = String(rawName || "").trim()
        if (!name || name.length === 0) return false
        if (Config.themeCustomThemes[name]) {
            console.warn("Custom theme already exists: " + name)
            return false
        }
        var updated = JSON.parse(JSON.stringify(Config.themeCustomThemes))
        updated[name] = {
            background: _safeHex(Config.themeBackground, "#11111b"),
            surface: _safeHex(Config.themeSurface, "#313244"),
            accent: _safeHex(Config.themeAccent, "#89b4fa"),
            secondaryAccent: _safeHex(Config.themeSecondaryAccent, "#cba6f7"),
            text: _safeHex(Config.themeText, "#cdd6f4"),
            secondaryText: _safeHex(Config.themeSecondaryText, "#a6adc8"),
            border: _safeHex(Config.themeBorder, "#45475a"),
            success: _safeHex(Config.themeSuccess, "#a6e3a1"),
            warning: _safeHex(Config.themeWarning, "#f9e2af"),
            error: _safeHex(Config.themeError, "#f38ba8"),
            opacity: _safeNum(Config.themeOpacity, 0.8, 0.1, 1.0),
            gradientEnabled: Config.themeGradientEnabled === true,
            gradientColor1: _safeHex(Config.themeGradientColor1, "#11111b"),
            gradientColor2: _safeHex(Config.themeGradientColor2, "#313244"),
            gradientColor3: _safeHex(Config.themeGradientColor3, ""),
            gradientDirection: String(Config.themeGradientDirection || "horizontal"),
            gradientIntensity: _safeNum(Config.themeGradientIntensity, 1.0, 0.0, 2.0),
            gradientApplyBg: Config.themeGradientApplyBg === true,
            gradientApplySurf: Config.themeGradientApplySurf === true
        }
        Config.setProp("Theme.customThemes", updated)
        return true
    }

    function _saveCustomTheme() {
        if (_saveCustomThemeNamed(newThemeName.text))
            newThemeName.text = ""
    }

    // Дублювання: копія палітри під новою назвою "N (copy)"
    function _duplicateCustomTheme(name) {
        var base = String(name || "").trim()
        if (!base || !Config.themeCustomThemes[base]) return
        var copy = base + " (copy)"
        var n = 2
        while (Config.themeCustomThemes[copy]) {
            copy = base + " (copy " + n + ")"
            ++n
        }
        var updated = JSON.parse(JSON.stringify(Config.themeCustomThemes))
        updated[copy] = JSON.parse(JSON.stringify(Config.themeCustomThemes[base]))
        Config.setProp("Theme.customThemes", updated)
    }

    function _themeIsLight(bg) {
        var s = String(bg || "")
        if (!/^#[0-9A-Fa-f]{6}$/.test(s)) return false
        var r = parseInt(s.substr(1, 2), 16) / 255
        var g = parseInt(s.substr(3, 2), 16) / 255
        var b = parseInt(s.substr(5, 2), 16) / 255
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.5
    }

    function _applyCustomTheme(name) {
        var t = Config.themeCustomThemes[name]
        if (!t) return
        // Усе пропускаємо через валідацію: пошкоджені/відсутні значення
        // замінюються коректними дефолтами, а не чорним fallback кольором.
        var bg = _safeHex(t.background, "#11111b")
        var light = _themeIsLight(bg)
        Config.setProp("Theme.background", bg)
        Config.setProp("Theme.surface", _safeHex(t.surface, "#313244"))
        Config.setProp("Theme.accent", _safeHex(t.accent, "#89b4fa"))
        // Старі кастомні теми не мають нових ключів — підбираємо текст/рамку
        // під світлий або темний фон, щоб зберегти читабельність.
        Config.setProp("Theme.secondaryAccent", _safeHex(t.secondaryAccent, "#cba6f7"))
        Config.setProp("Theme.text", _safeHex(t.text, light ? "#1e1e2e" : "#cdd6f4"))
        Config.setProp("Theme.secondaryText", _safeHex(t.secondaryText, light ? "#5c5f77" : "#a6adc8"))
        Config.setProp("Theme.border", _safeHex(t.border, light ? "#ccd0da" : "#45475a"))
        Config.setProp("Theme.success", _safeHex(t.success, "#a6e3a1"))
        Config.setProp("Theme.warning", _safeHex(t.warning, "#f9e2af"))
        Config.setProp("Theme.error", _safeHex(t.error, "#f38ba8"))
        Config.setProp("Theme.opacity", _safeNum(t.opacity, 0.8, 0.1, 1.0))
        Config.setProp("Theme.gradientEnabled", t.gradientEnabled === true)
        Config.setProp("Theme.gradientColor1", _safeHex(t.gradientColor1, "#11111b"))
        Config.setProp("Theme.gradientColor2", _safeHex(t.gradientColor2, "#313244"))
        Config.setProp("Theme.gradientColor3", _safeHex(t.gradientColor3, ""))
        Config.setProp("Theme.gradientDirection", String(t.gradientDirection || "horizontal"))
        Config.setProp("Theme.gradientIntensity", _safeNum(t.gradientIntensity, 1.0, 0.0, 2.0))
        Config.setProp("Theme.gradientApplyBg", t.gradientApplyBg === true)
        Config.setProp("Theme.gradientApplySurf", t.gradientApplySurf === true)
    }

    function _deleteCustomTheme(name) {
        var updated = JSON.parse(JSON.stringify(Config.themeCustomThemes))
        delete updated[name]
        Config.setProp("Theme.customThemes", updated)
    }

    // Єдина точка застосування пресета: картки галереї не дублюють логіку.
    function _presetColor(value, fallback) {
        return (value !== undefined && value !== null && value !== "") ? value : fallback
    }

    function _applyPreset(p) {
        if (!p) return
        Config.setProp("Theme.background", p.bg)
        Config.setProp("Theme.surface", p.surf)
        Config.setProp("Theme.accent", p.acc)
        Config.setProp("Theme.secondaryAccent", _presetColor(p.acc2, "#cba6f7"))
        Config.setProp("Theme.text", _presetColor(p.text, "#cdd6f4"))
        Config.setProp("Theme.secondaryText", _presetColor(p.textSub, "#a6adc8"))
        Config.setProp("Theme.border", _presetColor(p.border, "#45475a"))
        Config.setProp("Theme.success", _presetColor(p.success, "#a6e3a1"))
        Config.setProp("Theme.warning", _presetColor(p.warning, "#f9e2af"))
        Config.setProp("Theme.error", _presetColor(p.error, "#f38ba8"))
        Config.setProp("Theme.opacity", p.op)
        Config.setProp("Theme.gradientEnabled", p.gradEnabled === true)
        // Кольори градієнта змінюємо лише для пресетів із градієнтом, щоб
        // ручні налаштування Gradient Studio не затиралися при перемиканні.
        if (p.gradEnabled === true) {
            Config.setProp("Theme.gradientColor1", String(p.gradC1 || "#11111b"))
            Config.setProp("Theme.gradientColor2", String(p.gradC2 || "#313244"))
            Config.setProp("Theme.gradientColor3", String(p.gradC3 || ""))
            Config.setProp("Theme.gradientIntensity", p.gradInt || 1.0)
            if (p.presetType === "gradient") {
                Config.setProp("Theme.gradientDirection", p.gradDir || "horizontal")
                Config.setProp("Theme.gradientApplyBg", p.gradApplyBg !== false)
                Config.setProp("Theme.gradientApplySurf", p.gradApplySurf === true)
            }
        }
    }

    // Мінімальна ширина картки для адаптивної кількості колонок
    readonly property int _presetMinWidth: 160
    property string presetType: "normal"
    property string presetSearch: ""
    property string presetCategory: "All"

    // --- Модель пресетів (базові + новими темами, включаючи світлі та тємні) ---
    property var existingPresetModel: [
        // ================= ДІМНІ ТЕМИ (класичні) =================
        { name: "Mocha",           bg: "#11111b", surf: "#313244", acc: "#89b4fa",  acc2: "#b4befe",  text: "#cdd6f4", textSub: "#a6adc8", border: "#45475a", success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", op: 0.80, gradEnabled: false },
        { name: "Macchiato",       bg: "#1e2030", surf: "#363a4f", acc: "#8aadf4",  acc2: "#b4befe",  text: "#cdd6f4", textSub: "#a6adc8", border: "#45475a", success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", op: 0.75, gradEnabled: false },
        { name: "Frappe",          bg: "#232634", surf: "#414559", acc: "#8caaee",  acc2: "#b4befe",  text: "#cdd6f4", textSub: "#a6adc8", border: "#45475a", success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", op: 0.78, gradEnabled: false },
        { name: "Nord",            bg: "#2e3440", surf: "#3b4252", acc: "#88c0d0",  acc2: "#8fbcbb",  text: "#eceff4", textSub: "#d8dee9", border: "#4c566a", success: "#8fbcbb", warning: "#ebcb8b", error: "#bf616a", op: 0.82, gradEnabled: false },
        { name: "Dracula",         bg: "#282a36", surf: "#44475a", acc: "#bd93f9",  acc2: "#ff79c6",  text: "#f8f8f2", textSub: "#6272a4", border: "#6272a4", success: "#50fa7b", warning: "#f1fa8c", error: "#ff5555", op: 0.84, gradEnabled: false },
        { name: "Tokyo Night",     bg: "#1a1b26", surf: "#24283b", acc: "#7aa2f7",  acc2: "#bb9af7",  text: "#c0caf5", textSub: "#a9b1d6", border: "#414868", success: "#1abc9c", warning: "#e0af68", error: "#f7768e", op: 0.80, gradEnabled: false },
        { name: "Gruvbox Dark",    bg: "#282828", surf: "#3c3836", acc: "#fabd2f",  acc2: "#fe8019",  text: "#ebdbb2", textSub: "#d5c4a1", border: "#3c3836", success: "#b8bb26", warning: "#d8a657", error: "#fb4934", op: 0.85, gradEnabled: false },
        { name: "Rosé Pine",       bg: "#191724", surf: "#26233a", acc: "#ebbcba",  acc2: "#c4a7e7",  text: "#e0def4", textSub: "#908caa", border: "#2a2734", success: "#9ccfd8", warning: "#e69875", error: "#c4746e", op: 0.80, gradEnabled: false },
        { name: "Everforest",      bg: "#272e33", surf: "#3a454a", acc: "#a7c080",  acc2: "#d3c1a3",  text: "#d3c6aa", textSub: "#8da187", border: "#3a454a", success: "#a7c080", warning: "#e69875", error: "#e67e80", op: 0.82, gradEnabled: false },
        { name: "Solarized Dark",  bg: "#002b36", surf: "#073642", acc: "#268bd2",  acc2: "#2aa198",  text: "#839496", textSub: "#657b83", border: "#073642", success: "#859900", warning: "#b58900", error: "#dc322f", op: 0.85, gradEnabled: false },
        { name: "Kanagawa",        bg: "#1f1f28", surf: "#2a2a37", acc: "#7aa89f",  acc2: "#98bb6c",  text: "#dcd7ba", textSub: "#727169", border: "#2a2a37", success: "#76946a", warning: "#c0931c", error: "#c84053", op: 0.83, gradEnabled: false },
        { name: "Material Ocean",  bg: "#0f111a", surf: "#1c1f2b", acc: "#82aaff",  acc2: "#89ddff",  text: "#c0caf5", textSub: "#a9b1d6", border: "#3b4261", success: "#22d3ee", warning: "#fbbf24", error: "#f87171", op: 0.82, gradEnabled: false },
        { name: "Synthwave",       bg: "#241b2f", surf: "#34294f", acc: "#ff7edb",  acc2: "#ff00ff",  text: "#cdd6f4", textSub: "#a6adc8", border: "#45475a", success: "#a6e3a1", warning: "#f9e2af", error: "#f38ba8", op: 0.80, gradEnabled: true, gradC1: "#ff7edb", gradC2: "#1a1a2e", gradInt: 1.0 },
        { name: "AMOLED",          bg: "#000000", surf: "#16181d", acc: "#03dac6",  acc2: "#3700b3",  text: "#cfcfcf", textSub: "#8e8e93", border: "#333333", success: "#03dac6", warning: "#ffd700", error: "#ff0000", op: 1.0, gradEnabled: false },
        { name: "Cyberpunk Neon",  bg: "#0f0c1a", surf: "#1a162e", acc: "#00ffff",  acc2: "#ff00ff",  text: "#00ffff", textSub: "#a6adc8", border: "#45475a", success: "#00ff00", warning: "#ffff00", error: "#ff0000", op: 0.90, gradEnabled: true, gradC1: "#00ffff", gradC2: "#0f0c1a", gradInt: 1.2 },
        { name: "Deep Ocean",      bg: "#0a1a2e", surf: "#16213e", acc: "#00d4ff",  acc2: "#7cfcff",  text: "#e0f7ff", textSub: "#a6adc8", border: "#1e3a5f", success: "#2fe0a0", warning: "#f9e2af", error: "#f38ba8", op: 0.88, gradEnabled: true, gradC1: "#00d4ff", gradC2: "#0a1a2e", gradInt: 1.1 },
        { name: "Midnight Purple", bg: "#1a0a2e", surf: "#2d1b4e", acc: "#a855f7",  acc2: "#c084fc",  text: "#f3e8ff", textSub: "#c4b5fd", border: "#3b0f54", success: "#86efac", warning: "#fde047", error: "#fca5a5", op: 0.86, gradEnabled: true, gradC1: "#a855f7", gradC2: "#1a0a2e", gradInt: 1.0 },
        { name: "Amber Terminal",  bg: "#1a1a00", surf: "#2a2a00", acc: "#ffbf00",  acc2: "#f59e0b",  text: "#fef3c7", textSub: "#d97706", border: "#4d4d00", success: "#a3e635", warning: "#fbbf24", error: "#ef4444", op: 0.90, gradEnabled: true, gradC1: "#ffbf00", gradC2: "#1a1a00", gradInt: 1.3 },

        // ================= СВІТЛІ ТЕМИ (Light) =================
        { name: "Catppuccin Latte", bg: "#eff1f5", surf: "#ccd0da", acc: "#1e66f5", acc2: "#8839ef", text: "#4c4f69", textSub: "#6c6f85", border: "#bcc0cc", success: "#40a02b", warning: "#df8e1d", error: "#d20f39", op: 0.80, gradEnabled: false },
        { name: "Solarized Light",  bg: "#fdf6e3", surf: "#eee8d5", acc: "#268bd2", acc2: "#6c71c4", text: "#073642", textSub: "#586e75", border: "#d5cdb6", success: "#859900", warning: "#b58900", error: "#dc322f", op: 0.80, gradEnabled: false },
        { name: "One Light",        bg: "#fafafa", surf: "#f0f0f0", acc: "#4078f2", acc2: "#a626a4", text: "#383a42", textSub: "#696c77", border: "#d0d0d0", success: "#50a14f", warning: "#c18401", error: "#e45649", op: 0.80, gradEnabled: false },
        { name: "Rosé Pine Dawn",   bg: "#faf4ed", surf: "#fffaf3", acc: "#b4637a", acc2: "#ea9d34", text: "#575279", textSub: "#9893a5", border: "#f2e9de", success: "#286983", warning: "#ea9d34", error: "#b4637a", op: 0.80, gradEnabled: false },
        { name: "Gruvbox Light",    bg: "#fbf1c7", surf: "#ebdbb2", acc: "#076678", acc2: "#8f3f71", text: "#3c3836", textSub: "#7c6f64", border: "#d5c4a1", success: "#427b58", warning: "#b57614", error: "#9d0006", op: 0.82, gradEnabled: false },
        { name: "Nord Light",       bg: "#eceff4", surf: "#e5e9f0", acc: "#5e81ac", acc2: "#81a1c1", text: "#2e3440", textSub: "#4c566a", border: "#d8dee9", success: "#8fbcbb", warning: "#ebcb8b", error: "#bf616a", op: 0.80, gradEnabled: false },
        { name: "Everforest Light", bg: "#e8ead6", surf: "#d9dec4", acc: "#427b58", acc2: "#7c6f64", text: "#3c3836", textSub: "#7c6f64", border: "#c3c5aa", success: "#427b58", warning: "#d3a95f", error: "#e67e80", op: 0.82, gradEnabled: false },
        { name: "Tokyo Night Day",  bg: "#e1e2e7", surf: "#d5d6db", acc: "#2e7de9", acc2: "#9570e0", text: "#1e3a8a", textSub: "#787c99", border: "#c4c8da", success: "#449dab", warning: "#b47217", error: "#c64343", op: 0.80, gradEnabled: false },
        { name: "Ayu Light",        bg: "#f4f4f4", surf: "#f3f3f3", acc: "#55b4d4", acc2: "#f2ae49", text: "#5c6773", textSub: "#8a9199", border: "#d0d0d0", success: "#95c561", warning: "#f2ae49", error: "#ff3333", op: 0.80, gradEnabled: false },
        { name: "GitHub Light",     bg: "#ffffff", surf: "#f6f8fa", acc: "#0969da", acc2: "#8250df", text: "#1f2328", textSub: "#656d76", border: "#d0d7de", success: "#1a7f37", warning: "#9a6700", error: "#cf222e", op: 0.85, gradEnabled: false },
        { name: "Kanagawa Lotus",   bg: "#fefaf4", surf: "#f2ecbc", acc: "#c24f1a", acc2: "#6c6d7c", text: "#545464", textSub: "#727169", border: "#dcd7ba", success: "#6a9589", warning: "#c0931c", error: "#c84053", op: 0.82, gradEnabled: false },
        { name: "Mint Cream",       bg: "#f0fff0", surf: "#e6ffe6", acc: "#059669", acc2: "#34d399", text: "#064e3b", textSub: "#115e59", border: "#bbf7d0", success: "#059669", warning: "#d97706", error: "#dc2626", op: 0.85, gradEnabled: false },
        { name: "Peach Puff",       bg: "#fff7ed", surf: "#fed7aa", acc: "#c2410c", acc2: "#fb923c", text: "#7c2d12", textSub: "#9a3412", border: "#fddebe", success: "#15803d", warning: "#c2410c", error: "#b91c1c", op: 0.85, gradEnabled: false },

        // ================= ТІМНІ ТЕМИ (Dark, розширені) =================
        { name: "One Dark",         bg: "#282c34", surf: "#3e4451", acc: "#61afef",  acc2: "#c678dd",  text: "#abb2bf", textSub: "#5c6370", border: "#3e4451", success: "#98c379", warning: "#d19a66", error: "#e06c75", op: 0.82, gradEnabled: false },
        { name: "Oxocarbon",        bg: "#161616", surf: "#262626", acc: "#78a9ff",  acc2: "#00d9ff",  text: "#d9d9d9", textSub: "#8a8a8a", border: "#333333", success: "#00e676", warning: "#ffee58", error: "#ff1744", op: 0.90, gradEnabled: false },
        { name: "Decayce",          bg: "#0d0f18", surf: "#1c1e27", acc: "#86aaec",  acc2: "#82b1ff",  text: "#e0e0e0", textSub: "#a6adc8", border: "#2a2e44", success: "#69f0ae", warning: "#fce566", error: "#ff5f56", op: 0.85, gradEnabled: false },
        { name: "Horizon Dark",     bg: "#1c1e26", surf: "#232530", acc: "#f09383",  acc2: "#ff9e64",  text: "#d0d0d0", textSub: "#8a8a8a", border: "#3a3e4a", success: "#69f0ae", warning: "#ffe066", error: "#ff5f56", op: 0.85, gradEnabled: false },
        { name: "GitHub Dark Dimmed", bg: "#22272e", surf: "#2d333b", acc: "#539bf5", acc2: "#58a6ff", text: "#c9d1d9", textSub: "#8b949e", border: "#30363d", success: "#3fb950", warning: "#d29922", error: "#f85149", op: 0.85, gradEnabled: false },
        { name: "Obsidian",         bg: "#0b0b10", surf: "#191922", acc: "#8b7cf6",  acc2: "#c4b5fd",  text: "#e0e0e0", textSub: "#a6adc8", border: "#2a2a44", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Graphite",         bg: "#101215", surf: "#1e2228", acc: "#d0d6e0",  acc2: "#6f7b8a",  text: "#d0d6e0", textSub: "#6f7b8a", border: "#2a2e38", success: "#69f0ae", warning: "#ffe066", error: "#ff5f56", op: 0.88, gradEnabled: false },
        { name: "Crimson",          bg: "#12060b", surf: "#240a13", acc: "#e6294f",  acc2: "#ff8fa3",  text: "#ffe4e8", textSub: "#cc99a3", border: "#4a1a22", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Emerald",          bg: "#05130f", surf: "#0d2620", acc: "#2fe0a0",  acc2: "#7cf5cb",  text: "#d4ffe6", textSub: "#8acc99", border: "#1a4d22", success: "#2fe0a0", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Sapphire",         bg: "#050b1a", surf: "#0e1a33", acc: "#3b82f6",  acc2: "#93c5fd",  text: "#dbeafe", textSub: "#7dd3fc", border: "#1e3a8a", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Solarized Night",  bg: "#001f27", surf: "#00313c", acc: "#c9a227",  acc2: "#2aa198",  text: "#839496", textSub: "#657b83", border: "#073642", success: "#859900", warning: "#b58900", error: "#dc322f", op: 0.88, gradEnabled: false },
        { name: "Tokyo Neon",       bg: "#0b0a16", surf: "#181430", acc: "#ff4d9d",  acc2: "#2de2e6",  text: "#ffe4e8", textSub: "#cc99a3", border: "#3a2055", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: true, gradC1: "#ff4d9d", gradC2: "#0b0a16", gradInt: 1.0 },
        { name: "Ghost in the Shell", bg: "#081014", surf: "#102026", acc: "#22d3ee", acc2: "#a78bfa", text: "#d9f5fb", textSub: "#8fb8c4", border: "#1e3a44", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Carbon",           bg: "#0d0d0d", surf: "#1c1c1c", acc: "#e6e6e6",  acc2: "#8a8a8a",  text: "#e6e6e6", textSub: "#8a8a8a", border: "#333333", success: "#00e676", warning: "#ffee58", error: "#ff1744", op: 0.90, gradEnabled: false },
        { name: "Retro Terminal",   bg: "#050805", surf: "#0d160d", acc: "#3dff6e",  acc2: "#1f9e44",  text: "#d4ffe6", textSub: "#8acc99", border: "#1a4d22", success: "#3dff6e", warning: "#fde047", error: "#fca5a5", op: 0.90, gradEnabled: false },
        { name: "Arctic Blue",      bg: "#0a1620", surf: "#14293a", acc: "#8fe3ff",  acc2: "#4aa8d8",  text: "#e0f7ff", textSub: "#a6adc8", border: "#2c5282", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Blood Moon",       bg: "#160709", surf: "#2b0e12", acc: "#ff7a45",  acc2: "#ff3d68",  text: "#ffe4e8", textSub: "#cc99a3", border: "#4a1a22", success: "#4ade80", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Rust",             bg: "#1a0f0a", surf: "#2d1a12", acc: "#e05d2d",  acc2: "#f0a868",  text: "#f2e3d5", textSub: "#bfa08a", border: "#4a2f24", success: "#8fbf6a", warning: "#f2c14e", error: "#e5484d", op: 0.88, gradEnabled: false },
        { name: "Lime Circuit",     bg: "#0a1005", surf: "#14210c", acc: "#a3e635",  acc2: "#4ade80",  text: "#e8f5d8", textSub: "#a9bf8a", border: "#2c3d1e", success: "#a3e635", warning: "#facc15", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Magenta Flux",     bg: "#120614", surf: "#241030", acc: "#ff3d9a",  acc2: "#8b5cf6",  text: "#f6e6f6", textSub: "#c4a3c9", border: "#43234f", success: "#34d399", warning: "#fbbf24", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Copper",           bg: "#140d09", surf: "#251812", acc: "#d97746",  acc2: "#5eead4",  text: "#f0dfd3", textSub: "#b99a86", border: "#473126", success: "#5eead4", warning: "#fbbf24", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Tidepool",         bg: "#061418", surf: "#0d2730", acc: "#22d3ee",  acc2: "#7dd3fc",  text: "#d9f5fb", textSub: "#8fb8c4", border: "#1e4450", success: "#4ade80", warning: "#fde68a", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Indigo Ink",       bg: "#0b0b1f", surf: "#171735", acc: "#818cf8",  acc2: "#a78bfa",  text: "#e0e2ff", textSub: "#9fa4c8", border: "#2c2d55", success: "#6ee7b7", warning: "#fcd34d", error: "#f87171", op: 0.88, gradEnabled: false },
        { name: "Rosewood",         bg: "#1a0e12", surf: "#2d1920", acc: "#e07a8b",  acc2: "#f4b8c4",  text: "#f5e0e4", textSub: "#c4a0a8", border: "#4a2a34", success: "#86c9a0", warning: "#e8c07d", error: "#e05263", op: 0.88, gradEnabled: false },
        { name: "Olive Grove",      bg: "#11130b", surf: "#20241a", acc: "#b5c95a",  acc2: "#d9e08c",  text: "#eef0db", textSub: "#b3b892", border: "#3a4029", success: "#a3c76a", warning: "#e3c766", error: "#d97a6c", op: 0.88, gradEnabled: false },
        { name: "Glacier",          bg: "#0b1420", surf: "#182636", acc: "#7dd3fc",  acc2: "#bae6fd",  text: "#eaf6ff", textSub: "#a6c3d8", border: "#2c4357", success: "#86efac", warning: "#fde68a", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Amethyst",         bg: "#120a1a", surf: "#241533", acc: "#b388ff",  acc2: "#e0aaff",  text: "#f1e6ff", textSub: "#bfa8d8", border: "#432c5a", success: "#86e0b0", warning: "#fcd97a", error: "#ef7a8a", op: 0.88, gradEnabled: false },
        { name: "Sakura Dusk",      bg: "#1b0f16", surf: "#2e1824", acc: "#ff8fab",  acc2: "#ffc2d1",  text: "#fbe6ec", textSub: "#cfa8b5", border: "#4d2a39", success: "#7fd1a8", warning: "#f4c97a", error: "#ff6b81", op: 0.88, gradEnabled: false },
        { name: "Forest Ember",     bg: "#0d140d", surf: "#1a2618", acc: "#f0a35e",  acc2: "#9ccf6b",  text: "#e6f0dc", textSub: "#a9b89a", border: "#33452c", success: "#9ccf6b", warning: "#f0c05e", error: "#e06c75", op: 0.88, gradEnabled: false },
        { name: "Cobalt Current",   bg: "#070d18", surf: "#101c2e", acc: "#4da3ff",  acc2: "#7ee0ff",  text: "#dceaff", textSub: "#8fa9c7", border: "#24374f", success: "#4fd1a1", warning: "#f5c76a", error: "#ff6b7a", op: 0.88, gradEnabled: false },
        { name: "Cyber Red",        bg: "#18080a", surf: "#2d1016", acc: "#ff3355",  acc2: "#ff6b8a",  text: "#ffe4e8", textSub: "#cc99a3", border: "#4a1a22", success: "#4ade80", warning: "#fbbf24", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Toxic Green",      bg: "#051206", surf: "#0d260f", acc: "#00ff33",  acc2: "#66ff88",  text: "#d4ffe6", textSub: "#8acc99", border: "#1a4d22", success: "#22c55e", warning: "#eab308", error: "#ef4444", op: 0.88, gradEnabled: true, gradC1: "#00ff33", gradC2: "#051206", gradInt: 1.1 },
        { name: "Deep Space",       bg: "#020408", surf: "#0a121c", acc: "#4a9eff",  acc2: "#8bb8ff",  text: "#e0eaff", textSub: "#8a9cc7", border: "#1a2a4a", success: "#4fd1a1", warning: "#f5c76a", error: "#ff6b7a", op: 0.90, gradEnabled: false },
        { name: "Holographic",      bg: "#080412", surf: "#180d28", acc: "#00ffff",  acc2: "#ff00ff",  text: "#eefaff", textSub: "#b8a0d8", border: "#332055", success: "#4ade80", warning: "#fde047", error: "#fb7185", op: 0.88, gradEnabled: true, gradC1: "#00ffff", gradC2: "#ff00ff", gradInt: 1.2 },
        { name: "Neon Violet",      bg: "#0c0418", surf: "#1d0d30", acc: "#bf40ff",  acc2: "#d980ff",  text: "#f0e0ff", textSub: "#c4a8d8", border: "#402066", success: "#86e0b0", warning: "#fcd97a", error: "#ef7a8a", op: 0.88, gradEnabled: true, gradC1: "#bf40ff", gradC2: "#0c0418", gradInt: 1.0 },
        { name: "Burnt Orange",     bg: "#180c04", surf: "#2b1608", acc: "#e86c00",  acc2: "#ffa540",  text: "#ffe8d6", textSub: "#ccae88", border: "#553311", success: "#86efac", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Midnight Ember",   bg: "#100604", surf: "#220e0a", acc: "#ff6b2e",  acc2: "#ffaa66",  text: "#ffeedd", textSub: "#ccbbaa", border: "#4a2818", success: "#86efac", warning: "#fde047", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Venom",            bg: "#080610", surf: "#181326", acc: "#8b5cf6",  acc2: "#22d3ee",  text: "#e8e0ff", textSub: "#b8b0d8", border: "#383058", success: "#4ade80", warning: "#fbbf24", error: "#fb7185", op: 0.88, gradEnabled: true, gradC1: "#8b5cf6", gradC2: "#22d3ee", gradInt: 1.1 },
        { name: "Golden Hour",      bg: "#181004", surf: "#2b1e0a", acc: "#fbbf24",  acc2: "#fde68a",  text: "#fff8e7", textSub: "#d4c4a0", border: "#5a4a1a", success: "#86efac", warning: "#fde047", error: "#fca5a5", op: 0.88, gradEnabled: false },

        // ================= НОВІ ТЕМАТИЧНІ ПРЕСЕТИ (30) =================
        // Космос
        { name: "Galaxy",           bg: "#0a0a1a", surf: "#1a1a2e", acc: "#7b2cbf",  acc2: "#c084fc",  text: "#e0e7ff", textSub: "#a5b4fc", border: "#2e2a47", success: "#4ade80", warning: "#fde047", error: "#f87171", op: 0.88, gradEnabled: false },
        { name: "Nebula",           bg: "#0f0c29", surf: "#1e1a4a", acc: "#bc13fe",  acc2: "#f59e0b",  text: "#f3e8ff", textSub: "#d8b4fe", border: "#4c1d95", success: "#86efac", warning: "#fde047", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Saturn Rings",     bg: "#1a1a24", surf: "#2d2d44", acc: "#fbbf24",  acc2: "#fde68a",  text: "#fef3c7", textSub: "#d97706", border: "#4d4032", success: "#86efac", warning: "#fbbf24", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Mars",             bg: "#2d1b14", surf: "#4a2a1e", acc: "#ef4444",  acc2: "#f87171",  text: "#fecaca", textSub: "#fca5a5", border: "#7f1d1d", success: "#4ade80", warning: "#fbbf24", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Lunar Eclipse",    bg: "#0a0a0a", surf: "#1a1a1a", acc: "#6366f1",  acc2: "#a855f7",  text: "#e5e7eb", textSub: "#9ca3af", border: "#374151", success: "#22c55e", warning: "#eab308", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Aurora Borealis",  bg: "#061414", surf: "#0d2a2a", acc: "#10b981",  acc2: "#34d399",  text: "#d1fae5", textSub: "#6ee7b7", border: "#115e59", success: "#10b981", warning: "#fde047", error: "#f87171", op: 0.88, gradEnabled: false },
        { name: "Stellar Night",    bg: "#020617", surf: "#030712", acc: "#38bdf8",  acc2: "#7dd3fc",  text: "#f0f9ff", textSub: "#bae6fd", border: "#0c4a6e", success: "#22d3ee", warning: "#facc15", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Black Hole",       bg: "#000000", surf: "#0d0d0d", acc: "#ffffff",  acc2: "#e5e7eb",  text: "#ffffff", textSub: "#9ca3af", border: "#333333", success: "#22c55e", warning: "#eab308", error: "#ef4444", op: 1.0, gradEnabled: false },
        // Природа
        { name: "Sakura Garden",    bg: "#1a0b1e", surf: "#2e1a38", acc: "#ec4899",  acc2: "#f472b6",  text: "#fce7f3", textSub: "#f0abfc", border: "#7e22ce", success: "#34d399", warning: "#fde047", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Enchanted Forest", bg: "#061710", surf: "#14210c", acc: "#22c55e",  acc2: "#4ade80",  text: "#dcfce7", textSub: "#86efac", border: "#14532d", success: "#16a34a", warning: "#ca8a04", error: "#dc2626", op: 0.88, gradEnabled: false },
        { name: "Tropical Jungle",  bg: "#0a0f0a", surf: "#151d15", acc: "#15803d",  acc2: "#22c55e",  text: "#dcfce7", textSub: "#86efac", border: "#14532d", success: "#15803d", warning: "#d97706", error: "#b91c1c", op: 0.88, gradEnabled: false },
        { name: "Ocean Depths",     bg: "#030712", surf: "#07111e", acc: "#0891b2",  acc2: "#06b6d4",  text: "#cffafe", textSub: "#67e8f9", border: "#0f766e", success: "#14b8a6", warning: "#eab308", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Mountain Mist",    bg: "#0b1120", surf: "#172234", acc: "#0284c7",  acc2: "#38bdf8",  text: "#bfdbfe", textSub: "#7dd3fc", border: "#0c4a6e", success: "#22d3ee", warning: "#facc15", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Autumn Forest",    bg: "#1c0a02", surf: "#2d1b0a", acc: "#d97706",  acc2: "#f59e0b",  text: "#fef3c7", textSub: "#d97706", border: "#78350f", success: "#15803d", warning: "#d97706", error: "#b91c1c", op: 0.88, gradEnabled: false },
        { name: "Wildflower Meadow",bg: "#0a0f0a", surf: "#162113", acc: "#4ade80",  acc2: "#a3e635",  text: "#dcfce7", textSub: "#86efac", border: "#14532d", success: "#22c55e", warning: "#eab308", error: "#dc2626", op: 0.88, gradEnabled: false },
        // Животні
        { name: "Midnight Cat",     bg: "#0f0f0f", surf: "#1f1f1f", acc: "#fbbf24",  acc2: "#fde68a",  text: "#f3f4f6", textSub: "#d1d5db", border: "#4b5563", success: "#4ade80", warning: "#fbbf24", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Black Panther",    bg: "#000000", surf: "#0a0a0a", acc: "#facc15",  acc2: "#fde047",  text: "#f3f4f6", textSub: "#d1d5db", border: "#333333", success: "#4ade80", warning: "#facc15", error: "#fca5a5", op: 0.88, gradEnabled: false },
        { name: "Snow Leopard",     bg: "#f8fafc", surf: "#f1f5f9", acc: "#0f172a",  acc2: "#334155",  text: "#0f172a", textSub: "#475569", border: "#cbd5e1", success: "#059669", warning: "#d97706", error: "#dc2626", op: 0.85, gradEnabled: false },
        { name: "Arctic Fox",       bg: "#eff6ff", surf: "#dbeafe", acc: "#0ea5e9",  acc2: "#38bdf8",  text: "#0c4a6e", textSub: "#0369a1", border: "#bae6fd", success: "#059669", warning: "#d97706", error: "#dc2626", op: 0.85, gradEnabled: false },
        // Фантастика та образи
        { name: "Dragon Scale",     bg: "#1c0b08", surf: "#2d1a12", acc: "#b91c1c",  acc2: "#ef4444",  text: "#fecaca", textSub: "#fca5a5", border: "#7f1d1d", success: "#15803d", warning: "#d97706", error: "#b91c1c", op: 0.88, gradEnabled: false },
        { name: "Phoenix Fire",     bg: "#180c02", surf: "#2d1b0a", acc: "#f59e0b",  acc2: "#fbbf24",  text: "#fef3c7", textSub: "#d97706", border: "#78350f", success: "#15803d", warning: "#f59e0b", error: "#b91c1c", op: 0.88, gradEnabled: false },
        { name: "Butterfly Wings",  bg: "#0a0a1a", surf: "#1a1a2e", acc: "#8b5cf6",  acc2: "#a78bfa",  text: "#f3e8ff", textSub: "#d8b4fe", border: "#4c1d95", success: "#34d399", warning: "#fde047", error: "#fb7185", op: 0.88, gradEnabled: false },
        { name: "Coral Reef",       bg: "#0b0b0b", surf: "#1a1a1a", acc: "#f472b6",  acc2: "#fb7185",  text: "#fce7f3", textSub: "#f0abfc", border: "#9d174d", success: "#10b981", warning: "#fde047", error: "#f87171", op: 0.88, gradEnabled: false },
        // Авторські концепції
        { name: "Venetian Sunset",  bg: "#1a0b0a", surf: "#2d1814", acc: "#e11d48",  acc2: "#f43f5e",  text: "#fee2e2", textSub: "#fca5a5", border: "#7f1d1d", success: "#15803d", warning: "#d97706", error: "#e11d48", op: 0.88, gradEnabled: false },
        { name: "Frozen Lake",      bg: "#0a0f1a", surf: "#172032", acc: "#22d3ee",  acc2: "#7dd3fc",  text: "#e0f2fe", textSub: "#bae6fd", border: "#0369a1", success: "#06b6d4", warning: "#eab308", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Volcanic Ash",     bg: "#171717", surf: "#262626", acc: "#f97316",  acc2: "#fb923c",  text: "#f3f4f6", textSub: "#d1d5db", border: "#404040", success: "#22c55e", warning: "#f59e0b", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Desert Mirage",    bg: "#1e1408", surf: "#2e2016", acc: "#b45309",  acc2: "#d97706",  text: "#fef3c7", textSub: "#d97706", border: "#78350f", success: "#166534", warning: "#d97706", error: "#b45309", op: 0.88, gradEnabled: false },
        { name: "Deep Cave",        bg: "#050507", surf: "#0f0f12", acc: "#6366f1",  acc2: "#818cf8",  text: "#e5e7eb", textSub: "#9ca3af", border: "#27272a", success: "#22c55e", warning: "#eab308", error: "#ef4444", op: 0.88, gradEnabled: false },
        { name: "Bamboo Forest",    bg: "#0b0f0b", surf: "#141d14", acc: "#22c55e",  acc2: "#4ade80",  text: "#dcfce7", textSub: "#86efac", border: "#14532d", success: "#15803d", warning: "#d97706", error: "#dc2626", op: 0.88, gradEnabled: false },
        { name: "Stained Glass",    bg: "#0a0a0a", surf: "#171717", acc: "#ef4444",  acc2: "#f87171",  text: "#fca5a5", textSub: "#fecaca", border: "#3f3f46", success: "#22c55e", warning: "#f59e0b", error: "#ef4444", op: 0.88, gradEnabled: false }
    ]

    readonly property var normalPresetModel: existingPresetModel.concat(ThemePresets.normalPresets)
    readonly property var gradientPresetModel: ThemePresets.gradientPresets
    readonly property var presetModel: normalPresetModel.concat(gradientPresetModel)

    function _presetCategory(p) {
        return p && p.category ? p.category : "Classic"
    }

    function presetCategories() {
        var source = appearanceRoot.presetType === "gradient"
                ? appearanceRoot.gradientPresetModel : appearanceRoot.normalPresetModel
        var result = ["All"]
        var seen = ({})
        for (var i = 0; i < source.length; ++i) {
            var category = appearanceRoot._presetCategory(source[i])
            if (!seen[category]) {
                seen[category] = true
                result.push(category)
            }
        }
        return result
    }

    function filteredPresetModel() {
        var source = appearanceRoot.presetType === "gradient"
                ? appearanceRoot.gradientPresetModel : appearanceRoot.normalPresetModel
        var needle = appearanceRoot.presetSearch.trim().toLowerCase()
        var result = []
        for (var i = 0; i < source.length; ++i) {
            var preset = source[i]
            if (appearanceRoot.presetCategory !== "All"
                    && appearanceRoot._presetCategory(preset) !== appearanceRoot.presetCategory)
                continue
            if (needle && String(preset.name).toLowerCase().indexOf(needle) < 0)
                continue
            result.push(preset)
        }
        return result
    }

    function _presetActive(p) {
        if (!p)
            return false
        var paletteMatches = Config.themeBackground === p.bg
                && Config.themeSurface === p.surf
                && Config.themeAccent === p.acc
                && Config.themeSecondaryAccent === _presetColor(p.acc2, "#cba6f7")
                && Config.themeText === _presetColor(p.text, "#cdd6f4")
                && Config.themeSecondaryText === _presetColor(p.textSub, "#a6adc8")
                && Config.themeBorder === _presetColor(p.border, "#45475a")
                && Config.themeSuccess === _presetColor(p.success, "#a6e3a1")
                && Config.themeWarning === _presetColor(p.warning, "#f9e2af")
                && Config.themeError === _presetColor(p.error, "#f38ba8")
                && Config.themeGradientEnabled === p.gradEnabled
        if (!paletteMatches)
            return false
        if (p.presetType !== "gradient")
            return true
        return Config.themeGradientColor1 === String(p.gradC1 || "#11111b")
                && Config.themeGradientColor2 === String(p.gradC2 || "#313244")
                && Config.themeGradientColor3 === String(p.gradC3 || "")
                && Math.abs(Config.themeGradientIntensity - (p.gradInt || 1.0)) < 0.001
                && Config.themeGradientDirection === (p.gradDir || "horizontal")
                && Config.themeGradientApplyBg === (p.gradApplyBg !== false)
                && Config.themeGradientApplySurf === (p.gradApplySurf === true)
    }

    // Активний пресет визначається порівнянням усіх кольорів палітри з Config.
    // Для старих пресетів без нових ключів використовуються ті самі fallback-
    // значення, що й у _applyPreset. Ручна зміна будь-якого кольору => "Custom".
    function currentPresetName() {
        for (var i = 0; i < presetModel.length; ++i) {
            var p = presetModel[i]
            if (appearanceRoot._presetActive(p))
                return p.name
        }
        return "Custom"
    }

    // --- Прокрутка: зі збільшеною бібліотекою пресетів сторінка не вміщується ---
    Flickable {
        id: pageScroll
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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
            id: contentCol
            x: 20
            y: 20
            width: pageScroll.width - 40
            spacing: 16

            // --- Header (Appearance Studio) ---
            Rectangle {
                id: studioHeader
                Layout.fillWidth: true
                Layout.preferredHeight: headerCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: headerCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: "APPEARANCE STUDIO"
                                color: Theme.text
                                font.pixelSize: 20
                                font.bold: true
                                font.family: Theme.fontMono
                            }

                            Text {
                                text: "Керуйте палітрою, градієнтом та власними темами — зміни застосовуються одразу"
                                color: Theme.textSub
                                font.pixelSize: 11
                                font.family: Theme.fontMono
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Компактна дія: скидання
                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: resetThemeRow.implicitWidth + 24
                            radius: Theme.radiusSm
                            color: resetThemeMa.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : Theme.glassCard
                            border.color: resetThemeMa.containsMouse ? Theme.accentRed : Theme.glassBorder
                            border.width: 1

                            RowLayout {
                                id: resetThemeRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text { text: "󰜺"; color: Theme.accentRed; font.family: Theme.fontMono; font.pixelSize: 13 }
                                Text { text: "Скинути"; color: Theme.text; font.pixelSize: 10; font.bold: true; font.family: Theme.fontMono }
                            }

                            MouseArea {
                                id: resetThemeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.reset()
                            }
                        }
                    }
                }
            }

            // --- Кольори ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: colorsCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: colorsCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "COLOR STUDIO"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    // Групи кольорів: базова палітра, текст/лінії, статуси
                    Repeater {
                        model: [
                            { group: "БАЗОВА ПАЛІТРА", items: [
                                { label: "Background",       prop: "background",      fallback: "#11111b" },
                                { label: "Surface",          prop: "surface",         fallback: "#313244" },
                                { label: "Accent",           prop: "accent",          fallback: "#89b4fa" },
                                { label: "Secondary Accent", prop: "secondaryAccent", fallback: "#cba6f7" }
                            ]},
                            { group: "ТЕКСТ ТА ЛІНІЇ", items: [
                                { label: "Text",             prop: "text",            fallback: "#cdd6f4" },
                                { label: "Secondary Text",   prop: "secondaryText",   fallback: "#a6adc8" },
                                { label: "Border",           prop: "border",          fallback: "#45475a" }
                            ]},
                            { group: "СТАТУСИ", items: [
                                { label: "Success",          prop: "success",         fallback: "#a6e3a1" },
                                { label: "Warning",          prop: "warning",         fallback: "#f9e2af" },
                                { label: "Error",            prop: "error",           fallback: "#f38ba8" }
                            ]}
                        ]

                        delegate: ColumnLayout {
                            id: colorGroup
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            // Розділювач + назва групи
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle { Layout.preferredWidth: 3; Layout.preferredHeight: 3; radius: 1.5; color: Theme.accent }
                                Text {
                                    text: modelData.group
                                    color: Theme.textMuted
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: Theme.fontMono
                                    font.letterSpacing: 1
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.glassBorder
                                }
                            }

                            // Адаптивна сітка всередині групи
                            GridLayout {
                                Layout.fillWidth: true
                                columns: width >= 560 ? 2 : 1
                                columnSpacing: 10
                                rowSpacing: 8

                                Repeater {
                                    model: colorGroup.modelData.items

                                    delegate: Rectangle {
                                        id: colorCell
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        radius: Theme.radiusSm
                                        color: colorSwatchMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                                        border.color: colorSwatchMa.containsMouse ? Theme.glassBorderFocus : Theme.glassBorder
                                        border.width: 1

                                        readonly property string value: {
                                            var v = Config["theme" + modelData.prop.charAt(0).toUpperCase() + modelData.prop.slice(1)]
                                            return (v !== undefined && v !== null && v !== "") ? v : modelData.fallback
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: 24
                                                Layout.preferredHeight: 24
                                                radius: 6
                                                color: colorCell.value
                                                border.color: Theme.glassBorder
                                                border.width: 1
                                            }

                                            Text {
                                                text: colorCell.modelData.label
                                                color: Theme.textSub
                                                font.pixelSize: 10
                                                Layout.preferredWidth: 92
                                                elide: Text.ElideRight
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: colorCell.value.toUpperCase()
                                                color: Theme.text
                                                font.pixelSize: 10
                                                font.family: Theme.fontMono
                                            }
                                        }

                                        MouseArea {
                                            id: colorSwatchMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: colorPicker.openFor("Theme." + modelData.prop, colorCell.modelData.label, colorCell.value)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Opacity — окремий рядок на всю ширину
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true
                        Rectangle {
                            width: 26; height: 26; radius: 6
                            color: Qt.rgba(0.5, 0.5, 0.5, Config.themeOpacity)
                            border.color: Theme.glassBorder; border.width: 1
                        }
                        Text { text: "Opacity"; color: Theme.textSub; font.pixelSize: 11; Layout.preferredWidth: 92 }
                        Slider {
                            id: opacitySlider
                            Layout.fillWidth: true
                            from: 0.1; to: 1.0
                            value: Config.themeOpacity
                            onMoved: Config.setProp("Theme.opacity", value)

                            background: Rectangle {
                                x: opacitySlider.leftPadding
                                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                                width: opacitySlider.availableWidth; height: 6; radius: 3
                                color: Theme.bgSurface
                                Rectangle {
                                    width: opacitySlider.visualPosition * parent.width
                                    height: parent.height; radius: 3
                                    color: Theme.accent
                                }
                            }
                            handle: Rectangle {
                                x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                                implicitWidth: 16; implicitHeight: 16; radius: 8
                                color: opacitySlider.pressed ? Theme.accentHover : Theme.text
                                border.color: Theme.accent; border.width: 2
                            }
                        }
                        Text {
                            text: Config.themeOpacity.toFixed(2)
                            color: Theme.textSub; font.pixelSize: 11
                            Layout.preferredWidth: 34
                        }
                    }
                }
            }

            // --- Gradient Studio (Theme Studio 2.0) ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: gradCol.implicitHeight + 28
                    radius: Theme.radiusMd
                    color: Theme.glassCard
                    border.color: Theme.glassBorder
                    border.width: 1

                    ColumnLayout {
                        id: gradCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "GRADIENT STUDIO"
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        // Горизонтальний preview градієнта (live, з урахуванням інтенсивності)
                        Rectangle {
                            visible: Config.themeGradientEnabled
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Theme.radiusSm
                            border.color: Theme.glassBorder
                            border.width: 1
                            clip: true

                            // Два стопи
                            Rectangle {
                                anchors.fill: parent
                                visible: Config.themeGradientColor3 === ""
                                         || Config.themeGradientColor3 === undefined
                                         || Config.themeGradientColor3 === null
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: appearanceRoot._previewGradColor(Config.themeGradientColor1) }
                                    GradientStop { position: 1.0; color: appearanceRoot._previewGradColor(Config.themeGradientColor2) }
                                }
                            }

                            // Три стопи
                            Rectangle {
                                anchors.fill: parent
                                visible: !(Config.themeGradientColor3 === ""
                                           || Config.themeGradientColor3 === undefined
                                           || Config.themeGradientColor3 === null)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: appearanceRoot._previewGradColor(Config.themeGradientColor1) }
                                    GradientStop { position: 0.5; color: appearanceRoot._previewGradColor(Config.themeGradientColor3) }
                                    GradientStop { position: 1.0; color: appearanceRoot._previewGradColor(Config.themeGradientColor2) }
                                }
                            }

                            // Підпис цілей застосування поверх preview
                            Text {
                                anchors.centerIn: parent
                                text: (Config.themeGradientApplyBg ? "BG" : "—") + "  ·  " + (Config.themeGradientApplySurf ? "SURF" : "—")
                                      + "  ·  ×" + Config.themeGradientIntensity.toFixed(2)
                                color: Theme.textDark
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Theme.fontMono
                            }
                        }

                        // Enable toggle
                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            Text { text: "Увімкнути градієнт"; color: Theme.textSub; font.pixelSize: 12; Layout.preferredWidth: 140 }

                            // Ice-Cyber switch: плавний track-градус + ковзаючий knob
                            Rectangle {
                                id: gradSwitch
                                width: 52; height: 26; radius: 13
                                color: Config.themeGradientEnabled
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                                       : Theme.bgSurface
                                border.color: Config.themeGradientEnabled ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: Config.themeGradientEnabled ? 2 : 1

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                }

                                // М'яке світіння в активному стані
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Theme.accent
                                    border.width: 6
                                    opacity: Config.themeGradientEnabled ? 0.25 : 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
                                    }
                                }

                                // Knob
                                Rectangle {
                                    id: gradKnob
                                    width: 20; height: 20; radius: 10
                                    x: Config.themeGradientEnabled ? parent.width - width - 4 : 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.themeGradientEnabled ? Theme.text : Theme.textMuted
                                    border.color: Config.themeGradientEnabled ? Theme.textDark : Theme.glassBorder
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.animNormal
                                            easing.type: Theme.easingSpring
                                            easing.overshoot: Theme.easingOvershoot
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.setProp("Theme.gradientEnabled", !Config.themeGradientEnabled)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Config.themeGradientEnabled ? "УВІМКНЕНО" : "ВИМКНЕНО"
                                color: Config.themeGradientEnabled ? Theme.accent : Theme.textMuted
                                font.pixelSize: 10
                                font.bold: true
                                font.family: Theme.fontMono
                            }
                        }

                        RowLayout {
                            visible: Config.themeGradientEnabled
                            spacing: 10
                            Layout.fillWidth: true

                            // Color 1
                            ColumnLayout {
                                spacing: 6
                                Text { text: "Колір 1"; color: Theme.textSub; font.pixelSize: 11 }
                                RowLayout {
                                    spacing: 8
                                     Rectangle {
                                         width: 24; height: 24; radius: 6
                                         color: Config.themeGradientColor1
                                         border.color: Theme.glassBorder; border.width: 1
                                         MouseArea {
                                             anchors.fill: parent
                                             onClicked: colorPicker.openFor("Theme.gradientColor1", "Градієнт Колір 1", Config.themeGradientColor1)
                                         }
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: Config.themeGradientColor1
                                        font.pixelSize: 11
                                        font.family: Theme.fontMono
                                        onAccepted: Config.setProp("Theme.gradientColor1", text)
                                        background: Rectangle {
                                            radius: 6
                                            color: Theme.bgSurface
                                            border.color: Theme.glassBorder
                                            border.width: 1
                                        }
                                    }
                                 }
                            }

                            // Color 2
                            ColumnLayout {
                                spacing: 6
                                Text { text: "Колір 2"; color: Theme.textSub; font.pixelSize: 11 }
                                RowLayout {
                                    spacing: 8
                                     Rectangle {
                                         width: 24; height: 24; radius: 6
                                         color: Config.themeGradientColor2
                                         border.color: Theme.glassBorder; border.width: 1
                                         MouseArea {
                                             anchors.fill: parent
                                             onClicked: colorPicker.openFor("Theme.gradientColor2", "Градієнт Колір 2", Config.themeGradientColor2)
                                         }
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: Config.themeGradientColor2
                                        font.pixelSize: 11
                                        font.family: Theme.fontMono
                                        onAccepted: Config.setProp("Theme.gradientColor2", text)
                                        background: Rectangle {
                                            radius: 6
                                            color: Theme.bgSurface
                                            border.color: Theme.glassBorder
                                            border.width: 1
                                        }
                                    }
                                 }
                            }

                            // Color 3 (optional)
                            ColumnLayout {
                                spacing: 6
                                Text { text: "Колір 3 (опц.)"; color: Theme.textSub; font.pixelSize: 11 }
                                RowLayout {
                                    spacing: 8
                                     Rectangle {
                                         width: 24; height: 24; radius: 6
                                         color: Config.themeGradientColor3 !== "" ? Config.themeGradientColor3 : "transparent"
                                         border.color: Config.themeGradientColor3 !== "" ? Theme.glassBorder : Theme.textMuted
                                         border.width: 1
                                         MouseArea {
                                             anchors.fill: parent
                                             onClicked: colorPicker.openFor("Theme.gradientColor3", "Градієнт Колір 3", Config.themeGradientColor3)
                                         }
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: Config.themeGradientColor3
                                        font.pixelSize: 11
                                        font.family: Theme.fontMono
                                        placeholderText: "例えば #ff0000"
                                        onAccepted: Config.setProp("Theme.gradientColor3", text)
                                        background: Rectangle {
                                            radius: 6
                                            color: Theme.bgSurface
                                            border.color: Theme.glassBorder
                                            border.width: 1
                                        }
                                    }
                                 }
                            }
                        }

                        // Intensity
                        RowLayout {
                            visible: Config.themeGradientEnabled
                            spacing: 10
                            Layout.fillWidth: true

                            Text { text: "Інтенсивність"; color: Theme.textSub; font.pixelSize: 12; Layout.preferredWidth: 100 }
                            Slider {
                                id: slider
                                Layout.fillWidth: true
                                from: 0.0; to: 2.0; stepSize: 0.05
                                value: Config.themeGradientIntensity
                                onMoved: Config.setProp("Theme.gradientIntensity", value)
                                background: Rectangle {
                                    x: slider.leftPadding
                                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                                    width: slider.availableWidth; height: 6; radius: 3
                                    color: Theme.bgSurface
                                    Rectangle {
                                        width: slider.visualPosition * parent.width
                                        height: parent.height; radius: 3
                                        color: Theme.accent
                                    }
                                }
                                handle: Rectangle {
                                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                                    implicitWidth: 14; implicitHeight: 14; radius: 7
                                    color: slider.pressed ? Theme.accentHover : Theme.text
                                    border.color: Theme.accent; border.width: 2
                                }
                            }
                            Text {
                                text: Config.themeGradientIntensity.toFixed(2)
                                color: Theme.textSub; font.pixelSize: 11
                                Layout.preferredWidth: 34
                            }
                        }

                        // Apply to targets
                        RowLayout {
                            visible: Config.themeGradientEnabled
                            spacing: 10
                            Layout.fillWidth: true

                            Text { text: "Застосувати до"; color: Theme.textSub; font.pixelSize: 12; Layout.preferredWidth: 100 }

                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: Config.themeGradientEnabled ? (Config.themeGradientApplyBg ? Theme.accent : Theme.glassCard) : Theme.glassCard
                                border.color: Theme.glassBorder; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "B"
                                    color: Config.themeGradientApplyBg ? Theme.textDark : Theme.textSub
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { Config.setProp("Theme.gradientApplyBg", !Config.themeGradientApplyBg) }
                                }
                            }
                            Text { text: "Background"; color: Theme.textSub; font.pixelSize: 11 }

                            Rectangle {
                                width: 32; height: 32; radius: 8
                                color: Config.themeGradientEnabled ? (Config.themeGradientApplySurf ? Theme.accent : Theme.glassCard) : Theme.glassCard
                                border.color: Theme.glassBorder; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "S"
                                    color: Config.themeGradientApplySurf ? Theme.textDark : Theme.textSub
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { Config.setProp("Theme.gradientApplySurf", !Config.themeGradientApplySurf) }
                                }
                            }
                            Text { text: "Surface"; color: Theme.textSub; font.pixelSize: 11 }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

            // --- Кастомні теми (Theme Studio 2.0) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: customCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: customCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "CUSTOM THEMES"
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: Object.keys(Config.themeCustomThemes).length + " збережених"
                            color: Theme.textSub
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }
                    }

                    // Створення нової кастомної теми з поточних налаштувань
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        TextField {
                            id: newThemeName
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            placeholderText: "Назва теми…"
                            color: Theme.text
                            placeholderTextColor: Theme.textMuted
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.textDark
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                            text: ""
                            background: Rectangle {
                                radius: Theme.radiusSm
                                color: newThemeName.activeFocus ? Theme.glassCardActive : Theme.bgSurface
                                border.color: newThemeName.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: newThemeName.activeFocus ? 2 : 1
                            }
                            onAccepted: appearanceRoot._saveCustomTheme()
                        }

                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: createThemeRow.implicitWidth + 24
                            radius: Theme.radiusSm
                            color: createThemeMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                            border.color: createThemeMa.containsMouse ? Theme.glassBorderFocus : Theme.glassBorder
                            border.width: 1

                            RowLayout {
                                id: createThemeRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text { text: "+"; color: Theme.accent; font.pixelSize: 13; font.bold: true; font.family: Theme.fontMono }
                                Text { text: "Створити з поточної"; color: Theme.text; font.pixelSize: 10; font.bold: true; font.family: Theme.fontMono }
                            }

                            MouseArea {
                                id: createThemeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appearanceRoot._saveCustomTheme()
                            }
                        }
                    }

                    // Сітка збережених кастомних тем з мініатюрою палітри
                    GridLayout {
                        visible: Object.keys(Config.themeCustomThemes).length > 0
                        Layout.fillWidth: true
                        columns: pageScroll.width > 0
                            ? Math.max(1, Math.floor((pageScroll.width + columnSpacing) / (170 + columnSpacing)))
                            : 4
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: Object.keys(Config.themeCustomThemes)

                            delegate: Rectangle {
                                id: customCard
                                required property var modelData

                                readonly property var themeData: Config.themeCustomThemes[modelData]

                                Layout.fillWidth: true
                                Layout.preferredWidth: 170
                                implicitHeight: customCardCol.implicitHeight + 16
                                radius: Theme.radiusMd
                                color: Theme.glassCard
                                border.color: customCardMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                                border.width: 1

                                // Card-level hover — ВНИЗУ содержимого: объявлен ДО ColumnLayout,
                                // иначе он накрывает кнопки и перехватывает их клики.
                                MouseArea {
                                    id: customCardMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                ColumnLayout {
                                    id: customCardCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    // Назва теми
                                    Text {
                                        text: customCard.modelData
                                        color: Theme.text
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Theme.fontMono
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Мініатюра палітри: смуга основних кольорів + рядок акцентів
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: 6
                                        color: customCard.themeData.background || "#11111b"
                                        border.color: Theme.glassBorder
                                        border.width: 1
                                        clip: true

                                        // Градієнтна мініатюра
                                        Rectangle {
                                            visible: customCard.themeData.gradientEnabled === true
                                            anchors.fill: parent
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: customCard.themeData.gradientColor1 || customCard.themeData.background || "#11111b" }
                                                GradientStop { position: 1.0; color: customCard.themeData.gradientColor2 || customCard.themeData.surface || "#313244" }
                                            }
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 4
                                            spacing: 3

                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.surface || "#313244" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.accent || "#89b4fa" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.secondaryAccent || "#cba6f7" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.text || "#cdd6f4" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.success || "#a6e3a1" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.warning || "#f9e2af" }
                                            Rectangle { width: 10; height: 10; radius: 2; color: customCard.themeData.error || "#f38ba8" }
                                        }
                                    }

                                    // Дії: Apply / Edit / Duplicate / Delete
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Apply
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 24
                                            radius: 6
                                            color: Theme.accent
                                            border.color: Theme.glassBorder; border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "APPLY"
                                                color: Theme.textDark
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.family: Theme.fontMono
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appearanceRoot._applyCustomTheme(customCard.modelData)
                                            }
                                        }

                                        // Edit (завантажити в студію для редагування)
                                        Rectangle {
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                                            color: editBtnMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                            border.color: Theme.glassBorder; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✎"
                                                color: Theme.textSub
                                                font.pixelSize: 11
                                            }
                                            MouseArea {
                                                id: editBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appearanceRoot._applyCustomTheme(customCard.modelData)
                                            }
                                        }

                                        // Duplicate
                                        Rectangle {
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                                            color: dupBtnMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                            border.color: Theme.glassBorder; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "⧉"
                                                color: Theme.textSub
                                                font.pixelSize: 11
                                            }
                                            MouseArea {
                                                id: dupBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appearanceRoot._duplicateCustomTheme(customCard.modelData)
                                            }
                                        }

                                        // Delete
                                        Rectangle {
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                                            color: delBtnMa.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : Theme.glassCard
                                            border.color: delBtnMa.containsMouse ? Theme.accentRed : Theme.glassBorder
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: Theme.accentRed
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: delBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appearanceRoot._deleteCustomTheme(customCard.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Порожній стан
                    Rectangle {
                        visible: Object.keys(Config.themeCustomThemes).length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Theme.radiusSm
                        color: Theme.bgSurface
                        border.color: Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Немає збережених тем — створіть першу з поточної палітри"
                            color: Theme.textMuted
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // --- Пресети ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: presetCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "БІБЛІОТЕКА ТЕМ"
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        // Поточна тема: ім'я збігненого пресету або "Custom"
                        Text {
                            text: appearanceRoot.currentPresetName()
                            color: text === "Custom" ? Theme.accentYellow : Theme.accent
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "normal", label: "Звичайні", count: appearanceRoot.normalPresetModel.length },
                                { key: "gradient", label: "Градієнтні", count: appearanceRoot.gradientPresetModel.length }
                            ]

                            delegate: Rectangle {
                                id: typeTab
                                required property var modelData
                                readonly property bool selected: appearanceRoot.presetType === modelData.key
                                Layout.preferredWidth: typeLabel.implicitWidth + 24
                                Layout.preferredHeight: 32
                                radius: Theme.radiusSm
                                color: selected
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                       : (typeMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
                                border.color: selected ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: selected ? 2 : 1

                                Text {
                                    id: typeLabel
                                    anchors.centerIn: parent
                                    text: typeTab.modelData.label + "  " + typeTab.modelData.count
                                    color: typeTab.selected ? Theme.accent : Theme.textSub
                                    font.pixelSize: 10
                                    font.bold: typeTab.selected
                                    font.family: Theme.fontMono
                                }

                                MouseArea {
                                    id: typeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        appearanceRoot.presetType = typeTab.modelData.key
                                        appearanceRoot.presetCategory = "All"
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: appearanceRoot.filteredPresetModel().length + " показано"
                            color: Theme.textMuted
                            font.pixelSize: 9
                            font.family: Theme.fontMono
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: presetSearchField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            placeholderText: "Пошук за назвою…"
                            color: Theme.text
                            placeholderTextColor: Theme.textMuted
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.textDark
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                            onTextChanged: appearanceRoot.presetSearch = text
                            background: Rectangle {
                                radius: Theme.radiusSm
                                color: presetSearchField.activeFocus ? Theme.glassCardActive : Theme.bgSurface
                                border.color: presetSearchField.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: presetSearchField.activeFocus ? 2 : 1
                            }
                        }

                        ComboBox {
                            id: presetCategoryCombo
                            Layout.preferredWidth: Math.min(210, Math.max(150, presetCol.width * 0.28))
                            Layout.preferredHeight: 34
                            model: appearanceRoot.presetCategories()
                            currentIndex: Math.max(0, model.indexOf(appearanceRoot.presetCategory))
                            onActivated: function(index) {
                                appearanceRoot.presetCategory = model[index]
                            }
                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 28
                                text: presetCategoryCombo.displayText === "All"
                                      ? "Усі стилі" : presetCategoryCombo.displayText
                                color: Theme.textSub
                                font.pixelSize: 10
                                font.family: Theme.fontMono
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: Text {
                                x: presetCategoryCombo.width - width - 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⌄"
                                color: presetCategoryCombo.popup.visible ? Theme.accent : Theme.textMuted
                                font.pixelSize: 13
                            }
                            background: Rectangle {
                                radius: Theme.radiusSm
                                color: presetCategoryCombo.popup.visible ? Theme.glassCardActive : Theme.bgSurface
                                border.color: presetCategoryCombo.popup.visible
                                              ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: presetCategoryCombo.popup.visible ? 2 : 1
                            }
                            delegate: ItemDelegate {
                                width: presetCategoryCombo.popup.width - 8
                                implicitHeight: 30
                                contentItem: Text {
                                    text: modelData === "All" ? "Усі стилі" : modelData
                                    color: highlighted ? Theme.accent : Theme.textSub
                                    font.pixelSize: 10
                                    font.family: Theme.fontMono
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: highlighted ? Theme.glassCardHover : "transparent"
                                }
                            }
                            popup: Popup {
                                y: presetCategoryCombo.height + 4
                                width: presetCategoryCombo.width
                                implicitHeight: Math.min(280, contentItem.implicitHeight + 8)
                                padding: 4
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: presetCategoryCombo.delegateModel
                                    currentIndex: presetCategoryCombo.highlightedIndex
                                    boundsBehavior: Flickable.StopAtBounds
                                }
                                background: Rectangle {
                                    radius: Theme.radiusMd
                                    color: Theme.glassPopupSolid
                                    border.color: Theme.glassBorderHover
                                    border.width: 1
                                }
                            }
                        }
                    }

                    GridLayout {
                        id: presetGrid
                        Layout.fillWidth: true
                        // Адаптивна сітка: кількість колонок залежить від доступної ширини
                        columns: pageScroll.width > 0
                            ? Math.max(1, Math.floor((pageScroll.width + columnSpacing) / (appearanceRoot._presetMinWidth + columnSpacing)))
                            : 4
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            id: presetRepeater
                            model: appearanceRoot.filteredPresetModel()

                                delegate: Rectangle {
                                    id: presetCard
                                    required property var modelData

                                    readonly property bool active: appearanceRoot._presetActive(modelData)

                                readonly property string accent2:
                                    appearanceRoot._presetColor(modelData.acc2, "#cba6f7")
                                readonly property string textCol:
                                    appearanceRoot._presetColor(modelData.text, "#cdd6f4")
                                readonly property string textSubCol:
                                    appearanceRoot._presetColor(modelData.textSub, "#a6adc8")
                                readonly property string borderCol:
                                    appearanceRoot._presetColor(modelData.border, "#45475a")
                                readonly property string successCol:
                                    appearanceRoot._presetColor(modelData.success, "#a6e3a1")
                                readonly property string warningCol:
                                    appearanceRoot._presetColor(modelData.warning, "#f9e2af")
                                readonly property string errorCol:
                                    appearanceRoot._presetColor(modelData.error, "#f38ba8")

                                Layout.fillWidth: true
                                Layout.preferredWidth: appearanceRoot._presetMinWidth
                                implicitHeight: 104

                                radius: Theme.radiusMd
                                color: presetCard.active
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                                    : (presetMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
                                border.color: presetCard.active
                                    ? Theme.glassBorderFocus
                                    : (presetMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
                                border.width: presetCard.active ? 2 : 1

                                scale: presetMa.pressed ? 0.97 : 1.0

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
                                }

                                ColumnLayout {
                                    id: presetCardCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    // --- Мініпрев'ю: фон, поверхня, акцент і допоміжний колір ---
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: 7
                                        color: presetCard.modelData.bg
                                        border.color: Qt.rgba(Qt.color(presetCard.borderCol).r,
                                                              Qt.color(presetCard.borderCol).g,
                                                              Qt.color(presetCard.borderCol).b, 0.8)
                                         border.width: 1
                                         clip: true

                                         Rectangle {
                                             anchors.fill: parent
                                             visible: presetCard.modelData.presetType === "gradient"
                                                      && !presetCard.modelData.gradC3
                                             gradient: Gradient {
                                                 orientation: Gradient.Horizontal
                                                 GradientStop { position: 0.0; color: presetCard.modelData.gradC1 || presetCard.modelData.bg }
                                                 GradientStop { position: 1.0; color: presetCard.modelData.gradC2 || presetCard.modelData.surf }
                                             }
                                         }

                                         Rectangle {
                                             anchors.fill: parent
                                             visible: presetCard.modelData.presetType === "gradient"
                                                      && !!presetCard.modelData.gradC3
                                             gradient: Gradient {
                                                 orientation: Gradient.Horizontal
                                                 GradientStop { position: 0.0; color: presetCard.modelData.gradC1 || presetCard.modelData.bg }
                                                 GradientStop { position: 0.5; color: presetCard.modelData.gradC3 || presetCard.modelData.acc }
                                                 GradientStop { position: 1.0; color: presetCard.modelData.gradC2 || presetCard.modelData.surf }
                                             }
                                         }

                                         // Верхня панель (surface)
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 15
                                            color: presetCard.modelData.surf
                                        }

                                        // Кнопки «вікна»: success / warning / error з палітри
                                        Row {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 7
                                            anchors.topMargin: 5
                                            spacing: 4

                                            Rectangle { width: 5; height: 5; radius: 2.5; color: presetCard.successCol }
                                            Rectangle { width: 5; height: 5; radius: 2.5; color: presetCard.warningCol }
                                            Rectangle { width: 5; height: 5; radius: 2.5; color: presetCard.errorCol }
                                        }

                                        // Мінімальна бічна панель
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 7
                                            anchors.topMargin: 22
                                            width: 17
                                            height: parent.height - 29
                                            radius: 4
                                            color: presetCard.modelData.surf
                                        }

                                        // Акцентний рядок і рядки контенту
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 30
                                            anchors.topMargin: 22
                                            width: parent.width - 38
                                            height: 5
                                            radius: 2.5
                                            color: presetCard.modelData.acc
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 30
                                            anchors.topMargin: 31
                                            width: parent.width - 50
                                            height: 4
                                            radius: 2
                                            color: presetCard.accent2
                                            opacity: 0.9
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 30
                                            anchors.topMargin: 39
                                            width: parent.width - 62
                                            height: 4
                                            radius: 2
                                            color: presetCard.textCol
                                            opacity: 0.85
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.leftMargin: 30
                                            anchors.topMargin: 47
                                            width: parent.width - 78
                                            height: 4
                                            radius: 2
                                            color: presetCard.textSubCol
                                            opacity: 0.7
                                        }

                                        // Акцентний «чип» у правому нижньому куті
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.rightMargin: 7
                                            anchors.bottomMargin: 5
                                            width: 14
                                            height: 5
                                            radius: 2.5
                                            color: presetCard.modelData.acc
                                            opacity: 0.9
                                        }
                                    }

                                    // --- Назва + позначка активної теми ---
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: presetCard.modelData.name
                                            color: presetCard.active || presetMa.containsMouse ? Theme.text : Theme.textSub
                                            font.pixelSize: 10
                                            font.bold: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }

                                        Rectangle {
                                            visible: presetCard.active
                                            implicitWidth: 14
                                            implicitHeight: 14
                                            radius: 7
                                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                            border.color: Theme.glassBorderFocus
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                color: Theme.accent
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: presetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appearanceRoot._applyPreset(presetCard.modelData)
                                }
                            }
                        }
                    }
            }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // --- Вбудований color picker (без сторонніх залежностей) ---
    ColorPickerPopup {
        id: colorPicker
    }
}
