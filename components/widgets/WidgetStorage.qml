pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property int currentSchemaVersion: 1
    readonly property string storagePath: Quickshell.shellDir + "/widgets.json"

    property bool loaded: false
    property bool writable: true
    property string errorMessage: ""
    property var storedInstances: []
    property var pendingInstances: null
    property bool _backupTried: false

    property FileView backupFile: FileView {
        path: root.storagePath + ".bak"
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            if (root._backupTried) {
                root.acceptText(text())
                root._backupTried = false
            }
        }
    }

    function validArray(value) {
        return Array.isArray(value) ? value : []
    }

    function migrate(document) {
        var data = document && typeof document === "object" ? document : ({})
        var version = Number(data.schemaVersion || 0)

        if (version === 0 && Array.isArray(data.instances)) {
            data.schemaVersion = 1
            version = 1
        }

        if (version !== root.currentSchemaVersion)
            throw new Error("Unsupported widget schema version: " + version)

        return {
            schemaVersion: root.currentSchemaVersion,
            instances: root.validArray(data.instances)
        }
    }

    function acceptText(text) {
        try {
            var parsed = JSON.parse(text)
            var migrated = root.migrate(parsed)
            root.storedInstances = JSON.parse(JSON.stringify(migrated.instances))
            root.errorMessage = ""
            root.writable = true
        } catch (e) {
            // Keep the last known good state in memory; do not overwrite with empty.
            root.errorMessage = "widgets.json: " + e
            root.writable = false
        }
        root.loaded = true
    }

    function requestSave(instances) {
        if (!root.loaded || !root.writable)
            return false
        root.pendingInstances = JSON.parse(JSON.stringify(instances || []))
        saveTimer.restart()
        return true
    }

    function reload() {
        root.loaded = false
        root.errorMessage = ""
        root._backupTried = false
        // Do not touch pendingInstances or storedInstances here;
        // they are only updated after a successful acceptText().
        storageFile.reload()
    }

    function saveNow() {
        if (!root.writable || root.pendingInstances === null)
            return
        // Create a backup of the current file before overwriting.
        var currentText = storageFile.text()
        if (currentText && currentText.trim().length > 0) {
            backupFile.setText(currentText)
        }
        var document = {
            schemaVersion: root.currentSchemaVersion,
            instances: root.pendingInstances
        }
        storageFile.setText(JSON.stringify(document, null, 4))
        root.pendingInstances = null
    }

    property FileView storageFile: FileView {
        id: storageFile
        path: root.storagePath
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onLoaded: root.acceptText(text())

        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                root.storedInstances = []
                root.errorMessage = ""
                root.writable = true
                root.loaded = true
                root.pendingInstances = []
                saveTimer.restart()
            } else if (!root._backupTried) {
                root._backupTried = true
                backupFile.reload()
            } else {
                root.errorMessage = "Unable to load widgets.json: " + FileViewError.toString(error)
                root.writable = false
                root.loaded = true
            }
        }

        onSaveFailed: function(error) {
            root.errorMessage = "Unable to save widgets.json: " + FileViewError.toString(error)
        }
    }

    property Timer saveTimer: Timer {
        id: saveTimer
        interval: 650
        repeat: false
        onTriggered: root.saveNow()
    }
}
