import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import "../.."

Item {
    id: root

    property string instanceId: ""
    property var settings: ({})
    property bool previewMode: false
    signal settingChanged(string key, var value)

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property var calendarLocale: settings.weekStartsMonday === false
            ? Qt.locale("en_US") : Qt.locale("uk_UA")

    function shiftMonth(delta) {
        var date = new Date(root.viewYear, root.viewMonth + delta, 1)
        root.viewYear = date.getFullYear()
        root.viewMonth = date.getMonth()
    }

    function resetToday() {
        var now = new Date()
        root.viewYear = now.getFullYear()
        root.viewMonth = now.getMonth()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: {
                    var value = root.calendarLocale.standaloneMonthName(root.viewMonth)
                    return (value ? value.charAt(0).toUpperCase() + value.slice(1) : "")
                            + " " + root.viewYear
                }
                color: Theme.text
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }
            WidgetButton {
                text: "‹"; implicitWidth: 32; controlHeight: 32; leftPadding: 0; rightPadding: 0
                onClicked: root.shiftMonth(-1)
            }
            WidgetButton {
                text: "●"; implicitWidth: 32; controlHeight: 32; leftPadding: 0; rightPadding: 0
                onClicked: root.resetToday()
            }
            WidgetButton {
                text: "›"; implicitWidth: 32; controlHeight: 32; leftPadding: 0; rightPadding: 0
                onClicked: root.shiftMonth(1)
            }
        }

        Basic.DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Text {
                required property var model
                text: model.shortName
                color: Theme.textMuted
                font.pixelSize: 10
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Basic.MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: root.viewMonth
            year: root.viewYear
            locale: root.calendarLocale

            delegate: Item {
                id: cell
                required property var model
                readonly property bool inMonth: model.month === grid.month
                visible: root.settings.showOutsideDays !== false || inMonth

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(20, Math.min(30, Math.min(parent.width, parent.height) - 4))
                    height: width
                    radius: width / 2
                    color: cell.model.today ? Theme.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: cell.model.day
                    color: cell.model.today ? Theme.textDark
                          : (cell.inMonth ? Theme.text : Theme.textMuted)
                    opacity: cell.inMonth ? 1 : 0.45
                    font.pixelSize: 12
                    font.bold: cell.model.today
                }
            }
        }
    }
}
