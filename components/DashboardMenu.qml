import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import "."
// Компактне меню, що випадає з-під годинника: плитки (Wi-Fi/Bluetooth/Мікрофон/Не турбувати),
// Гучність/Яскравість, Сповіщення. Прив'язка до кнопки годинника (anchor.item у TopBar) —
// коректне позиціонування на будь-якому моніторі та масштабі, Waybar не перекривається.

PopupWindow {
    id: root

    signal openControlCenter()

    // --- Компактне вікно: ширина фіксована, висота — за вмістом ---
    implicitWidth: 420
    implicitHeight: contentCol.implicitHeight + 24

    grabFocus: true
    color: "transparent"

    // ---------- Відкриття/закриття: пряме керування видимістю ----------
    // Стара (стабільна) механіка: visible керується імперативно, похідних станів
    // немає. Wayland може закрити grab-попап зовні (popup_done) — QuickShell
    // синхронізує visible, тож наступний клік завжди бачить актуальний стан.
    // Анімація — лише поява, всередині вмісту вікна; закриття — миттєве
    // (Qt.Popup не тримається відкритим заради анімації).
    visible: false

    function openPanel() {
        if (root.visible)
            return
        // Кожне нове відкриття панелі — з головної сторінки
        root.currentPage = "home"
        // Початковий зсув залежить від напрямку відкриття popup
        // (top → вниз, bottom → вгору, left → вправо, right → вліво).
        // Анімація довчить зсув до 0; неактивна ось залишається на 0.
        var dir = PanelController.popupDirection
        if (dir === "down") { panelTranslate.y = -root.implicitHeight; panelTranslate.x = 0 }
        else if (dir === "up") { panelTranslate.y = root.implicitHeight; panelTranslate.x = 0 }
        else if (dir === "right") { panelTranslate.x = -root.implicitWidth; panelTranslate.y = 0 }
        else { panelTranslate.x = root.implicitWidth; panelTranslate.y = 0 }
        // Миттєвий старт з-під бару, далі анімація появи всередині вікна
        panel.opacity = 0.35
        panel.scale = 0.97
        root.visible = true
        openAnim.restart()
    }

    function closePanel() {
        openAnim.stop()
        root.visible = false
        panelTranslate.y = -9999
        panelTranslate.x = 0
        panel.opacity = 0
        panel.scale = 0.97
    }

    // Поява: виїжджає у бік popupDirection + легкі opacity/scale.
    // Запускається з openPanel() після показу вікна; жодних станів не змінює.
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: panelTranslate; property: "y"
            to: 0
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panelTranslate; property: "x"
            to: 0
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panel; property: "opacity"
            to: 1
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panel; property: "scale"
            to: 1
            duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.05
        }
    }

    // ---------- Композиція ----------
    readonly property int gap: 8

    // ---------- Сторінки ----------
    // "home" | "calendar" | "monitor" | "settings"
    property string currentPage: "home"
    // Фіксована висота контенту: вікно не змінює розмір при перемиканні вкладок
    readonly property int pageHeight: 264

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.closePanel()
    }

    // ---------- Звук ----------
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    property real vol: sink && sink.audio ? sink.audio.volume : 0.0
    property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false
    property bool micMuted: source && source.audio ? source.audio.muted : false

    PwObjectTracker { objects: [root.sink, root.source] }

    // ---------- Яскравість (вбудований дисплей, /sys/class/backlight) ----------
    // Вибираємо пристрій з eDP (вбудована панель), щоб не чіпати яскравість зовнішніх моніторів.
    // Зміна: brightnessctl (вже встановлений), читання: безпосередньо з sysfs.
    property string briDev: ""
    property bool briAvailable: briDev.length > 0
    property real briVal: 0        // 0..1
    property real briMax: 1
    property real briPending: -1   // зміна в очікуванні відправки (дебаунс)

    Process {
        id: briFind
        command: ["sh", "-c",
                  "d=\"\";" +
                  "for x in /sys/class/backlight/*; do" +
                  " readlink -f \"$x\" 2>/dev/null | grep -q \"eDP\" && { d=$(basename \"$x\"); break; };" +
                  "done;" +
                  "[ -n \"$d\" ] || d=$(ls /sys/class/backlight 2>/dev/null | head -n1);" +
                  "echo \"$d\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim()
                if (name.length > 0) {
                    root.briDev = name
                    briGet.running = true
                }
            }
        }
    }

    Process {
        id: briGet
        command: ["sh", "-c",
                  "echo \"$(cat /sys/class/backlight/" + root.briDev + "/brightness 2>/dev/null) " +
                  "$(cat /sys/class/backlight/" + root.briDev + "/max_brightness 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/)
                var cur = parseFloat(p[0])
                var max = parseFloat(p[1])
                if (!isNaN(max) && max > 0) {
                    root.briMax = max
                    if (!isNaN(cur)) {
                        root.briVal = Math.max(0, Math.min(1, cur / max))
                        root.briPending = -1
                    }
                }
            }
        }
    }

    Process {
        id: briSet
        // Перечит sysfs ПІСЛЯ фактичного завершення запису (не одразу):
        // інакше brightnessctl ще пише, а старe значення «відкидає» повзунок назад.
        onExited: briGet.running = true
    }

    function applyBrightness() {
        if (root.briPending < 0 || root.briDev.length === 0)
            return
        var pct = Math.max(1, Math.min(100, Math.round(root.briPending * 100)))
        briPending = -1
        briSet.command = ["brightnessctl", "-d", root.briDev, "set", pct + "%"]
        briSet.running = true
    }

    // Дебаунс: відправляємо значення лише 150 мс після останнього руху повзунка
    Timer {
        id: briCommitTimer
        interval: 150
        repeat: true
        running: root.briPending >= 0
        onTriggered: root.applyBrightness()
    }

    // Фонове читання (клавіші зовнішні зміни), раз на 4 с, лише коли видно
    Timer {
        interval: 4000
        running: root.visible && root.briAvailable
        repeat: true
        triggeredOnStart: false
        onTriggered: if (!briGet.running && root.briPending < 0) briGet.running = true
    }

    // ---------- Wi-Fi (через nmcli) ----------
    property bool wifiOn: false
    property string wifiSsid: ""

    Process {
        id: wifiGet
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }
    Process { id: wifiSet }

    // Назва активної мережі (реальні дані з того ж nmcli)
    Process {
        id: wifiInfo
        command: ["sh", "-c",
                  "nmcli -t -f NAME,TYPE connection show --active | grep 802-11-wireless | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.length > 0 && line.indexOf(":802-11-wireless") > 0)
                    root.wifiSsid = line.slice(0, line.indexOf(":802-11-wireless"))
                else
                    root.wifiSsid = ""
            }
        }
    }

    function toggleWifi() {
        wifiSet.command = ["nmcli", "radio", "wifi", wifiOn ? "off" : "on"]
        wifiSet.running = true
        wifiOn = !wifiOn
        wifiInfo.running = true
    }

    onVisibleChanged: {
        if (visible) {
            wifiGet.running = true
            wifiInfo.running = true
            briFind.running = true
        }
    }

    // ---------- Не турбувати (DND) ----------
    // Стан зберігається в settings.json (Config.Notifications.dnd).
    // Увімкнено: спливаючі тости приховані, сповіщення приймаються
    // й накопичуються в історії. Вимкнено: тости знову показуються.
    property bool dnd: Config.notificationsDnd

    function toggleDnd() {
        Config.setProp("Notifications.dnd", !root.dnd)
    }

    // ---------- Сповіщення ----------
    // Єдиний NotificationServer у застосунку (DBus org.freedesktop.Notifications).
    // Другий інстанс створювати не можна — інакше ім'я на шині конфліктуватиме.
    property var notifTimes: ({})   // id -> час отримання (мс)
    // Кількість непрочитаних: росте з кожним новим, скидається відкриттям історії
    property int unreadCount: 0
    // Доступ для NotificationHistory (окремоє вікно у TopBar): модель історії
    readonly property var notifModel: notifServer.trackedNotifications

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        onNotification: (n) => {
            n.tracked = true
            notifTimes[n.id] = new Date().getTime()
            root.unreadCount++
            console.debug("Dashboard: notification received —", n.appName, "·", n.summary)
            // Тости показуємо лише поза режимом «Не турбувати»;
            // історія (trackedNotifications) наповнюється в обох режимах.
            if (!root.dnd)
                notifToast.push(n)
        }
    }

    function notifTimeText(id) {
        var t = notifTimes[id]
        return t ? Qt.formatDateTime(new Date(t), "hh:mm") : ""
    }

    function clearNotifications() {
        var list = notifServer.trackedNotifications.values.slice()
        for (var i = 0; i < list.length; i++)
            list[i].dismiss()
    }

    // ================= ІНТЕРФЕЙС =================
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg ? "transparent" : Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
            intensity: Theme.cfgGradientIntensity
            target: "bg"
            solidColor: Theme.glassPopupSolid
            radius: Theme.radiusXl
            clip: true
        }

        // Блокуємо клік всередині панелі
        MouseArea { anchors.fill: parent; onClicked: {} }

        // Стан панелі керує openAnim (поява); стартові значення ставить openPanel().
        // y — статичне значення (не биндинг!): биндинг повертав панель за бар
        // при переоцінці — саме це давало «відкривається через раз».
        opacity: 0
        scale: 0.97
        // Масштаб розгортається від сторони, якою панель прилягає до бару:
        // top → від верху (випадає вниз), bottom → від низу (випадає вгору).
        // Для left/right лишається історична поведінка (Item.Top).
        transformOrigin: PanelController.panelPosition === "bottom" ? Item.Bottom : Item.Top
        transform: Translate {
            id: panelTranslate
            // Статичне значення (НЕ биндинг): реальний старт ставляє openPanel().
            // Биндинг на y конфліктував з анімаціями — панель «тікала» за бар.
            y: -9999
        }


        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: root.gap

            // ---------- Шапка: заголовок + закриття ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "ЦЕНТР КЕРУВАННЯ"
                    color: Theme.textMuted
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.2
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: closeMa.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            // ---------- Сторінки ----------
            // StackLayout тримає всі сторінки створеними (без перестворення при
            // перемиканні) і показує рівно одну — накладання неможливе.
            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.preferredHeight: root.pageHeight
                currentIndex: root.currentPage === "home" ? 0
                            : (root.currentPage === "calendar" ? 1
                            : (root.currentPage === "monitor" ? 2 : 3))

                transform: Translate { id: pageShift; y: 0 }

                onCurrentIndexChanged: switchAnim.restart()

                ColumnLayout {
                    id: homePage
                    spacing: root.gap

                    // ---------- Плитки 2×2 ----------
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: root.gap
                        rowSpacing: root.gap

                        QuickTile {
                            icon: "󰖩"
                            title: "Wi-Fi"
                            subtitle: root.wifiOn ? ("Увімкнено" + (root.wifiSsid.length > 0 ? " · " + root.wifiSsid : "")) : "Вимкнено"
                            active: root.wifiOn
                            onClicked: root.toggleWifi()
                        }
                        QuickTile {
                            icon: "󰂯"
                            title: "Bluetooth"
                            subtitle: !Bluetooth.defaultAdapter ? "Недоступно"
                                      : (Bluetooth.defaultAdapter.enabled ? "Увімкнено" : "Вимкнено")
                            active: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
                            onClicked: {
                                if (Bluetooth.defaultAdapter)
                                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                            }
                        }
                        QuickTile {
                            icon: root.micMuted ? "󰍭" : "󰍬"
                            title: "Мікрофон"
                            subtitle: root.micMuted ? "Вимкнено" : "Активний"
                            active: !root.micMuted
                            onClicked: {
                                if (root.source && root.source.audio)
                                    root.source.audio.muted = !root.source.audio.muted
                            }
                        }
                        // DND — справжній перемикач режиму «Не турбувати»
                        QuickTile {
                            icon: root.dnd ? "󰂛" : "󰂚"
                            title: "Не турбувати"
                            subtitle: root.dnd ? "Увімкнено · тости приховані" : "Вимкнено"
                            active: root.dnd
                            onClicked: root.toggleDnd()
                        }
                    }

                    // Кнопка відкриття налаштувань (Control Center)
                    SettingsBtn {
                        Layout.fillWidth: true
                        onClicked: {
                            root.closePanel()
                            root.openControlCenter()
                        }
                    }

                    // ---------- Гучність + Яскравість ----------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.gap

                        // Гучність: Pipewire; клік по іконці — mute
                        Card {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            radius: Theme.radiusLg
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        radius: 10

                                        color: root.sinkMuted
                                            ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.14 * Theme.glassOpacity)
                                            : Theme.bgSurface
                                        border.color: root.sinkMuted ? Theme.glassBorderFocus : Theme.glassBorder
                                        border.width: 1
                                        scale: volIconMa.pressed ? 0.9 : 1.0

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.sinkMuted ? "󰖁" : (root.vol > 0.5 ? "󰕾" : (root.vol > 0 ? "󰖀" : "󰕿"))
                                            color: root.sinkMuted ? Theme.accentRed : Theme.accent
                                            font.family: Theme.fontMono
                                            font.pixelSize: 14

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }

                                        MouseArea {
                                            id: volIconMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.sink && root.sink.audio)
                                                    root.sink.audio.muted = !root.sink.audio.muted
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Гучність"
                                        color: Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: true
                                        Layout.minimumWidth: 0
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Math.round(root.vol * 100) + "%"
                                        color: root.sinkMuted ? Theme.textMuted : Theme.text
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 48
                                        Layout.minimumWidth: 48
                                        Layout.maximumWidth: 48

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }
                                }

                                MiniSlider {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    external: root.vol
                                    hold: true
                                    fill: Theme.accent
                                    trackDim: root.sinkMuted

                                    onMoved: {
                                        if (root.sink && root.sink.audio)
                                            root.sink.audio.volume = value
                                    }
                                }
                            }
                        }

                        // Яскравість: sysfs eDP-панель; запис через brightnessctl
                        Card {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            radius: Theme.radiusLg
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        radius: 10

                                        color: root.briAvailable ? Theme.bgSurface
                                            : Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.10)
                                        border.color: root.briAvailable ? Theme.glassBorder : Theme.glassBorderHover
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰖙"
                                            color: root.briAvailable ? Theme.accentPeach : Theme.textMuted
                                            font.family: Theme.fontMono
                                            font.pixelSize: 14

                                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                        }
                                    }

                                    Text {
                                        text: "Яскравість"
                                        color: Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: true
                                        Layout.minimumWidth: 0
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: root.briAvailable ? Math.round((root.briPending >= 0 ? root.briPending : root.briVal) * 100) + "%" : "N/A"
                                        color: root.briAvailable ? Theme.text : Theme.textMuted
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 48
                                        Layout.minimumWidth: 48
                                        Layout.maximumWidth: 48

                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }
                                }

                                MiniSlider {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    external: root.briVal
                                    hold: root.briPending < 0
                                    fill: Theme.accentPeach
                                    trackDim: !root.briAvailable

                                    onMoved: {
                                        root.briPending = value
                                    }
                                }
                            }
                        }
                    }
                }

                CalendarPage {
                    id: calendarPage
                    active: root.currentPage === "calendar"
                }

                MonitorPage {
                    id: monitorPage
                    active: root.currentPage === "monitor"
                }

                ColumnLayout {
                    id: settingsPage
                    spacing: 10

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 28
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14 * Theme.glassOpacity)
                        border.color: Theme.glassBorderFocus
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 26
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Центр налаштувань"
                        color: Theme.text
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Теми, панель, дисплеї, віджети та анімації"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    SettingsBtn {
                        Layout.fillWidth: true
                        onClicked: {
                            root.closePanel()
                            root.openControlCenter()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ---------- Нижня навігація ----------
            Rectangle {
                id: navBar
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusLg
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: [
                            { key: "home",     icon: "󰋜", label: "Домівка" },
                            { key: "calendar", icon: "󰃭", label: "Календар" },
                            { key: "monitor",  icon: "󰐰", label: "Моніторинг" },
                            { key: "settings", icon: "󰒓", label: "Налаштування" }
                        ]

                        delegate: Rectangle {
                            id: navBtn
                            required property var modelData

                            readonly property bool current: root.currentPage === navBtn.modelData.key

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusMd
                            color: navBtn.current
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16 * Theme.glassOpacity)
                                : (navMa.containsMouse ? Theme.glassCardHover : "transparent")
                            border.color: navBtn.current ? Theme.glassBorderFocus : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: navBtn.modelData.icon
                                    color: navBtn.current ? Theme.accent : Theme.textSub
                                    font.family: Theme.fontMono
                                    font.pixelSize: 15

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: navBtn.modelData.label
                                    color: navBtn.current ? Theme.text : Theme.textMuted
                                    font.pixelSize: 8
                                    font.bold: navBtn.current

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }

                            MouseArea {
                                id: navMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPage = navBtn.modelData.key
                            }
                        }
                    }
                }
            }

            // Плавна поява нової сторінки: StackLayout уже показав рівно одну,
            // тому це лише легкий fade + зсув (без накладання сторінок).
            ParallelAnimation {
                id: switchAnim
                NumberAnimation {
                    target: pageStack
                    property: "opacity"
                    from: 0.55
                    to: 1
                    duration: Theme.animFast
                    easing.type: Theme.easingStandard
                }
                NumberAnimation {
                    target: pageShift
                    property: "y"
                    from: 4
                    to: 0
                    duration: Theme.animFast
                    easing.type: Theme.easingStandard
                }
            }

        }
    }

    // ---------- Спливаючі тости сповіщень (показуються лише поза DND) ----------
    NotificationPopup {
        id: notifToast
    }

    // ================= ЛОКАЛЬНІ КОМПОНЕНТИ =================

    // Плитка швидкого налаштування: іконка в контейнері + два рівні тексту.
    // Ввімк/вимк стан однозначно розрізняється: акцентний тінт + акцентна рамка і іконка.
    component QuickTile: Rectangle {
        id: tile

        property string icon
        property string title
        property string subtitle
        property bool active: false

        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 58
        radius: Theme.radiusLg

        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf ? "transparent" : (tile.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15 * Theme.glassOpacity)
             : (tileMa.containsMouse ? Theme.glassCardHover : Theme.glassCard))
        border.color: tile.active ? Theme.glassBorderFocus
             : (tileMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
        border.width: 1
        scale: tileMa.pressed ? 0.97 : 1.0

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
            intensity: Theme.cfgGradientIntensity
            target: "surf"
            solidColor: tile.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15 * Theme.glassOpacity)
                 : (tileMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
            radius: Theme.radiusLg
            clip: true
        }

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 12

                color: tile.active ? Theme.accent : Theme.bgSurface
                border.color: tile.active ? Theme.accentHover : Theme.glassBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

                Text {
                    anchors.centerIn: parent
                    text: tile.icon
                    color: tile.active ? Theme.textDark : (tileMa.containsMouse ? Theme.text : Theme.textSub)
                    font.family: Theme.fontMono
                    font.pixelSize: 16

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: tile.title
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: tile.subtitle
                    color: tile.active ? Theme.accent : Theme.textMuted
                    font.pixelSize: 10
                    font.bold: tile.active
                    elide: Text.ElideRight
                    Layout.fillWidth: true

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                }
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    // Кнопка відкриття налаштувань: органічно продовжує стилістику плиток
    component SettingsBtn: Rectangle {
        id: sb

        signal clicked()

        implicitHeight: 44
        radius: Theme.radiusLg

        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf ? "transparent" : (sbMa.containsMouse ? Theme.glassCardHover : Theme.glassCard)
        border.color: sbMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
        border.width: 1
        scale: sbMa.pressed ? 0.97 : 1.0

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
            intensity: Theme.cfgGradientIntensity
            target: "surf"
            solidColor: sbMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
            radius: Theme.radiusLg
            clip: true
        }

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                Layout.fillWidth: false

                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18 * Theme.glassOpacity)
                border.color: Theme.glassBorderFocus
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }
            }

            Text {
                text: "Налаштування"
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "›"
                color: sbMa.containsMouse ? Theme.accent : Theme.textMuted
                font.pixelSize: 14
                font.bold: true

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        MouseArea {
            id: sbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.clicked()
        }
    }

    // Слайдер у стилі Dashboard: тонка доріжка + бігунок, що росте при наведенні.
    // Спільний для гучності та яскравості.
    component MiniSlider: Slider {
        id: ms

        // Зовнішнє значення: автооновлення поки користувач не тягне бігунок
        property real external: 0
        property bool hold: true    // false — не оновлювати (триває відправка/перечит)
        property color fill: Theme.accent
        property bool trackDim: false

        from: 0.0
        to: 1.0
        topPadding: 6
        bottomPadding: 6

        Binding on value {
            value: ms.external
            when: !ms.pressed && ms.hold
        }

        background: Rectangle {
            x: ms.leftPadding
            y: ms.topPadding + ms.availableHeight / 2 - height / 2
            width: ms.availableWidth
            height: 8
            radius: 4
            color: Theme.bgSurface
            border.color: Theme.glassBorder
            border.width: 1

            Rectangle {
                width: Math.min(parent.width, ms.visualPosition * parent.width)
                height: parent.height
                radius: 5
                color: ms.trackDim ? Theme.textMuted : ms.fill

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        handle: Rectangle {
            x: ms.leftPadding + ms.visualPosition * (ms.availableWidth - width)
            y: ms.topPadding + ms.availableHeight / 2 - height / 2
            implicitWidth: ms.pressed || ms.hovered ? 18 : 14
            implicitHeight: ms.pressed || ms.hovered ? 18 : 14
            radius: height / 2
            color: ms.pressed ? Theme.accentHover : Theme.text
            border.color: ms.trackDim ? Theme.textMuted : ms.fill
            border.width: 2

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast } }
            Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast } }
        }
    }
}
