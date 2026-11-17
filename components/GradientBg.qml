import QtQuick 2.15
import "."

Rectangle {
    id: root
    clip: true

    property bool enabled: false
    property real intensity: 1.0
    property string target: "bg"
    property color solidColor: Theme.glassCard


    readonly property bool hasColor3: Config.themeGradientColor3 !== ""

    readonly property color c1: Theme._gradIntensify(Theme.cfgGradientColor1, root.intensity)
    readonly property color c2: Theme._gradIntensify(Theme.cfgGradientColor2, root.intensity)
    readonly property color c3: Theme._gradIntensify(Theme.cfgGradientColor3, root.intensity)

    // Base solid color (shown when gradient disabled for this component)
    color: root.enabled ? "transparent" : root.solidColor
    border.color: Theme.glassBorder
    border.width: 1

    // Gradient layer (always horizontal, left to right)
    Rectangle {
        visible: root.enabled
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.c1 }
            GradientStop { position: root.hasColor3 ? 0.5 : 1.0; color: root.hasColor3 ? root.c3 : root.c2 }
            GradientStop { position: 1.0; color: root.c2 }
        }
        color: "transparent"
        transformOrigin: Item.Center
    }

    // Solid fallback layer (shown when gradient disabled)
    Rectangle {
        visible: !root.enabled
        anchors.fill: parent
        radius: root.radius
        color: root.solidColor
    }
}
