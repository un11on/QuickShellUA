
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    id: root
    spacing: 7

    // Версия списка окон — меняется при IPC-событиях
    property int windowsRevision: 0

    // Реагируем на изменения окон непосредственно от Hyprland
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

    function getAppIcon(className) {
        var c = String(className || "").toLowerCase();

        if (c.includes("zen"))
            return "file:///home/union/.local/share/icons/Papirus/48x48/apps/zen-browser.svg";

        if (c.includes("telegram"))
            return "file:///usr/share/icons/hicolor/256x256/apps/org.telegram.desktop.png";

        if (c.includes("kitty"))
            return "file:///home/union/.local/share/icons/Papirus/48x48/apps/kitty.svg";

        if (c.includes("code-oss") || c.includes("vscode"))
            return "file:///usr/share/pixmaps/com.visualstudio.code.oss.png";

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

        // Системная тема для остальных приложений
        return Quickshell.iconPath(c, true);
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: wsRect

            required property var modelData

            // Обновляем фильтр при изменении windowsRevision
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

            implicitWidth: contentRow.implicitWidth
                + (isFocused ? 28 : 20)

            implicitHeight: 32
            radius: 11

            color: isFocused
                ? "#89b4fa"
                : workspaceWindows.length > 0
                    ? (mouseArea.containsMouse ? "#45475a" : "#313244")
                    : (mouseArea.containsMouse ? "#313244" : "#1e1e2e")

            border.color: isFocused ? "#b4befe" : "#45475a"
            border.width: 1

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            Behavior on color {
                ColorAnimation { duration: 180 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 180 }
            }

            RowLayout {
                id: contentRow

                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: wsRect.modelData.id
                    color: wsRect.isFocused
                        ? "#11111b"
                        : "#cdd6f4"

                    font.pixelSize: 14
                    font.bold: true

                    verticalAlignment: Text.AlignVCenter
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

                        source: root.getAppIcon(appClass)

                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.minimumWidth: 24
                        Layout.maximumWidth: 24

                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        cache: true

                        visible: source !== ""

                        scale: 0.1
                        opacity: 0

                        Component.onCompleted: animIn.start()

                        ParallelAnimation {
                            id: animIn

                            NumberAnimation {
                                target: appIcon
                                property: "scale"
                                to: 1
                                duration: 350
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.5
                            }

                            NumberAnimation {
                                target: appIcon
                                property: "opacity"
                                to: 1
                                duration: 250
                            }
                        }
                    }
                }
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
