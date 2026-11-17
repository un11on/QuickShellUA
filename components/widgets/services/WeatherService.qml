pragma Singleton
import QtQuick

QtObject {
    id: root

    property var entries: ({})
    property var subscribers: ({})
    property int revision: 0

    function validCoordinates(latitude, longitude) {
        var lat = parseFloat(latitude)
        var lon = parseFloat(longitude)
        return !isNaN(lat) && !isNaN(lon)
                && lat >= -90 && lat <= 90
                && lon >= -180 && lon <= 180
    }

    function makeKey(settings) {
        var mode = settings.locationMode || "city"
        var unit = settings.temperatureUnit || "celsius"
        if (mode === "coordinates") {
            if (!root.validCoordinates(settings.latitude, settings.longitude))
                return ""
            return "coord:" + parseFloat(settings.latitude).toFixed(5) + ","
                    + parseFloat(settings.longitude).toFixed(5) + ":" + unit
        }
        var city = String(settings.city || "").trim()
        if (!city)
            return ""
        var coordinatePart = root.validCoordinates(settings.latitude, settings.longitude)
                ? ":" + parseFloat(settings.latitude).toFixed(5) + ","
                        + parseFloat(settings.longitude).toFixed(5)
                : ""
        return "city:" + city.toLowerCase() + coordinatePart + ":" + unit
    }

    function subscribe(key, settings) {
        if (!key)
            return
        var subs = root.subscribers
        subs[key] = (subs[key] || 0) + 1
        root.subscribers = Object.assign({}, subs)
        if (!root.entries[key]) {
            var normalizedSettings = {
                locationMode: String(settings.locationMode || "city"),
                city: String(settings.city || ""),
                latitude: String(settings.latitude || ""),
                longitude: String(settings.longitude || ""),
                temperatureUnit: String(settings.temperatureUnit || "celsius")
            }
            var allEntries = Object.assign({}, root.entries)
            allEntries[key] = {
                loading: true, error: "", temperature: 0,
                weatherCode: -1,
                city: settings.city || "", updatedAt: 0,
                settings: normalizedSettings
            }
            root.entries = allEntries
            root.revision++
            root.request(key)
        }
    }

    function unsubscribe(key) {
        var subs = root.subscribers
        if (subs[key]) {
            subs[key]--
            if (subs[key] <= 0)
                delete subs[key]
            root.subscribers = Object.assign({}, subs)
        }
    }

    function dataFor(key) {
        root.revision
        return root.entries[key] || null
    }

    function update(key, patch) {
        var current = root.entries[key]
        if (!current)
            return
        var next = Object.assign({}, current)
        for (var field in patch)
            next[field] = patch[field]
        var allEntries = Object.assign({}, root.entries)
        allEntries[key] = next
        root.entries = allEntries
        root.revision++
    }

    function request(key) {
        var entry = root.entries[key]
        if (!entry || entry.requesting)
            return
        var settings = entry.settings || {}
        root.update(key, { requesting: true, loading: true, error: "" })
        if ((settings.locationMode || "city") === "coordinates") {
            var lat = parseFloat(settings.latitude)
            var lon = parseFloat(settings.longitude)
            if (!root.validCoordinates(lat, lon)) {
                root.update(key, { loading: false, requesting: false, error: "Некоректні координати" })
                return
            }
            root.requestForecast(key, lat, lon, settings.city || "")
            return
        }

        var city = String(settings.city || "").trim()
        if (!city) {
            root.update(key, { loading: false, requesting: false, error: "Оберіть місто в налаштуваннях" })
            return
        }

        var savedLatitude = parseFloat(settings.latitude)
        var savedLongitude = parseFloat(settings.longitude)
        if (!isNaN(savedLatitude) && !isNaN(savedLongitude)) {
            root.requestForecast(key, savedLatitude, savedLongitude, city)
            return
        }

        var geo = new XMLHttpRequest()
        geo.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&language=uk&name="
                 + encodeURIComponent(city), true)
        geo.timeout = 10000
        geo.onreadystatechange = function() {
            if (geo.readyState !== XMLHttpRequest.DONE)
                return
            if (geo.status >= 200 && geo.status < 300) {
                try {
                    var json = JSON.parse(geo.responseText)
                    if (!json.results || json.results.length === 0) {
                        root.update(key, { loading: false, requesting: false, error: "Місто не знайдено" })
                        return
                    }
                    var result = json.results[0]
                    root.requestForecast(key, result.latitude, result.longitude,
                                         result.name + (result.country ? ", " + result.country : ""))
                } catch (e) {
                    root.update(key, { loading: false, requesting: false, error: "Помилка відповіді геокодера" })
                }
            } else {
                root.update(key, {
                    loading: false,
                    requesting: false,
                    error: geo.status === 0 ? "Немає інтернет-з'єднання"
                                           : "Помилка геокодера HTTP " + geo.status
                })
            }
        }
        geo.onerror = function() {
            root.update(key, { loading: false, requesting: false, error: "Немає інтернет-з'єднання" })
        }
        geo.ontimeout = function() {
            root.update(key, { loading: false, requesting: false, error: "Таймаут геокодера" })
        }
        geo.send()
    }

    function requestForecast(key, latitude, longitude, cityLabel) {
        var entry = root.entries[key]
        if (!entry)
            return
        var unit = (entry.settings.temperatureUnit || "celsius") === "fahrenheit"
                ? "fahrenheit" : "celsius"
        var request = new XMLHttpRequest()
        var url = "https://api.open-meteo.com/v1/forecast?current=temperature_2m,weather_code"
                + "&latitude=" + encodeURIComponent(latitude)
                + "&longitude=" + encodeURIComponent(longitude)
                + "&temperature_unit=" + unit
        request.open("GET", url, true)
        request.timeout = 10000
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (request.status >= 200 && request.status < 300) {
                try {
                    var json = JSON.parse(request.responseText)
                    var current = json.current
                    if (!current)
                        throw new Error("missing current")
                    root.update(key, {
                        loading: false,
                        requesting: false,
                        error: "",
                        temperature: Number(current.temperature_2m),
                        weatherCode: Number(current.weather_code),
                        city: cityLabel,
                        updatedAt: Date.now()
                    })
                } catch (e) {
                    root.update(key, { loading: false, requesting: false, error: "Некоректна відповідь погоди" })
                }
            } else {
                root.update(key, {
                    loading: false,
                    requesting: false,
                    error: request.status === 0 ? "Немає інтернет-з'єднання"
                                               : "Помилка погоди HTTP " + request.status
                })
            }
        }
        request.onerror = function() {
            root.update(key, { loading: false, requesting: false, error: "Немає інтернет-з'єднання" })
        }
        request.ontimeout = function() {
            root.update(key, { loading: false, requesting: false, error: "Таймаут сервісу погоди" })
        }
        request.send()
    }

    function refreshAll() {
        var keys = Object.keys(root.subscribers)
        for (var i = 0; i < keys.length; ++i)
            root.request(keys[i])
    }

    property Timer refreshTimer: Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: Object.keys(root.subscribers).length > 0
        onTriggered: root.refreshAll()
    }
}
