import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

PopupWindow {
    id: root

    implicitWidth: 540
    implicitHeight: 650

    visible: false
    grabFocus: true
    color: "transparent"

    property var adapter: Bluetooth.defaultAdapter
    property bool isBtOn: adapter && adapter.enabled
    property bool isDiscovering: adapter && adapter.discovering
    property bool isDiscoverable: adapter && adapter.discoverable

    // Режим відображення: "orbit" (Планети) або "list" (Класичний список)
    property string viewMode: "orbit"

    // Вибраний девайс для детальної картки
    property var selectedDevice: null

    // Анімація злиття планет при підключенні
    property bool isFusing: false
    property var fusingDevice: null

    // Знайдене підключене ядро (Домашня планета)
    property var connectedDevice: {
        if (!adapter || !adapter.devices || !adapter.devices.values) return null;
        for (var i = 0; i < adapter.devices.values.length; i++) {
            if (adapter.devices.values[i].connected) return adapter.devices.values[i];
        }
        return null;
    }

    // Допоміжний процес для виконання команд bluetoothctl
    Process {
        id: btProc
    }

    function disconnectDevice(dev) {
        if (!dev) return;
        try {
            if (dev.disconnect) dev.disconnect();
        } catch (e) {
            console.log("dev.disconnect error:", e);
        }
        if (dev.address) {
            btProc.command = ["bluetoothctl", "disconnect", dev.address];
            btProc.running = true;
        }
    }

    function connectDevice(dev) {
        if (!dev) return;

        // Запуск анімації гравітаційного притягання до ядра
        root.fusingDevice = dev;
        root.isFusing = true;
        fuseTimer.start();

        try {
            if (!dev.paired && dev.pair) {
                dev.pair();
            } else if (dev.connect) {
                dev.connect();
            }
        } catch (e) {
            console.log("dev.connect error:", e);
        }
        if (dev.address) {
            btProc.command = ["bluetoothctl", "connect", dev.address];
            btProc.running = true;
        }
    }

    Timer {
        id: fuseTimer
        interval: 800
        onTriggered: {
            root.isFusing = false;
            root.fusingDevice = null;
        }
    }

    onVisibleChanged: {
        if (!visible) {
            if (adapter && adapter.discovering) adapter.discovering = false;
            selectedDevice = null;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }

    // Орбітальний час (плавний безперервний дрейф планет)
    property real orbitAngle: 0
    NumberAnimation on orbitAngle {
        from: 0
        to: 360
        duration: 48000
        loops: Animation.Infinite
        running: root.visible && root.viewMode === "orbit"
    }

    function getDeviceIcon(dev) {
        var name = String(dev.name || "").toLowerCase();
        var icon = String(dev.icon || "").toLowerCase();

        if (name.includes("airpod") || name.includes("bud") || name.includes("head") || name.includes("freebuds") || name.includes("live") || icon.includes("headset") || icon.includes("audio-headset"))
            return "󰋋";
        if (name.includes("key") || icon.includes("keyboard") || icon.includes("input-keyboard"))
            return "󰌒";
        if (name.includes("mouse") || name.includes("superlight") || icon.includes("mouse") || icon.includes("input-mouse"))
            return "󰍽";
        if (name.includes("xbox") || name.includes("dual") || name.includes("controller") || name.includes("gamepad") || icon.includes("gamepad"))
            return "󰊴";
        if (name.includes("charge") || name.includes("speaker") || name.includes("jbl") || icon.includes("speaker") || icon.includes("audio-card"))
            return "󰓆";
        if (icon.includes("phone") || name.includes("iphone") || name.includes("pixel") || name.includes("samsung"))
            return "󰄜";

        return "󰂯";
    }

    function getDeviceCategory(dev) {
        var name = String(dev.name || "").toLowerCase();
        var icon = String(dev.icon || "").toLowerCase();

        if (name.includes("airpod") || name.includes("bud") || name.includes("head") || name.includes("freebuds") || name.includes("live") || name.includes("charge") || name.includes("speaker") || name.includes("jbl") || icon.includes("audio") || icon.includes("headset"))
            return "Аудіо";
        if (name.includes("key") || icon.includes("keyboard"))
            return "Клавіатура";
        if (name.includes("mouse") || name.includes("superlight") || icon.includes("mouse"))
            return "Миша";
        if (name.includes("xbox") || name.includes("dual") || name.includes("controller") || name.includes("gamepad"))
            return "Геймпад";
        if (icon.includes("phone"))
            return "Телефон";

        return "Пристрій";
    }

    // Космічний Switch
    component CosmicSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()

        implicitWidth: 44
        implicitHeight: 24
        radius: 12
        color: checked ? "#8b5cf6" : "#242538"
        border.color: checked ? "#a855f7" : "#3b3d56"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Rectangle {
            id: knob
            x: sw.checked ? sw.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: "#ffffff"

            Behavior on x {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    // Головний контейнер вікна
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        radius: 20

        color: Qt.rgba(Theme._mochaBg.r, Theme._mochaBg.g, Theme._mochaBg.b, 0.94)
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.09)
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        transform: Translate {
            y: root.visible ? 0 : -10
            Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.15 } }

        // Мерехтливі зірки на фоні
        Repeater {
            model: [
                { x: 40, y: 80, s: 2, d: 2400 },
                { x: 120, y: 220, s: 1.5, d: 3100 },
                { x: 460, y: 140, s: 2, d: 2800 },
                { x: 500, y: 380, s: 2.5, d: 2000 },
                { x: 80, y: 460, s: 1.5, d: 3500 },
                { x: 420, y: 520, s: 2, d: 2600 }
            ]
            delegate: Rectangle {
                x: modelData.x
                y: modelData.y
                width: modelData.s
                height: modelData.s
                radius: modelData.s / 2
                color: "#ffffff"

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: modelData.d }
                    NumberAnimation { to: 0.8; duration: modelData.d }
                }
            }
        }

        // Фонове сяйво туманності
        Rectangle {
            width: 320
            height: 320
            radius: 160
            anchors.centerIn: parent
            color: Qt.rgba(0.55, 0.35, 0.96, 0.08)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ================= 1. ШАПКА =================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    id: backBtn
                    implicitWidth: 32
                    implicitHeight: 32
                    contentItem: Text {
                        text: "‹"
                        color: "#f8fafc"
                        font.pixelSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 16
                        color: backBtn.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        scale: backBtn.pressed ? 0.92 : (backBtn.hovered ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }
                    onClicked: root.visible = false
                }

                Text {
                    text: "Bluetooth Solar System"
                    color: "#f8fafc"
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Перемикач режимів [🪐 Орбіти] / [📋 Список]
                Rectangle {
                    implicitWidth: 160
                    implicitHeight: 28
                    radius: 14
                    color: Qt.rgba(0.12, 0.14, 0.22, 0.80)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: root.viewMode === "orbit" ? "#8b5cf6" : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text: "🪐 Орбіти"
                                color: root.viewMode === "orbit" ? "#ffffff" : Theme.btTextMuted
                                font.bold: true
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.viewMode = "orbit"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: root.viewMode === "list" ? "#8b5cf6" : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text: "📋 Список"
                                color: root.viewMode === "list" ? "#ffffff" : "#94a3b8"
                                font.bold: true
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.viewMode = "list"
                            }
                        }
                    }
                }

                CosmicSwitch {
                    checked: root.isBtOn
                    onToggled: {
                        if (root.adapter)
                            root.adapter.enabled = !root.adapter.enabled;
                    }
                }
            }

            // ================= 2. ОСНОВНА ОБЛАСТЬ =================

            // -------- РЕЖИМ 1: ПЛАНЕТАРНА ОРБІТАЛЬНА СИСТЕМА --------
            Item {
                id: orbitViewport
                visible: root.viewMode === "orbit"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Кільця орбіт
                Rectangle {
                    anchors.centerIn: parent
                    width: 250
                    height: 250
                    radius: 125
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 370
                    height: 370
                    radius: 185
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                }

                // ================= ЦЕНТРАЛЬНА ПЛАНЕТА (Connected Core) =================
                Item {
                    id: homePlanet
                    anchors.centerIn: parent
                    width: 104
                    height: 104

                    // Ореол свічення
                    Rectangle {
                        anchors.centerIn: parent
                        width: 140
                        height: 140
                        radius: 70
                        color: root.connectedDevice ? Qt.rgba(0.55, 0.35, 0.96, 0.18) : Qt.rgba(0.22, 0.74, 0.97, 0.10)

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.15; duration: 2000; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Сама сфера планети
                    Rectangle {
                        id: planetSphere
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: root.connectedDevice ? "#3b82f6" : "#1e293b"
                            }
                            GradientStop {
                                position: 1.0
                                color: root.connectedDevice ? "#8b5cf6" : "#334155"
                            }
                        }
                        border.color: root.connectedDevice ? "#c084fc" : "#475569"
                        border.width: 2

                        scale: homeMa.pressed ? 0.95 : (homeMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.connectedDevice ? root.getDeviceIcon(root.connectedDevice) : "󰣇"
                                color: "#ffffff"
                                font.family: Theme.fontMono
                                font.pixelSize: 30
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.connectedDevice ? "CONNECTED" : "STANDBY"
                                color: root.connectedDevice ? "#4ade80" : "#94a3b8"
                                font.bold: true
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                        }

                        MouseArea {
                            id: homeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.connectedDevice)
                                    root.selectedDevice = root.connectedDevice;
                            }
                        }
                    }

                    // Підпис під центральною планетою
                    Rectangle {
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: nameRow.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(0.10, 0.12, 0.20, 0.85)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1

                        RowLayout {
                            id: nameRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.connectedDevice ? root.connectedDevice.name : "ПК (Готовий до зв'язку)"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 11
                            }

                            Text {
                                visible: root.connectedDevice && root.connectedDevice.batteryAvailable
                                text: "󰂂 " + Math.round((root.connectedDevice ? root.connectedDevice.battery : 0) * 100) + "%"
                                color: "#4ade80"
                                font.bold: true
                                font.pixelSize: 10
                                font.family: Theme.fontMono
                            }
                        }
                    }
                }

                // ================= ПЛАНЕТИ-СПУТНИКИ (Доступні пристрої) =================
                Repeater {
                    model: (root.adapter && root.adapter.devices) ? root.adapter.devices : []

                    delegate: Item {
                        id: satellite
                        required property var modelData
                        required property int index

                        // Показуємо тільки доступні (не підключені) пристрої
                        visible: !modelData.connected

                        // Орбітальні розрахунки для дрейфу по еліпсу
                        property real orbitRadius: (index % 2 === 0) ? 125 : 185
                        property real baseAngleDeg: (index * 72)
                        property real curAngleRad: ((baseAngleDeg + (index % 2 === 0 ? 1 : -0.7) * root.orbitAngle) * Math.PI) / 180

                        // Плавне покачування
                        property real drift: Math.sin(root.orbitAngle * 0.1 + index) * 6
                        property real effectiveRadius: (root.isFusing && root.fusingDevice === modelData) ? 0 : (orbitRadius + drift)

                        Behavior on effectiveRadius {
                            NumberAnimation { duration: 600; easing.type: Easing.InBack }
                        }

                        x: (orbitViewport.width / 2) + Math.cos(curAngleRad) * effectiveRadius - width / 2
                        y: (orbitViewport.height / 2) + Math.sin(curAngleRad) * effectiveRadius - height / 2

                        width: 50
                        height: 50

                        // Сфера супутника
                        Rectangle {
                            id: satSphere
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: 22

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: (index % 2 === 0) ? "#06b6d4" : "#a855f7" }
                                GradientStop { position: 1.0; color: (index % 2 === 0) ? "#3b82f6" : "#ec4899" }
                            }

                            border.color: (root.selectedDevice === modelData || satMa.containsMouse) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25)
                            border.width: (root.selectedDevice === modelData || satMa.containsMouse) ? 2 : 1

                            scale: satMa.pressed ? 0.90 : (satMa.containsMouse ? 1.25 : (root.selectedDevice === modelData ? 1.15 : 1.0))
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                            Text {
                                anchors.centerIn: parent
                                text: root.getDeviceIcon(modelData)
                                color: "#ffffff"
                                font.family: Theme.fontMono
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: satMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedDevice = modelData
                            }
                        }

                        // Текстовий бейдж під планетою
                        Rectangle {
                            anchors.top: satSphere.bottom
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitWidth: badgeText.implicitWidth + 12
                            implicitHeight: 18
                            radius: 9
                            color: Qt.rgba(0.08, 0.09, 0.15, 0.85)
                            border.color: (root.selectedDevice === modelData) ? "#c084fc" : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: (modelData.name || "Пристрій")
                                color: (root.selectedDevice === modelData) ? "#c084fc" : "#e2e8f0"
                                font.pixelSize: 10
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }
            }

            // -------- РЕЖИМ 2: КЛАСИЧНИЙ СПИСОК --------
            ScrollView {
                visible: root.viewMode === "list"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                Column {
                    width: parent.width
                    spacing: 12

                    // ПІДКЛЮЧЕНІ
                    Text {
                        text: "Підключені пристрої"
                        color: "#f8fafc"
                        font.bold: true
                        font.pixelSize: 13
                    }

                    Rectangle {
                        width: parent.width
                        radius: 14
                        color: Qt.rgba(0.09, 0.10, 0.17, 0.85)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        implicitHeight: Math.max(50, listConnCol.implicitHeight + 8)

                        Column {
                            id: listConnCol
                            width: parent.width
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: (root.adapter && root.adapter.devices) ? root.adapter.devices : []

                                delegate: Item {
                                    required property var modelData
                                    visible: modelData.connected
                                    width: parent.width
                                    height: modelData.connected ? 60 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Rectangle {
                                            implicitWidth: 38
                                            implicitHeight: 38
                                            radius: 19
                                            color: Qt.rgba(139, 92, 246, 0.15)
                                            border.color: "#c084fc"
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getDeviceIcon(modelData)
                                                color: "#c084fc"
                                                font.family: Theme.fontMono
                                                font.pixelSize: 18
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: modelData.name || "Bluetooth-пристрій"
                                                color: "#ffffff"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                text: "● Підключено"
                                                color: "#4ade80"
                                                font.pixelSize: 10
                                            }
                                        }

                                        Button {
                                            implicitWidth: 100
                                            implicitHeight: 32
                                            contentItem: Text {
                                                text: "Відключити"
                                                color: "#f43f5e"
                                                font.bold: true
                                                font.pixelSize: 11
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                radius: 8
                                                color: Qt.rgba(0.95, 0.25, 0.35, 0.15)
                                                border.color: "#f43f5e"
                                                border.width: 1
                                            }
                                            onClicked: root.disconnectDevice(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ДОСТУПНІ
                    Text {
                        text: "Доступні пристрої"
                        color: "#f8fafc"
                        font.bold: true
                        font.pixelSize: 13
                    }

                    Rectangle {
                        width: parent.width
                        radius: 14
                        color: Qt.rgba(0.09, 0.10, 0.17, 0.85)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        implicitHeight: Math.max(50, listAvailCol.implicitHeight + 8)

                        Column {
                            id: listAvailCol
                            width: parent.width
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: (root.adapter && root.adapter.devices) ? root.adapter.devices : []

                                delegate: Item {
                                    required property var modelData
                                    visible: !modelData.connected
                                    width: parent.width
                                    height: !modelData.connected ? 56 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Rectangle {
                                            implicitWidth: 36
                                            implicitHeight: 36
                                            radius: 18
                                            color: Qt.rgba(56, 189, 248, 0.12)
                                            border.color: "#38bdf8"
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getDeviceIcon(modelData)
                                                color: "#38bdf8"
                                                font.family: Theme.fontMono
                                                font.pixelSize: 17
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: modelData.name || "Пристрій"
                                                color: "#ffffff"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                text: "Доступний"
                                                color: "#94a3b8"
                                                font.pixelSize: 10
                                            }
                                        }

                                        Button {
                                            implicitWidth: 100
                                            implicitHeight: 32
                                            contentItem: Text {
                                                text: "Підключити"
                                                color: "#e2e8f0"
                                                font.bold: true
                                                font.pixelSize: 11
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                radius: 8
                                                color: Qt.rgba(0.20, 0.22, 0.36, 0.90)
                                                border.color: "#a855f7"
                                                border.width: 1
                                            }
                                            onClicked: root.connectDevice(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= 3. ПАНЕЛЬ ДІЙ / КАРТКА ОБРАНОГО ДЕВАЙСА =================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 68
                radius: 16
                color: Qt.rgba(0.10, 0.12, 0.20, 0.88)
                border.color: root.selectedDevice ? "#8b5cf6" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 200 } }

                // КОЛИ ВИБРАНА ПЛАНЕТА
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    visible: root.selectedDevice !== null

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: (root.selectedDevice && root.selectedDevice.connected) ? "#3b82f6" : "#a855f7" }
                            GradientStop { position: 1.0; color: (root.selectedDevice && root.selectedDevice.connected) ? "#8b5cf6" : "#ec4899" }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.selectedDevice ? root.getDeviceIcon(root.selectedDevice) : "󰂯"
                            color: "#ffffff"
                            font.family: Theme.fontMono
                            font.pixelSize: 22
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.selectedDevice ? root.selectedDevice.name : ""
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 6

                            Text {
                                text: root.selectedDevice && root.selectedDevice.connected
                                    ? "● Підключено · " + root.getDeviceCategory(root.selectedDevice)
                                    : "Доступний для з'єднання"
                                color: root.selectedDevice && root.selectedDevice.connected ? "#4ade80" : "#94a3b8"
                                font.pixelSize: 11
                            }

                            Text {
                                visible: root.selectedDevice && root.selectedDevice.batteryAvailable
                                text: "· 󰂂 " + Math.round((root.selectedDevice ? root.selectedDevice.battery : 0) * 100) + "%"
                                color: "#4ade80"
                                font.bold: true
                                font.pixelSize: 11
                                font.family: Theme.fontMono
                            }
                        }
                    }

                    // Кнопка дії
                    Button {
                        id: actionBtn
                        implicitWidth: 114
                        implicitHeight: 36

                        property bool isDevConn: root.selectedDevice && root.selectedDevice.connected

                        contentItem: RowLayout {
                            spacing: 5
                            anchors.centerIn: parent
                            Text {
                                text: actionBtn.isDevConn ? "—" : "󰂯"
                                color: actionBtn.isDevConn ? "#ffffff" : "#ffffff"
                                font.bold: true
                                font.pixelSize: 14
                            }
                            Text {
                                text: actionBtn.isDevConn ? "Відключити" : "Підключити"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }

                        background: Rectangle {
                            radius: 10
                            color: actionBtn.isDevConn
                                ? (actionBtn.hovered ? "#e11d48" : Qt.rgba(0.95, 0.25, 0.35, 0.85))
                                : (actionBtn.hovered ? "#8b5cf6" : "#6366f1")
                            border.color: actionBtn.isDevConn ? "#f43f5e" : "#a855f7"
                            border.width: 1

                            scale: actionBtn.pressed ? 0.94 : (actionBtn.hovered ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        onClicked: {
                            if (actionBtn.isDevConn)
                                root.disconnectDevice(root.selectedDevice);
                            else
                                root.connectDevice(root.selectedDevice);
                        }
                    }

                    // Закрити картку
                    Button {
                        implicitWidth: 28
                        implicitHeight: 28
                        contentItem: Text {
                            text: "✕"
                            color: "#94a3b8"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 14
                            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        }
                        onClicked: root.selectedDevice = null
                    }
                }

                // КОЛИ ПЛАНЕТА НЕ ВИБРАНА (ДОК СКАНУВАННЯ)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    visible: root.selectedDevice === null

                    Button {
                        id: scanDockBtn
                        implicitWidth: 150
                        implicitHeight: 38

                        contentItem: RowLayout {
                            spacing: 6
                            anchors.centerIn: parent

                            Text {
                                text: "󰑐"
                                color: "#c084fc"
                                font.family: Theme.fontMono
                                font.pixelSize: 16

                                RotationAnimation on rotation {
                                    running: root.isDiscovering
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }

                            Text {
                                text: root.isDiscovering ? "Сканування..." : "Scan for devices"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }

                        background: Rectangle {
                            radius: 10
                            color: scanDockBtn.hovered ? Qt.rgba(0.55, 0.35, 0.96, 0.35) : Qt.rgba(0.20, 0.22, 0.36, 0.85)
                            border.color: scanDockBtn.hovered ? "#8b5cf6" : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            scale: scanDockBtn.pressed ? 0.94 : (scanDockBtn.hovered ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }
                        }

                        onClicked: {
                            if (root.adapter)
                                root.adapter.discovering = !root.adapter.discovering;
                        }
                    }

                    Text {
                        text: root.isDiscovering
                            ? "Пошук нових планет-пристроїв..."
                            : "Клікніть на планету для керування"
                        color: "#94a3b8"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 6
                        Text {
                            text: "Виявлення"
                            color: "#94a3b8"
                            font.pixelSize: 11
                        }
                        CosmicSwitch {
                            checked: root.isDiscoverable
                            onToggled: {
                                if (root.adapter)
                                    root.adapter.discoverable = !root.adapter.discoverable;
                            }
                        }
                    }
                }
            }
        }
    }
}
