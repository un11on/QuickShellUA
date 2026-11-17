import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    signal settingChanged(string key, var value)

    readonly property bool use24Hour: settings.use24Hour !== false
    readonly property bool showSeconds: settings.showSeconds !== false
    readonly property bool showDate: settings.showDate !== false

    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    function timeText() {
        var format = root.use24Hour
                ? (root.showSeconds ? "HH:mm:ss" : "HH:mm")
                : (root.showSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        return Qt.formatDateTime(clock.date, format)
    }

    function dateText() {
        var mode = settings.dateFormat || "long"
        if (mode === "iso")
            return Qt.formatDate(clock.date, "yyyy-MM-dd")
        if (mode === "short")
            return Qt.formatDate(clock.date, "dd.MM.yyyy")
        return Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 28)
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: root.timeText()
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Math.max(28, Math.min(64, root.height * 0.38))
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.showDate
            text: root.dateText()
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textSub
            font.pixelSize: Math.max(11, Math.min(18, root.height * 0.12))
            elide: Text.ElideRight
        }
    }
}
