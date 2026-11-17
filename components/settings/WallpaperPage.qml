import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import ".."
import "../widgets"

Item {
    id: page
    anchors.fill: parent

    property string bindingState: "unknown"
    property string bindingDetail: ""

    readonly property var modeValues: ["fill", "fit", "stretch", "center"]
    readonly property var modeLabels: ["Fill", "Fit", "Stretch", "Center"]

    function urlToPath(u) {
        var s = String(u || "")
        if (s.indexOf("file://") === 0)
            s = s.substring(7)
        try {
            s = decodeURIComponent(s)
        } catch (e) {
            // залишаємо як є
        }
        return s
    }

    function modeIndex(value) {
        var idx = page.modeValues.indexOf(String(value || "fill").toLowerCase())
        return idx >= 0 ? idx : 0
    }

    function checkBinding() {
        page.bindingState = "checking"
        page.bindingDetail = ""
        if (bindingProc.running)
            bindingProc.running = false
        bindingProc.running = true
    }

    function statusColor() {
        if (page.bindingState === "ok")
            return Theme.wpSuccess
        if (page.bindingState === "conflict")
            return Theme.wpError
        if (page.bindingState === "missing")
            return Theme.wpWarning
        return Theme.textMuted
    }

    function statusText() {
        if (page.bindingState === "ok")
            return "АКТИВНИЙ"
        if (page.bindingState === "conflict")
            return "КОНФЛІКТ"
        if (page.bindingState === "missing")
            return "НЕ ЗНАЙДЕНО"
        if (page.bindingState === "checking")
            return "ПЕРЕВІРКА…"
        return "НЕВІДОМО"
    }

    Component.onCompleted: {
        WallpaperService.ensureScanned()
        page.checkBinding()
    }

    Connections {
        target: WallpaperService
        function onScanFinished() { /* стан оновлюється через властивості */ }
    }

    Flickable {
        id: pageFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.textMuted
                opacity: 0.4
            }
        }

        ColumnLayout {
            id: pageColumn
            x: 20
            y: 20
            width: pageFlick.width - 40
            spacing: 16

            // ================= HEADER =================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Шпалери"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        text: "Wallpaper Studio · локальна колекція та застосування через hyprpaper"
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    implicitWidth: launchPill.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: Qt.rgba(Theme.wpIce.r, Theme.wpIce.g, Theme.wpIce.b, 0.10)
                    border.width: 1
                    border.color: Theme.wpBorderFocus

                    Text {
                        id: launchPill
                        anchors.centerIn: parent
                        text: "SUPER + A"
                        color: Theme.wpIce
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                WidgetButton {
                    text: "Відкрити Picker"
                    tone: "accent"
                    onClicked: WallpaperService.requestOpenPicker()
                }
            }

            // ================= COLLECTION =================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: collectionCol.implicitHeight + 28
                radius: Theme.radiusLg
                color: Theme.glassCard
                border.width: 1
                border.color: Theme.glassBorder

                ColumnLayout {
                    id: collectionCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "КОЛЕКЦІЯ"
                            color: Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: WallpaperService.loading
                                  ? "Сканування…"
                                  : (WallpaperService.totalCount + " зображень"
                                     + (WallpaperService.truncated ? " · ліміт 2000" : ""))
                            color: Theme.textSub
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        WidgetTextField {
                            id: folderField
                            Layout.fillWidth: true
                            text: Config.wallpaperFolder
                            placeholderText: "Шлях до папки з обоями"
                            onEditingFinished: {
                                if (text.trim() !== "" && text.trim() !== Config.wallpaperFolder)
                                    WallpaperService.setFolder(text.trim())
                            }
                        }

                        WidgetButton {
                            text: "Обрати папку"
                            onClicked: folderDialog.open()
                        }

                        WidgetButton {
                            text: "Оновити"
                            onClicked: WallpaperService.refresh()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: WallpaperService.resolvedFolder !== ""
                        text: "Сканується: " + WallpaperService.resolvedFolder
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: WallpaperService.error.length > 0
                        implicitHeight: collectionError.implicitHeight + 16
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b, 0.45)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: "󰅚"
                                color: Theme.accentRed
                                font.family: Theme.fontMono
                                font.pixelSize: 14
                            }
                            Text {
                                id: collectionError
                                Layout.fillWidth: true
                                text: WallpaperService.error
                                color: Theme.accentRed
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Підтримуються png, jpg, jpeg, webp"
                              + (WallpaperService.supportsAvif ? ", avif" : "")
                              + ". Сканується лише вибрана папка (без підпапок)."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            // ================= APPLY =================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: applyCol.implicitHeight + 28
                radius: Theme.radiusLg
                color: Theme.glassCard
                border.width: 1
                border.color: Theme.glassBorder

                ColumnLayout {
                    id: applyCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "ЗАСТОСУВАННЯ"
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 190
                            Layout.preferredHeight: 108
                            radius: Theme.radiusMd
                            color: Theme.bgCrust
                            border.width: 1
                            border.color: Theme.glassBorder
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: Config.wallpaperCurrentPath
                                        ? WallpaperService.fileUrl(Config.wallpaperCurrentPath) : ""
                                sourceSize.width: 380
                                sourceSize.height: 220
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                                visible: Config.wallpaperCurrentPath !== ""
                                         && status !== Image.Error
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: Config.wallpaperCurrentPath === ""
                                text: "󰸉"
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 30
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                Layout.fillWidth: true
                                text: Config.wallpaperCurrentPath !== ""
                                      ? WallpaperService.baseName(Config.wallpaperCurrentPath)
                                      : "Обої ще не застосовані"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Config.wallpaperCurrentPath !== ""
                                      ? Config.wallpaperCurrentPath
                                      : "Виберіть зображення у Wallpaper Picker"
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                WidgetComboBox {
                                    id: pageMonitorCombo
                                    Layout.preferredWidth: 180
                                    model: WallpaperService.monitorOptions()
                                    currentIndex: WallpaperService.monitorIndex(
                                                      Config.wallpaperMonitor)
                                    onActivated: function(index) {
                                        WallpaperService.setMonitor(
                                                    WallpaperService.monitorValueAt(index))
                                    }
                                }

                                WidgetComboBox {
                                    id: pageModeCombo
                                    Layout.preferredWidth: 140
                                    model: page.modeLabels
                                    currentIndex: page.modeIndex(Config.wallpaperFillMode)
                                    onActivated: function(index) {
                                        WallpaperService.setFillMode(page.modeValues[index])
                                    }
                                }

                                WidgetButton {
                                    text: "Застосувати"
                                    tone: "accent"
                                    enabled: Config.wallpaperCurrentPath !== ""
                                             && !WallpaperService.applying
                                    onClicked: WallpaperService.applyWallpaper(
                                                   Config.wallpaperCurrentPath,
                                                   Config.wallpaperMonitor,
                                                   Config.wallpaperFillMode)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: WallpaperService.applyStatus.length > 0
                                 && WallpaperService.applyError.length === 0
                        text: WallpaperService.applyStatus
                        color: Theme.accentGreen
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: WallpaperService.applyError.length > 0
                        text: WallpaperService.applyError
                        color: Theme.accentRed
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            // ================= LAUNCH =================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: launchCol.implicitHeight + 28
                radius: Theme.radiusLg
                color: Theme.glassCard
                border.width: 1
                border.color: Theme.glassBorder

                ColumnLayout {
                    id: launchCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "ЗАПУСК"
                            color: Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: bindingLabel.implicitWidth + 18
                            implicitHeight: 22
                            radius: 11
                            color: Qt.rgba(page.statusColor().r, page.statusColor().g,
                                           page.statusColor().b, 0.14)
                            border.width: 1
                            border.color: page.statusColor()

                            Text {
                                id: bindingLabel
                                anchors.centerIn: parent
                                text: page.statusText()
                                color: page.statusColor()
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "SUPER + A"
                            color: Theme.wpIce
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "відкриває / закриває Wallpaper Picker"
                            color: Theme.textSub
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }

                        WidgetButton {
                            text: "Перевірити бинд"
                            onClicked: page.checkBinding()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: page.bindingDetail !== ""
                        text: page.bindingDetail
                        color: page.bindingState === "conflict" ? Theme.accentRed
                             : page.bindingState === "missing" ? Theme.accentYellow
                             : Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.glassBorder
                    }

                    WidgetSwitch {
                        Layout.fillWidth: true
                        text: "Відновлювати останні обої після запуску"
                        checked: Config.wallpaperRestoreOnStartup
                        onToggled: Config.setProp("Wallpaper.restoreOnStartup", checked)
                    }

                    WidgetSwitch {
                        Layout.fillWidth: true
                        text: "Відкривати Picker після запуску оболонки"
                        checked: Config.wallpaperOpenOnStartup
                        onToggled: Config.setProp("Wallpaper.openOnStartup", checked)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Picker працює як окреме вікно і не залежить від відкритих Налаштувань."
                        color: Theme.textMuted
                        font.pixelSize: 9
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ================= FOLDER DIALOG =================
    FolderDialog {
        id: folderDialog
        title: "Оберіть папку з обоями"
        currentFolder: "file://" + (WallpaperService.expandPath(
                           Config.wallpaperFolder) || Quickshell.env("HOME"))
        onAccepted: {
            WallpaperService.setFolder(page.urlToPath(selectedFolder))
        }
    }

    // ================= BIND CHECK =================
    Process {
        id: bindingProc
        command: ["sh", "-c",
            "grep -n -A2 -F 'SUPER + A' \"$1\" 2>/dev/null || true",
            "sh", Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"]
        stdout: StdioCollector {
            id: bindingOut
            waitForEnd: true
        }
        onExited: function(code, status) {
            var out = String(bindingOut.text || "").trim()
            if (out === "") {
                page.bindingState = "missing"
                page.bindingDetail = "У ~/.config/hypr/hyprland.lua не знайдено бинд SUPER + A."
                return
            }
            if (out.indexOf("wallpaper toggle") >= 0) {
                page.bindingState = "ok"
                page.bindingDetail = "Super + A → quickshell ipc call wallpaper toggle"
            } else {
                page.bindingState = "conflict"
                page.bindingDetail = "Super + A зайнято іншою дією: " + out
            }
        }
    }
}
