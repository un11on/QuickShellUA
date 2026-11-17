pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import "."

QtObject {
    id: root

    readonly property alias instanceModel: instances
    property bool loaded: false
    property int revision: 0
    property string selectedInstanceId: ""
    property string editScreenKey: ""
    property int gridSize: 20
    property int idCounter: 0

    property ListModel instanceStore: ListModel {
        id: instances
        dynamicRoles: true
    }

    property Connections storageConnections: Connections {
        target: WidgetStorage
        function onLoadedChanged() {
            if (WidgetStorage.loaded)
                root.restore()
        }
    }

    property Connections screenConnections: Connections {
        target: Quickshell
        function onScreensChanged() {
            var changed = false
            for (var i = 0; i < instances.count; ++i) {
                var record = instances.get(i)
                if (record.unknownWidget)
                    continue
                var screen = root.screenForKey(record.screenKey, record.screenName, record.screenModel, record.screenSerial)
                if (!screen) {
                    // Try to find by name or serial only
                    screen = root.screenForKey("", record.screenName, record.screenModel, record.screenSerial)
                }
                if (screen) {
                    var newKey = root.screenKeyForScreen(screen)
                    if (newKey !== record.screenKey) {
                        instances.setProperty(i, "screenKey", newKey)
                        instances.setProperty(i, "screenName", screen.name)
                        instances.setProperty(i, "screenModel", screen.model)
                        instances.setProperty(i, "screenSerial", screen.serialNumber)
                        changed = true
                    }
                }
            }
            if (changed)
                root.revision++
        }
    }

    Component.onCompleted: {
        if (WidgetStorage.loaded)
            root.restore()
    }

    function safeString(value) {
        return value === undefined || value === null ? "" : String(value)
    }

    function screenKeyForScreen(screen) {
        if (!screen)
            return ""
        var serial = root.safeString(screen.serialNumber)
        var model = root.safeString(screen.model)
        if (serial && serial !== "{ NULL SCREEN }")
            return "serial:" + serial + "|model:" + model
        return "name:" + root.safeString(screen.name)
    }

    function screenForKey(key, fallbackName, fallbackModel, fallbackSerial) {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; ++i) {
            if (root.screenKeyForScreen(screens[i]) === key)
                return screens[i]
        }
        if (fallbackName) {
            for (var j = 0; j < screens.length; ++j) {
                if (screens[j].name === fallbackName)
                    return screens[j]
            }
        }
        if (fallbackSerial) {
            for (var k = 0; k < screens.length; ++k) {
                if (screens[k].serialNumber === fallbackSerial
                        && (!fallbackModel || screens[k].model === fallbackModel))
                    return screens[k]
            }
        }
        return null
    }

    function screenByName(name) {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; ++i) {
            if (screens[i].name === name)
                return screens[i]
        }
        return null
    }

    function makeId() {
        root.idCounter++
        return "widget-" + Date.now().toString(36) + "-"
                + root.idCounter.toString(36) + "-"
                + Math.floor(Math.random() * 0xffffff).toString(36)
    }

    function indexOf(instanceId) {
        for (var i = 0; i < instances.count; ++i) {
            if (instances.get(i).instanceId === instanceId)
                return i
        }
        return -1
    }

    function snapshot(instanceId) {
        var index = root.indexOf(instanceId)
        return index >= 0 ? instances.get(index) : null
    }

    function sanitizeRecord(record) {
        var definition = WidgetRegistry.get(record.widgetId)
        if (!definition) {
            return {
                instanceId: root.safeString(record.instanceId) || root.makeId(),
                widgetId: root.safeString(record.widgetId),
                widgetVersion: root.safeString(record.widgetVersion),
                screenKey: root.safeString(record.screenKey) || "name:" + root.safeString(record.screenName),
                screenName: root.safeString(record.screenName),
                screenModel: root.safeString(record.screenModel),
                screenSerial: root.safeString(record.screenSerial),
                posX: Math.max(0, Number(record.posX || 0)),
                posY: Math.max(0, Number(record.posY || 0)),
                widgetWidth: Math.max(200, Number(record.widgetWidth || 300)),
                widgetHeight: Math.max(100, Number(record.widgetHeight || 200)),
                instanceEnabled: record.instanceEnabled !== false,
                zOrder: Number(record.zOrder || 0),
                instanceSettings: record.settings && typeof record.settings === "object" ? record.settings : ({}),
                unknownWidget: true
            }
        }
        var settings = WidgetRegistry.cloneDefaults(record.widgetId)
        var savedSettings = record.settings && typeof record.settings === "object" ? record.settings : ({})
        for (var key in savedSettings)
            settings[key] = savedSettings[key]
        return {
            instanceId: root.safeString(record.instanceId) || root.makeId(),
            widgetId: definition.id,
            widgetVersion: root.safeString(record.widgetVersion) || definition.version,
            screenKey: root.safeString(record.screenKey) || "name:" + root.safeString(record.screenName),
            screenName: root.safeString(record.screenName),
            screenModel: root.safeString(record.screenModel),
            screenSerial: root.safeString(record.screenSerial),
            posX: Math.max(0, Number(record.posX || 0)),
            posY: Math.max(0, Number(record.posY || 0)),
            widgetWidth: Math.max(definition.minWidth, Number(record.widgetWidth || definition.defaultWidth)),
            widgetHeight: Math.max(definition.minHeight, Number(record.widgetHeight || definition.defaultHeight)),
            instanceEnabled: record.instanceEnabled !== false,
            zOrder: Number(record.zOrder || 0),
            instanceSettings: settings
        }
    }

    function restore() {
        if (root.loaded)
            return
        instances.clear()
        var saved = WidgetStorage.storedInstances || []
        for (var i = 0; i < saved.length; ++i) {
            var record = root.sanitizeRecord(saved[i])
            if (record)
                instances.append(record)
        }
        root.loaded = true
        root.revision++
    }

    function serializedInstances() {
        var result = []
        for (var i = 0; i < instances.count; ++i) {
            var record = instances.get(i)
            result.push({
                instanceId: record.instanceId,
                widgetId: record.widgetId,
                widgetVersion: record.widgetVersion,
                screenKey: record.screenKey,
                screenName: record.screenName,
                screenModel: record.screenModel,
                screenSerial: record.screenSerial,
                posX: record.posX,
                posY: record.posY,
                widgetWidth: record.widgetWidth,
                widgetHeight: record.widgetHeight,
                instanceEnabled: record.instanceEnabled,
                zOrder: record.zOrder,
                settings: record.instanceSettings
            })
        }
        return result
    }

    function persist() {
        WidgetStorage.requestSave(root.serializedInstances())
    }

    function addWidget(widgetId, screen) {
        var definition = WidgetRegistry.get(widgetId)
        if (!definition || !screen || !WidgetStorage.writable)
            return ""
        if (!definition.multiple) {
            for (var existing = 0; existing < instances.count; ++existing) {
                if (instances.get(existing).widgetId === widgetId)
                    return instances.get(existing).instanceId
            }
        }

        var countOnScreen = 0
        var targetKey = root.screenKeyForScreen(screen)
        for (var i = 0; i < instances.count; ++i) {
            if (instances.get(i).screenKey === targetKey)
                countOnScreen++
        }
        var offset = countOnScreen * 28
        var width = Math.min(definition.defaultWidth, screen.width)
        var height = Math.min(definition.defaultHeight, screen.height)
        var id = root.makeId()
        instances.append({
            instanceId: id,
            widgetId: widgetId,
            widgetVersion: definition.version,
            screenKey: targetKey,
            screenName: screen.name,
            screenModel: screen.model,
            screenSerial: screen.serialNumber,
            posX: Math.max(0, Math.min(screen.width - width, 80 + offset)),
            posY: Math.max(0, Math.min(screen.height - height, 80 + offset)),
            widgetWidth: width,
            widgetHeight: height,
            instanceEnabled: true,
            zOrder: instances.count,
            instanceSettings: WidgetRegistry.cloneDefaults(widgetId)
        })
        root.selectedInstanceId = id
        root.revision++
        root.persist()
        return id
    }

    function removeWidget(instanceId) {
        var index = root.indexOf(instanceId)
        if (index < 0)
            return
        instances.remove(index)
        if (root.selectedInstanceId === instanceId)
            root.selectedInstanceId = ""
        root.revision++
        root.persist()
    }

    function setEnabled(instanceId, enabled) {
        var index = root.indexOf(instanceId)
        if (index < 0)
            return
        instances.setProperty(index, "instanceEnabled", !!enabled)
        root.revision++
        root.persist()
    }

    function snap(value) {
        return Math.round(value / root.gridSize) * root.gridSize
    }

    function setGeometry(instanceId, x, y, width, height, useSnap) {
        var index = root.indexOf(instanceId)
        if (index < 0)
            return
        var record = instances.get(index)
        var definition = WidgetRegistry.get(record.widgetId)
        var screen = root.screenForKey(record.screenKey, record.screenName, record.screenModel, record.screenSerial)
        var w = Math.max(definition.minWidth, Number(width))
        var h = Math.max(definition.minHeight, Number(height))
        var px = Math.max(0, Number(x))
        var py = Math.max(0, Number(y))
        if (useSnap) {
            w = root.snap(w)
            h = root.snap(h)
            px = root.snap(px)
            py = root.snap(py)
        }
        if (screen) {
            w = Math.min(w, screen.width)
            h = Math.min(h, screen.height)
            px = Math.min(px, Math.max(0, screen.width - w))
            py = Math.min(py, Math.max(0, screen.height - h))
        }
        instances.setProperty(index, "posX", px)
        instances.setProperty(index, "posY", py)
        instances.setProperty(index, "widgetWidth", w)
        instances.setProperty(index, "widgetHeight", h)
        root.revision++
        root.persist()
    }

    function coerceSettingValue(schemaEntry, value) {
        if (!schemaEntry)
            return value
        var type = schemaEntry.type
        if (type === "bool") {
            if (value === true || value === "true")
                return true
            if (value === false || value === "false")
                return false
            return null
        }
        if (type === "string")
            return String(value)
        if (type === "choice") {
            var options = schemaEntry.options || []
            for (var o = 0; o < options.length; ++o) {
                if (options[o] === value)
                    return value
            }
            return null
        }
        return value
    }

    function updateSetting(instanceId, key, value) {
        var patch = ({})
        patch[key] = value
        root.updateSettings(instanceId, patch)
    }

    function updateSettings(instanceId, patch) {
        var index = root.indexOf(instanceId)
        if (index < 0)
            return
        var record = instances.get(index)
        var definition = WidgetRegistry.get(record.widgetId)
        var settings = JSON.parse(JSON.stringify(record.instanceSettings || {}))
        var applied = false
        for (var key in patch) {
            var schemaEntry = null
            if (definition) {
                for (var s = 0; s < definition.settings.length; ++s) {
                    if (definition.settings[s].key === key) {
                        schemaEntry = definition.settings[s]
                        break
                    }
                }
            }
            var coerced = root.coerceSettingValue(schemaEntry, patch[key])
            if (coerced !== null) {
                settings[key] = coerced
                applied = true
            }
        }
        if (!applied)
            return
        instances.setProperty(index, "instanceSettings", settings)
        root.revision++
        root.persist()
    }

    function moveToScreen(instanceId, screen) {
        var index = root.indexOf(instanceId)
        if (index < 0 || !screen)
            return
        instances.setProperty(index, "screenKey", root.screenKeyForScreen(screen))
        instances.setProperty(index, "screenName", screen.name)
        instances.setProperty(index, "screenModel", screen.model)
        instances.setProperty(index, "screenSerial", screen.serialNumber)
        root.setGeometry(instanceId, 80, 80,
                         instances.get(index).widgetWidth,
                         instances.get(index).widgetHeight, true)
        root.revision++
        root.persist()
    }

    function enabledCountForScreen(screen) {
        var key = root.screenKeyForScreen(screen)
        var count = 0
        for (var i = 0; i < instances.count; ++i) {
            var record = instances.get(i)
            if (record.screenKey === key && record.instanceEnabled)
                count++
        }
        return count
    }

    function shouldRenderScreen(screen) {
        if (!screen)
            return false
        var key = root.screenKeyForScreen(screen)
        return root.enabledCountForScreen(screen) > 0 || root.editScreenKey === key
    }

    function beginEdit(screen) {
        if (!screen)
            return
        root.editScreenKey = root.screenKeyForScreen(screen)
        root.revision++
    }

    function endEdit() {
        root.editScreenKey = ""
        root.selectedInstanceId = ""
        root.revision++
    }

    function resetLayout(screen) {
        if (!screen)
            return
        var key = root.screenKeyForScreen(screen)
        var slot = 0
        for (var i = 0; i < instances.count; ++i) {
            var record = instances.get(i)
            if (record.screenKey !== key)
                continue
            root.setGeometry(record.instanceId,
                             60 + (slot % 3) * 380,
                             80 + Math.floor(slot / 3) * 300,
                             record.widgetWidth,
                             record.widgetHeight,
                             true)
            slot++
        }
        root.persist()
    }

    function clampScreen(screen) {
        if (!screen)
            return
        var key = root.screenKeyForScreen(screen)
        for (var i = 0; i < instances.count; ++i) {
            var record = instances.get(i)
            if (record.screenKey === key)
                root.setGeometry(record.instanceId, record.posX, record.posY,
                                 record.widgetWidth, record.widgetHeight, false)
        }
    }
}
