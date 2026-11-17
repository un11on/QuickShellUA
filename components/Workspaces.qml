import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    property bool iconsVisible: true
    property int windowsRevision: 0

    // Стиль індикатора з Config.Panel.workspaceStyle. Невідоме/відсутнє
    // значення (старі settings.json) безпечно трактується як Smart.
    readonly property string workspaceStyle: {
        var s = String(Config.panelWorkspaceStyle || "")
        return ["smart", "dots", "segments", "blocks", "bars"].indexOf(s) >= 0
            ? s : "smart"
    }

    readonly property int workspaceSpacing: {
        switch (workspaceStyle) {
            case "dots":     return 5
            case "segments": return 6
            case "blocks":   return 5
            case "bars":     return 6
            default:         return 7
        }
    }

    implicitWidth: layout.implicitWidth + 20
    implicitHeight: layout.implicitHeight + 16

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.topMargin: 8
        anchors.rightMargin: 10
        anchors.bottomMargin: 8
        spacing: root.workspaceSpacing

        property var getAppIconFn: function(className) {
            var c = String(className || "").toLowerCase();

            if (c.includes("zen"))
                return Quickshell.iconPath("zen-browser", "application-x-executable");

            if (c.includes("telegram"))
                return Quickshell.iconPath("org.telegram.desktop", "application-x-executable");

            if (c.includes("kitty"))
                return Quickshell.iconPath("kitty", "application-x-executable");

            if (c.includes("code-oss") || c.includes("vscode"))
                return Quickshell.iconPath("com.visualstudio.code.oss", "application-x-executable");

            if (c.includes("firefox"))
                return Quickshell.iconPath("firefox", true);

            if (c.includes("discord") || c.includes("vesktop"))
                return Quickshell.iconPath("discord", true);

            if (c.includes("steam"))
                return Quickshell.iconPath("steam", true);

            if (c.includes("obsidian"))
                return Quickshell.iconPath("obsidian", true);

            if (c.includes("obsproject"))
                return Quickshell.iconPath("com.obsproject.studio", true);

            // Системна тема для решти застосунків
            return Quickshell.iconPath(c, true);
        }

        // Видимость иконок запущенных приложений у номеров рабочих столов.
        // Переключается по Super+X (hyprland.lua → quickshell ipc call workspaces toggleIcons).
        // Скрывается только отображение: модель Hyprland.workspaces/toplevels,
        // фокус и переключение рабочих столов не затрагиваются.
        property bool iconsVisible: root.iconsVisible

        IpcHandler {
            target: "workspaces"

            function toggleIcons() {
                root.iconsVisible = !root.iconsVisible
                console.log("Workspaces: app icons ->", root.iconsVisible ? "visible" : "hidden")
            }

            // Проверка состояния: quickshell ipc call workspaces getIconsVisible
            function getIconsVisible() {
                return root.iconsVisible ? "visible" : "hidden"
            }
        }

        // Версія списку вікон — оновлюється при IPC-подіях

        Connections {
            target: Hyprland

            function onRawEvent(event) {
                var name = event.name;

                if (
                    name === "openwindow"
                    || name === "closewindow"
                    || name === "movewindow"
                    || name === "movewindowv2"
                    || name === "windowtitle"
                    || name === "windowtitlev2"
                ) {
                    Hyprland.refreshToplevels();
                    Hyprland.refreshWorkspaces();
                    root.windowsRevision++;
                }
            }
        }

        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                id: wsRect

                required property var modelData

                readonly property string style: root.workspaceStyle
                readonly property bool isOccupied: workspaceWindows.length > 0
                readonly property color occupiedColor: mouseArea.containsMouse
                    ? Theme.text : Theme.textSub
                readonly property color idleColor: mouseArea.containsMouse
                    ? Theme.glassBorderHover : Theme.glassBorder

                property var workspaceWindows: {
                    root.windowsRevision;

                    return Hyprland.toplevels.values.filter(
                        w => w.workspace
                            && Number(w.workspace.id) === Number(modelData.id)
                    );
                }

                property bool isFocused:
                    Hyprland.focusedWorkspace
                    && Number(Hyprland.focusedWorkspace.id)
                        === Number(modelData.id)

                implicitWidth: {
                    if (style === "dots")     return 16
                    if (style === "segments") return isFocused ? 26 : (isOccupied ? 20 : 16)
                    if (style === "blocks")   return 15
                    if (style === "bars")     return 12
                    return smartRow.implicitWidth + (isFocused ? 26 : 18)
                }

                implicitHeight: 32
                radius: style === "smart" ? Theme.radiusMd : 0
                clip: style === "smart"

                // Smart: матове скло для неактивних, акцент для активного.
                // Інші стилі малюють лише компактний індикатор.
                color: style !== "smart"
                    ? "transparent"
                    : (isFocused
                        ? Theme.accent
                        : (isOccupied
                            ? (mouseArea.containsMouse ? Theme.glassCardActive : Theme.glassCard)
                            : (mouseArea.containsMouse ? Theme.glassBgHover : "transparent")))

                border.color: style !== "smart"
                    ? "transparent"
                    : (isFocused
                        ? Theme.accentHover
                        : (isOccupied
                            ? (mouseArea.containsMouse ? Theme.glassBorderHover : Theme.glassBorder)
                            : (mouseArea.containsMouse ? Theme.glassBorderHover : "transparent")))
                border.width: style === "smart" ? 1 : 0

                scale: mouseArea.pressed ? 0.93 : (mouseArea.containsMouse ? 1.04 : 1.0)

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Theme.easingSpring
                        easing.overshoot: Theme.easingOvershoot
                    }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animFast }
                }

                // ---------- Smart Workspaces ----------
                RowLayout {
                    id: smartRow

                    visible: wsRect.style === "smart"
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        text: wsRect.modelData.id
                        color: wsRect.isFocused
                            ? Theme.textDark
                            : Theme.text

                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        font.bold: true

                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }
                    }

                    Repeater {
                        model: wsRect.workspaceWindows

                        delegate: Image {
                            id: appIcon

                            required property var modelData

                            property string appClass: String(
                                modelData.lastIpcObject
                                    ? modelData.lastIpcObject.class || ""
                                    : ""
                            )

                            source: layout.getAppIconFn(appClass)

                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.minimumWidth: 22
                            Layout.maximumWidth: 22

                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            cache: true

                            // Super+X: скрывать только иконки; номера остаются
                            visible: root.iconsVisible && source !== ""

                            scale: 0.1
                            opacity: 0

                            Component.onCompleted: animIn.start()

                            ParallelAnimation {
                                id: animIn

                                NumberAnimation {
                                    target: appIcon
                                    property: "scale"
                                    to: 1
                                    duration: 320
                                    easing.type: Theme.easingSpring
                                    easing.overshoot: 1.4
                                }

                                NumberAnimation {
                                    target: appIcon
                                    property: "opacity"
                                    to: 1
                                    duration: 220
                                }
                            }
                        }
                    }
                }

                // ---------- Minimal Dots ----------
                Rectangle {
                    visible: wsRect.style === "dots"
                    anchors.centerIn: parent
                    width: wsRect.isFocused ? 10 : (wsRect.isOccupied ? 7 : 6)
                    height: width
                    radius: width / 2
                    color: wsRect.isFocused
                        ? Theme.accent
                        : (wsRect.isOccupied ? wsRect.occupiedColor : wsRect.idleColor)
                    border.width: wsRect.isFocused ? 1 : 0
                    border.color: Theme.accentHover

                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                // ---------- Segments ----------
                Rectangle {
                    visible: wsRect.style === "segments"
                    anchors.centerIn: parent
                    width: wsRect.isFocused ? 22 : (wsRect.isOccupied ? 16 : 12)
                    height: wsRect.isFocused ? 7 : 5
                    radius: height / 2
                    color: wsRect.isFocused
                        ? Theme.accent
                        : (wsRect.isOccupied ? wsRect.occupiedColor : wsRect.idleColor)

                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                // ---------- Blocks ----------
                Rectangle {
                    visible: wsRect.style === "blocks"
                    anchors.centerIn: parent
                    width: wsRect.isFocused ? 12 : (wsRect.isOccupied ? 9 : 8)
                    height: width
                    radius: 2
                    color: wsRect.isFocused
                        ? Theme.accent
                        : (wsRect.isOccupied ? wsRect.occupiedColor : wsRect.idleColor)
                    border.width: wsRect.isFocused ? 1 : 0
                    border.color: Theme.accentHover

                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                // ---------- Bars ----------
                Rectangle {
                    visible: wsRect.style === "bars"
                    anchors.centerIn: parent
                    width: wsRect.isFocused ? 5 : 4
                    height: wsRect.isFocused ? 18 : (wsRect.isOccupied ? 13 : 8)
                    radius: 2
                    color: wsRect.isFocused
                        ? Theme.accent
                        : (wsRect.isOccupied ? wsRect.occupiedColor : wsRect.idleColor)

                    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: wsRect.modelData.activate()
                }
            }
        }
    }
}
