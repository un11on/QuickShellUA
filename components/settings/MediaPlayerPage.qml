import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."
import "."  // ColorPickerPopup (qmldir поточного каталогу)

// ============================================================================
// MediaPlayerPage — вкладка «Медіаплеєр».
//
// A. TopBar Player: керує тим самим LEGO-модулем mediaplayer у Panel.layout
//    (жодного другого блоку чи MPRIS-сервісу не створюється).
// B. Lyrics, C. Поведінка: зберігаються у Config.MediaPlayer через існуючий
//    mergeDefaults/setProp; застосовуються одразу.
//
// Popup Player не має окремої секції: його геометрія фіксована, а вікно
// відкривається з блоку TopBar (MediaPlayerPanel).
//
// Сторінка не містить власного плеєра і не відкриває других вікон.
// ============================================================================
Item {
    id: mediaRoot
    anchors.fill: parent
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ------------------------------------------------------------------
    // LEGO-модуль mediaplayer (єдине джерело для TopBar-блоку)
    // ------------------------------------------------------------------
    readonly property var mediaModule: mediaRoot.findModule()

    // ------------------------------------------------------------------
    // Живий popup (той самий єдиний екземпляр із TopBar). Використовується
    // лише для читання стану Lyrics і кнопки повторного пошуку.
    // ------------------------------------------------------------------
    readonly property var mediaPanelRef: PanelController.mediaPanel

    // Висота Lyrics має сенс лише тоді, коли текст реально показаний:
    // Lyrics увімкнено, є музичний плеєр (не відео), область відкрита і
    // текст успішно завантажено. Якщо текст зникне — рядок знову ховається.
    readonly property bool lyricsSizeVisible: {
        var p = mediaRoot.mediaPanelRef
        return Config.mediaPlayerLyricsEnabled
            && p !== null && p !== undefined
            && p.hasPlayer === true
            && p.isVideo === false
            && p.lyricsOpen === true
            && p.lyricsState === "ready"
    }

    function findModule() {
        var cur = Config.normalizeLayout(Config.panelLayout)
        var zones = ["left", "center", "right", "disabled"]
        for (var z = 0; z < zones.length; z++) {
            var list = cur[zones[z]] || []
            for (var i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === "mediaplayer")
                    return list[i]
            }
        }
        return null
    }

    function moduleZone() {
        var cur = Config.normalizeLayout(Config.panelLayout)
        var order = ["left", "center", "right", "disabled"]
        for (var zi = 0; zi < order.length; zi++) {
            var list = cur[order[zi]] || []
            for (var mi = 0; mi < list.length; mi++) {
                if (list[mi] && list[mi].id === "mediaplayer")
                    return order[zi]
            }
        }
        return "disabled"
    }

    function moduleValue(prop, fallback) {
        var m = mediaRoot.mediaModule
        if (!m || m[prop] === undefined || m[prop] === null)
            return fallback
        return m[prop]
    }

    function setModuleProp(prop, value) {
        Config.setLayoutModuleProp("mediaplayer", prop, value)
    }

    function resetMediaPlayer() {
        var d = Config.defaults.MediaPlayer
        for (var k in d) {
            if (d.hasOwnProperty(k))
                Config.setProp("MediaPlayer." + k, d[k])
        }
        setModuleProp("size", "normal")
        setModuleProp("display", "both")
        setModuleProp("showArt", true)
        setModuleProp("showTitle", true)
        setModuleProp("showArtist", true)
        setModuleProp("showControls", true)
        setModuleProp("maxTitleLength", 28)
        setModuleProp("titleWidth", 0)
        setModuleProp("coverSize", 0)
    }

    property string retryNote: ""

    // ------------------------------------------------------------------
    // Lyrics Presets: оформлення тексту пісень.
    // Єдине джерело дефолтів пресета; значення зберігаються у Config.
    // MediaPlayer (той самий механізм, що й решта вкладки — без другої
    // системи). Панель (MediaPlayerPanel) читає лише фінальні значення.
    // ------------------------------------------------------------------
    readonly property var lyricsPresets: [
        { key: "classic", label: "Classic",
          vals: { fontSize: 11, textColor: "", activeColor: "",
                  bgOpacity: 0.6, align: "center", lineSpacing: 1.25 } },
        { key: "karaoke", label: "Karaoke",
          vals: { fontSize: 12, textColor: "", activeColor: "",
                  bgOpacity: 0.6, align: "center", lineSpacing: 1.15 } },
        { key: "minimal", label: "Minimal",
          vals: { fontSize: 14, textColor: "", activeColor: "",
                  bgOpacity: 0.0, align: "center", lineSpacing: 1.35 } },
        { key: "glass", label: "Glass",
          vals: { fontSize: 12, textColor: "", activeColor: "",
                  bgOpacity: 0.35, align: "left", lineSpacing: 1.25 } }
    ]

    function lyricsPresetByKey(key) {
        for (var i = 0; i < mediaRoot.lyricsPresets.length; ++i)
            if (mediaRoot.lyricsPresets[i].key === key)
                return mediaRoot.lyricsPresets[i]
        return null
    }

    function applyLyricsPreset(key) {
        var p = mediaRoot.lyricsPresetByKey(key)
        if (!p) return
        var v = p.vals
        Config.setProp("MediaPlayer.lyricsPreset", p.key)
        Config.setProp("MediaPlayer.lyricsFontSize", v.fontSize)
        Config.setProp("MediaPlayer.lyricsTextColor", v.textColor)
        Config.setProp("MediaPlayer.lyricsActiveColor", v.activeColor)
        Config.setProp("MediaPlayer.lyricsBgOpacity", v.bgOpacity)
        Config.setProp("MediaPlayer.lyricsAlign", v.align)
        Config.setProp("MediaPlayer.lyricsLineSpacing", v.lineSpacing)
    }

    // Активний пресет: порівняння фактичних значень із дефолтами.
    // Ручна зміна будь-якого параметра => "custom" (бейдж «змінено»).
    function currentLyricsPresetKey() {
        var cur = {
            fontSize: Config.mediaPlayerLyricsFontSize,
            textColor: String(Config.mediaPlayerLyricsTextColor || ""),
            activeColor: String(Config.mediaPlayerLyricsActiveColor || ""),
            bgOpacity: Number(Config.mediaPlayerLyricsBgOpacity),
            align: Config.mediaPlayerLyricsAlign,
            lineSpacing: Number(Config.mediaPlayerLyricsLineSpacing)
        }
        for (var i = 0; i < mediaRoot.lyricsPresets.length; ++i) {
            var v = mediaRoot.lyricsPresets[i].vals
            if (cur.fontSize === v.fontSize && cur.textColor === v.textColor
                    && cur.activeColor === v.activeColor
                    && Math.abs(cur.bgOpacity - v.bgOpacity) < 0.001
                    && cur.align === v.align
                    && Math.abs(cur.lineSpacing - v.lineSpacing) < 0.001)
                return mediaRoot.lyricsPresets[i].key
        }
        return "custom"
    }

    // Валідація значень для контролів (захист від пошкодженого settings.json)
    function _lyrClampI(v, fallback, lo, hi) {
        var n = Math.round(Number(v))
        return (!isNaN(n) && n >= lo && n <= hi) ? n : fallback
    }
    function _lyrClampR(v, fallback, lo, hi) {
        var n = Number(v)
        return (!isNaN(n) && n >= lo && n <= hi) ? n : fallback
    }
    function _lyrSafeColor(v, fallback) {
        var s = String(v || "")
        return /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(s) ? s : fallback
    }

    // ------------------------------------------------------------------
    // Перевикористовувані контроли (стиль PanelPage/AnimationsPage)
    // ------------------------------------------------------------------
    component CardTitle: Text {
        color: Theme.textMuted
        font.pixelSize: 11
        font.bold: true
        font.family: Theme.fontMono
    }

    component ParamSlider: RowLayout {
        id: psRoot

        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property string prop: ""
        property real step: 1
        property var format: null
        property bool enabled: true

        signal edited(real value)

        spacing: 10

        onValueChanged: Qt.callLater(function() { psCtrl.value = psRoot.value })

        Text {
            text: psRoot.label
            color: psRoot.enabled ? Theme.textSub : Theme.textMuted
            font.pixelSize: 12
            Layout.preferredWidth: 150
            elide: Text.ElideRight
        }

        Slider {
            id: psCtrl
            Layout.fillWidth: true
            from: psRoot.from
            to: psRoot.to
            stepSize: psRoot.step
            value: psRoot.value
            enabled: psRoot.enabled
            onMoved: {
                if (psRoot.prop.length > 0)
                    Config.setProp(psRoot.prop, psCtrl.value)
                else
                    psRoot.edited(psCtrl.value)
            }

            background: Rectangle {
                x: psCtrl.leftPadding
                y: psCtrl.topPadding + psCtrl.availableHeight / 2 - height / 2
                width: psCtrl.availableWidth
                height: 6
                radius: 3
                color: psCtrl.enabled ? Theme.bgSurface : Theme.textMuted

                Rectangle {
                    width: psCtrl.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: psCtrl.enabled ? Theme.accent : Theme.textMuted
                }
            }
            handle: Rectangle {
                x: psCtrl.leftPadding + psCtrl.visualPosition * (psCtrl.availableWidth - width)
                y: psCtrl.topPadding + psCtrl.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: psCtrl.pressed ? Theme.accentHover : Theme.text
                border.color: psCtrl.enabled ? Theme.accent : Theme.textMuted
                border.width: 2
            }
        }

        Text {
            text: psRoot.format
                ? String(psRoot.format(psRoot.value))
                : String(Math.round(psRoot.value))
            color: psRoot.enabled ? Theme.textSub : Theme.textMuted
            font.pixelSize: 11
            font.family: Theme.fontMono
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 66
            elide: Text.ElideRight
        }
    }

    component SwitchRow: Rectangle {
        id: sw

        property string label: ""
        property string hint: ""
        property bool value: false
        property bool enabled: true

        signal toggled()

        Layout.fillWidth: true
        implicitHeight: sw.hint.length > 0 ? 52 : 42
        radius: Theme.radiusSm
        color: swMa.containsMouse && sw.enabled
            ? Theme.glassCardHover : Theme.glassCard
        border.color: swMa.containsMouse && sw.enabled
            ? Theme.glassBorderHover : Theme.glassBorder
        border.width: 1
        opacity: sw.enabled ? 1 : 0.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: sw.label
                    color: Theme.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: sw.hint.length > 0
                    text: sw.hint
                    color: Theme.textMuted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 22
                radius: 11
                color: sw.value ? Theme.accent : Theme.bgSurface
                border.color: sw.value ? Theme.accent : Theme.glassBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: sw.value ? parent.width - width - 3 : 3
                    color: sw.value ? Theme.textDark : Theme.textSub

                    Behavior on x { NumberAnimation { duration: Theme.animFast } }
                }
            }
        }

        MouseArea {
            id: swMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: sw.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    // ====================== Сторінка ======================
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

            // --- Заголовок ---
            Text {
                text: "Медіаплеєр"
                color: Theme.text
                font.pixelSize: 22
                font.bold: true
                font.family: Theme.fontMono
            }

            Text {
                Layout.fillWidth: true
                text: "Компактний блок у TopBar і велике вікно керування. Один MPRIS-сервіс, один екземпляр вікна."
                color: Theme.textSub
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            // ============================================================
            // A. TOPBAR PLAYER
            // ============================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: topbarCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: topbarCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CardTitle { text: "TOPBAR PLAYER" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "LEGO: " + mediaRoot.moduleZone().toUpperCase()
                            color: mediaRoot.moduleZone() === "disabled"
                                ? Theme.textMuted : Theme.accent
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Це той самий модуль mediaplayer із конструктора панелі. Зона й порядок змінюються на вкладці «Панель»."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    // Режим розміру (LEGO size)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "compact",  label: "Compact",  hint: "Мінімум місця" },
                                { key: "normal",   label: "Normal",   hint: "Стандарт" },
                                { key: "expanded", label: "Expanded", hint: "Більше деталей" }
                            ]

                            delegate: Rectangle {
                                id: modeCard
                                required property var modelData

                                readonly property bool active:
                                    mediaRoot.moduleValue("size", "normal") === modelData.key

                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: Theme.radiusSm
                                color: modeMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                border.color: active ? Theme.glassBorderFocus
                                    : (modeMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
                                border.width: active ? 2 : 1

                                scale: modeMa.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modeCard.modelData.label
                                        color: modeCard.active ? Theme.text : Theme.textSub
                                        font.pixelSize: 11
                                        font.bold: modeCard.active
                                        font.family: Theme.fontMono
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modeCard.modelData.hint
                                        color: Theme.textMuted
                                        font.pixelSize: 9
                                    }
                                }

                                MouseArea {
                                    id: modeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mediaRoot.setModuleProp("size", modeCard.modelData.key)
                                }
                            }
                        }
                    }

                    SwitchRow {
                        label: "Обкладинка"
                        hint: "Показувати альбом-арт у блоці TopBar"
                        value: mediaRoot.moduleValue("showArt", true) !== false
                        onToggled: mediaRoot.setModuleProp("showArt",
                            !(mediaRoot.moduleValue("showArt", true) !== false))
                    }

                    SwitchRow {
                        label: "Назва треку"
                        hint: "Основний рядок із назвою"
                        value: mediaRoot.moduleValue("showTitle", true) !== false
                        onToggled: mediaRoot.setModuleProp("showTitle",
                            !(mediaRoot.moduleValue("showTitle", true) !== false))
                    }

                    SwitchRow {
                        label: "Виконавець"
                        hint: "Другий рядок; у compact-режимі прихований"
                        value: mediaRoot.moduleValue("showArtist", true) !== false
                        onToggled: mediaRoot.setModuleProp("showArtist",
                            !(mediaRoot.moduleValue("showArtist", true) !== false))
                    }

                    SwitchRow {
                        label: "Кнопки керування"
                        hint: "Previous / Play-Pause / Next у блоці"
                        value: mediaRoot.moduleValue("showControls", true) !== false
                        onToggled: mediaRoot.setModuleProp("showControls",
                            !(mediaRoot.moduleValue("showControls", true) !== false))
                    }

                    ParamSlider {
                        label: "Обмеження назви"
                        from: 0; to: 64; step: 1
                        value: Number(mediaRoot.moduleValue("maxTitleLength", 28))
                        format: v => Math.round(v) > 0
                            ? Math.round(v) + " симв." : "без обмежень"
                        onEdited: v => mediaRoot.setModuleProp("maxTitleLength", Math.round(v))
                    }

                    ParamSlider {
                        label: "Ширина тексту"
                        from: 0; to: 320; step: 8
                        value: Number(mediaRoot.moduleValue("titleWidth", 0))
                        format: v => Math.round(v) > 0
                            ? Math.round(v) + " px" : "авто"
                        onEdited: v => mediaRoot.setModuleProp("titleWidth", Math.round(v))
                    }

                    ParamSlider {
                        label: "Розмір обкладинки"
                        from: 0; to: 56; step: 2
                        value: Number(mediaRoot.moduleValue("coverSize", 0))
                        format: v => Math.round(v) > 0
                            ? Math.round(v) + " px" : "авто"
                        onEdited: v => mediaRoot.setModuleProp("coverSize", Math.round(v))
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "0 = автоматично за режимом. Висота блоку дорівнює висоті панелі."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ============================================================
            // B. LYRICS
            // ============================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: lyricsCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: lyricsCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    CardTitle { text: "LYRICS" }

                    SwitchRow {
                        label: "Показувати тексти пісень"
                        hint: "Кнопка «Текст пісні» у popup; для відео вимкнено завжди"
                        value: Config.mediaPlayerLyricsEnabled
                        onToggled: Config.setProp("MediaPlayer.lyricsEnabled",
                                                  !Config.mediaPlayerLyricsEnabled)
                    }

                    SwitchRow {
                        label: "Автоматичний пошук"
                        hint: "Шукати текст при відкритті Lyrics і зміні треку"
                        enabled: Config.mediaPlayerLyricsEnabled
                        value: Config.mediaPlayerLyricsAutoFetch
                        onToggled: Config.setProp("MediaPlayer.lyricsAutoFetch",
                                                  !Config.mediaPlayerLyricsAutoFetch)
                    }

                    // --- Пресети оформлення ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CardTitle { text: "ПРЕСЕТИ ОФОРМЛЕННЯ" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: mediaRoot.currentLyricsPresetKey() === "custom"
                                  ? "змінено" : mediaRoot.currentLyricsPresetKey()
                            color: mediaRoot.currentLyricsPresetKey() === "custom"
                                  ? Theme.accentYellow : Theme.accent
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: mediaRoot.lyricsPresets

                            delegate: Rectangle {
                                id: presetCard
                                required property var modelData

                                readonly property bool active:
                                    mediaRoot.currentLyricsPresetKey() === modelData.key
                                readonly property var vals: modelData.vals

                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: Theme.radiusSm
                                color: cardMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                border.color: active ? Theme.glassBorderFocus
                                    : (cardMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
                                border.width: active ? 2 : 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4

                                    // Міні-прев'ю стилю
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 5
                                        // підложка пресета: 0 = прозоро (Minimal)
                                        color: presetCard.vals.bgOpacity > 0.01
                                            ? Qt.rgba(Theme.cfgSurface.r, Theme.cfgSurface.g,
                                                      Theme.cfgSurface.b, presetCard.vals.bgOpacity)
                                            : "transparent"
                                        border.color: presetCard.vals.bgOpacity > 0.01
                                            ? Theme.glassBorder : Theme.textMuted
                                        border.width: 1
                                        clip: true

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: presetCard.vals.align === "left" ? 6 : 0
                                            anchors.rightMargin: 6
                                            spacing: 3

                                            // три «рядки тексту»: активний — акцентний
                                            Rectangle {
                                                width: presetCard.vals.align === "left"
                                                    ? parent.width * 0.55 : parent.width * 0.42
                                                height: 3; radius: 1.5
                                                anchors.horizontalCenter: presetCard.vals.align === "left"
                                                    ? undefined : parent.horizontalCenter
                                                color: Theme.textMuted
                                                opacity: 0.7
                                            }
                                            Rectangle {
                                                width: presetCard.vals.align === "left"
                                                    ? parent.width * 0.7 : parent.width * 0.56
                                                height: presetCard.key === "minimal" ? 5 : 4
                                                radius: 2
                                                anchors.horizontalCenter: presetCard.vals.align === "left"
                                                    ? undefined : parent.horizontalCenter
                                                color: presetCard.key === "karaoke"
                                                    ? Theme.accent : Theme.textSub
                                            }
                                            Rectangle {
                                                width: presetCard.vals.align === "left"
                                                    ? parent.width * 0.5 : parent.width * 0.36
                                                height: 3; radius: 1.5
                                                anchors.horizontalCenter: presetCard.vals.align === "left"
                                                    ? undefined : parent.horizontalCenter
                                                color: Theme.textMuted
                                                opacity: 0.7
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: presetCard.modelData.label
                                        color: presetCard.active ? Theme.text : Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: presetCard.active
                                        font.family: Theme.fontMono
                                    }
                                }

                                MouseArea {
                                    id: cardMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mediaRoot.applyLyricsPreset(presetCard.modelData.key)
                                }
                            }
                        }
                    }

                    // --- Custom-налаштування поверх пресета ---
                    ParamSlider {
                        label: "Розмір тексту"
                        from: 9; to: 24; step: 1
                        value: mediaRoot._lyrClampI(Config.mediaPlayerLyricsFontSize, 11, 9, 24)
                        prop: "MediaPlayer.lyricsFontSize"
                        format: v => Math.round(v) + " px"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Колір тексту"
                            color: Theme.textSub
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 6
                            color: mediaRoot._lyrSafeColor(Config.mediaPlayerLyricsTextColor, Theme.textSub)
                            border.color: lyricsTextMa.containsMouse ? Theme.glassBorderFocus : Theme.glassBorder
                            border.width: lyricsTextMa.containsMouse ? 2 : 1
                            MouseArea {
                                id: lyricsTextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lyricsColorPicker.openFor(
                                    "MediaPlayer.lyricsTextColor", "Колір тексту пісень",
                                    mediaRoot._lyrSafeColor(Config.mediaPlayerLyricsTextColor, "#cdd6f4"))
                            }
                        }

                        Text {
                            text: String(Config.mediaPlayerLyricsTextColor || "") === ""
                                  ? "авто (з Theme)" : String(Config.mediaPlayerLyricsTextColor).toUpperCase()
                            color: Theme.textSub
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        // Повернути автоколір
                        Rectangle {
                            implicitWidth: autoTextRow.implicitWidth + 16
                            implicitHeight: 24; radius: 6
                            visible: String(Config.mediaPlayerLyricsTextColor || "") !== ""
                            color: autoTextMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                            border.color: Theme.glassBorder; border.width: 1
                            RowLayout {
                                id: autoTextRow
                                anchors.centerIn: parent
                                Text { text: "авто"; color: Theme.textSub; font.pixelSize: 9; font.family: Theme.fontMono }
                            }
                            MouseArea {
                                id: autoTextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.setProp("MediaPlayer.lyricsTextColor", "")
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Колір активного рядка"
                            color: Theme.textSub
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 6
                            color: mediaRoot._lyrSafeColor(Config.mediaPlayerLyricsActiveColor, Theme.accent)
                            border.color: lyricsActiveMa.containsMouse ? Theme.glassBorderFocus : Theme.glassBorder
                            border.width: lyricsActiveMa.containsMouse ? 2 : 1
                            MouseArea {
                                id: lyricsActiveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lyricsColorPicker.openFor(
                                    "MediaPlayer.lyricsActiveColor", "Колір активного рядка",
                                    mediaRoot._lyrSafeColor(Config.mediaPlayerLyricsActiveColor, "#89b4fa"))
                            }
                        }

                        Text {
                            text: String(Config.mediaPlayerLyricsActiveColor || "") === ""
                                  ? "авто (accent)" : String(Config.mediaPlayerLyricsActiveColor).toUpperCase()
                            color: Theme.textSub
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: autoActiveRow.implicitWidth + 16
                            implicitHeight: 24; radius: 6
                            visible: String(Config.mediaPlayerLyricsActiveColor || "") !== ""
                            color: autoActiveMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                            border.color: Theme.glassBorder; border.width: 1
                            RowLayout {
                                id: autoActiveRow
                                anchors.centerIn: parent
                                Text { text: "авто"; color: Theme.textSub; font.pixelSize: 9; font.family: Theme.fontMono }
                            }
                            MouseArea {
                                id: autoActiveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.setProp("MediaPlayer.lyricsActiveColor", "")
                            }
                        }
                    }

                    ParamSlider {
                        label: "Прозорість підложки"
                        from: 0; to: 1; step: 0.05
                        value: mediaRoot._lyrClampR(Config.mediaPlayerLyricsBgOpacity, 0.6, 0, 1)
                        prop: "MediaPlayer.lyricsBgOpacity"
                        format: v => Math.round(v * 100) + " %"
                    }

                    // Вирівнювання
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Вирівнювання"
                            color: Theme.textSub
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }

                        Repeater {
                            model: [
                                { key: "center", label: "По центру" },
                                { key: "left",   label: "Ліворуч" }
                            ]

                            delegate: Rectangle {
                                id: alignBtn
                                required property var modelData

                                readonly property bool selected:
                                    Config.mediaPlayerLyricsAlign === modelData.key

                                Layout.preferredWidth: alignLbl.implicitWidth + 22
                                Layout.preferredHeight: 28
                                radius: Theme.radiusSm
                                color: selected
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                    : (alignMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
                                border.color: selected ? Theme.glassBorderFocus : Theme.glassBorder
                                border.width: selected ? 2 : 1

                                Text {
                                    id: alignLbl
                                    anchors.centerIn: parent
                                    text: alignBtn.modelData.label
                                    color: alignBtn.selected ? Theme.accent : Theme.textSub
                                    font.pixelSize: 10
                                    font.bold: alignBtn.selected
                                    font.family: Theme.fontMono
                                }

                                MouseArea {
                                    id: alignMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.setProp("MediaPlayer.lyricsAlign", alignBtn.modelData.key)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    ParamSlider {
                        label: "Міжрядковий інтервал"
                        from: 1.0; to: 2.0; step: 0.05
                        value: mediaRoot._lyrClampR(Config.mediaPlayerLyricsLineSpacing, 1.25, 1.0, 2.0)
                        prop: "MediaPlayer.lyricsLineSpacing"
                        format: v => "×" + Number(v).toFixed(2)
                    }

                    // Повернення до дефолтів вибраного пресета
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: resetPresetRow.implicitWidth + 22
                            implicitHeight: 30
                            radius: Theme.radiusSm
                            color: resetPresetMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                            border.color: resetPresetMa.containsMouse
                                ? Theme.glassBorderFocus : Theme.glassBorder
                            border.width: 1

                            RowLayout {
                                id: resetPresetRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰁯"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "Повернути налаштування пресета"
                                    color: Theme.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: resetPresetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mediaRoot.applyLyricsPreset(Config.mediaPlayerLyricsPreset)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Karaoke виділяє активний рядок лише для синхронізованого тексту (.lrc); для звичайного — статичний вид."
                            color: Theme.textMuted
                            font.pixelSize: 9
                            font.italic: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    ParamSlider {
                        label: "Висота області Lyrics"
                        from: 72; to: 320; step: 4
                        visible: mediaRoot.lyricsSizeVisible
                        enabled: mediaRoot.lyricsSizeVisible
                        value: Config.mediaPlayerLyricsHeight
                        prop: "MediaPlayer.lyricsHeight"
                        format: v => Math.round(v) + " px"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: retryRow.implicitWidth + 22
                            implicitHeight: 30
                            radius: Theme.radiusSm
                            enabled: Config.mediaPlayerLyricsEnabled
                            opacity: enabled ? 1 : 0.5
                            color: retryMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                            border.color: retryMa.containsMouse
                                ? Theme.glassBorderFocus : Theme.glassBorder
                            border.width: 1

                            RowLayout {
                                id: retryRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰑐"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "Повторити пошук"
                                    color: Theme.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: retryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = PanelController.mediaPanel
                                    if (!p) {
                                        mediaRoot.retryNote = "Панель медіаплеєра недоступна"
                                    } else if (!p.hasPlayer) {
                                        mediaRoot.retryNote = "Немає активного плеєра"
                                    } else if (p.isVideo) {
                                        mediaRoot.retryNote = "Для відео тексти вимкнено"
                                    } else {
                                        p.refreshLyrics()
                                        mediaRoot.retryNote = "Пошук тексту запущено"
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mediaRoot.retryNote
                            color: Theme.textMuted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Джерела: локальний .lrc поруч із файлом, потім lrclib.net / lyrics.ovh. Якщо текст не знайдено — панель показує коректний стан і кнопку повтору."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ============================================================
            // C. ПОВЕДІНКА
            // ============================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: behaviorCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: behaviorCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    CardTitle { text: "ПОВЕДІНКА" }

                    SwitchRow {
                        label: "Відкривати popup по кліку"
                        hint: "Клік по блоку Media Player у TopBar"
                        value: Config.mediaPlayerOpenOnClick
                        onToggled: Config.setProp("MediaPlayer.openOnClick",
                                                  !Config.mediaPlayerOpenOnClick)
                    }

                    SwitchRow {
                        label: "Закривати по Escape"
                        value: Config.mediaPlayerCloseOnEscape
                        onToggled: Config.setProp("MediaPlayer.closeOnEscape",
                                                  !Config.mediaPlayerCloseOnEscape)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Повторний клік по блоку закриває вікно. Клік поза вікном закриває його штатним grab-popup; вікно завжди одне."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // --- Скидання ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: resetRow.implicitWidth + 20
                    height: 32
                    radius: Theme.radiusSm
                    color: resetMa.containsMouse
                        ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : Theme.glassCard
                    border.color: resetMa.containsMouse ? Theme.accentRed : Theme.glassBorder
                    border.width: 1

                    RowLayout {
                        id: resetRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text { text: "󰜺"; color: Theme.accentRed; font.family: Theme.fontMono; font.pixelSize: 14 }
                        Text { text: "Скинути медіаплеєр"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaRoot.resetMediaPlayer()
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // --- Вбудований color picker для кольорів тексту пісень ---
    ColorPickerPopup {
        id: lyricsColorPicker
    }
}
