import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    property string direction: "row"   // "row" | "column"
    property Item contentItem: null    // Set from TopBar.qml to the GridLayout inside

    // Висота і ширина залежно від напрямку панелі та вмісту.
    // Горизонтальний режим: висота = висота панелі, ширина = ширина вмісту.
    // Вертикальний режим: ширина = висота панелі, висота = висота вмісту.
    implicitHeight: PanelController.isVertical
        ? (contentItem ? contentItem.implicitHeight : Config.panelHeight)
        : Config.panelHeight
    implicitWidth: PanelController.isVertical
        ? (contentItem ? contentItem.implicitWidth : Config.panelHeight)
        : (contentItem ? contentItem.implicitWidth : Config.panelHeight * 2)
    clip: true
    radius: Math.min(Config.panelIslandRadius, height / 2)
    readonly property bool flat: Config.panelBackground

    color: flat ? "transparent" : (Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf ? "transparent" : Theme.glassBg)
    border.color: flat ? "transparent" : Theme.glassBorder
    border.width: 1

    GradientBg {
        anchors.fill: parent
        radius: root.radius
        enabled: !flat && Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
        intensity: Theme.cfgGradientIntensity
        target: "surf"
        solidColor: Theme.glassBg
        clip: true
    }

    Behavior on radius {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
}
