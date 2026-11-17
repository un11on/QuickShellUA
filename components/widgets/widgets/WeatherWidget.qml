import QtQuick
import QtQuick.Layouts
import ".."
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    property string subscriptionKey: ""
    signal settingChanged(string key, var value)

    readonly property bool configured: {
        if ((settings.locationMode || "city") === "coordinates")
            return WeatherService.validCoordinates(settings.latitude, settings.longitude)
        return String(settings.city || "").trim().length > 0
    }
    readonly property string desiredKey: configured ? WeatherService.makeKey(settings || {}) : ""
    readonly property var weather: WeatherService.dataFor(subscriptionKey)
    readonly property string degreeUnit: settings.temperatureUnit === "fahrenheit" ? "°F" : "°C"

    function resubscribe() {
        if (root.previewMode)
            return
        if (root.subscriptionKey)
            WeatherService.unsubscribe(root.subscriptionKey)
        root.subscriptionKey = root.desiredKey
        if (root.subscriptionKey)
            WeatherService.subscribe(root.subscriptionKey, root.settings || {})
    }

    function description(code) {
        if (code === 0) return "Ясно"
        if (code === 1 || code === 2) return "Мінлива хмарність"
        if (code === 3) return "Хмарно"
        if (code === 45 || code === 48) return "Туман"
        if (code >= 51 && code <= 67) return "Дощ"
        if (code >= 71 && code <= 77) return "Сніг"
        if (code >= 80 && code <= 82) return "Злива"
        if (code >= 95) return "Гроза"
        return "Невідомо"
    }

    function glyph(code) {
        if (code === 0) return "󰖙"
        if (code <= 3) return "󰖕"
        if (code === 45 || code === 48) return "󰖑"
        if (code >= 71 && code <= 77) return "󰖘"
        if (code >= 95) return "󰖓"
        return "󰖗"
    }

    onDesiredKeyChanged: Qt.callLater(root.resubscribe)
    Component.onCompleted: root.resubscribe()
    Component.onDestruction: if (root.subscriptionKey) WeatherService.unsubscribe(root.subscriptionKey)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.weather ? root.glyph(root.weather.weatherCode) : "󰖐"
                color: Theme.accentSapphire
                font.family: Theme.fontMono
                font.pixelSize: Math.max(30, Math.min(58, root.height * 0.28))
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.weather && root.weather.city ? root.weather.city
                          : (root.configured ? (root.settings.city || "Погода") : "Погода не налаштована")
                    color: Theme.text
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    text: root.weather && !root.weather.loading && !root.weather.error
                          ? root.description(root.weather.weatherCode) : ""
                    color: Theme.textSub
                    font.pixelSize: 12
                }
            }
            WidgetButton {
                text: "↻"
                implicitWidth: 34
                leftPadding: 0
                rightPadding: 0
                enabled: root.configured && root.weather && !root.weather.loading
                onClicked: if (root.subscriptionKey) WeatherService.request(root.subscriptionKey)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.configured && root.weather && !root.weather.loading && !root.weather.error
            text: Math.round(root.weather ? root.weather.temperature : 0) + root.degreeUnit
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Math.max(30, Math.min(56, root.height * 0.3))
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            visible: !root.configured
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: "Оберіть місто у налаштуваннях віджета"
                color: Theme.textMuted
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ColumnLayout {
            visible: root.configured && (!root.weather || root.weather.loading)
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰔟"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 20
                RotationAnimation on rotation {
                    running: parent.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Оновлення погоди…"
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ColumnLayout {
            visible: root.configured && root.weather && !!root.weather.error && !root.weather.loading
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: root.weather ? root.weather.error : "Погода недоступна"
                color: Theme.accentRed
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            WidgetButton {
                Layout.alignment: Qt.AlignHCenter
                text: "Повторити"
                onClicked: if (root.subscriptionKey) WeatherService.request(root.subscriptionKey)
            }
        }
    }
}
