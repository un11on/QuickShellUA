import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

PopupWindow {
    id: root

    implicitWidth: 820
    implicitHeight: 470
    visible: false
    grabFocus: true
    color: "transparent"

    // Змініть на своє місто
    property string city: "Nadvirna"

    // ---------- Звук ----------
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    property real vol: sink && sink.audio ? sink.audio.volume : 0.0
    property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false
    property bool micMuted: source && source.audio ? source.audio.muted : false

    PwObjectTracker { objects: [root.sink, root.source] }

    // ---------- Wi-Fi (через nmcli) ----------
    property bool wifiOn: false

    Process {
        id: wifiGet
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }
    Process { id: wifiSet }

    function toggleWifi() {
        wifiSet.command = ["nmcli", "radio", "wifi", wifiOn ? "off" : "on"]
        wifiSet.running = true
        wifiOn = !wifiOn
    }

    onVisibleChanged: {
        if (visible) {
            wifiGet.running = true
            calYear = new Date().getFullYear()
            calMonth = new Date().getMonth()
        }
    }

    // ---------- Навантаження ----------
    property real cpuUsage: 0
    property real ramUsage: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real prevIdle: 0
    property real prevTotal: 0

    function parseStats(text) {
        var lines = text.split("\n")
        var memTotal = 0, memAvail = 0

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (l.startsWith("cpu ")) {
                var p = l.trim().split(/\s+/).slice(1, 9).map(Number)
                var idle = p[3] + p[4]
                var total = p.reduce(function(a, b) { return a + b }, 0)
                var dTotal = total - prevTotal
                var dIdle = idle - prevIdle
                if (prevTotal > 0 && dTotal > 0)
                    cpuUsage = 1 - dIdle / dTotal
                prevTotal = total
                prevIdle = idle
            } else if (l.startsWith("MemTotal:")) {
                memTotal = parseInt(l.split(/\s+/)[1])
            } else if (l.startsWith("MemAvailable:")) {
                memAvail = parseInt(l.split(/\s+/)[1])
            }
        }

        if (memTotal > 0) {
            ramTotalGb = memTotal / 1048576
            ramUsedGb = (memTotal - memAvail) / 1048576
            ramUsage = (memTotal - memAvail) / memTotal
        }
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // ---------- Погода (wttr.in) ----------
    property string weatherTemp: "--"
    property string weatherDesc: "Завантаження..."
    property string weatherFeels: ""

    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "8",
                  "wttr.in/" + root.city + "?format=%t|%C|%f&lang=uk"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|")
                if (p.length >= 3) {
                    root.weatherTemp = p[0]
                    root.weatherDesc = p[1]
                    root.weatherFeels = "відчувається " + p[2]
                } else {
                    root.weatherDesc = "Немає даних"
                }
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // ---------- Медіа (MPRIS) ----------
    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    Timer {
        interval: 1000
        running: root.visible && root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // ---------- Календар ----------
    property int calMonth: new Date().getMonth()
    property int calYear: new Date().getFullYear()

    function shiftMonth(d) {
        var m = calMonth + d
        if (m < 0) { m = 11; calYear-- }
        else if (m > 11) { m = 0; calYear++ }
        calMonth = m
    }

    // ---------- Сповіщення ----------
    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        onNotification: (n) => { n.tracked = true }
    }

    function clearNotifications() {
        var list = notifServer.trackedNotifications.values.slice()
        for (var i = 0; i < list.length; i++)
            list[i].dismiss()
    }

    // ================= ІНТЕРФЕЙС =================
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#181825"
        border.color: "#45475a"
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ---------- ЛІВА КОЛОНКА ----------
            ColumnLayout {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                spacing: 8

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    ToggleTile {
                        icon: "󰖩"
                        title: "Wi-Fi"
                        subtitle: root.wifiOn ? "Увімкнено" : "Вимкнено"
                        active: root.wifiOn
                        onClicked: root.toggleWifi()
                    }
                    ToggleTile {
                        icon: "󰂯"
                        title: "Bluetooth"
                        subtitle: Bluetooth.defaultAdapter?.enabled ? "Увімкнено" : "Вимкнено"
                        active: Bluetooth.defaultAdapter?.enabled ?? false
                        onClicked: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }
                    ToggleTile {
                        icon: root.micMuted ? "󰍭" : "󰍬"
                        title: "Мікрофон"
                        subtitle: root.micMuted ? "Вимкнено" : "Активний"
                        active: !root.micMuted
                        onClicked: {
                            if (root.source && root.source.audio)
                                root.source.audio.muted = !root.source.audio.muted
                        }
                    }
                    ToggleTile {
                        icon: root.sinkMuted ? "󰖁" : "󰕾"
                        title: "Звук"
                        subtitle: root.sinkMuted ? "Вимкнено" : "Увімкнено"
                        active: !root.sinkMuted
                        onClicked: {
                            if (root.sink && root.sink.audio)
                                root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }
                }

                // Гучність
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: root.sinkMuted ? "󰖁" : (root.vol > 0.5 ? "󰕾" : (root.vol > 0 ? "󰖀" : "󰕿"))
                            color: root.sinkMuted ? "#f38ba8" : "#89b4fa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                        }

                        Slider {
                            id: volSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 1.0

                            Binding {
                                target: volSlider
                                property: "value"
                                value: root.vol
                                when: !volSlider.pressed
                            }

                            onMoved: {
                                if (root.sink && root.sink.audio)
                                    root.sink.audio.volume = value
                            }

                            background: Rectangle {
                                x: volSlider.leftPadding
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                width: volSlider.availableWidth
                                height: 6
                                radius: 3
                                color: "#313244"

                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: "#89b4fa"
                                }
                            }

                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: volSlider.pressed ? "#b4befe" : "#cdd6f4"
                                border.color: "#89b4fa"
                                border.width: 2
                            }
                        }

                        Text {
                            text: Math.round(root.vol * 100) + "%"
                            color: "#a6adc8"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Навантаження
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "НАВАНТАЖЕННЯ"
                            color: "#a6adc8"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        StatRow {
                            label: "CPU"
                            valueText: Math.round(root.cpuUsage * 100) + "%"
                            fraction: root.cpuUsage
                            barColor: root.cpuUsage > 0.85 ? "#f38ba8" : (root.cpuUsage > 0.6 ? "#f9e2af" : "#a6e3a1")
                        }

                        StatRow {
                            label: "RAM"
                            valueText: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                            fraction: root.ramUsage
                            barColor: root.ramUsage > 0.85 ? "#f38ba8" : (root.ramUsage > 0.6 ? "#f9e2af" : "#89b4fa")
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ---------- СЕРЕДНЯ КОЛОНКА ----------
            ColumnLayout {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                spacing: 8

                // Медіаплеєр
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: 10
                                color: "#313244"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.player ? root.player.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source !== ""
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: root.player && root.player.trackTitle ? root.player.trackTitle : "Нічого не грає"
                                    color: "#cdd6f4"
                                    font.bold: true
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: root.player ? (root.player.trackArtist || "") : ""
                                    color: "#a6adc8"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: "#313244"

                            Rectangle {
                                width: parent.width * (root.player && root.player.length > 0
                                       ? Math.min(1, root.player.position / root.player.length) : 0)
                                height: parent.height
                                radius: 2
                                color: "#89b4fa"
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Text {
                                text: "󰒮"
                                color: prevMa.containsMouse ? "#89b4fa" : "#cdd6f4"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                MouseArea {
                                    id: prevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.previous()
                                }
                            }
                            Text {
                                text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                                color: playMa.containsMouse ? "#89b4fa" : "#cdd6f4"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 24
                                MouseArea {
                                    id: playMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.togglePlaying()
                                }
                            }
                            Text {
                                text: "󰒭"
                                color: nextMa.containsMouse ? "#89b4fa" : "#cdd6f4"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                MouseArea {
                                    id: nextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.next()
                                }
                            }
                        }
                    }
                }

                // Погода
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: root.weatherTemp
                            color: "#cdd6f4"
                            font.pixelSize: 30
                            font.bold: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.weatherDesc
                                color: "#cdd6f4"
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.weatherFeels
                                color: "#a6adc8"
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.city
                                color: "#6c7086"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // Календар
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: Qt.locale("uk_UA").standaloneMonthName(root.calMonth) + " " + root.calYear
                                color: "#cdd6f4"
                                font.bold: true
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "‹"
                                color: "#89b4fa"
                                font.pixelSize: 20
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.shiftMonth(-1)
                                }
                            }
                            Text {
                                text: "›"
                                color: "#89b4fa"
                                font.pixelSize: 20
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.shiftMonth(1)
                                }
                            }
                        }

                        DayOfWeekRow {
                            Layout.fillWidth: true
                            locale: grid.locale
                            delegate: Text {
                                required property var model
                                text: model.shortName
                                color: "#6c7086"
                                font.pixelSize: 10
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MonthGrid {
                            id: grid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            month: root.calMonth
                            year: root.calYear
                            locale: Qt.locale("uk_UA")

                            delegate: Rectangle {
                                required property var model
                                implicitWidth: 28
                                implicitHeight: 22
                                radius: 6
                                color: model.today ? "#89b4fa" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    font.pixelSize: 11
                                    font.bold: model.today
                                    color: model.today ? "#1e1e2e"
                                         : (model.month === grid.month ? "#cdd6f4" : "#45475a")
                                }
                            }
                        }
                    }
                }
            }

            // ---------- ПРАВА КОЛОНКА: СПОВІЩЕННЯ ----------
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Сповіщення"
                            color: "#cdd6f4"
                            font.bold: true
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Очистити"
                            color: clearMa.containsMouse ? "#b4befe" : "#89b4fa"
                            font.pixelSize: 11
                            font.bold: true
                            visible: notifServer.trackedNotifications.values.length > 0
                            MouseArea {
                                id: clearMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearNotifications()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: "Нічого нового"
                            color: "#6c7086"
                            font.pixelSize: 12
                            visible: notifServer.trackedNotifications.values.length === 0
                        }

                        ListView {
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            model: notifServer.trackedNotifications

                            delegate: Rectangle {
                                required property var modelData

                                width: ListView.view.width
                                height: notifCol.implicitHeight + 20
                                radius: 10
                                color: "#313244"

                                ColumnLayout {
                                    id: notifCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: modelData.appName
                                            color: "#89b4fa"
                                            font.pixelSize: 10
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: "✕"
                                            color: "#a6adc8"
                                            font.pixelSize: 11
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.dismiss()
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.summary
                                        color: "#cdd6f4"
                                        font.bold: true
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.body
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}