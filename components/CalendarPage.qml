import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Локальна сторінка календаря (без мережі та синхронізації).
// Сітка побудована на MonthGrid/DayOfWeekRow з Quickshell.Widgets: вони коректно
// обробляють місяці різної довжини, високосні роки та перший день тижня локалі.
Item {
    id: root

    // Сторінка активна лише коли вона видима (StackLayout у DashboardMenu).
    // Використовується для скидання на поточний місяць при кожному відкритті.
    property bool active: false

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()   // 0..11

    readonly property var loc: Qt.locale("uk_UA")

    function shiftMonth(delta) {
        // Date нормалізує перехід через межу року й довжину місяця
        var d = new Date(root.viewYear, root.viewMonth + delta, 1)
        root.viewYear = d.getFullYear()
        root.viewMonth = d.getMonth()
    }

    function monthTitle(m) {
        var s = root.loc.standaloneMonthName(m)
        return s.length > 0 ? (s.charAt(0).toUpperCase() + s.slice(1)) : ""
    }

    // Кожне відкриття вкладки — поточний місяць (передбачувана поведінка)
    onActiveChanged: {
        if (!root.active)
            return
        var now = new Date()
        root.viewYear = now.getFullYear()
        root.viewMonth = now.getMonth()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ---------- Заголовок: місяць + перемикання ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.monthTitle(root.viewMonth) + " " + root.viewYear
                color: Theme.text
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 0.3
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            IconBtn {
                implicitWidth: 30
                implicitHeight: 30
                icon: "󰅁" // nf-md-chevron_left
                iconSize: 16
                iconColor: Theme.textSub
                onClicked: root.shiftMonth(-1)
            }

            IconBtn {
                implicitWidth: 30
                implicitHeight: 30
                icon: "󰅂" // nf-md-chevron_right
                iconSize: 16
                iconColor: Theme.textSub
                onClicked: root.shiftMonth(1)
            }
        }

        // ---------- Дні тижня ----------
        DayOfWeekRow {
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

        // ---------- Сітка днів ----------
        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: root.viewMonth
            year: root.viewYear
            locale: root.loc

            delegate: Item {
                id: dayCell
                required property var model

                implicitWidth: 36
                implicitHeight: 30

                // Постійний круглий «чип» дня; розмір підлаштовується під комірку
                readonly property real ring: Math.max(20, Math.min(30, Math.min(dayCell.width, dayCell.height) - 3))
                readonly property bool inMonth: dayCell.model.month === grid.month

                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: dayCell.inMonth
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: dayCell.ring
                    height: dayCell.ring
                    radius: dayCell.ring / 2
                    color: dayCell.model.today ? Theme.accent
                           : (cellMa.containsMouse && dayCell.inMonth ? Theme.bgSurfaceHover : "transparent")
                    border.color: dayCell.model.today ? Theme.glassBorderFocus : "transparent"
                    border.width: dayCell.model.today ? 2 : 0

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    anchors.centerIn: parent
                    text: dayCell.model.day
                    font.pixelSize: 13
                    font.bold: dayCell.model.today
                    color: dayCell.model.today ? Theme.textDark
                         : (dayCell.inMonth ? Theme.text : Theme.textMuted)
                    opacity: dayCell.inMonth ? 1 : 0.45
                }
            }
        }
    }
}
