import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell
import ".."
import "../widgets"

Item {
    id: root
    anchors.fill: parent

    property string searchText: ""
    property string category: "All"
    property int activeTab: 0  // 0=Усі, 1=Системні, 2=Інструменти

    readonly property var tabSystemIds: ["system-monitor", "network-monitor", "battery", "storage-monitor", "system-uptime", "workspace-overview"]
    readonly property var tabToolIds: ["clock", "calendar", "pomodoro", "quick-notes", "tasks", "audio-visualizer", "quick-launcher"]
    property string selectedInstanceId: WidgetManager.selectedInstanceId
    property var screenNames: {
        var result = []
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; ++i)
            result.push(screens[i].name)
        return result
    }

    function selectedScreen() {
        if (monitorCombo.currentIndex < 0 || monitorCombo.currentIndex >= root.screenNames.length)
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        return WidgetManager.screenByName(root.screenNames[monitorCombo.currentIndex])
    }

    function filteredDefinitions() {
        var result = []
        var needle = root.searchText.trim().toLowerCase()
        var definitions = WidgetRegistry.definitions
        for (var i = 0; i < definitions.length; ++i) {
            var definition = definitions[i]
            // Tab filtering
            if (root.activeTab === 1 && root.tabSystemIds.indexOf(definition.id) < 0)
                continue
            if (root.activeTab === 2 && root.tabToolIds.indexOf(definition.id) < 0)
                continue
            // Category dropdown filtering
            if (root.category !== "All" && definition.category !== root.category)
                continue
            var haystack = (definition.name + " " + definition.description + " " + definition.category).toLowerCase()
            if (needle && haystack.indexOf(needle) < 0)
                continue
            result.push(definition)
        }
        return result
    }

    Flickable {
        id: page
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            x: 20
            y: 20
            width: page.width - 40
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: "Віджети"; color: Theme.text; font.pixelSize: 22; font.bold: true }
                    Text { text: "Каталог і розташування віджетів робочого столу"; color: Theme.textMuted; font.pixelSize: 11 }
                }
                WidgetComboBox {
                    id: monitorCombo
                    model: root.screenNames
                    Layout.preferredWidth: 160
                }
                WidgetButton {
                    text: WidgetManager.editScreenKey ? "Завершити редагування" : "Редагувати робочий стіл"
                    tone: WidgetManager.editScreenKey ? "accent" : "normal"
                    enabled: root.selectedScreen() !== null
                    onClicked: {
                        if (WidgetManager.editScreenKey)
                            WidgetManager.endEdit()
                        else
                            WidgetManager.beginEdit(root.selectedScreen())
                    }
                }
            }

            Rectangle {
                visible: WidgetStorage.errorMessage.length > 0
                Layout.fillWidth: true
                implicitHeight: storageError.implicitHeight + 20
                radius: Theme.radiusMd
                color: Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.14)
                border.color: Theme.accentRed
                Text {
                    id: storageError
                    anchors.fill: parent
                    anchors.margins: 10
                    text: WidgetStorage.errorMessage
                    color: Theme.accentRed
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                WidgetTextField {
                    Layout.fillWidth: true
                    placeholderText: "Пошук віджетів…"
                    onTextChanged: root.searchText = text
                }
                WidgetComboBox {
                    model: WidgetRegistry.categories()
                    Layout.preferredWidth: 170
                    onCurrentTextChanged: root.category = currentText || "All"
                }
            }

            Text { text: "КАТАЛОГ"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true }

            Flow {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: root.filteredDefinitions()
                    delegate: Rectangle {
                        id: catalogCard
                        required property var modelData
                        width: Math.max(220, Math.min(300, (content.width - 24) / 3))
                        height: 190
                        radius: Theme.radiusLg
                        color: Theme.glassCard
                        border.color: cardMouse.containsMouse ? Theme.glassBorderHover : Theme.glassBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 7
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    width: 42; height: 42; radius: 13
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                    Text {
                                        anchors.centerIn: parent
                                        text: catalogCard.modelData.icon
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: 22
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Text { text: catalogCard.modelData.name; color: Theme.text; font.bold: true; font.pixelSize: 14 }
                                    Text { text: catalogCard.modelData.category; color: Theme.accent; font.pixelSize: 10 }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: catalogCard.modelData.description
                                color: Theme.textSub
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                            }
                            Text {
                                text: catalogCard.modelData.defaultWidth + "×" + catalogCard.modelData.defaultHeight
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }
                            WidgetButton {
                                Layout.fillWidth: true
                                text: "Додати на " + (monitorCombo.currentText || "екран")
                                tone: "accent"
                                enabled: root.selectedScreen() !== null && WidgetStorage.writable
                                onClicked: WidgetManager.addWidget(catalogCard.modelData.id, root.selectedScreen())
                            }
                        }
                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
            }

            Text { text: "МОЇ ВІДЖЕТИ"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    visible: WidgetManager.instanceModel.count === 0
                    Layout.fillWidth: true
                    text: "Ще немає доданих віджетів"
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    padding: 20
                }

                Repeater {
                    model: WidgetManager.instanceModel
                    delegate: Rectangle {
                        id: instanceCard
                        required property string instanceId
                        required property string widgetId
                        required property string screenName
                        required property bool instanceEnabled
                        required property var instanceSettings

                        readonly property var definition: WidgetRegistry.get(widgetId)

                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: Theme.radiusMd
                        color: WidgetManager.selectedInstanceId === instanceId ? Theme.glassCardActive : Theme.glassCard
                        border.color: WidgetManager.selectedInstanceId === instanceId ? Theme.glassBorderFocus : Theme.glassBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                Text { text: instanceCard.definition ? instanceCard.definition.icon : "?"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 20 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Text { text: instanceCard.definition ? instanceCard.definition.name : instanceCard.widgetId; color: Theme.text; font.bold: true }
                                    Text { text: instanceCard.screenName + " · " + instanceCard.instanceId + (instanceCard.definition ? "" : "  (неизвестный тип)"); color: Theme.textMuted; font.pixelSize: 9; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                }
                            WidgetComboBox {
                                model: root.screenNames
                                Layout.preferredWidth: 130
                                currentIndex: Math.max(0, model.indexOf(instanceCard.screenName))
                                onActivated: function(index) {
                                    WidgetManager.moveToScreen(instanceCard.instanceId,
                                                               WidgetManager.screenByName(model[index]))
                                }
                            }
                            WidgetSwitch {
                                checked: instanceCard.instanceEnabled
                                onToggled: WidgetManager.setEnabled(instanceCard.instanceId, checked)
                            }
                            WidgetButton {
                                text: "Налаштувати"
                                visible: instanceCard.definition !== null
                                onClicked: WidgetManager.selectedInstanceId = instanceCard.instanceId
                            }
                            WidgetButton {
                                text: "Видалити"
                                tone: "danger"
                                onClicked: WidgetManager.removeWidget(instanceCard.instanceId)
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: WidgetManager.selectedInstanceId.length > 0
                Layout.fillWidth: true
                implicitHeight: settingsEditor.implicitHeight + 28
                radius: Theme.radiusLg
                color: Theme.glassCard
                border.color: Theme.glassBorderFocus

                WidgetSettingEditor {
                    id: settingsEditor
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    instanceId: WidgetManager.selectedInstanceId
                    definition: {
                        var record = WidgetManager.snapshot(instanceId)
                        return record ? WidgetRegistry.get(record.widgetId) : null
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
