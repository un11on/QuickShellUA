import QtQuick
import Quickshell
import "./components"

ShellRoot {
    // Глобальное состояние видимости ИИ-панели
    property bool aiSidebarVisible: false

    // Верхняя панель
    TopBar {
        id: topBar
        onToggleAiRequested: aiSidebarVisible = !aiSidebarVisible
    }

    // Боковая панель ИИ-агента
    AiSidebar {
        id: aiSidebar
        visible: aiSidebarVisible
        onCloseRequested: aiSidebarVisible = false
    }
}