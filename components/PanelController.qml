pragma Singleton
import QtQuick 2.15
import "."

// ============================================================================
// PanelController — единственный источник состояния положения панели.
//
// Все компоненты (TopBar, popup-окна, страницы настроек) читают положение,
// направление открытия popup и геометрию отсюда. Дублировать логику в каждом
// компоненте запрещено — используйте PanelController.
//
// Хранит только вычисляемое производное от Config + текущего экрана.
// Настройки сами по себе живут в Config.Panel (settings.json) и сохраняются
// существующей системой Config (debounce save 500мс, mergeDefaults, миграция).
// ============================================================================
QtObject {
    id: root

    // ---------- Исходные настройки (из Config / settings.json) ----------
    property string panelPosition: Config.panelPosition          // "top" | "bottom" | "left" | "right"
    property bool   autoHideEnabled: Config.panelAutoHide
    property int    autoHideDelay: Config.panelAutoHideDelay     // мс до скрытия после ухода с панели
    property int    autoHideShowDelay: Config.panelAutoHideShowDelay // мс задержка показа у края
    property int    autoHideEdgeZone: Config.panelAutoHideEdgeZone // ширина чувствительной зоны у края

    // ---------- Производные ----------
    readonly property bool isHorizontal: panelPosition === "top" || panelPosition === "bottom"
    readonly property bool isVertical: panelPosition === "left" || panelPosition === "right"

    // Направление открытия popup относительно панели:
    // top → вниз, bottom → вверх, left → вправо, right → влево.
    readonly property string popupDirection: {
        if (panelPosition === "top")    return "down"
        if (panelPosition === "bottom") return "up"
        if (panelPosition === "left")   return "right"
        return "left"
    }

    // Якорь панели (сторона экрана, к которой приклеено окно панели).
    readonly property string anchorSide: panelPosition

    // ---------- Внутренний размер панели (поперечная ось) ----------
    // Фактическая толщина окна панели. Для горизонтальной панели это высота
    // окна, для вертикальной — его ширина (она зависит от контента и может
    // быть больше Config.panelHeight). TopBar обновляет эти значения живыми
    // размерами окна; до готовности окна используется Config.panelHeight.
    property int panelWindowWidth: Config.panelHeight
    property int panelWindowHeight: Config.panelHeight
    readonly property int panelThickness: isHorizontal
        ? panelWindowHeight : panelWindowWidth

    // Позиция элемента внутри окна панели (в координатах contentItem).
    // mapToItem не является реактивным, поэтому дополнительно читаем x/y
    // каждого родителя — это заставляет binding пересчитаться при сдвиге
    // капсулы/островка внутри панели.
    function itemWindowPos(item) {
        if (!item)
            return { x: 0, y: 0 }
        var pos = item.mapToItem(null, 0, 0)
        var node = item
        while (node) {
            var tracked = node.x + node.y
            if (tracked === -2147483648) // недостижимая ветка только для чтения свойств
                break
            node = node.parent
        }
        return pos
    }

    // Точка на краю панели со стороны открытия popup, относительно верхнего
    // левого угла anchor.item. Вторая ось остаётся в начале item.
    // Используется там, где размер popup заранее неизвестен (меню трея).
    function panelEdgeOffset(anchorItem, gap, panelW, panelH) {
        var side = panelPosition
        var pos = itemWindowPos(anchorItem)
        var pw = panelW > 0 ? panelW : Config.panelHeight
        var ph = panelH > 0 ? panelH : Config.panelHeight
        gap = gap === undefined ? 6 : gap
        if (side === "top")
            return { x: 0, y: ph + gap - pos.y }
        if (side === "bottom")
            return { x: 0, y: -gap - pos.y }
        if (side === "left")
            return { x: pw + gap - pos.x, y: 0 }
        return { x: -gap - pos.x, y: 0 }
    }

    // ---------- Смещение popup-якоря относительно anchor.item ----------
    // anchor.rect.x / anchor.rect.y задаются относительно верхнего левого угла
    // anchor.item (в координатах окна панели). Функция возвращает {x, y} так,
    // чтобы popup не накладывался на панель и открывался в сторону popupDirection.
    // panelW/panelH — реальные размеры окна панели. gap — зазор (px).
    function popupOffset(anchorItem, popupW, popupH, gap, panelW, panelH) {
        var side = panelPosition
        var iw = anchorItem ? anchorItem.width : 0
        var ih = anchorItem ? anchorItem.height : 0
        var edge = panelEdgeOffset(anchorItem, gap, panelW, panelH)
        var x = 0, y = 0
        // edges/gravity у PopupWindow за замовчуванням — Top|Left / Bottom|Right,
        // тобто якір задає ЛІВИЙ ВЕРХНІЙ кут popup. Тому для bottom/right, де
        // popup росте вгору/вліво, зі зсуву віднімаємо його власний розмір.
        if (side === "top") {
            x = (iw - popupW) / 2
            y = edge.y
        } else if (side === "bottom") {
            x = (iw - popupW) / 2
            y = edge.y - popupH
        } else if (side === "left") {
            x = edge.x
            y = (ih - popupH) / 2
        } else { // "right"
            x = edge.x - popupW
            y = (ih - popupH) / 2
        }
        return { x: x, y: y }
    }

    // ---------- Безопасное позиционирование popup по экрану ----------
    // clampPopupX/clampPopupY ограничивают позицию popup (уже переведённую в
    // координаты экрана) так, чтобы окно не выходило за границы монитора.
    // Учитывается origin монитора (мультимонитор), а не только его размер.
    function clampPopupX(screenX, popupW, screenW) {
        var scr = panelScreen
        var minX = scr ? scr.x : 0
        var maxX = (scr ? scr.x + scr.width : screenW) - popupW
        if (maxX < minX) maxX = minX
        return Math.min(maxX, Math.max(minX, screenX))
    }
    function clampPopupY(screenY, popupH, screenH) {
        var scr = panelScreen
        var minY = scr ? scr.y : 0
        var maxY = (scr ? scr.y + scr.height : screenH) - popupH
        if (maxY < minY) maxY = minY
        return Math.min(maxY, Math.max(minY, screenY))
    }

    // ---------- Геометрия монитора панели ----------
    // panelScreen реактивно отримує лише живий targetScreen із TopBar.
    // Під час grace period / відсутності екранів Binding встановлює null.
    property var panelScreen: null
    readonly property int screenWidth:  panelScreen ? panelScreen.width : 0
    readonly property int screenHeight: panelScreen ? panelScreen.height : 0

    // ---------- Міст до єдиного MediaPlayerPanel ----------
    // TopBar публікує сюди свій єдиний popup. Сторінка налаштувань
    // використовує це лише для дій (повторний пошук текстів) — других
    // екземплярів вікна чи MPRIS-сервісу не створюється.
    property var mediaPanel: null
}
