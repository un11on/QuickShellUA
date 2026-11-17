import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

Rectangle {
    id: constructorRoot

    Layout.fillWidth: true
    implicitHeight: mainCol.implicitHeight + 32
    Layout.preferredHeight: implicitHeight
    radius: Theme.radiusMd
    color: Theme.glassCard
    border.color: Theme.glassBorder
    border.width: 1

    // Текущая раскладка из Config
    readonly property var layout: Config.normalizeLayout(Config.panelLayout)

    // Состояние перетаскивания (Drag and Drop)
    property bool isDragging: false
    property string dragId: ""
    property string dragFromZone: ""
    property int dragFromIndex: -1
    property string dragTargetZone: ""
    property int dragTargetIndex: -1
    property real dragGlobalX: 0
    property real dragGlobalY: 0

    // Метаданные модулей
    readonly property var moduleMeta: ({
        "workspaces":    { name: "Робочі столи",    icon: "󰮯", desc: "Перемикач робочих столів Hyprland" },
        "activewindow":  { name: "Активне вікно",   icon: "󰖲", desc: "Заголовок поточного активного вікна" },
        "clock":         { name: "Годинник та дата", icon: "󰥔", desc: "Час, календар та кнопка меню" },
        "wifi":          { name: "Wi-Fi",           icon: "󰤨", desc: "Статус мережі та список точок" },
        "bluetooth":     { name: "Bluetooth",       icon: "󰂯", desc: "Статус Bluetooth та пристрої" },
        "volume":        { name: "Гучність",        icon: "󰕾", desc: "Рівень звуку та перемикач" },
        "notifications": { name: "Сповіщення",      icon: "󰂚", desc: "Колокольчик та лічильник непрочитаних" },
        "tray":          { name: "Системний трей",  icon: "󱊖", desc: "Іконки додатків (SNI)" },
        "ai":            { name: "AI-кнопка",       icon: "󰚩", desc: "Швидкий виклик AI-помічника" },
        "mediaplayer":   { name: "Медіаплеєр",      icon: "󰎆", desc: "MPRIS: обкладинка, трек і керування" }
    })

    function getMeta(id) {
        return moduleMeta[id] || { name: id, icon: "󰏤", desc: "" }
    }

    // Операции с раскладкой
    function moveModule(id, toZone, toIndex) {
        var cur = Config.normalizeLayout(Config.panelLayout)
        var zones = ["left", "center", "right", "disabled"]
        var targetMod = null

        for (var z = 0; z < zones.length; z++) {
            var zn = zones[z]
            var list = cur[zn]
            for (var i = 0; i < list.length; i++) {
                if (list[i].id === id) {
                    targetMod = list.splice(i, 1)[0]
                    break
                }
            }
            if (targetMod) break
        }

        if (!targetMod) return

        targetMod.enabled = (toZone !== "disabled")
        if (toIndex < 0 || toIndex > cur[toZone].length)
            cur[toZone].push(targetMod)
        else
            cur[toZone].splice(toIndex, 0, targetMod)

        Config.setPanelLayout(cur)
    }

    function reorderModule(zone, fromIdx, toIdx) {
        var cur = Config.normalizeLayout(Config.panelLayout)
        if (!cur[zone] || fromIdx < 0 || fromIdx >= cur[zone].length) return
        if (toIdx < 0 || toIdx >= cur[zone].length || fromIdx === toIdx) return

        var item = cur[zone].splice(fromIdx, 1)[0]
        cur[zone].splice(toIdx, 0, item)
        Config.setPanelLayout(cur)
    }

    function updateModuleProp(id, prop, val) {
        Config.setLayoutModuleProp(id, prop, val)
    }

    // Явное удаление модуля с панели. Не toggle: модуль гарантированно
    // убирается из Left/Center/Right и возвращается в список доступных
    // (disabled) с сохранением своих настроек.
    function removeModule(id) {
        var cur = Config.normalizeLayout(Config.panelLayout)
        var activeZones = ["left", "center", "right"]
        var removed = null

        for (var z = 0; z < activeZones.length; z++) {
            var list = cur[activeZones[z]]
            for (var i = list.length - 1; i >= 0; --i) {
                if (list[i] && list[i].id === id) {
                    var item = list.splice(i, 1)[0]
                    if (!removed)
                        removed = item
                }
            }
        }

        // Убираем возможные устаревшие дубликаты из disabled, затем
        // добавляем один канонический экземпляр обратно в доступные.
        var disabled = []
        for (var d = 0; d < cur.disabled.length; d++) {
            var dm = cur.disabled[d]
            if (dm && dm.id === id) {
                if (!removed)
                    removed = dm
            } else {
                disabled.push(dm)
            }
        }
        cur.disabled = disabled

        if (removed) {
            removed.enabled = false
            cur.disabled.push(removed)
        }

        Config.setPanelLayout(cur)
    }

    function toggleModule(id) {
        var cur = Config.normalizeLayout(Config.panelLayout)
        var inDisabled = false
        for (var i = 0; i < cur.disabled.length; i++) {
            if (cur.disabled[i].id === id) {
                inDisabled = true
                break
            }
        }
        if (inDisabled) {
            var targetZone = "right"
            if (id === "workspaces" || id === "activewindow") targetZone = "left"
            else if (id === "clock") targetZone = "center"
            moveModule(id, targetZone, cur[targetZone] ? cur[targetZone].length : 0)
        } else {
            moveModule(id, "disabled", cur.disabled.length)
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 16

        // --- Заголовок секции ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰅩"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 16
            }

            Text {
                text: "КОНСТРУКТОР ПАНЕЛІ (LEGO)"
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                font.family: Theme.fontMono
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Перетягуйте модулі або використовуйте кнопки керування"
                color: Theme.textMuted
                font.pixelSize: 10
            }
        }

        // --- Пресеты панели ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: presetCol.implicitHeight + 20
            Layout.preferredHeight: implicitHeight
            radius: Theme.radiusSm
            color: Theme.glassCardHover
            border.color: Theme.glassBorder
            border.width: 1

            ColumnLayout {
                id: presetCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "ГОТОВІ ПРЕСЕТИ"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Активний: " + Config.panelPreset
                        color: Theme.accent
                        font.pixelSize: 10
                        font.family: Theme.fontMono
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { key: "Minimal",      label: "Minimal",      icon: "󰒲", hint: "Лише базове" },
                            { key: "Classic",      label: "Classic",      icon: "󰕰", hint: "Класична розкладка" },
                            { key: "Cyber",        label: "Cyber",        icon: "󰚩", hint: "Розширений кібер-стиль" },
                            { key: "Full Control",  label: "Full Control", icon: "󱐋", hint: "Усі модулі" }
                        ]

                        delegate: Rectangle {
                            id: pBtn
                            required property var modelData

                            readonly property bool active: Config.panelPreset === modelData.key

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            implicitHeight: 34
                            radius: Theme.radiusSm
                            color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                 : (pMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
                            border.color: active ? Theme.accent : (pMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
                            border.width: active ? 1.5 : 1

                            scale: pMa.pressed ? 0.96 : 1.0
                            Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: pBtn.modelData.icon
                                    color: pBtn.active ? Theme.accent : Theme.textSub
                                    font.family: Theme.fontMono
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: pBtn.modelData.label
                                    color: pBtn.active ? Theme.text : Theme.textSub
                                    font.pixelSize: 11
                                    font.bold: pBtn.active
                                    font.family: Theme.fontMono
                                }
                            }

                            MouseArea {
                                id: pMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.applyPanelPreset(pBtn.modelData.key)
                            }
                        }
                    }
                }
            }
        }

        // --- Настройка отступов между блоками ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                implicitHeight: 46
                radius: Theme.radiusSm
                color: Theme.glassCardHover
                border.color: Theme.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Відступ між блоками:"
                        color: Theme.textSub
                        font.pixelSize: 11
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 32; stepSize: 1
                        value: Config.panelBlockSpacing
                        onMoved: Config.setProp("Panel.blockSpacing", value)
                    }

                    Text {
                        text: Config.panelBlockSpacing + " px"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                implicitHeight: 46
                radius: Theme.radiusSm
                color: Theme.glassCardHover
                border.color: Theme.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Відступ усередині острівця:"
                        color: Theme.textSub
                        font.pixelSize: 11
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 24; stepSize: 1
                        value: Config.panelIslandSpacing
                        onMoved: Config.setProp("Panel.islandSpacing", value)
                    }

                    Text {
                        text: Config.panelIslandSpacing + " px"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // --- Три зоны LEGO-конструктора ---
        RowLayout {
            id: zonesRow
            Layout.fillWidth: true
            implicitHeight: Math.max(leftZoneBox.implicitHeight, centerZoneBox.implicitHeight, rightZoneBox.implicitHeight, 120)
            Layout.preferredHeight: implicitHeight
            spacing: 12

            // Левая зона
            ZoneContainer {
                id: leftZoneBox
                zoneName: "left"
                zoneTitle: "LEFT ZONE"
                zoneIcon: "󰁍"
                modules: constructorRoot.layout.left
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
            }

            // Центральная зона
            ZoneContainer {
                id: centerZoneBox
                zoneName: "center"
                zoneTitle: "CENTER ZONE"
                zoneIcon: "󰁊"
                modules: constructorRoot.layout.center
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
            }

            // Правая зона
            ZoneContainer {
                id: rightZoneBox
                zoneName: "right"
                zoneTitle: "RIGHT ZONE"
                zoneIcon: "󰁔"
                modules: constructorRoot.layout.right
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
            }
        }

        // --- Отключённые / Доступные модули ---
        Rectangle {
            id: disabledShelf
            Layout.fillWidth: true
            implicitHeight: disabledCol.implicitHeight + 24
            Layout.preferredHeight: implicitHeight
            radius: Theme.radiusSm
            color: constructorRoot.isDragging && constructorRoot.dragTargetZone === "disabled"
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                : Theme.glassCardHover
            border.color: constructorRoot.isDragging && constructorRoot.dragTargetZone === "disabled"
                ? Theme.accent : Theme.glassBorder
            border.width: constructorRoot.isDragging && constructorRoot.dragTargetZone === "disabled" ? 2 : 1

            ColumnLayout {
                id: disabledCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰏤"
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                    }

                    Text {
                        text: "ВИМКНЕНІ / ДОСТУПНІ МОДУЛІ (" + constructorRoot.layout.disabled.length + ")"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Натисніть «+», щоб додати модуль на панель"
                        color: Theme.textMuted
                        font.pixelSize: 10
                    }
                }

                // Список отключённых карточек
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: constructorRoot.layout.disabled

                        delegate: Rectangle {
                            id: disCard
                            required property var modelData
                            required property int index

                            readonly property var meta: constructorRoot.getMeta(modelData.id)

                            width: disRow.implicitWidth + 18
                            height: 36
                            radius: Theme.radiusSm
                            color: disMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                            border.color: disMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                            border.width: 1

                            RowLayout {
                                id: disRow
                                anchors.centerIn: parent
                                spacing: 8
                                z: 1

                                Text {
                                    text: disCard.meta.icon
                                    color: Theme.textMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: disCard.meta.name
                                    color: Theme.textSub
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    id: addBtn
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: addMa.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                                    border.color: Theme.accent
                                    border.width: 1
                                    z: 10

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: addMa.containsMouse ? Theme.textDark : Theme.accent
                                        font.bold: true
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: addMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        z: 11
                                        onClicked: constructorRoot.toggleModule(disCard.modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: disMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                z: -1
                                onClicked: constructorRoot.toggleModule(disCard.modelData.id)

                                onPressAndHold: {
                                    constructorRoot.startDrag(disCard.modelData.id, "disabled", disCard.index, disMa)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: constructorRoot.layout.disabled.length === 0
                    text: "Усі модулі активні на панелі"
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.italic: true
                }
            }
        }
    }

    // ============================================================
    // КОМПОНЕНТ ЗОНЫ (Left / Center / Right)
    // ============================================================
    component ZoneContainer: Rectangle {
        id: zoneBox

        property string zoneName: "left"
        property string zoneTitle: "ZONE"
        property string zoneIcon: ""
        property var modules: []

        readonly property bool isDropTarget: constructorRoot.isDragging && constructorRoot.dragTargetZone === zoneName

        Layout.fillWidth: true
        Layout.minimumWidth: 160
        implicitWidth: 180
        implicitHeight: Math.max(120, zoneCol.implicitHeight + 20)
        Layout.preferredHeight: implicitHeight
        radius: Theme.radiusSm
        color: isDropTarget ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : Theme.glassCardHover
        border.color: isDropTarget ? Theme.accent : Theme.glassBorder
        border.width: isDropTarget ? 2 : 1

        ColumnLayout {
            id: zoneCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            // Шапка зоны
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: zoneBox.zoneIcon
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }

                Text {
                    text: zoneBox.zoneTitle
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.fontMono
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: countText.implicitWidth + 8
                    height: 16
                    radius: 8
                    color: Theme.glassCard
                    border.color: Theme.glassBorder
                    border.width: 1

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: String(zoneBox.modules.length)
                        color: zoneBox.modules.length > 0 ? Theme.accent : Theme.textMuted
                        font.pixelSize: 9
                        font.bold: true
                        font.family: Theme.fontMono
                    }
                }
            }

            // Разделительная линия
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.glassBorder
            }

            // Список карточек модулей в этой зоне
            ColumnLayout {
                id: cardsCol
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: zoneBox.modules

                    delegate: ColumnLayout {
                        id: cardDelegate
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 4

                        // Индикатор места вставки сверху
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            implicitHeight: 3
                            radius: 1.5
                            color: Theme.accent
                            visible: constructorRoot.isDragging
                                     && constructorRoot.dragTargetZone === zoneBox.zoneName
                                     && constructorRoot.dragTargetIndex === cardDelegate.index
                        }

                        // Сама карточка LEGO-модуля
                        ModuleCard {
                            Layout.fillWidth: true
                            modData: cardDelegate.modelData
                            zone: zoneBox.zoneName
                            itemIndex: cardDelegate.index
                        }

                        // Индикатор места вставки снизу (для последнего элемента)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            implicitHeight: 3
                            radius: 1.5
                            color: Theme.accent
                            visible: constructorRoot.isDragging
                                     && constructorRoot.dragTargetZone === zoneBox.zoneName
                                     && constructorRoot.dragTargetIndex === (cardDelegate.index + 1)
                                     && cardDelegate.index === (zoneBox.modules.length - 1)
                        }
                    }
                }

                // Если зона пуста
                Rectangle {
                    visible: zoneBox.modules.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    implicitHeight: 60
                    radius: Theme.radiusSm
                    color: "transparent"
                    border.color: Theme.glassBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Порожня зона\n(перетягніть сюди модуль)"
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.italic: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // Отслеживание наведения при drag-and-drop
        MouseArea {
            anchors.fill: parent
            enabled: constructorRoot.isDragging
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: (mouse) => {
                if (!constructorRoot.isDragging) return
                constructorRoot.dragTargetZone = zoneBox.zoneName
                // Рассчитываем индекс вставки
                var count = zoneBox.modules.length
                if (count === 0) {
                    constructorRoot.dragTargetIndex = 0
                } else {
                    var relY = mouse.y - cardsCol.y
                    var idx = Math.floor((relY / Math.max(1, cardsCol.height)) * count)
                    constructorRoot.dragTargetIndex = Math.max(0, Math.min(count, idx))
                }
            }
        }
    }

    // ============================================================
    // КАРТОЧКА МОДУЛЯ (LEGO BLOCK)
    // ============================================================
    component ModuleCard: Rectangle {
        id: cardRoot

        property var modData: ({})
        property string zone: "left"
        property int itemIndex: 0

        readonly property var meta: constructorRoot.getMeta(modData.id)
        readonly property bool isBeingDragged: constructorRoot.isDragging && constructorRoot.dragId === modData.id
        readonly property int mediaTitleLen: modData.maxTitleLength === undefined
            ? 28 : Number(modData.maxTitleLength)

        Layout.fillWidth: true
        implicitWidth: 160
        implicitHeight: cardContentCol.implicitHeight + 16
        Layout.preferredHeight: implicitHeight

        radius: Theme.radiusSm
        color: cardMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
        border.color: isBeingDragged ? Theme.accent : (cardMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
        border.width: isBeingDragged ? 2 : 1
        opacity: isBeingDragged ? 0.35 : 1.0

        ColumnLayout {
            id: cardContentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6
            z: 1

            // Верхняя строка: Grip, иконка, название, кнопки включения/удаления
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                z: 2

                // Grip handle для перетаскивания
                Item {
                    width: 14
                    height: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰍜"
                        color: gripMa.containsMouse ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: gripMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeAllCursor
                        onPressed: (mouse) => {
                            constructorRoot.startDrag(cardRoot.modData.id, cardRoot.zone, cardRoot.itemIndex, gripMa)
                        }
                    }
                }

                // Иконка модуля
                Text {
                    text: cardRoot.meta.icon
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignVCenter
                }

                // Название модуля
                Text {
                    text: cardRoot.meta.name
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Кнопка отключения (крестик)
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: offMa.containsMouse ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.2) : "transparent"
                    border.color: offMa.containsMouse ? Theme.accentRed : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: offMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: offMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: constructorRoot.removeModule(cardRoot.modData.id)
                    }
                }
            }

            // Вторая строка: выбор размера и отображения.
            // Компактные отступы нужны, чтобы минимальная ширина ряда
            // (C/N/E + іконка/T/іконка+T) не перевищувала внутрішню
            // ширину картки: інакше ColumnLayout викладає рядки ширше
            // картки й кнопка × виходить за її межі.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Размер: Compact / Normal / Expanded
                RowLayout {
                    spacing: 1

                    Repeater {
                        model: [
                            { key: "compact",  label: "C" },
                            { key: "normal",   label: "N" },
                            { key: "expanded", label: "E" }
                        ]

                        delegate: Rectangle {
                            id: szBtn
                            required property var modelData

                            readonly property bool active: (cardRoot.modData.size || "normal") === modelData.key

                            width: 20
                            height: 18
                            radius: 3
                            color: active ? Theme.accent : (szMa.containsMouse ? Theme.glassCardActive : Theme.glassCard)
                            border.color: active ? Theme.accent : Theme.glassBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: szBtn.modelData.label
                                color: szBtn.active ? Theme.textDark : Theme.textSub
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                font.bold: szBtn.active
                            }

                            MouseArea {
                                id: szMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: constructorRoot.updateModuleProp(cardRoot.modData.id, "size", szBtn.modelData.key)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Отображение: Icon / Text / Icon + Text
                RowLayout {
                    spacing: 1

                    Repeater {
                        model: [
                            { key: "icon", label: "󰏤" },
                            { key: "text", label: "T" },
                            { key: "both", label: "󰏤+T" }
                        ]

                        delegate: Rectangle {
                            id: dispBtn
                            required property var modelData

                            readonly property bool active: (cardRoot.modData.display || "both") === modelData.key

                            width: modelData.key === "both" ? 28 : 20
                            height: 18
                            radius: 3
                            color: active ? Theme.accent : (dispMa.containsMouse ? Theme.glassCardActive : Theme.glassCard)
                            border.color: active ? Theme.accent : Theme.glassBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: dispBtn.modelData.label
                                color: dispBtn.active ? Theme.textDark : Theme.textSub
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                font.bold: dispBtn.active
                            }

                            MouseArea {
                                id: dispMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: constructorRoot.updateModuleProp(cardRoot.modData.id, "display", dispBtn.modelData.key)
                            }
                        }
                    }
                }
            }

            // Додаткові налаштування медіаплеєра.
            // Раніше всі контроли були в одному RowLayout із мінімальною
            // шириною ~235 px. Внутрішня ширина картки — 144 px, тому
            // ColumnLayout викладав рядок ширше картки: кнопка × у верхньому
            // ряду зсувалася за межі картки й не отримувала кліків.
            // Два компактні ряди тримають мінімальну ширину < 144 px.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 4
                z: 1
                visible: cardRoot.modData.id === "mediaplayer"

                Text {
                    text: "МЕДІА"
                    color: Theme.textMuted
                    font.pixelSize: 8
                    font.bold: true
                    font.family: Theme.fontMono
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }

                // Обкладинка
                Rectangle {
                    readonly property bool active: cardRoot.modData.showArt !== false
                    width: 42; height: 18; radius: 3
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: artMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                    border.color: active ? Theme.accent : Theme.glassBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Обкл."
                        color: parent.active ? Theme.accent : Theme.textMuted
                        font.pixelSize: 8
                        font.family: Theme.fontMono
                        font.bold: parent.active
                    }

                    MouseArea {
                        id: artMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: constructorRoot.updateModuleProp(cardRoot.modData.id, "showArt", !parent.active)
                    }
                }

                // Виконавець
                Rectangle {
                    readonly property bool active: cardRoot.modData.showArtist !== false
                    width: 36; height: 18; radius: 3
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: artistMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                    border.color: active ? Theme.accent : Theme.glassBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Вик."
                        color: parent.active ? Theme.accent : Theme.textMuted
                        font.pixelSize: 8
                        font.family: Theme.fontMono
                        font.bold: parent.active
                    }

                    MouseArea {
                        id: artistMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: constructorRoot.updateModuleProp(cardRoot.modData.id, "showArtist", !parent.active)
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 4
                z: 1
                visible: cardRoot.modData.id === "mediaplayer"

                Text {
                    text: "Назва:"
                    color: Theme.textMuted
                    font.pixelSize: 8
                    font.family: Theme.fontMono
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }

                // Обмеження довжини назви: ∞ / 16 / 24 / 32 символи
                RowLayout {
                    spacing: 2

                    Repeater {
                        model: [
                            { len: 0,  label: "∞" },
                            { len: 16, label: "16" },
                            { len: 24, label: "24" },
                            { len: 32, label: "32" }
                        ]

                        delegate: Rectangle {
                            id: lenBtn
                            required property var modelData

                            readonly property bool active: cardRoot.mediaTitleLen === modelData.len

                            width: modelData.label === "∞" ? 18 : 20
                            height: 18
                            Layout.preferredWidth: modelData.label === "∞" ? 18 : 20
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            radius: 3
                            color: active ? Theme.accent : (lenMa.containsMouse ? Theme.glassCardActive : Theme.glassCard)
                            border.color: active ? Theme.accent : Theme.glassBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: lenBtn.modelData.label
                                color: lenBtn.active ? Theme.textDark : Theme.textSub
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                font.bold: lenBtn.active
                            }

                            MouseArea {
                                id: lenMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: constructorRoot.updateModuleProp(cardRoot.modData.id, "maxTitleLength", lenBtn.modelData.len)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Третья строка: кнопки перемещения между зонами и изменения порядка
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Перемещение между зонами
                RowLayout {
                    spacing: 2

                    // В левую зону
                    Rectangle {
                        visible: cardRoot.zone !== "left"
                        width: 20; height: 18; radius: 3
                        color: toLeftMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                        border.color: Theme.glassBorder; border.width: 1

                        Text { anchors.centerIn: parent; text: "◀"; color: Theme.accent; font.pixelSize: 8 }
                        MouseArea {
                            id: toLeftMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: constructorRoot.moveModule(cardRoot.modData.id, "left", constructorRoot.layout.left.length)
                        }
                    }

                    // В центральную зону
                    Rectangle {
                        visible: cardRoot.zone !== "center"
                        width: 20; height: 18; radius: 3
                        color: toCenterMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                        border.color: Theme.glassBorder; border.width: 1

                        Text { anchors.centerIn: parent; text: "●"; color: Theme.accent; font.pixelSize: 8 }
                        MouseArea {
                            id: toCenterMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: constructorRoot.moveModule(cardRoot.modData.id, "center", constructorRoot.layout.center.length)
                        }
                    }

                    // В правую зону
                    Rectangle {
                        visible: cardRoot.zone !== "right"
                        width: 20; height: 18; radius: 3
                        color: toRightMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                        border.color: Theme.glassBorder; border.width: 1

                        Text { anchors.centerIn: parent; text: "▶"; color: Theme.accent; font.pixelSize: 8 }
                        MouseArea {
                            id: toRightMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: constructorRoot.moveModule(cardRoot.modData.id, "right", constructorRoot.layout.right.length)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Кнопки перемещения вверх / вниз (альтернатива drag-and-drop)
                RowLayout {
                    spacing: 2

                    // Вверх
                    Rectangle {
                        width: 20; height: 18; radius: 3
                        color: upMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                        border.color: Theme.glassBorder; border.width: 1
                        opacity: cardRoot.itemIndex > 0 ? 1.0 : 0.4

                        Text { anchors.centerIn: parent; text: "▲"; color: Theme.textSub; font.pixelSize: 8 }
                        MouseArea {
                            id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: cardRoot.itemIndex > 0
                            onClicked: constructorRoot.reorderModule(cardRoot.zone, cardRoot.itemIndex, cardRoot.itemIndex - 1)
                        }
                    }

                    // Вниз
                    Rectangle {
                        readonly property int maxIdx: (constructorRoot.layout[cardRoot.zone] ? constructorRoot.layout[cardRoot.zone].length : 0) - 1
                        width: 20; height: 18; radius: 3
                        color: downMa.containsMouse ? Theme.glassCardActive : Theme.glassCard
                        border.color: Theme.glassBorder; border.width: 1
                        opacity: cardRoot.itemIndex < maxIdx ? 1.0 : 0.4

                        Text { anchors.centerIn: parent; text: "▼"; color: Theme.textSub; font.pixelSize: 8 }
                        MouseArea {
                            id: downMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: cardRoot.itemIndex < cardRoot.maxIdx
                            onClicked: constructorRoot.reorderModule(cardRoot.zone, cardRoot.itemIndex, cardRoot.itemIndex + 1)
                        }
                    }
                }
            }
        }

        MouseArea {
            id: cardMa
            anchors.fill: parent
            hoverEnabled: true
            z: -1
        }
    }

    // ============================================================
    // ЛОГИКА DRAG & DROP
    // ============================================================
    function startDrag(id, fromZone, fromIdx, sourceItem) {
        dragId = id
        dragFromZone = fromZone
        dragFromIndex = fromIdx
        dragTargetZone = fromZone
        dragTargetIndex = fromIdx
        isDragging = true
    }

    function endDrag() {
        if (!isDragging) return
        if (dragTargetZone && dragTargetIndex >= 0) {
            moveModule(dragId, dragTargetZone, dragTargetIndex)
        }
        isDragging = false
        dragId = ""
        dragFromZone = ""
        dragFromIndex = -1
        dragTargetZone = ""
        dragTargetIndex = -1
    }

    // Окно захвата мыши во время перетаскивания
    MouseArea {
        id: globalDragCatcher
        anchors.fill: parent
        visible: constructorRoot.isDragging
        enabled: constructorRoot.isDragging
        hoverEnabled: true
        cursorShape: Qt.ClosedHandCursor
        z: 999

        onPositionChanged: (mouse) => {
            constructorRoot.dragGlobalX = mouse.x
            constructorRoot.dragGlobalY = mouse.y

            // Проверяем, над какой зоной находится мышь
            var leftPos = leftZoneBox.mapFromItem(constructorRoot, mouse.x, mouse.y)
            var centerPos = centerZoneBox.mapFromItem(constructorRoot, mouse.x, mouse.y)
            var rightPos = rightZoneBox.mapFromItem(constructorRoot, mouse.x, mouse.y)
            var disPos = disabledShelf.mapFromItem(constructorRoot, mouse.x, mouse.y)

            if (leftPos.x >= 0 && leftPos.x <= leftZoneBox.width && leftPos.y >= 0 && leftPos.y <= leftZoneBox.height) {
                constructorRoot.dragTargetZone = "left"
            } else if (centerPos.x >= 0 && centerPos.x <= centerZoneBox.width && centerPos.y >= 0 && centerPos.y <= centerZoneBox.height) {
                constructorRoot.dragTargetZone = "center"
            } else if (rightPos.x >= 0 && rightPos.x <= rightZoneBox.width && rightPos.y >= 0 && rightPos.y <= rightZoneBox.height) {
                constructorRoot.dragTargetZone = "right"
            } else if (disPos.x >= 0 && disPos.x <= disabledShelf.width && disPos.y >= 0 && disPos.y <= disabledShelf.height) {
                constructorRoot.dragTargetZone = "disabled"
                constructorRoot.dragTargetIndex = constructorRoot.layout.disabled.length
            }
        }

        onReleased: {
            constructorRoot.endDrag()
        }
    }

    // Всплывающий фантомный блок во время перетаскивания
    Rectangle {
        visible: constructorRoot.isDragging
        x: constructorRoot.dragGlobalX - width / 2
        y: constructorRoot.dragGlobalY - height / 2
        width: 140
        height: 34
        radius: Theme.radiusSm
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
        border.color: Theme.accent
        border.width: 2
        z: 1000

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: constructorRoot.getMeta(constructorRoot.dragId).icon
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 13
            }

            Text {
                text: constructorRoot.getMeta(constructorRoot.dragId).name
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
            }
        }
    }
}
