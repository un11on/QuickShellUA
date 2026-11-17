import QtQuick
import Quickshell
import Quickshell.Io
import "."

Scope {
    id: root

    signal openSettingsRequested()

    // One cheap LazyLoader per connected output; no fullscreen window exists
    // until the monitor has an enabled widget or is explicitly being edited.
    Variants {
        model: Quickshell.screens

        LazyLoader {
            required property var modelData
            active: {
                WidgetManager.revision
                return WidgetManager.loaded && WidgetManager.shouldRenderScreen(modelData)
            }

            WidgetRenderer {
                targetScreen: modelData
            }
        }
    }

    IpcHandler {
        target: "widgets"

        function state(): string {
            return JSON.stringify({
                loaded: WidgetManager.loaded,
                count: WidgetManager.instanceModel.count,
                editScreenKey: WidgetManager.editScreenKey,
                storageError: WidgetStorage.errorMessage,
                metrics: {
                    subscribers: SystemMetricsService.subscriberCount,
                    cpuUsage: SystemMetricsService.cpuUsage,
                    ramUsage: SystemMetricsService.ramUsage,
                    gpuAvailable: SystemMetricsService.gpuAvailable,
                    gpuUsage: SystemMetricsService.gpuUsage,
                    gpuError: SystemMetricsService.gpuError
                },
                weather: WeatherService.entries,
                instances: WidgetManager.serializedInstances()
            })
        }

        function add(widgetId: string, screenName: string): string {
            var screen = WidgetManager.screenByName(screenName)
            if (!screen && Quickshell.screens.length > 0)
                screen = Quickshell.screens[0]
            return WidgetManager.addWidget(widgetId, screen)
        }

        function remove(instanceId: string) {
            WidgetManager.removeWidget(instanceId)
        }

        function enable(instanceId: string, enabled: bool) {
            WidgetManager.setEnabled(instanceId, enabled)
        }

        function geometry(instanceId: string, x: real, y: real, width: real, height: real) {
            WidgetManager.setGeometry(instanceId, x, y, width, height, true)
        }

        function setting(instanceId: string, key: string, value: string) {
            var parsed = value
            if (value === "true") parsed = true
            else if (value === "false") parsed = false
            else if (value !== "" && !isNaN(Number(value))) parsed = Number(value)
            WidgetManager.updateSetting(instanceId, key, parsed)
        }

        function edit(screenName: string) {
            WidgetManager.beginEdit(WidgetManager.screenByName(screenName))
        }

        function resetLayout(screenName: string) {
            WidgetManager.resetLayout(WidgetManager.screenByName(screenName))
        }

        function done() {
            WidgetManager.endEdit()
        }

        function openSettings() {
            root.openSettingsRequested()
        }
    }
}
