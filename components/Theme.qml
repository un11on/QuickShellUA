pragma Singleton
import QtQuick
import "."

QtObject {
    id: root

    // ================= FALLBACK: CATPPUCCIN MOCHA =================
    // Базові "(каттпучін)" кольори — використовуються, коли Config
    // не дає коректного значення (порожній/невалідний hex тощо).
    readonly property color _mochaBg:          "#11111b"
    readonly property color _mochaMantle:      "#181825"
    readonly property color _mochaBase:        "#1e1e2e"
    readonly property color _mochaSurface:     "#313244"
    readonly property color _mochaSurfaceHover:"#45475a"
    readonly property color _mochaSurfaceActive:"#585b70"
    readonly property color _mochaAccent:      "#89b4fa"
    readonly property color _mochaAccentHover: "#b4befe"

    // ================= ВАЛІДАЦІЯ / ХЕЛПЕРИ =================
    function _safeColor(str, fallback) {
        var s = String(str || "")
        if (/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(s))
            return s
        return fallback
    }

    function _mix(c1, c2, t) {
        // явная конвертация: строковые литералы не автовыражаются в color внутри JS
        var a = Qt.color(c1)
        var b = Qt.color(c2)
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    // ================= ДИНАМІЧНІ КОЛЬОРИ З CONFIG =================
    // Theme ← Config (односторонній зв'язок, без циклів: Config не знає про Theme)
    readonly property color cfgBg:      _safeColor(Config.themeBackground, root._mochaBg)
    readonly property color cfgSurface: _safeColor(Config.themeSurface,  root._mochaSurface)
    readonly property color cfgAccent:  _safeColor(Config.themeAccent,   root._mochaAccent)

    // === РОЗШИРЕНА ПАЛІТРА (редагована в налаштуваннях) ===
    readonly property color cfgSecondaryAccent: _safeColor(Config.themeSecondaryAccent, "#cba6f7")
    readonly property color cfgText:            _safeColor(Config.themeText,            "#cdd6f4")
    readonly property color cfgTextSub:         _safeColor(Config.themeSecondaryText,   "#a6adc8")
    readonly property color cfgBorder:          _safeColor(Config.themeBorder,          "#45475a")
    readonly property color cfgSuccess:         _safeColor(Config.themeSuccess,         "#a6e3a1")
    readonly property color cfgWarning:         _safeColor(Config.themeWarning,         "#f9e2af")
    readonly property color cfgError:           _safeColor(Config.themeError,           "#f38ba8")

    // === GRADIENT STUDIO (Theme Studio 2.0) ===
    // Напрямок завжди горизонтальний (ліворуч направо).
    readonly property bool  cfgGradientEnabled: Config.themeGradientEnabled === true
    readonly property color cfgGradientColor1: _safeColor(Config.themeGradientColor1, root._mochaBg)
    readonly property color cfgGradientColor2: _safeColor(Config.themeGradientColor2, root._mochaSurface)
    readonly property color cfgGradientColor3: _safeColor(Config.themeGradientColor3, "")
    readonly property real  cfgGradientIntensity: {
        var v = Number(Config.themeGradientIntensity)
        return (!isNaN(v) && v >= 0 && v <= 2) ? v : 1.0
    }
    readonly property bool  cfgGradientApplyBg: Config.themeGradientApplyBg === true
    readonly property bool  cfgGradientApplySurf: Config.themeGradientApplySurf === true
    readonly property var cfgGradientDirection: {
    var v = Config.themeGradientDirection
    if (v === undefined || v === null) return Qt.Horizontal
    return v
}

    // Збірка gradient stops (уplier intensity до колірів)
    // intensity: 0 = оригінальні кольори, 1 = оригінальні кольори,
    // проміжні значення — легке підсвітлення/затемнення без перебілу в білого
    function _gradIntensify(c, t) {
        var cc = Qt.color(c)
        var factor = 1.0 + (t - 1.0) * 0.2
        return Qt.rgba(
            Math.min(1, Math.max(0, cc.r * factor)),
            Math.min(1, Math.max(0, cc.g * factor)),
            Math.min(1, Math.max(0, cc.b * factor)), 1
        )
    }

    // QGradient конфігурація для компонентів (Theme Studio 2.0)
    // Повертає об'єкт конфігурації, який компоненти можуть використати
    // для створення Rectangle.gradient або fallback-коліру.
    readonly property variant gradient: {
        if (!cfgGradientEnabled) {
            return { enabled: false, color: cfgBg }
        }
        var c1 = _gradIntensify(cfgGradientColor1, cfgGradientIntensity)
        var c2 = _gradIntensify(cfgGradientColor2, cfgGradientIntensity)
        var stops = [
            { position: 0.0, color: c1 },
            { position: 1.0, color: c2 }
        ]
        if (cfgGradientColor3 && cfgGradientColor3 !== "") {
            var c3 = _gradIntensify(cfgGradientColor3, cfgGradientIntensity)
            stops.push({ position: 0.5, color: c3 })
        }
        return {
            enabled: true,
            orientation: cfgGradientDirection,
            stops: stops
        }
    }

    // Похідні кольори для компонентів без gradient-підтримки (solid fallback)
    readonly property color gradBgSolid: cfgGradientEnabled ? _mix(cfgGradientColor1, cfgGradientColor2, 0.5) : cfgBg
    readonly property color gradSurfSolid: cfgGradientEnabled ? _mix(cfgGradientColor1, cfgGradientColor2, 0.6) : cfgSurface

    // Множник прозорості скла (Config.Theme.opacity, захищений від NaN/виходу за межі)
    readonly property real glassOpacity: {
        var v = Number(Config.themeOpacity)
        return (!isNaN(v) && v > 0 && v <= 1) ? v : 1
    }

    // === Проміжні результуючі (перераховуються один раз при зміні кольорів) ===
    readonly property color mixBgSurfLight:  _mix(cfgBg, cfgSurface, 0.42)   // ≈ скло (базове)
    readonly property color mixBgSurfFull:   _mix(cfgBg, cfgSurface, 0.9)    // ≈ скло при hover
    readonly property color mixBgSurfDark:   _mix(cfgBg, cfgSurface, 0.19)   // ≈ скло popup
    readonly property color mixBgSurfMid:    _mix(cfgBg, cfgSurface, 0.35)   // ≈ скло суцільне
    readonly property color surfaceLiftS:    _mix(cfgSurface, "#ffffff", 0.07)
    readonly property color surfaceLiftM:    _mix(cfgSurface, "#ffffff", 0.075)
    readonly property color surfaceLiftL:    _mix(cfgSurface, "#ffffff", 0.15)

    // === BACKGROUNDS ===
    readonly property color bgCrust:  cfgBg
    readonly property color bgMantle: _mix(cfgBg, cfgSurface, 0.2)
    readonly property color bgBase:   _mix(cfgBg, cfgSurface, 0.41)
    readonly property color bgSurface:       cfgSurface
    readonly property color bgSurfaceHover:  _mix(cfgSurface, "#ffffff", 0.09)
    readonly property color bgSurfaceActive: _mix(cfgSurface, "#ffffff", 0.2)

    // === FROSTED GLASS & ACRYLIC (Alpha для Hyprland blur) ===
    // Альфи масштабуються glassOpacity; opacity=1 дає точні "мучні" (Mocha) значення
    readonly property color glassBg:        Qt.rgba(mixBgSurfLight.r, mixBgSurfLight.g, mixBgSurfLight.b, 0.72 * glassOpacity)
    readonly property color glassBgHover:   Qt.rgba(mixBgSurfFull.r, mixBgSurfFull.g, mixBgSurfFull.b, 0.82 * glassOpacity)
    readonly property color glassBgActive:  Qt.rgba(surfaceLiftS.r, surfaceLiftS.g, surfaceLiftS.b, 0.90 * glassOpacity)

    readonly property color glassPopup:      Qt.rgba(mixBgSurfDark.r, mixBgSurfDark.g, mixBgSurfDark.b, Math.min(1, 0.82 * glassOpacity))
    readonly property color glassPopupSolid: Qt.rgba(mixBgSurfMid.r, mixBgSurfMid.g, mixBgSurfMid.b, Math.min(1, 0.94 * glassOpacity))

    readonly property color glassCard:       Qt.rgba(cfgSurface.r, cfgSurface.g, cfgSurface.b, 0.60 * glassOpacity)
    readonly property color glassCardHover:  Qt.rgba(surfaceLiftM.r, surfaceLiftM.g, surfaceLiftM.b, 0.75 * glassOpacity)
    readonly property color glassCardActive: Qt.rgba(surfaceLiftL.r, surfaceLiftL.g, surfaceLiftL.b, 0.85 * glassOpacity)

    // === BORDERS & GLOWS ===
    readonly property color border:       cfgBorder
    readonly property color borderHover:  _mix(cfgBorder, "#ffffff", 0.18)
    readonly property color borderFocus:  cfgAccent

    readonly property color glassBorder:       Qt.rgba(cfgBorder.r, cfgBorder.g, cfgBorder.b, 0.55)
    readonly property color glassBorderHover:  Qt.rgba(cfgBorder.r, cfgBorder.g, cfgBorder.b, 0.95)
    readonly property color glassBorderFocus:  Qt.rgba(cfgAccent.r, cfgAccent.g, cfgAccent.b, 0.50)

    // === ACCENTS ===
    // accent, accentHover і рамки фокусу прив'язані до обраного акценту.
    // Семантичні success/warning/error тепер теж редаговані в палітрі.
    readonly property color accent:           cfgAccent
    readonly property color accentHover:      _mix(cfgAccent, "#ffffff", 0.35)
    readonly property color accentSecondary: cfgSecondaryAccent
    readonly property color accentPink: "#f5c2e7"      // Pink
    readonly property color accentRed: cfgError        // Error
    readonly property color accentPeach: "#fab387"     // Peach
    readonly property color accentYellow: cfgWarning   // Warning
    readonly property color accentGreen: cfgSuccess    // Success
    readonly property color accentTeal: "#94e2d5"      // Teal
    readonly property color accentSapphire: "#74c7ec"  // Sapphire

    // === TYPOGRAPHY ===
    // Адаптивные цвета текста: для светлых тем — тёмный текст, для тёмных — светлый.
    // Определение светлой/тёмной темы по относительной luminance фона (sRGB).
    readonly property real bgLuminance: {
        var c = Qt.color(cfgBg)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
    readonly property bool isLightTheme: bgLuminance > 0.5

    // Контрастный текст на цветном фоне (белый на тёмном, тёмный на светлом)
    function _contrastText(color) {
        var c = Qt.color(color)
        var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return lum > 0.5 ? "#11111b" : "#cdd6f4"
    }

    readonly property color text: cfgText
    readonly property color textDark: _contrastText(cfgAccent)
    readonly property color textSub: cfgTextSub
    readonly property color textMuted: isLightTheme ? "#6c6f85" : "#6c7086"

    readonly property string fontMono: "JetBrainsMono Nerd Font"

    // === RADII ===
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 20
    readonly property int radiusRound: 9999

    // ================= АНІМАЦІЇ (Config.Animations.*) =================
    // duration = базовий "fast"; normal/slow масштабуються відносно нього,
    // тож значення за замовчуванням (140/240/350) зберігаються 1:1.
    readonly property bool animEnabled: Config.animationsEnabled === true

    function _animDur(raw) {
        var v = Math.round(Number(raw))
        return (!isNaN(v) && v > 0) ? Math.min(v, 3000) : 140
    }

    readonly property real _durScale: _animDur(Config.animationsDuration) / 140

    // Базові тривалості (0 коли анімації вимкнені)
    readonly property int animFast:   animEnabled ? _animDur(Config.animationsDuration) : 0
    readonly property int animNormal: animEnabled ? Math.round(240 * _durScale) : 0
    readonly property int animSlow:   animEnabled ? Math.round(350 * _durScale) : 0

    // Множники тривалості за категоріями (1.0 = базова)
    readonly property real animWindowMult:   Config.animationsWindow
    readonly property real animPopupMult:    Config.animationsPopup
    readonly property real animElementMult:  Config.animationsElement
    readonly property real animTabMult:      Config.animationsTab
    readonly property real animHoverMult:    Config.animationsHover
    readonly property real animPanelMult:    Config.animationsPanel

    // Тривалість за категорією (базова × множник)
    function animDurFor(category, baseMs) {
        if (!animEnabled) return 0
        var mult = 1.0
        switch (category) {
            case "window":   mult = animWindowMult; break
            case "popup":    mult = animPopupMult; break
            case "element":  mult = animElementMult; break
            case "tab":      mult = animTabMult; break
            case "hover":    mult = animHoverMult; break
            case "panel":    mult = animPanelMult; break
            default:         mult = 1.0; break
        }
        return Math.round(baseMs * mult)
    }

    // Spring-mode: якщо увімкнено — компоненти мають використати SpringAnimation
    // замість NumberAnimation/ColorAnimation з easing.
    readonly property bool animUseSpring: Config.animationsSpringEnabled === true
    readonly property int  animSpringStiffness: Config.animationsSpringStiffness
    readonly property int  animSpringDamping: Config.animationsSpringDamping

    // Еasing-параметри (беремо з Config, з дефолтами для зворотної сумісності)
    readonly property int easingStandard: Config.animationsEnabled === true ? Easing.OutCubic : Easing.Linear
    readonly property int easingSpring: Easing.OutBack
    readonly property real easingOvershoot: Config.animationsOvershoot

    // ================= BLUETOOTH MENU =================
    // Єдина точка для всіх bluetooth-специфічних кольорів (орбітальний режим)
    readonly property color btBg:        Qt.rgba(_mochaBg.r, _mochaBg.g, _mochaBg.b, 0.94)
    readonly property color btNebula:   Qt.rgba(0.55, 0.35, 0.96, 0.08)
    readonly property color btOrbitRing: Qt.rgba(1.0, 1.0, 1.0, 0.06)
    readonly property color btTextMuted: "#94a3b8"    // ≈ textSub
    readonly property color btTextLight: "#e2e8f0"    // ≈ text, але трохи світліший для контрасту на темному
    readonly property color btPurple:   "#a855f7"
    readonly property color btPurpleDark: "#8b5cf6"
    readonly property color btCyan:     "#38bdf8"
    readonly property color btGreen:    "#4ade80"
    readonly property color btPink:     "#ec4899"
    readonly property color btBlue1:    "#3b82f6"
    readonly property color btTeal:     "#06b6d4"
    readonly property color btRed:      "#f43f5e"
    readonly property color btSurface: Qt.rgba(0.09, 0.10, 0.17, 0.85)
    readonly property color btBorder:   Qt.rgba(1, 1, 1, 0.08)

    // ================= WALLPAPER STUDIO (ICE-CYBER) =================
    // Окрема фіксована палітра для вікна Wallpaper Picker: не залежить від
    // користувацької теми, щоб зберегти темний ice-cyber вигляд.
    readonly property color wpBg:            "#050a12"
    readonly property color wpBgDeep:        "#03060c"
    readonly property color wpPanel:         Qt.rgba(0.035, 0.060, 0.100, 0.975)
    readonly property color wpSurface:       Qt.rgba(0.060, 0.110, 0.170, 0.92)
    readonly property color wpSurfaceHover:  Qt.rgba(0.100, 0.180, 0.260, 0.95)
    readonly property color wpSurfaceActive: Qt.rgba(0.130, 0.240, 0.340, 0.98)
    readonly property color wpBorder:        Qt.rgba(0.45, 0.85, 1.00, 0.16)
    readonly property color wpBorderHover:   Qt.rgba(0.55, 0.90, 1.00, 0.38)
    readonly property color wpBorderFocus:   Qt.rgba(0.55, 0.92, 1.00, 0.85)
    readonly property color wpIce:           "#8be9ff"
    readonly property color wpIceBright:     "#d6f7ff"
    readonly property color wpIceDim:        "#3aa8c9"
    readonly property color wpText:          "#e8f8ff"
    readonly property color wpTextSub:       "#93b8cc"
    readonly property color wpTextMuted:     "#5d7d90"
    readonly property color wpError:         "#ff6b8a"
    readonly property color wpSuccess:       "#5ef2c0"
    readonly property color wpWarning:       "#ffd166"
    readonly property color wpGlow:          Qt.rgba(0.35, 0.85, 1.00, 0.35)
    readonly property color wpGridLine:      Qt.rgba(0.45, 0.85, 1.00, 0.05)
}
