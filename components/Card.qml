import QtQuick
import "."

Rectangle {
    radius: Theme.radiusLg
    color: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf ? "transparent" : Theme.glassCard
    border.color: Theme.glassBorder
    border.width: 1

    GradientBg {
        anchors.fill: parent
        enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplySurf
        intensity: Theme.cfgGradientIntensity
        target: "surf"
        solidColor: Theme.glassCard
        radius: Theme.radiusLg
        clip: true
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }
}
