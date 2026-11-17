import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    signal settingChanged(string key, var value)

    readonly property string storagePath: Quickshell.shellDir + "/widget-tasks-" + instanceId + ".json"
    property var tasks: []
    property bool loaded: false
    property bool showCompleted: false
    property string newTaskText: ""

    FileView {
        id: taskFile
        path: root.storagePath
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                root.tasks = JSON.parse(text())
            } catch(e) {
                root.tasks = []
            }
            root.loaded = true
        }
        onLoadFailed: function(error) {
            root.tasks = []
            root.loaded = true
        }
    }

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.loaded)
                taskFile.setText(JSON.stringify(root.tasks, null, 2))
        }
    }

    function saveTasks() {
        tasks = tasks.slice() // trigger binding update
        saveTimer.restart()
    }

    function addTask(text) {
        if (!text.trim()) return
        var task = {
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            text: text.trim(),
            done: false,
            priority: "normal",
            createdAt: new Date().toISOString()
        }
        tasks.push(task)
        saveTasks()
    }

    function toggleTask(taskId) {
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].id === taskId) {
                tasks[i].done = !tasks[i].done
                break
            }
        }
        saveTasks()
    }

    function removeTask(taskId) {
        tasks = tasks.filter(function(t) { return t.id !== taskId })
        saveTasks()
    }

    function cyclePriority(taskId) {
        var priorities = ["low", "normal", "high"]
        for (var i = 0; i < tasks.length; i++) {
            if (tasks[i].id === taskId) {
                var idx = priorities.indexOf(tasks[i].priority || "normal")
                tasks[i].priority = priorities[(idx + 1) % 3]
                break
            }
        }
        saveTasks()
    }

    function filteredTasks() {
        var result = []
        for (var i = 0; i < tasks.length; i++) {
            if (root.showCompleted || !tasks[i].done)
                result.push(tasks[i])
        }
        return result
    }

    function priorityColor(p) {
        if (p === "high") return Theme.accentRed
        if (p === "low") return Theme.accentTeal
        return Theme.accent
    }

    function priorityIcon(p) {
        if (p === "high") return "▲"
        if (p === "low") return "▼"
        return "●"
    }

    readonly property int activeCount: {
        var c = 0
        for (var i = 0; i < tasks.length; i++)
            if (!tasks[i].done) c++
        return c
    }

    readonly property int doneCount: tasks.length - activeCount

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰄬"
                color: Theme.accentGreen
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: "ЗАДАЧІ"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: counterLabel.implicitWidth + 12
                height: 20
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                Text {
                    id: counterLabel
                    anchors.centerIn: parent
                    text: root.activeCount + "/" + root.tasks.length
                    color: Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                }
            }
            WidgetButton {
                text: root.showCompleted ? "󰈈" : "󰈉"
                implicitWidth: 34
                leftPadding: 0; rightPadding: 0
                onClicked: root.showCompleted = !root.showCompleted
            }
        }

        // Add task row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: Theme.radiusSm
                color: Qt.rgba(Theme.bgSurface.r, Theme.bgSurface.g, Theme.bgSurface.b, 0.5)
                border.color: newTaskInput.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder

                TextInput {
                    id: newTaskInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    clip: true
                    selectByMouse: true
                    focus: true
                    onAccepted: {
                        root.addTask(text)
                        text = ""
                    }
                }

                Text {
                    visible: newTaskInput.text.length === 0 && !newTaskInput.activeFocus
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Нова задача…"
                    color: Theme.textMuted
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                }
            }

            WidgetButton {
                text: "+"
                tone: "accent"
                implicitWidth: 34
                leftPadding: 0; rightPadding: 0
                onClicked: {
                    root.addTask(newTaskInput.text)
                    newTaskInput.text = ""
                }
            }
        }

        // Tasks list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: tasksCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: tasksCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.filteredTasks()
                    delegate: Rectangle {
                        id: taskItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radiusSm
                        color: taskMouse.containsMouse
                            ? Theme.glassCardHover : Theme.glassCard
                        border.color: Theme.glassBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 6

                            // Checkbox
                            Rectangle {
                                width: 18; height: 18
                                radius: 4
                                color: taskItem.modelData.done
                                    ? Qt.rgba(Theme.accentGreen.r, Theme.accentGreen.g, Theme.accentGreen.b, 0.3)
                                    : "transparent"
                                border.color: taskItem.modelData.done ? Theme.accentGreen : Theme.glassBorderHover
                                border.width: 1.5

                                Text {
                                    visible: taskItem.modelData.done
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Theme.accentGreen
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleTask(taskItem.modelData.id)
                                }
                            }

                            // Priority dot
                            Text {
                                text: root.priorityIcon(taskItem.modelData.priority)
                                color: root.priorityColor(taskItem.modelData.priority)
                                font.pixelSize: 8

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cyclePriority(taskItem.modelData.id)
                                }
                            }

                            // Text
                            Text {
                                Layout.fillWidth: true
                                text: taskItem.modelData.text
                                color: taskItem.modelData.done ? Theme.textMuted : Theme.text
                                font.pixelSize: 12
                                font.strikeout: taskItem.modelData.done
                                elide: Text.ElideRight
                            }

                            // Remove
                            Text {
                                text: "×"
                                color: removeMouse.containsMouse ? Theme.accentRed : Theme.textMuted
                                font.pixelSize: 14
                                MouseArea {
                                    id: removeMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeTask(taskItem.modelData.id)
                                }
                            }
                        }

                        MouseArea {
                            id: taskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                Text {
                    visible: root.filteredTasks().length === 0
                    Layout.fillWidth: true
                    text: root.tasks.length === 0 ? "Додайте першу задачу" : "Усі задачі виконано!"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    padding: 16
                }
            }
        }
    }
}
