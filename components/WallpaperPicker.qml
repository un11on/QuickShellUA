import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."
import "./widgets"

PanelWindow {
    id: picker

    // ================= PUBLIC STATE =================
    property bool shown: false
    property bool closing: false
    property string selectedPath: ""
    property string searchText: ""
    property var filtered: []

    signal settingsRequested()

    readonly property var selectedImage: {
        var list = WallpaperService.images
        for (var i = 0; i < list.length; ++i) {
            if (list[i].path === picker.selectedPath)
                return list[i]
        }
        return null
    }

    readonly property string selectedName: picker.selectedImage
            ? picker.selectedImage.name : ""

    visible: picker.shown
    color: "transparent"

    // Пикер обоев открывается с панели — используем её монитор.
    screen: PanelController.panelScreen
            ? PanelController.panelScreen
            : (Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name : ""))
               || Quickshell.screens[0])

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: picker.shown
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ================= OPEN / CLOSE =================
    function open() {
        if (picker.shown && !picker.closing)
            return
        closeTimer.stop()
        picker.closing = false
        picker.shown = true
        if (!WallpaperService.applying) {
            WallpaperService.applyError = ""
            WallpaperService.applyStatus = ""
        }
        WallpaperService.refreshCurrent()
        WallpaperService.ensureScanned()
        Qt.callLater(function() {
            searchField.forceActiveFocus()
            picker.ensureSelection()
        })
    }

    function close() {
        if (!picker.shown || picker.closing)
            return
        picker.closing = true
        closeTimer.restart()
    }

    function toggle() {
        if (picker.shown && !picker.closing)
            picker.close()
        else
            picker.open()
    }

    function updateFiltered() {
        var needle = picker.searchText.trim().toLowerCase()
        var source = WallpaperService.images
        var out = []
        for (var i = 0; i < source.length; ++i) {
            if (needle === ""
                    || String(source[i].name).toLowerCase().indexOf(needle) >= 0)
                out.push(source[i])
        }
        picker.filtered = out
        picker.ensureSelection()
    }

    function ensureSelection() {
        var list = picker.filtered
        if (list.length === 0) {
            picker.selectedPath = ""
            return
        }
        for (var i = 0; i < list.length; ++i) {
            if (list[i].path === picker.selectedPath)
                return
        }
        if (WallpaperService.currentPath !== "") {
            for (var j = 0; j < list.length; ++j) {
                if (list[j].path === WallpaperService.currentPath) {
                    picker.selectedPath = list[j].path
                    return
                }
            }
        }
        picker.selectedPath = list[0].path
    }

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

    Component.onCompleted: picker.updateFiltered()

    Connections {
        target: WallpaperService
        function onImagesChanged() { picker.updateFiltered() }
        function onScanFinished() { picker.updateFiltered() }
        function onCurrentPathChanged() { picker.ensureSelection() }
        function onOpenPickerRequested() { picker.open() }
    }

    Shortcut {
        sequence: "Escape"
        enabled: picker.shown
        onActivated: picker.close()
    }

    Timer {
        id: closeTimer
        interval: Math.max(1, Theme.animNormal)
        repeat: false
        onTriggered: {
            picker.shown = false
            picker.closing = false
        }
    }

    // ================= IPC =================
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            picker.toggle()
        }

        function open(): void {
            picker.open()
        }

        function close(): void {
            picker.close()
        }

        function refresh(): string {
            WallpaperService.refresh()
            return "started"
        }

        function setFolder(path: string): string {
            WallpaperService.setFolder(path)
            return "started"
        }

        function apply(path: string, monitor: string, mode: string): string {
            WallpaperService.applyWallpaper(path, monitor, mode, false)
            return "started"
        }

        function settings(): void {
            picker.settingsRequested()
        }

        function state(): string {
            return JSON.stringify({
                shown: picker.shown,
                closing: picker.closing,
                folder: WallpaperService.folder,
                resolvedFolder: WallpaperService.resolvedFolder,
                total: WallpaperService.totalCount,
                filtered: picker.filtered.length,
                current: WallpaperService.currentPath,
                selected: picker.selectedPath,
                monitor: Config.wallpaperMonitor,
                mode: Config.wallpaperFillMode,
                loading: WallpaperService.loading,
                error: WallpaperService.error,
                backendReady: WallpaperService.backendReady,
                backendError: WallpaperService.backendError,
                applying: WallpaperService.applying,
                applyStatus: WallpaperService.applyStatus,
                applyError: WallpaperService.applyError
            })
        }
    }

    // ================= INLINE COMPONENTS =================
    component CyberButton: Rectangle {
        id: btn

        property string label: ""
        property string glyph: ""
        property bool primary: false
        property bool danger: false
        signal clicked()

        implicitWidth: Math.max(34, btnRow.implicitWidth + 20)
        implicitHeight: 34
        radius: Theme.radiusSm
        color: btn.primary
                ? (btnMa.containsMouse
                   ? Qt.rgba(Theme.wpIce.r, Theme.wpIce.g, Theme.wpIce.b, 0.22)
                   : Qt.rgba(Theme.wpIce.r, Theme.wpIce.g, Theme.wpIce.b, 0.12))
                : btn.danger
                  ? (btnMa.containsMouse
                     ? Qt.rgba(Theme.wpError.r, Theme.wpError.g, Theme.wpError.b, 0.22)
                     : Qt.rgba(Theme.wpError.r, Theme.wpError.g, Theme.wpError.b, 0.08))
                  : (btnMa.containsMouse ? Theme.wpSurfaceHover : Theme.wpSurface)
        border.width: 1
        border.color: btn.primary ? Theme.wpBorderFocus
                    : btn.danger ? Qt.rgba(Theme.wpError.r, Theme.wpError.g, Theme.wpError.b, 0.55)
                    : btnMa.containsMouse ? Theme.wpBorderHover : Theme.wpBorder
        opacity: btn.enabled ? 1 : 0.38

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                visible: btn.glyph !== ""
                text: btn.glyph
                color: btn.primary ? Theme.wpIce
                     : btn.danger ? Theme.wpError
                     : Theme.wpTextSub
                font.family: Theme.fontMono
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: btn.label !== ""
                text: btn.label
                color: btn.primary ? Theme.wpIceBright
                     : btn.danger ? Theme.wpError
                     : Theme.wpText
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.bold: btn.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component CyberSearch: TextField {
        id: field

        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        color: Theme.wpText
        placeholderTextColor: Theme.wpTextMuted
        selectionColor: Theme.wpIce
        selectedTextColor: Theme.wpBg
        font.family: Theme.fontMono
        font.pixelSize: 11
        selectByMouse: true

        background: Rectangle {
            radius: Theme.radiusSm
            color: field.activeFocus ? Theme.wpSurfaceActive
                 : field.hovered ? Theme.wpSurfaceHover : Theme.wpSurface
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? Theme.wpBorderFocus
                        : field.hovered ? Theme.wpBorderHover : Theme.wpBorder
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    component CyberCombo: ComboBox {
        id: combo

        implicitHeight: 32
        leftPadding: 10
        rightPadding: 30
        hoverEnabled: true

        contentItem: Text {
            leftPadding: 0
            rightPadding: 0
            text: combo.displayText
            color: Theme.wpText
            font.family: Theme.fontMono
            font.pixelSize: 10
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: combo.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: combo.popup.visible || combo.hovered ? Theme.wpIce : Theme.wpTextMuted
            font.family: Theme.fontMono
            font.pixelSize: 12
            rotation: combo.popup.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.animFast } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        background: Rectangle {
            radius: Theme.radiusSm
            color: combo.down ? Theme.wpSurfaceActive
                 : combo.hovered ? Theme.wpSurfaceHover : Theme.wpSurface
            border.width: combo.activeFocus || combo.popup.visible ? 2 : 1
            border.color: combo.activeFocus || combo.popup.visible ? Theme.wpBorderFocus
                        : combo.hovered ? Theme.wpBorderHover : Theme.wpBorder
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        }

        delegate: ItemDelegate {
            id: option
            width: combo.popup.width - 8
            implicitHeight: 32
            highlighted: combo.highlightedIndex === index

            contentItem: Text {
                text: modelData
                color: option.highlighted ? Theme.wpIce : Theme.wpTextSub
                font.family: Theme.fontMono
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: Theme.radiusSm
                color: option.highlighted ? Theme.wpSurfaceHover : "transparent"
            }
        }

        popup: Popup {
            y: combo.height + 5
            width: combo.width
            implicitHeight: Math.min(250, contentItem.implicitHeight + 8)
            padding: 4

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.delegateModel
                currentIndex: combo.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
                ScrollIndicator.vertical: ScrollIndicator { }
            }
            background: Rectangle {
                radius: Theme.radiusMd
                color: Theme.wpPanel
                border.color: Theme.wpBorderHover
                border.width: 1
            }
        }
    }

    // ================= BACKDROP =================
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.01, 0.02, 0.04, 0.72)
        opacity: picker.shown && !picker.closing ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: picker.close()
        }
    }

    // ================= PANEL =================
    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1320, parent.width - 72)
        height: Math.min(820, parent.height - 72)
        radius: Theme.radiusXl
        color: Theme.wpPanel
        border.width: 1
        border.color: picker.closing ? Theme.wpBorder : Theme.wpBorderHover
        opacity: picker.shown && !picker.closing ? 1 : 0
        scale: picker.shown && !picker.closing ? 1 : 0.94

        Behavior on opacity {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animUseSpring ? Theme.animNormal : Theme.animFast
                easing.type: Theme.animUseSpring ? Theme.easingSpring : Theme.easingStandard
                easing.overshoot: Theme.easingOvershoot
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // поглинаємо клік
        }

        // Ice-cyber фон
        Rectangle {
            anchors.fill: parent
            radius: panel.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.wpBgDeep }
                GradientStop { position: 0.55; color: Theme.wpBg }
                GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.06, 0.11, 1.0) }
            }
        }

        // Ледь помітна технічна сітка
        Repeater {
            model: 26
            Rectangle {
                x: Math.round(index * (panel.width / 26))
                y: 0
                width: 1
                height: panel.height
                color: Theme.wpGridLine
            }
        }
        Repeater {
            model: 14
            Rectangle {
                x: 0
                y: Math.round(index * (panel.height / 14))
                width: panel.width
                height: 1
                color: Theme.wpGridLine
            }
        }

        // Верхня акцентна лінія
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Theme.wpGlow }
                GradientStop { position: 0.5; color: Theme.wpIce }
                GradientStop { position: 0.8; color: Theme.wpGlow }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ================= TOP BAR =================
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                spacing: 10

                RowLayout {
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: Qt.rgba(Theme.wpIce.r, Theme.wpIce.g, Theme.wpIce.b, 0.12)
                        border.width: 1
                        border.color: Theme.wpBorderFocus

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉"
                            color: Theme.wpIce
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: "WALLPAPER STUDIO"
                            color: Theme.wpIceBright
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            font.bold: true
                            font.letterSpacing: 1.4
                        }
                        Text {
                            text: "ICE-CYBER COLLECTION"
                            color: Theme.wpTextMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            font.letterSpacing: 1.8
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                CyberSearch {
                    id: searchField
                    Layout.preferredWidth: Math.min(280, Math.max(180, panel.width * 0.22))
                    placeholderText: "Пошук за назвою…"
                    onTextChanged: {
                        picker.searchText = text
                        picker.updateFiltered()
                    }
                }

                Text {
                    text: WallpaperService.loading
                          ? "СКАНУВАННЯ…"
                          : (picker.filtered.length + " / " + WallpaperService.totalCount)
                    color: Theme.wpTextSub
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.bold: true
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                }

                CyberButton {
                    glyph: "󰉋"
                    label: "ПАПКА"
                    onClicked: folderDialog.open()
                }

                CyberButton {
                    glyph: "󰑐"
                    onClicked: WallpaperService.refresh()
                }

                CyberButton {
                    glyph: "󰒓"
                    onClicked: {
                        picker.close()
                        picker.settingsRequested()
                    }
                }

                CyberButton {
                    glyph: "✕"
                    danger: true
                    onClicked: picker.close()
                }
            }

            // ================= ERROR BANNER =================
            Rectangle {
                Layout.fillWidth: true
                visible: WallpaperService.error.length > 0
                implicitHeight: errorText.implicitHeight + 14
                radius: Theme.radiusSm
                color: Qt.rgba(Theme.wpError.r, Theme.wpError.g, Theme.wpError.b, 0.10)
                border.width: 1
                border.color: Qt.rgba(Theme.wpError.r, Theme.wpError.g, Theme.wpError.b, 0.45)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 8

                    Text {
                        text: "󰅚"
                        color: Theme.wpError
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }
                    Text {
                        id: errorText
                        Layout.fillWidth: true
                        text: WallpaperService.error
                        color: Theme.wpError
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            // ================= MAIN =================
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // ---------- PREVIEW ----------
                Rectangle {
                    Layout.preferredWidth: Math.max(320, Math.min(430, panel.width * 0.34))
                    Layout.fillHeight: true
                    radius: Theme.radiusLg
                    color: Qt.rgba(0.03, 0.07, 0.12, 0.72)
                    border.width: 1
                    border.color: Theme.wpBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 200
                            radius: Theme.radiusMd
                            color: Theme.wpBgDeep
                            border.width: 1
                            border.color: Theme.wpBorder
                            clip: true

                            Image {
                                id: previewImage
                                anchors.fill: parent
                                anchors.margins: 6
                                source: picker.selectedPath
                                        ? WallpaperService.fileUrl(picker.selectedPath) : ""
                                sourceSize.width: 900
                                sourceSize.height: 620
                                asynchronous: true
                                cache: true
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                visible: picker.selectedPath !== ""
                                        && status !== Image.Error
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.animNormal }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: picker.selectedPath === ""
                                text: "󰸉"
                                color: Theme.wpTextMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 44
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: picker.selectedPath === ""

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Виберіть зображення"
                                    color: Theme.wpTextSub
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "з колекції праворуч"
                                    color: Theme.wpTextMuted
                                    font.pixelSize: 9
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: picker.selectedPath !== ""
                                        && previewImage.status === Image.Loading

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰔟"
                                    color: Theme.wpIce
                                    font.family: Theme.fontMono
                                    font.pixelSize: 26
                                    RotationAnimator on rotation {
                                        from: 0; to: 360
                                        duration: 1100
                                        loops: Animation.Infinite
                                        running: previewImage.status === Image.Loading
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Завантаження прев'ю…"
                                    color: Theme.wpTextMuted
                                    font.pixelSize: 9
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: picker.selectedPath !== ""
                                        && previewImage.status === Image.Error

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰋩"
                                    color: Theme.wpError
                                    font.family: Theme.fontMono
                                    font.pixelSize: 28
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Не вдалося завантажити прев'ю"
                                    color: Theme.wpError
                                    font.pixelSize: 9
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: picker.selectedName !== "" ? picker.selectedName : "—"
                                color: Theme.wpText
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                visible: picker.selectedPath !== ""
                                        && WallpaperService.currentPath === picker.selectedPath
                                implicitWidth: currentLabel.implicitWidth + 14
                                implicitHeight: 20
                                radius: 10
                                color: Qt.rgba(0.37, 0.95, 0.75, 0.12)
                                border.width: 1
                                border.color: Theme.wpSuccess

                                Text {
                                    id: currentLabel
                                    anchors.centerIn: parent
                                    text: "ПОТОЧНІ"
                                    color: Theme.wpSuccess
                                    font.family: Theme.fontMono
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: picker.selectedPath !== ""
                                  ? picker.selectedPath
                                  : "Папка: " + (WallpaperService.folder || "не вибрана")
                            color: Theme.wpTextMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.wpBorder
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: "МОНІТОР"
                                    color: Theme.wpTextMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                                CyberCombo {
                                    id: monitorCombo
                                    Layout.fillWidth: true
                                    model: WallpaperService.monitorOptions()
                                    currentIndex: WallpaperService.monitorIndex(
                                                      Config.wallpaperMonitor)
                                    onActivated: function(index) {
                                        WallpaperService.setMonitor(
                                                    WallpaperService.monitorValueAt(index))
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: "РЕЖИМ"
                                    color: Theme.wpTextMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                                CyberCombo {
                                    id: modeCombo
                                    Layout.fillWidth: true
                                    model: ["Fill", "Fit", "Stretch", "Center"]
                                    currentIndex: Math.max(0, ["fill", "fit", "stretch", "center"]
                                                   .indexOf(Config.wallpaperFillMode))
                                    onActivated: function(index) {
                                        WallpaperService.setFillMode(
                                            ["fill", "fit", "stretch", "center"][index])
                                    }
                                }
                            }
                        }

                        CyberButton {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            label: WallpaperService.applying
                                   ? "ЗАСТОСУВАННЯ…"
                                   : "ЗАСТОСУВАТИ ОБОЇ"
                            glyph: WallpaperService.applying ? "󰔟" : "󰄬"
                            primary: true
                            enabled: picker.selectedPath !== ""
                                     && !WallpaperService.applying
                            onClicked: WallpaperService.applyWallpaper(
                                           picker.selectedPath,
                                           Config.wallpaperMonitor,
                                           Config.wallpaperFillMode)
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: WallpaperService.applyStatus.length > 0
                                     && WallpaperService.applyError.length === 0
                            text: WallpaperService.applyStatus
                            color: Theme.wpSuccess
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: WallpaperService.applyError.length > 0
                            text: WallpaperService.applyError
                            color: Theme.wpError
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: WallpaperService.currentPath !== ""
                            text: "Зараз: " + WallpaperService.baseName(
                                      WallpaperService.currentPath)
                            color: Theme.wpTextMuted
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            elide: Text.ElideMiddle
                        }
                    }
                }

                // ---------- GRID ----------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusLg
                    color: Qt.rgba(0.03, 0.07, 0.12, 0.55)
                    border.width: 1
                    border.color: Theme.wpBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "КОЛЕКЦІЯ"
                                color: Theme.wpTextMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.5
                            }

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 3
                                color: Theme.wpIce
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: WallpaperService.truncated
                                      ? "ЛІМІТ 2000"
                                      : "ЛОКАЛЬНІ ФАЙЛИ"
                                color: Theme.wpTextMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            GridView {
                                id: grid
                                anchors.fill: parent
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                cacheBuffer: 420
                                cellWidth: Math.max(120, width / Math.max(2,
                                           Math.floor(width / 188)))
                                cellHeight: Math.round(cellWidth * 0.72)
                                model: picker.filtered
                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: Theme.wpIceDim
                                        opacity: 0.55
                                    }
                                }

                                delegate: WallpaperCard {
                                    width: grid.cellWidth - 10
                                    height: grid.cellHeight - 10
                                    path: modelData.path
                                    name: modelData.name
                                    isCurrent: WallpaperService.currentPath === modelData.path
                                    isSelected: picker.selectedPath === modelData.path
                                    onActivated: {
                                        picker.selectedPath = modelData.path
                                    }
                                }
                            }

                            // Порожній стан
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !WallpaperService.loading
                                         && picker.filtered.length === 0

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰸉"
                                    color: Theme.wpTextMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 40
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: WallpaperService.error.length > 0
                                          ? "Колекція недоступна"
                                          : "Нічого не знайдено"
                                    color: Theme.wpTextSub
                                    font.family: Theme.fontMono
                                    font.pixelSize: 12
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(360, grid.width - 40)
                                    text: WallpaperService.error.length > 0
                                          ? WallpaperService.error
                                          : "Змініть пошуковий запит або виберіть іншу папку"
                                    color: Theme.wpTextMuted
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }
                            }

                            // Індикатор сканування
                            Rectangle {
                                anchors.fill: parent
                                visible: WallpaperService.loading
                                color: Qt.rgba(0.02, 0.04, 0.07, 0.55)
                                radius: Theme.radiusMd

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰔟"
                                        color: Theme.wpIce
                                        font.family: Theme.fontMono
                                        font.pixelSize: 30
                                        RotationAnimator on rotation {
                                            from: 0; to: 360
                                            duration: 1100
                                            loops: Animation.Infinite
                                            running: WallpaperService.loading
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Сканування колекції…"
                                        color: Theme.wpTextSub
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= FOLDER DIALOG =================
    FolderDialog {
        id: folderDialog
        title: "Оберіть папку з обоями"
        currentFolder: "file://" + (WallpaperService.expandPath(
                           WallpaperService.folder) || Quickshell.env("HOME"))
        onAccepted: {
            WallpaperService.setFolder(picker.urlToPath(selectedFolder))
        }
    }
}
