import QtQuick
import QtQuick.Layouts
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

    readonly property string storagePath: Quickshell.shellDir + "/widget-notes-" + instanceId + ".txt"
    property string noteText: ""
    property bool loaded: false

    FileView {
        id: noteFile
        path: root.storagePath
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.noteText = text()
            root.loaded = true
        }
        onLoadFailed: function(error) {
            root.noteText = ""
            root.loaded = true
        }
    }

    Timer {
        id: saveTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (root.loaded)
                noteFile.setText(root.noteText)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰏪"
                color: Theme.accentYellow
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: "НОТАТКИ"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                text: root.noteText.length + " символів"
                color: Theme.textMuted
                font.pixelSize: 9
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSm
            color: Qt.rgba(Theme.bgSurface.r, Theme.bgSurface.g, Theme.bgSurface.b, 0.5)
            border.color: noteArea.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder
            border.width: noteArea.activeFocus ? 2 : 1

            Flickable {
                id: noteFlick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: noteArea.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: noteArea
                    width: noteFlick.width
                    text: root.noteText
                    color: Theme.text
                    selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                    selectedTextColor: Theme.text
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    focus: true
                    onTextChanged: {
                        if (root.loaded) {
                            root.noteText = text
                            saveTimer.restart()
                        }
                    }

                    Component.onCompleted: {
                        if (root.loaded)
                            text = root.noteText
                    }
                }
            }

            Text {
                visible: root.loaded && root.noteText.length === 0 && !noteArea.activeFocus
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 12
                text: "Напишіть нотатку…"
                color: Theme.textMuted
                font.pixelSize: 12
                font.family: Theme.fontMono
            }
        }
    }

    Connections {
        target: root
        function onLoadedChanged() {
            if (root.loaded)
                noteArea.text = root.noteText
        }
    }
}
