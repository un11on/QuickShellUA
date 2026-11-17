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

    property var allApps: []
    property var favorites: settings.favorites || []
    property string searchQuery: ""

    // Load .desktop files
    Process {
        id: appLoader
        running: false
        command: ["sh", "-c",
            "find /usr/share/applications /usr/local/share/applications " +
            "$HOME/.local/share/applications -name '*.desktop' -maxdepth 2 2>/dev/null | " +
            "while IFS= read -r f; do " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  hidden=$(grep -m1 '^Hidden=' \"$f\" | cut -d= -f2-); " +
            "  if [ -n \"$name\" ] && [ \"$nodisplay\" != \"true\" ] && [ \"$hidden\" != \"true\" ]; then " +
            "    printf '%s\\t%s\\t%s\\n' \"$name\" \"$icon\" \"$exec\"; " +
            "  fi; " +
            "done | sort -t$'\t' -k1,1 -u 2>&1"
        ]
        stdout: StdioCollector { id: appOutput }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                var lines = appOutput.text.trim().split("\n")
                var result = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t")
                    if (parts.length >= 3 && parts[0].trim()) {
                        result.push({
                            name: parts[0].trim(),
                            icon: parts[1] ? parts[1].trim() : "",
                            exec: parts[2] ? parts[2].trim() : ""
                        })
                    }
                }
                root.allApps = result
            } else {
                console.error("QuickLauncher: appLoader exited with code", exitCode)
                console.error("QuickLauncher: stdout/stderr:", appOutput.text)
            }
        }
    }

    Component.onCompleted: {
        if (!root.previewMode)
            appLoader.running = true
    }

    function filteredApps() {
        var needle = root.searchQuery.trim().toLowerCase()
        var result = []

        if (!needle && root.favorites.length > 0) {
            // Show favorites first
            for (var f = 0; f < root.favorites.length; f++) {
                for (var a = 0; a < root.allApps.length; a++) {
                    if (root.allApps[a].name === root.favorites[f]) {
                        result.push(root.allApps[a])
                        break
                    }
                }
            }
            return result
        }

        for (var i = 0; i < root.allApps.length; i++) {
            if (!needle || root.allApps[i].name.toLowerCase().indexOf(needle) >= 0) {
                result.push(root.allApps[i])
            }
        }
        return result.slice(0, 50)
    }

    function launchApp(exec) {
        if (!exec) return
        launchProc.command = ["sh", "-c", exec + " &"]
        launchProc.running = true
    }

    Process {
        id: launchProc
        running: false
    }

    function toggleFavorite(appName) {
        var favs = root.favorites.slice()
        var idx = favs.indexOf(appName)
        if (idx >= 0)
            favs.splice(idx, 1)
        else
            favs.push(appName)
        root.settingChanged("favorites", favs)
    }

    function isFavorite(appName) {
        return root.favorites.indexOf(appName) >= 0
    }

    function getAppInitial(name) {
        return name ? name.charAt(0).toUpperCase() : "?"
    }

    function initialColor(name) {
        if (!name) return Theme.accent
        var hash = 0
        for (var i = 0; i < name.length; i++)
            hash = ((hash << 5) - hash + name.charCodeAt(i)) & 0xffff
        var colors = [Theme.accent, Theme.accentSecondary, Theme.accentTeal,
                      Theme.accentSapphire, Theme.accentGreen, Theme.accentPink, Theme.accentPeach]
        return colors[hash % colors.length]
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰀻"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 22
            }
            Text {
                text: root.searchQuery.length === 0 && root.favorites.length > 0
                    ? "ОБРАНЕ" : "ЗАПУСК"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                text: root.allApps.length + " додатків"
                color: Theme.textMuted
                font.pixelSize: 9
            }
        }

        // Search
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: Theme.radiusSm
            color: Qt.rgba(Theme.bgSurface.r, Theme.bgSurface.g, Theme.bgSurface.b, 0.5)
            border.color: searchInput.activeFocus ? Theme.glassBorderFocus : Theme.glassBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: "󰍉"
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.searchQuery = text
                }
            }

            Text {
                visible: searchInput.text.length === 0 && !searchInput.activeFocus
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                text: "Пошук додатків…"
                color: Theme.textMuted
                font.pixelSize: 12
                font.family: Theme.fontMono
            }
        }

        // App list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: appsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: appsCol
                width: parent.width
                spacing: 3

                Repeater {
                    model: root.filteredApps()
                    delegate: Rectangle {
                        id: appItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 38
                        radius: Theme.radiusSm
                        color: appMouse.containsMouse ? Theme.glassCardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 8

                            // App initial/icon
                            Rectangle {
                                width: 26; height: 26
                                radius: 7
                                color: Qt.rgba(root.initialColor(appItem.modelData.name).r,
                                              root.initialColor(appItem.modelData.name).g,
                                              root.initialColor(appItem.modelData.name).b, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.getAppInitial(appItem.modelData.name)
                                    color: root.initialColor(appItem.modelData.name)
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: appItem.modelData.name
                                color: Theme.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            // Favorite toggle
                            Text {
                                text: root.isFavorite(appItem.modelData.name) ? "★" : "☆"
                                color: root.isFavorite(appItem.modelData.name)
                                    ? Theme.accentYellow : Theme.textMuted
                                font.pixelSize: 14
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleFavorite(appItem.modelData.name)
                                }
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp(appItem.modelData.exec)
                        }
                    }
                }

                Text {
                    visible: root.filteredApps().length === 0
                    Layout.fillWidth: true
                    text: root.allApps.length === 0 ? "Завантаження…" : "Нічого не знайдено"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    padding: 16
                }
            }
        }
    }
}
