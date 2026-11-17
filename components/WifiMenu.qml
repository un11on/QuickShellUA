import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

// ============================================================================
// WifiMenu — випадаюче меню Wi-Fi для верхньої панелі.
//
// • Індикатор у барі показує стан радіо та силу сигналу активної мережі.
// • Список мереж: сигнал, безпека, «збережена», активна.
// • Клік по мережі: відкрита/збережена — підключення одразу;
//   захищена й невідома — поле пароля. Активна мережа — відключення.
// • Дані та керування — через nmcli (Quickshell.Networking у цій збірці
//   недоступний: quickshell-networkplugin не входить у пакет).
// ============================================================================
PopupWindow {
    id: root

    implicitWidth: 380
    implicitHeight: panelCol.implicitHeight + 24

    visible: false
    grabFocus: true
    color: "transparent"

    // ---------- Стан ----------
    property bool wifiOn: false
    property bool scanning: false
    property bool connecting: false
    property string connectingSsid: ""

    // [{ ssid, signal, security, open, inUse, known }]
    property var networks: []
    property var savedNames: []

    property string connectedSsid: ""
    property int connectedSignal: 0
    readonly property bool connected: connectedSsid.length > 0

    property string errorText: ""

    // Очікувана мережа для введення пароля
    property var pendingNetwork: null
    property bool passwordMode: false
    property string password: ""

    // Іконка для індикатора в барі
    readonly property string barIcon: wifiOn ? "󰖩" : "󰤮"

    // ---------- Процеси ----------
    Process {
        id: radioGet
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }

    Process {
        id: radioSet
        onExited: root.refreshAll(false)
    }

    Process {
        id: listGet
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                  "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: root.applyList(text)
        }
        onExited: root.scanning = false
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: rescanDelay.restart()
    }

    Process {
        id: savedGet
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    var idx = line.lastIndexOf(":")
                    if (idx < 0)
                        continue
                    var type = line.slice(idx + 1).trim()
                    if (type !== "802-11-wireless")
                        continue
                    var name = line.slice(0, idx).replace(/\\:/g, ":").trim()
                    if (name.length > 0)
                        out.push(name)
                }
                root.savedNames = out
                root.rebuildKnown()
            }
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector { id: connectOut }
        stderr: StdioCollector { id: connectErr }
        onExited: function(code) {
            root.connecting = false
            root.connectingSsid = ""
            if (code === 0) {
                root.passwordMode = false
                root.pendingNetwork = null
                root.password = ""
                root.errorText = ""
                root.refreshAll(false)
                return
            }
            var err = connectErr.text.trim()
            if (err.length === 0)
                err = connectOut.text.trim()
            if (/secrets were required|no secrets/i.test(err)) {
                if (root.pendingNetwork) {
                    root.passwordMode = true
                    root.errorText = "Введіть пароль для «" + root.pendingNetwork.ssid + "»"
                } else {
                    root.errorText = "Не вдалося підключитися"
                }
            } else {
                var last = err.length > 0 ? err.split("\n").pop() : ""
                root.errorText = last.length > 0 ? last : "Не вдалося підключитися"
                root.passwordMode = false
            }
        }
    }

    Process {
        id: disconnectProc
        onExited: root.refreshAll(false)
    }

    Timer {
        id: rescanDelay
        interval: 1200
        repeat: false
        onTriggered: listGet.running = true
    }

    // Періодичне оновлення індикатора в барі (навіть коли меню закрите).
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            radioGet.running = true
            listGet.running = true
        }
    }

    // ---------- Логіка ----------
    function refreshAll(rescan) {
        radioGet.running = true
        savedGet.running = true
        if (rescan) {
            scanning = true
            rescanProc.running = true
        } else {
            listGet.running = true
        }
    }

    function applyList(text) {
        var lines = text.split("\n")
        var map = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.length === 0)
                continue
            var parts = line.split(":")
            if (parts.length < 4)
                continue

            var inUse = parts[0].indexOf("*") !== -1
            var signal = parseInt(parts[parts.length - 2], 10)
            var security = parts[parts.length - 1].trim()
            var ssid = parts.slice(1, parts.length - 2).join(":").replace(/\\:/g, ":")
            if (ssid.length === 0)
                continue

            var entry = {
                ssid: ssid,
                signal: isNaN(signal) ? 0 : signal,
                security: security,
                open: security.length === 0 || security === "--",
                inUse: inUse,
                known: root.savedNames.indexOf(ssid) !== -1
            }

            if (!map[ssid] || entry.inUse || (!map[ssid].inUse && entry.signal > map[ssid].signal))
                map[ssid] = entry
        }

        var out = []
        for (var key in map)
            out.push(map[key])

        out.sort(function(a, b) {
            if (a.inUse !== b.inUse)
                return a.inUse ? -1 : 1
            return b.signal - a.signal
        })

        root.networks = out

        var found = false
        for (var j = 0; j < out.length; j++) {
            if (out[j].inUse) {
                root.connectedSsid = out[j].ssid
                root.connectedSignal = out[j].signal
                found = true
                break
            }
        }
        if (!found) {
            root.connectedSsid = ""
            root.connectedSignal = 0
        }
    }

    function rebuildKnown() {
        var out = []
        for (var i = 0; i < root.networks.length; i++) {
            var n = root.networks[i]
            out.push({
                ssid: n.ssid,
                signal: n.signal,
                security: n.security,
                open: n.open,
                inUse: n.inUse,
                known: root.savedNames.indexOf(n.ssid) !== -1
            })
        }
        root.networks = out
    }

    function setWifi(on) {
        root.errorText = ""
        root.wifiOn = on
        radioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        radioSet.running = true
    }

    function signalIcon(s) {
        return s >= 75 ? "󰤨"
            : (s >= 50 ? "󰤥"
            : (s >= 25 ? "󰤢"
            : (s >= 10 ? "󰤟" : "󰤯")))
    }

    function netSubtitle(net) {
        if (net.inUse)
            return "Підключено · " + net.signal + "%"
        if (net.open)
            return "Відкрита мережа · " + net.signal + "%"
        if (net.known)
            return "Збережена · " + net.signal + "%"
        return net.security + " · " + net.signal + "%"
    }

    function connectNetwork(net, psk) {
        if (!net)
            return
        root.errorText = ""
        root.connecting = true
        root.connectingSsid = net.ssid
        if (psk && psk.length > 0)
            connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid, "password", psk]
        else
            connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid]
        connectProc.running = true
    }

    function disconnectNetwork(net) {
        if (!net)
            return
        root.errorText = ""
        disconnectProc.command = ["nmcli", "connection", "down", "id", net.ssid]
        disconnectProc.running = true
    }

    function handleNetworkClick(net) {
        if (root.connecting)
            return
        if (net.inUse) {
            disconnectNetwork(net)
            return
        }
        root.errorText = ""
        root.pendingNetwork = net
        root.password = ""
        if (!net.open && !net.known) {
            root.passwordMode = true
            return
        }
        root.passwordMode = false
        connectNetwork(net, "")
    }

    function submitPassword() {
        if (!root.pendingNetwork)
            return
        if (root.password.length === 0) {
            root.errorText = "Пароль не може бути порожнім"
            return
        }
        connectNetwork(root.pendingNetwork, root.password)
    }

    function cancelPassword() {
        root.passwordMode = false
        root.pendingNetwork = null
        root.password = ""
        root.errorText = ""
    }

    // ---------- Відкриття / закриття ----------
    onVisibleChanged: {
        if (visible) {
            root.errorText = ""
            root.passwordMode = false
            root.pendingNetwork = null
            root.password = ""
            root.refreshAll(true)
        } else {
            root.passwordMode = false
            root.pendingNetwork = null
            root.password = ""
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }

    // ---------- Інтерфейс ----------
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

        // Блокуємо клік усередині панелі
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: panelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // ---------- Шапка ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 15
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                // Перемикач радіо
                Rectangle {
                    id: wifiSwitch
                    implicitWidth: 40
                    implicitHeight: 22
                    radius: 11
                    color: root.wifiOn
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                        : Theme.glassCard
                    border.color: root.wifiOn ? Theme.accent : Theme.glassBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        y: 2
                        x: root.wifiOn ? parent.width - width - 2 : 2
                        color: "#ffffff"

                        Behavior on x {
                            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setWifi(!root.wifiOn)
                    }
                }

                // Оновити / сканувати
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: refreshMa.containsMouse ? Theme.glassCardHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.scanning ? "󰑓" : "󰑐"
                        color: refreshMa.containsMouse ? Theme.accent : Theme.textSub
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshAll(true)
                    }
                }

                // Закрити
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
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
                        onClicked: root.visible = false
                    }
                }
            }

            // ---------- Помилка ----------
            Text {
                Layout.fillWidth: true
                visible: root.errorText.length > 0
                text: root.errorText
                color: Theme.accentRed
                font.family: Theme.fontMono
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // ---------- Список мереж ----------
            ListView {
                id: netList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(320, root.networks.length * 54)
                visible: root.networks.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.networks

                delegate: Rectangle {
                    id: netRow
                    required property var modelData

                    width: netList.width
                    height: 52
                    radius: Theme.radiusMd
                    color: modelData.inUse
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                        : (rowMa.containsMouse ? Theme.glassCardHover : "transparent")
                    border.color: modelData.inUse
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                        : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: root.signalIcon(modelData.signal)
                            color: modelData.inUse ? Theme.accent
                                : (modelData.signal >= 50 ? Theme.text : Theme.textMuted)
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                            verticalAlignment: Text.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.connecting && root.connectingSsid === modelData.ssid
                                    ? "Підключення…"
                                    : root.netSubtitle(modelData)
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: !modelData.open
                            text: modelData.inUse ? "󰄬" : "󰌾"
                            color: modelData.inUse ? Theme.accentGreen : Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleNetworkClick(modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.networks.length === 0
                text: root.scanning ? "Сканування…" : "Мереж не знайдено"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                topPadding: 12
                bottomPadding: 12
            }

            // ---------- Пароль ----------
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.passwordMode
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Пароль для «" + (root.pendingNetwork ? root.pendingNetwork.ssid : "") + "»"
                    color: Theme.textSub
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSm
                    color: Theme.glassCard
                    border.color: pwdInput.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder
                    border.width: 1

                    TextInput {
                        id: pwdInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        selectByMouse: true
                        clip: true
                        focus: root.passwordMode
                        onTextChanged: root.password = text
                        onAccepted: root.submitPassword()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 92
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: cancelMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                        border.color: Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Скасувати"
                            color: Theme.textSub
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelPassword()
                        }
                    }

                    Rectangle {
                        implicitWidth: 100
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Підключити"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitPassword()
                        }
                    }
                }
            }
        }
    }
}
