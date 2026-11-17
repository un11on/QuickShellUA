import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
import ".."

ColumnLayout {
    id: root

    required property string instanceId
    required property var definition
    spacing: 10

    property string draftCity: ""
    property string draftLatitude: ""
    property string draftLongitude: ""
    property string draftMode: "city"
    property string draftUnit: "celsius"
    property var citySuggestions: []
    property string citySearchError: ""
    property bool citySearchRunning: false
    property bool suggestionSelected: false
    property int searchGeneration: 0

    readonly property bool hasUnsavedWeatherChanges: {
        if (!root.record || !root.record.instanceSettings || !root.definition
                || root.definition.id !== "weather")
            return false
        var s = root.record.instanceSettings
        return root.draftCity !== String(s.city || "")
                || root.draftLatitude !== String(s.latitude || "")
                || root.draftLongitude !== String(s.longitude || "")
                || root.draftMode !== String(s.locationMode || "city")
                || root.draftUnit !== String(s.temperatureUnit || "celsius")
    }

    readonly property var record: {
        WidgetManager.revision
        return WidgetManager.snapshot(root.instanceId)
    }

    function syncDrafts() {
        if (!root.record || !root.record.instanceSettings || !root.definition
                || root.definition.id !== "weather")
            return
        var values = root.record.instanceSettings
        root.draftCity = String(values.city || "")
        root.draftLatitude = String(values.latitude || "")
        root.draftLongitude = String(values.longitude || "")
        root.draftMode = String(values.locationMode || "city")
        root.draftUnit = String(values.temperatureUnit || "celsius")
        root.suggestionSelected = root.draftLatitude.length > 0 && root.draftLongitude.length > 0
    }

    function suggestionLabel(item) {
        var parts = [item.name]
        if (item.admin1) parts.push(item.admin1)
        if (item.country) parts.push(item.country)
        return parts.join(", ")
    }

    function searchCities() {
        var query = root.draftCity.trim()
        root.searchGeneration++
        var generation = root.searchGeneration
        root.citySuggestions = []
        root.citySearchError = ""
        if (query.length < 2 || root.draftMode !== "city") {
            root.citySearchRunning = false
            return
        }

        root.citySearchRunning = true
        var request = new XMLHttpRequest()
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=uk&name="
                     + encodeURIComponent(query), true)
        request.timeout = 10000
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || generation !== root.searchGeneration)
                return
            root.citySearchRunning = false
            if (request.status >= 200 && request.status < 300) {
                try {
                    var json = JSON.parse(request.responseText)
                    root.citySuggestions = json.results || []
                    if (root.citySuggestions.length === 0)
                        root.citySearchError = "Місто не знайдено"
                } catch (e) {
                    root.citySearchError = "Некоректна відповідь геокодера"
                }
            } else {
                root.citySearchError = request.status === 0
                        ? "Немає інтернет-з'єднання"
                        : "Помилка геокодера HTTP " + request.status
            }
        }
        request.onerror = function() {
            if (generation === root.searchGeneration) {
                root.citySearchRunning = false
                root.citySearchError = "Немає інтернет-з'єднання"
            }
        }
        request.ontimeout = function() {
            if (generation === root.searchGeneration) {
                root.citySearchRunning = false
                root.citySearchError = "Таймаут пошуку міста"
            }
        }
        request.send()
    }

    function chooseSuggestion(item) {
        root.draftCity = root.suggestionLabel(item)
        root.draftLatitude = String(item.latitude)
        root.draftLongitude = String(item.longitude)
        root.suggestionSelected = true
        root.citySuggestions = []
        root.citySearchError = ""
    }

    function commitWeatherSettings(patch) {
        WidgetManager.updateSettings(root.instanceId, patch)
        var key = WeatherService.makeKey(patch)
        if (key)
            Qt.callLater(function() { WeatherService.request(key) })
    }

    function saveWeatherSettings() {
        var city = root.draftCity.trim()
        if (root.draftMode === "city" && !city) {
            root.commitWeatherSettings({
                locationMode: "city", city: "", latitude: "", longitude: "",
                temperatureUnit: root.draftUnit
            })
            root.citySearchError = "Оберіть місто"
            return
        }

        if (root.draftMode === "coordinates") {
            var latitude = parseFloat(root.draftLatitude)
            var longitude = parseFloat(root.draftLongitude)
            if (isNaN(latitude) || isNaN(longitude)
                    || latitude < -90 || latitude > 90
                    || longitude < -180 || longitude > 180) {
                root.citySearchError = "Вкажіть коректні координати"
                return
            }
            root.commitWeatherSettings({
                locationMode: "coordinates", city: city,
                latitude: String(latitude), longitude: String(longitude),
                temperatureUnit: root.draftUnit
            })
            root.citySearchError = ""
            return
        }

        if (root.suggestionSelected && root.draftLatitude && root.draftLongitude) {
            root.commitWeatherSettings({
                locationMode: "city", city: city,
                latitude: root.draftLatitude, longitude: root.draftLongitude,
                temperatureUnit: root.draftUnit
            })
            root.citySearchError = ""
            return
        }

        // Explicit Save also resolves and persists coordinates when the user
        // typed a city but did not click a suggestion.
        root.citySearchRunning = true
        var request = new XMLHttpRequest()
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&language=uk&name="
                     + encodeURIComponent(city), true)
        request.timeout = 10000
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            root.citySearchRunning = false
            if (request.status >= 200 && request.status < 300) {
                try {
                    var json = JSON.parse(request.responseText)
                    if (!json.results || json.results.length === 0) {
                        root.citySearchError = "Місто не знайдено"
                        return
                    }
                    root.chooseSuggestion(json.results[0])
                    root.commitWeatherSettings({
                        locationMode: "city", city: root.draftCity,
                        latitude: root.draftLatitude, longitude: root.draftLongitude,
                        temperatureUnit: root.draftUnit
                    })
                } catch (e) {
                    root.citySearchError = "Некоректна відповідь геокодера"
                }
            } else {
                root.citySearchError = request.status === 0
                        ? "Немає інтернет-з'єднання"
                        : "Помилка геокодера HTTP " + request.status
            }
        }
        request.onerror = function() {
            root.citySearchRunning = false
            root.citySearchError = "Немає інтернет-з'єднання"
        }
        request.ontimeout = function() {
            root.citySearchRunning = false
            root.citySearchError = "Таймаут пошуку міста"
        }
        request.send()
    }

    onInstanceIdChanged: Qt.callLater(root.syncDrafts)
    onDefinitionChanged: Qt.callLater(root.syncDrafts)
    Component.onCompleted: Qt.callLater(root.syncDrafts)

    Timer {
        id: searchTimer
        interval: 500
        repeat: false
        onTriggered: root.searchCities()
    }

    Text {
        Layout.fillWidth: true
        text: root.definition ? root.definition.name + " — налаштування" : "Налаштування"
        color: Theme.text
        font.pixelSize: 14
        font.bold: true
    }

    ColumnLayout {
        visible: root.definition && root.definition.id === "weather"
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Локація"; color: Theme.textSub; Layout.fillWidth: true }
            WidgetComboBox {
                Layout.preferredWidth: 180
                model: ["city", "coordinates"]
                displayText: currentText === "coordinates" ? "Координати" : "Місто"
                currentIndex: Math.max(0, model.indexOf(root.draftMode))
                onActivated: function(index) {
                    root.draftMode = model[index]
                    root.citySuggestions = []
                    root.citySearchError = ""
                }
            }
        }

        WidgetTextField {
            Layout.fillWidth: true
            placeholderText: "London, Paris, Tokyo…"
            text: root.draftCity
            onTextEdited: {
                root.draftCity = text
                root.suggestionSelected = false
                root.draftLatitude = ""
                root.draftLongitude = ""
                searchTimer.restart()
            }
        }

        RowLayout {
            visible: root.draftMode === "coordinates"
            Layout.fillWidth: true
            WidgetTextField {
                Layout.fillWidth: true
                placeholderText: "Широта"
                text: root.draftLatitude
                onTextEdited: root.draftLatitude = text
            }
            WidgetTextField {
                Layout.fillWidth: true
                placeholderText: "Довгота"
                text: root.draftLongitude
                onTextEdited: root.draftLongitude = text
            }
        }

        ColumnLayout {
            visible: root.citySuggestions.length > 0 && root.draftMode === "city"
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.citySuggestions
                delegate: WidgetButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: root.suggestionLabel(modelData)
                    onClicked: root.chooseSuggestion(modelData)
                }
            }
        }

        Text {
            visible: root.citySearchRunning
            text: "Пошук міста…"
            color: Theme.accent
            font.pixelSize: 10
            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
            }
        }

        Text {
            visible: root.citySearchError.length > 0
            Layout.fillWidth: true
            text: root.citySearchError
            color: Theme.accentRed
            wrapMode: Text.WordWrap
            font.pixelSize: 10
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Температура"; color: Theme.textSub; Layout.fillWidth: true }
            WidgetComboBox {
                Layout.preferredWidth: 150
                model: ["celsius", "fahrenheit"]
                displayText: currentText === "fahrenheit" ? "°F" : "°C"
                currentIndex: Math.max(0, model.indexOf(root.draftUnit))
                onActivated: function(index) { root.draftUnit = model[index] }
            }
        }

        WidgetButton {
            Layout.fillWidth: true
            tone: "accent"
            text: root.citySearchRunning ? "Зачекайте…" : (root.hasUnsavedWeatherChanges ? "Зберегти й оновити" : "Зберегти й оновити")
            enabled: !root.citySearchRunning
            onClicked: root.saveWeatherSettings()
        }

        Text {
            visible: root.hasUnsavedWeatherChanges && !root.citySearchRunning
            Layout.fillWidth: true
            text: "Є незбережені зміни"
            color: Theme.accent
            font.pixelSize: 10
            font.italic: true
        }
    }

    Repeater {
        model: root.definition && root.definition.id !== "weather" ? root.definition.settings : []

        delegate: RowLayout {
            id: settingRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 10

            readonly property var currentValue: root.record && root.record.instanceSettings
                    ? root.record.instanceSettings[modelData.key] : undefined

            Text {
                Layout.fillWidth: true
                text: settingRow.modelData.label
                color: Theme.textSub
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            WidgetSwitch {
                visible: settingRow.modelData.type === "bool"
                checked: settingRow.currentValue === true
                onToggled: WidgetManager.updateSetting(root.instanceId,
                                                        settingRow.modelData.key,
                                                        checked)
            }

            WidgetTextField {
                visible: settingRow.modelData.type === "string"
                Layout.preferredWidth: 210
                text: settingRow.currentValue === undefined ? "" : String(settingRow.currentValue)
                onEditingFinished: WidgetManager.updateSetting(root.instanceId,
                                                                 settingRow.modelData.key,
                                                                 text.trim())
            }

            WidgetComboBox {
                visible: settingRow.modelData.type === "choice"
                Layout.preferredWidth: 170
                model: settingRow.modelData.options || []
                currentIndex: Math.max(0, model.indexOf(String(settingRow.currentValue)))
                onActivated: function(index) {
                    WidgetManager.updateSetting(root.instanceId,
                                                settingRow.modelData.key,
                                                model[index])
                }
            }
        }
    }
}
