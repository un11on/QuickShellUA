import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: panelRoot
    anchors.fill: parent
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ============ Режими щільності (тільки геометрія/інтервали) ============
    function applyDensity(key) {
        var map = {
            "compact":  { height: 32, marginTop: 4,  marginLeft: 6,  marginRight: 6,  islandPadH: 8,  islandSpacing: 4,  blockSpacing: 6 },
            "normal":   { height: 40, marginTop: 6,  marginLeft: 10, marginRight: 10, islandPadH: 10, islandSpacing: 6,  blockSpacing: 8 },
            "spacious": { height: 48, marginTop: 10, marginLeft: 16, marginRight: 16, islandPadH: 14, islandSpacing: 10, blockSpacing: 12 }
        }
        var v = map[key]
        if (!v) return
        for (var k in v)
            Config.setProp("Panel." + k, v[k])
        Config.setProp("Panel.density", key)
    }

    // Скидання параметрів панелі до значень за замовчуванням (геометрія, розміщення, поведінка).
    // Теми, пресети та кольорове оформлення не чіпаються — керується на сторінці «Зовнішній вигляд».
    function resetPanel() {
        var d = Config.defaults.Panel
        var keys = [
            "height", "marginTop", "marginLeft", "marginRight",
            "maxWidth", "density", "workspaceStyle",
            "position",
            "autoHide", "autoHideDelay", "autoHideShowDelay", "autoHideEdgeZone",
            "blockSpacing", "islandPadH", "islandSpacing"
        ]
        for (var i = 0; i < keys.length; ++i)
            Config.setProp("Panel." + keys[i], d[keys[i]])
        Config.setPanelLayout(Config.defaults.Panel.layout)
    }

    property bool advExpanded: false

    // ============ Переиспользуемый slider-ряд ============
    component ParamSlider: RowLayout {
        id: psRoot

        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property string prop: ""
        property real step: 1
        property var format: null   // function(value) -> string; null -> округление

        spacing: 10

        // Держимо внутрішній слайдер синхронізованим із Config навіть після того,
        // як користувач перетягнув його (drag ламає value-прив'язку — відновлюємо)
        onValueChanged: Qt.callLater(function() { psCtrl.value = psRoot.value })

        Text {
            text: psRoot.label
            color: Theme.textSub
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
            onMoved: {
                Config.setProp(psRoot.prop, psCtrl.value)
            }

            background: Rectangle {
                x: psCtrl.leftPadding
                y: psCtrl.topPadding + psCtrl.availableHeight / 2 - height / 2
                width: psCtrl.availableWidth
                height: 6
                radius: 3
                color: Theme.bgSurface

                Rectangle {
                    width: psCtrl.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                }
            }
            handle: Rectangle {
                x: psCtrl.leftPadding + psCtrl.visualPosition * (psCtrl.availableWidth - width)
                y: psCtrl.topPadding + psCtrl.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: psCtrl.pressed ? Theme.accentHover : Theme.text
                border.color: Theme.accent
                border.width: 2
            }
        }

        Text {
            text: psRoot.format
                ? String(psRoot.format(psRoot.value))
                : String(Math.round(psRoot.value))
            color: Theme.textSub
            font.pixelSize: 11
            font.family: Theme.fontMono
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 52
            elide: Text.ElideRight
        }
    }

    // ============ Прев'ю стилю індикатора робочих столів ============
    // Кольори лише з Theme, без власних палітр.
    component WorkspaceStylePreview: Row {
        id: preview

        property string style: "smart"
        property int activeIndex: 1
        property int occupiedLimit: 4

        spacing: 4

        Repeater {
            model: 5

            delegate: Item {
                id: cell
                required property int index

                readonly property bool active: index === preview.activeIndex
                readonly property bool occupied: !active && index < preview.occupiedLimit
                readonly property color stateColor: active
                    ? Theme.accent
                    : (occupied ? Theme.textSub : Theme.glassBorder)

                width: preview.style === "segments" ? (active ? 14 : 10)
                    : preview.style === "bars" ? 7 : 13
                height: 22

                Rectangle {
                    visible: preview.style === "smart"
                    anchors.centerIn: parent
                    width: cell.active ? 13 : 11
                    height: 13
                    radius: 4
                    color: cell.active
                        ? Theme.accent
                        : (cell.occupied ? Theme.glassCardActive : "transparent")
                    border.color: cell.active ? Theme.accentHover : Theme.glassBorder
                    border.width: 1
                }

                Text {
                    visible: preview.style === "smart"
                    anchors.centerIn: parent
                    text: cell.index + 1
                    color: cell.active ? Theme.textDark : Theme.textSub
                    font.family: Theme.fontMono
                    font.pixelSize: 8
                    font.bold: true
                }

                Rectangle {
                    visible: preview.style === "dots"
                    anchors.centerIn: parent
                    width: cell.active ? 8 : (cell.occupied ? 6 : 5)
                    height: width
                    radius: width / 2
                    color: cell.stateColor
                }

                Rectangle {
                    visible: preview.style === "segments"
                    anchors.centerIn: parent
                    width: cell.active ? 14 : 10
                    height: 4
                    radius: 2
                    color: cell.stateColor
                }

                Rectangle {
                    visible: preview.style === "blocks"
                    anchors.centerIn: parent
                    width: cell.active ? 9 : 7
                    height: width
                    radius: 2
                    color: cell.stateColor
                }

                Rectangle {
                    visible: preview.style === "bars"
                    anchors.centerIn: parent
                    width: 3
                    height: cell.active ? 14 : (cell.occupied ? 10 : 7)
                    radius: 1.5
                    color: cell.stateColor
                }
            }
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
                text: "Панель"
                color: Theme.text
                font.pixelSize: 22
                font.bold: true
                font.family: Theme.fontMono
            }

            Text {
                text: "Геометрія та розташування верхньої панелі"
                color: Theme.textSub
                font.pixelSize: 12
            }

            // --- Режим щільності ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: densityCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: densityCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "РЕЖИМ ЩІЛЬНОСТІ"
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "лише геометрія; ручні зміни нижче доступні"
                            color: Theme.textMuted
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "compact",  label: "Compact",  icon: "󰛁" },
                                { key: "normal",   label: "Normal",   icon: "󰡨" },
                                { key: "spacious", label: "Spacious", icon: "󰛂" }
                            ]

                            delegate: Rectangle {
                                id: densCard
                                required property var modelData

                                readonly property bool active:
                                    Config.panelDensity === modelData.key

                                Layout.fillWidth: true
                                Layout.minimumWidth: 120
                                Layout.preferredWidth: 180
                                height: 40
                                radius: Theme.radiusSm
                                color: densMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                border.color: active ? Theme.glassBorderFocus
                                            : densMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                                border.width: active ? 2 : 1

                                scale: densMa.pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: densCard.modelData.icon
                                        color: densCard.active ? Theme.accent : Theme.textSub
                                        font.family: Theme.fontMono
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: densCard.modelData.label
                                        color: densCard.active ? Theme.text : Theme.textSub
                                        font.pixelSize: 11
                                        font.bold: densCard.active
                                    }
                                }

                                MouseArea {
                                    id: densMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panelRoot.applyDensity(densCard.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            // --- Конструктор панелі ---
            PanelConstructor {
                Layout.fillWidth: true
            }

            // --- Стиль індикатора робочих столів ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: wsStyleCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: wsStyleCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "СТИЛЬ ІНДИКАТОРА РОБОЧИХ СТОЛІВ"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "smart",    label: "Smart Workspaces", hint: "Цифри + зайняті" },
                                { key: "dots",     label: "Minimal Dots",     hint: "Точки" },
                                { key: "segments", label: "Segments",         hint: "Сегменти" },
                                { key: "blocks",   label: "Blocks",           hint: "Блоки" },
                                { key: "bars",     label: "Bars",             hint: "Смуги" }
                            ]

                            delegate: Rectangle {
                                id: wsStyleCard
                                required property var modelData

                                readonly property bool active:
                                    Config.panelWorkspaceStyle === modelData.key

                                Layout.fillWidth: true
                                Layout.minimumWidth: 118
                                Layout.preferredWidth: 148
                                Layout.preferredHeight: 88
                                radius: Theme.radiusSm
                                color: wsStyleMa.containsMouse
                                    ? Theme.glassCardHover : Theme.glassCard
                                border.color: active
                                    ? Theme.glassBorderFocus
                                    : (wsStyleMa.containsMouse
                                        ? Theme.glassBorderHover : Theme.glassBorder)
                                border.width: active ? 2 : 1

                                scale: wsStyleMa.pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24

                                        WorkspaceStylePreview {
                                            anchors.centerIn: parent
                                            style: wsStyleCard.modelData.key
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: wsStyleCard.modelData.label
                                        color: active ? Theme.text : Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: active
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: wsStyleCard.modelData.hint
                                        color: Theme.textMuted
                                        font.pixelSize: 9
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: wsStyleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.setProp("Panel.workspaceStyle",
                                                       wsStyleCard.modelData.key)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Кольори, прозорість і акцент успадковуються з поточної теми."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // --- Геометрія: основні налаштування завжди видимі ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: geoCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: geoCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "ГЕОМЕТРІЯ"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    ParamSlider {
                        label: "Висота панелі"
                        from: 24; to: 64
                        value: Config.panelHeight
                        prop: "Panel.height"
                    }

                    ParamSlider {
                        label: "Макс. ширина"
                        from: 0; to: 2560
                        step: 40
                        value: Config.panelMaxWidth
                        prop: "Panel.maxWidth"
                        format: v => v > 0 ? Math.round(v) : "авто"
                    }

                    ParamSlider {
                        label: "Верхній відступ"
                        from: 0; to: 24
                        value: Config.panelMarginTop
                        prop: "Panel.marginTop"
                    }

                    ParamSlider {
                        label: "Лівий відступ"
                        from: 0; to: 40
                        value: Config.panelMarginLeft
                        prop: "Panel.marginLeft"
                    }

                    ParamSlider {
                        label: "Правий відступ"
                        from: 0; to: 40
                        value: Config.panelMarginRight
                        prop: "Panel.marginRight"
                    }
                }
            }

            // --- Додаткові налаштування: сворачуваний розділ (за замовчуванням згорнуті) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: advCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: advHover.hovered ? Theme.glassBorderHover : Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: advCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // --- Заголовок розділу (клікабельний) ---
                    RowLayout {
                        id: advHeader
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: panelRoot.advExpanded ? "󰅀" : "󰅂"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                        }

                        Text {
                            text: "ДОДАТКОВІ НАЛАШТУВАННЯ"
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Theme.fontMono
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: panelRoot.advExpanded ? "" : "фони та скруглення, відстані"
                            color: Theme.textMuted
                            font.pixelSize: 10
                        }

                        // Tap/Hover-handler замість MouseArea: MouseArea с anchors.fill
                        // всередині layout — undefined behavior (anchors у layout-оцінок)
                        TapHandler {
                            onTapped: panelRoot.advExpanded = !panelRoot.advExpanded
                        }
                        HoverHandler {
                            id: advHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Text {
                        visible: panelRoot.advExpanded
                        text: "Відстані між блоками панелі та всередині островків. Усі зміни застосовуються одразу."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    ParamSlider {
                        visible: panelRoot.advExpanded
                        label: "Відстань правий блок ↔ AI"
                        from: 0; to: 32
                        value: Config.panelBlockSpacing
                        prop: "Panel.blockSpacing"
                    }

                    ParamSlider {
                        visible: panelRoot.advExpanded
                        label: "Відступ всередині островків"
                        from: 4; to: 24
                        value: Config.panelIslandPadH
                        prop: "Panel.islandPadH"
                    }

                    ParamSlider {
                        visible: panelRoot.advExpanded
                        label: "Відстань між елементами"
                        from: 0; to: 16
                        value: Config.panelIslandSpacing
                        prop: "Panel.islandSpacing"
                    }
                }
            }

            // --- Скидання панелі ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: pResetRow.implicitWidth + 20
                    height: 32
                    radius: Theme.radiusSm
                    color: pResetMa.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : Theme.glassCard
                    border.color: pResetMa.containsMouse ? Theme.accentRed : Theme.glassBorder
                    border.width: 1

                    RowLayout {
                        id: pResetRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text { text: "󰜺"; color: Theme.accentRed; font.family: Theme.fontMono; font.pixelSize: 14 }
                        Text { text: "Скинути панель"; color: Theme.text; font.pixelSize: 11; font.bold: true }
                    }

                    MouseArea {
                        id: pResetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelRoot.resetPanel()
                    }
                }
            }

            // --- Положение панели ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: posCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: posCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "ПОЛОЖЕННЯ ПАНЕЛІ"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { key: "top",    label: "▲ Верх",    icon: "▲" },
                                { key: "bottom", label: "▼ Низ",     icon: "▼" },
                                { key: "left",   label: "◀ Ліворуч", icon: "◀" },
                                { key: "right",  label: "▶ Праворуч",icon: "▶" }
                            ]

                            delegate: Rectangle {
                                id: posCard
                                required property var modelData

                                readonly property bool active: Config.panelPosition === modelData.key

                                Layout.fillWidth: true
                                Layout.minimumWidth: 100
                                height: 40
                                radius: Theme.radiusSm
                                color: posMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                                border.color: active ? Theme.glassBorderFocus
                                            : posMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                                border.width: active ? 2 : 1

                                scale: posMa.pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: posCard.modelData.icon
                                        color: active ? Theme.accent : Theme.textSub
                                        font.family: Theme.fontMono
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: posCard.modelData.label
                                        color: active ? Theme.text : Theme.textSub
                                        font.pixelSize: 11
                                        font.bold: active
                                    }
                                }

                                MouseArea {
                                    id: posMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.setProp("Panel.position", posCard.modelData.key)
                                }
                                }
                            }
                        }
                    }
                }
            }

            // --- Автоскриття панелі ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: ahCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: ahCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ToggleTile {
                            Layout.fillWidth: true
                            icon: "󰥔"
                            title: "Автоскриття панелі"
                            subtitle: "Приховати у край екрана, з’являтись під курсором"
                            active: Config.panelAutoHide
                            onClicked: Config.setProp("Panel.autoHide", !Config.panelAutoHide)
                        }

                        Text {
                            text: Config.panelAutoHide ? "УВІМКНО" : "ВИМКНО"
                            color: Config.panelAutoHide ? Theme.accent : Theme.textMuted
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                        }
                    }

                    ParamSlider {
                        label: "Затримка сховавання (мс)"
                        from: 0; to: 2000; step: 50
                        value: Config.panelAutoHideDelay
                        prop: "Panel.autoHideDelay"
                        visible: Config.panelAutoHide
                    }

                    ParamSlider {
                        label: "Затримка появи (мс)"
                        from: 0; to: 1000; step: 50
                        value: Config.panelAutoHideShowDelay
                        prop: "Panel.autoHideShowDelay"
                        visible: Config.panelAutoHide
                    }

                    ParamSlider {
                        label: "Чутлива зона у краю (пікселів)"
                        from: 0; to: 60; step: 2
                        value: Config.panelAutoHideEdgeZone
                        prop: "Panel.autoHideEdgeZone"
                        visible: Config.panelAutoHide
                    }

                    Text {
                        visible: Config.panelAutoHide
                        text: "Панель не сховається, доки відкрито будь-яке пов’язане спливаюче вікно."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }



            Item { Layout.fillHeight: true }
        }
    }
}
