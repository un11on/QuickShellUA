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

    property var workspaces: []
    property int activeWorkspace: 1

    Process {
        id: wsProc
        running: false
        command: ["sh", "-c", "hyprctl workspaces -j 2>/dev/null"]
        stdout: StdioCollector { id: wsOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var parsed = JSON.parse(wsOutput.text)
                    var result = []
                    for (var i = 0; i < parsed.length; i++) {
                        result.push({
                            id: parsed[i].id,
                            name: parsed[i].name || String(parsed[i].id),
                            windows: parsed[i].windows || 0,
                            monitor: parsed[i].monitor || "",
                            hasfullscreen: parsed[i].hasfullscreen || false
                        })
                    }
                    result.sort(function(a, b) { return a.id - b.id })
                    root.workspaces = result
                } catch(e) {
                    root.workspaces = []
                }
            }
        }
    }

    Process {
        id: activeProc
        running: false
        command: ["sh", "-c", "hyprctl activeworkspace -j 2>/dev/null"]
        stdout: StdioCollector { id: activeOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var parsed = JSON.parse(activeOutput.text)
                    root.activeWorkspace = parsed.id || 1
                } catch(e) {}
            }
        }
    }

    function refresh() {
        if (!wsProc.running)
            wsProc.running = true
        if (!activeProc.running)
            activeProc.running = true
    }

    function switchWorkspace(wsId) {
        switchProc.command = ["hyprctl", "dispatch", "workspace", String(wsId)]
        switchProc.running = true
    }

    Process {
        id: switchProc
        running: false
        onExited: function(exitCode, exitStatus) {
            root.refresh()
        }
    }

    // Hyprland socket listener for live updates
    Process {
        id: socketListener
        running: !root.previewMode
        command: ["sh", "-c", "socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = String(data)
                if (line.indexOf("workspace") >= 0 || line.indexOf("createworkspace") >= 0 ||
                    line.indexOf("destroyworkspace") >= 0 || line.indexOf("openwindow") >= 0 ||
                    line.indexOf("closewindow") >= 0 || line.indexOf("movewindow") >= 0) {
                    refreshDebounce.restart()
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (!root.previewMode)
                socketRestartTimer.restart()
        }
    }

    Timer {
        id: socketRestartTimer
        interval: 3000
        repeat: false
        onTriggered: if (!root.previewMode) socketListener.running = true
    }

    Timer {
        id: refreshDebounce
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: !root.previewMode
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰍹"
                color: Theme.accentSecondary
                font.family: Theme.fontMono
                font.pixelSize: 24
            }
            Text {
                text: "РОБОЧІ СТОЛИ"
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                width: activeLabel.implicitWidth + 12
                height: 20
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                Text {
                    id: activeLabel
                    anchors.centerIn: parent
                    text: root.workspaces.length + " шт."
                    color: Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.workspaces
                delegate: Rectangle {
                    id: wsCard
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: modelData.id === root.activeWorkspace

                    width: Math.max(60, Math.min(80, (root.width - 48) / Math.max(1, root.workspaces.length) - 8))
                    height: 64
                    radius: Theme.radiusMd
                    color: isCurrent
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                        : (wsMouse.containsMouse ? Theme.glassCardHover : Theme.glassCard)
                    border.color: isCurrent ? Theme.accent : Theme.glassBorder
                    border.width: isCurrent ? 2 : 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: wsCard.modelData.name
                            color: wsCard.isCurrent ? Theme.accent : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: wsCard.modelData.windows + " вікон"
                            color: Theme.textMuted
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchWorkspace(wsCard.modelData.id)
                    }

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        Text {
            visible: root.workspaces.length === 0
            Layout.fillWidth: true
            text: "Hyprland не виявлено"
            color: Theme.textMuted
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.fillHeight: true }
    }
}
