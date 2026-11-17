import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: ccWindow

    // --- Public API ---
    function open() {
        visible = true
    }
    function close() {
        visible = false
    }
    function toggle() {
        visible = !visible
    }

    // Все всплывающие окна закрыты при запуске — открывается только по действию пользователя
    visible: false
    color: "transparent"

    // Окно настроек открывается с панели — используем её монитор.
    // Фолбек нужен только до готовности host-экрана.
    screen: PanelController.panelScreen
        ? PanelController.panelScreen
        : (Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""))
           || Quickshell.screens[0])

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.keyboardFocus: ccWindow.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // --- Внутреннее состояние ---
    property string currentPage: "monitors"

    Shortcut {
        sequence: "Escape"
        enabled: ccWindow.visible
        onActivated: ccWindow.close()
    }

    // --- Закрытие по клику вне окна ---
    // Специально БЕЗ затемнения: полностью прозрачный слой,
    // только ловит клик мимо панельки
    MouseArea {
        anchors.fill: parent
        onClicked: ccWindow.close()
    }

    // --- Основное окно ---
    Rectangle {
        id: ccPanel
        // Центр экрана, поднятый на 40px — работает на любом разрешении
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -40
        width: Math.min(1060, parent.width - 96)
        height: Math.min(660, parent.height - 96)
        radius: Theme.radiusXl
        color: Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        // Блокируем клик на самом окне
        MouseArea {
            anchors.fill: parent
            onClicked: {} // eat click
        }

        opacity: ccWindow.visible ? 1 : 0
        scale: ccWindow.visible ? 1 : 0.92

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

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // --- Sidebar ---
            SettingsSidebar {
                id: navSidebar
                currentPage: ccWindow.currentPage
                onPageRequested: function(pageName) {
                    ccWindow.currentPage = pageName
                }
            }

            // --- Контент ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Кнопка закрытия
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 4
                    anchors.rightMargin: 4
                    width: 28; height: 28; radius: 14
                    color: closeMa.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.2) : "transparent"
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ccWindow.close()
                    }
                }

                // --- Лоадер страниц ---
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    source: {
                        switch (ccWindow.currentPage) {
                            case "overview":   return "settings/OverviewPage.qml"
                            case "appearance": return "settings/AppearancePage.qml"
                            case "panel":      return "settings/PanelPage.qml"
                            case "media":      return "settings/MediaPlayerPage.qml"
                            case "monitors":   return "settings/MonitorsPage.qml"
                            case "wallpaper":  return "settings/WallpaperPage.qml"
                            case "widgets":    return "settings/WidgetsPage.qml"
                            case "animations": return "settings/AnimationsPage.qml"
                            default:           return ""
                        }
                    }

                    // Плавная смена
                    opacity: 1
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }
                }

            }
        }
    }
}
