import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."

// Спливаючі тости для нових сповіщень (верхній правий кут).
// Викликається з DashboardMenu: push(notification) — лише коли DND вимкнено.
// Історія сповіщень живе в NotificationServer (trackedNotifications) з DashboardMenu —
// цей компонент лише ВІДОБРАЖАЄ тости і не є другою системою сповіщень.
PanelWindow {
    id: toastWindow

    readonly property int toastWidth: 340
    readonly property int gap: 8
    readonly property int maxToasts: 3
    // Масив об'єктів Notification (Quickshell.Services.Notifications)
    property var toasts: []

    visible: toasts.length > 0
    color: "transparent"

    // Тост живёт на том же мониторе, что и панель.
    screen: PanelController.panelScreen
        ? PanelController.panelScreen
        : Quickshell.screens[0]

    readonly property bool panelAtBottom: PanelController.panelPosition === "bottom"
    readonly property int edgeGap: 8

    anchors {
        top: !panelAtBottom
        bottom: panelAtBottom
        right: true
    }

    // Margins layer-shell отсчитываются от usable area, из которой compositor
    // уже вычел exclusive zone панели. Поэтому толщину панели здесь добавлять
    // нельзя — иначе тост уезжает от панели на её толщину + отступ.
    margins {
        top: panelAtBottom ? 0 : edgeGap
        bottom: panelAtBottom ? edgeGap : 0
        right: edgeGap
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    implicitWidth: toastWidth
    implicitHeight: toastsCol.implicitHeight

    // Снимок уведомления: обычный JS-объект вместо ссылки на серверный QObject.
    // Уведомление может быть удалено из истории (dismiss → retainedDestroy,
    // server.cpp), пока тост ещё показан; ссылка на уничтоженный QObject в
    // toasts приводит к SEGV при regenerate/incubation делегата (Qt 6.12).
    function snapshot(n) {
        return {
            id: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            expireTimeout: n.expireTimeout || 0
        }
    }

    function push(n) {
        if (!n)
            return
        var arr = toasts.slice()
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].id === n.id)   // вже показуємо
                return
        }
        arr.push(snapshot(n))
        while (arr.length > maxToasts)
            arr.shift()
        toasts = arr
    }

    function remove(n) {
        if (!n)
            return
        // Реентерабельность: заміна toasts зсередини обробника делегата
        // (таймер автозакриття / кнопка ✕) руйнувала делегат посеред
        // випромінювання сигналу → Repeater::regenerate → SEGV (Qt 6.12).
        // Мутація моделі відкладається до кінця ітерації циклу подій.
        // id читається одразу, поки об'єкт живий — колбек не торкається n.
        var id = n.id
        Qt.callLater(function() {
            var arr = []
            var found = false
            for (var i = 0; i < toasts.length; i++) {
                if (toasts[i].id === id) {
                    found = true
                    continue
                }
                arr.push(toasts[i])
            }
            // Повторний виклик для вже видаленого тоста: модель не змінюємо —
            // зайвий regenerate (перезапуск усіх делегатів) не потрібен.
            if (!found)
                return
            toasts = arr
        })
    }

    function clearAll() {
        toasts = []
    }

    Column {
        id: toastsCol
        anchors.top: parent.top
        anchors.right: parent.right
        width: toastWidth
        spacing: toastWindow.gap

        Repeater {
            model: toastWindow.toasts

            delegate: Rectangle {
                id: toast
                required property var modelData

                width: toastWidth
                height: toastCol.implicitHeight + 20
                radius: Theme.radiusLg
                color: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg ? "transparent" : Theme.glassPopupSolid
                border.color: Theme.glassBorder
                border.width: 1

                GradientBg {
                    anchors.fill: parent
                    enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
                    intensity: Theme.cfgGradientIntensity
                    target: "bg"
                    solidColor: Theme.glassPopupSolid
                    radius: Theme.radiusLg
                    clip: true
                }

                // Поява: м'яке зникнення/масштаб у стилі панелі
                opacity: 0
                scale: 0.96
                Component.onCompleted: {
                    toast.opacity = 1
                    toast.scale = 1
                }
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.1 } }

                // Автозникнення: expireTimeout зі знімка (мс), інакше 5 с
                Timer {
                    interval: toast.modelData && toast.modelData.expireTimeout > 0
                              ? Math.min(toast.modelData.expireTimeout, 15000) : 5000
                    running: true
                    repeat: false
                    onTriggered: toastWindow.remove(toast.modelData)
                }

                ColumnLayout {
                    id: toastCol
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.rightMargin: 30
                    spacing: 3

                    Text {
                        text: toast.modelData.appName
                        color: Theme.accent
                        font.pixelSize: 9
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: toast.modelData.summary
                        color: Theme.text
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text.length > 0
                    }
                    Text {
                        text: toast.modelData.body
                        color: Theme.textSub
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text.length > 0
                    }
                }

                // ✕ — прибрати тост (сповіщення лишається в історії панелі)
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.rightMargin: 6
                    width: 20
                    height: 20
                    radius: 10
                    color: toastCloseMa.containsMouse
                           ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.22)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: toastCloseMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.pixelSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: toastCloseMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toastWindow.remove(toast.modelData)
                    }
                }
            }
        }
    }
}
