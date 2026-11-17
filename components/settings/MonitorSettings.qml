import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    property var manager
    property var monitor  // currently selected monitor
    property bool multi: false

    // -------- Local working state --------
    property string workingName: ""
    property string workingDesc: ""
    property int workingWidth: 0
    property int workingHeight: 0
    property real workingRefreshRate: 0
    property real workingScale: 1.0
    property int workingTransform: 0
    property bool workingDisabled: false
    property int workingX: 0
    property int workingY: 0

    property var resolutions: []
    property var refreshRates: []

    function syncWithMonitor() {
        if (!monitor) {
            workingName = ""
            workingDesc = ""
            workingWidth = 0
            workingHeight = 0
            workingRefreshRate = 0
            workingScale = 1.0
            workingTransform = 0
            workingDisabled = false
            workingX = 0
            workingY = 0
            resolutions = []
            refreshRates = []
            return
        }

        workingName = monitor.name || ""
        workingDesc = monitor.description || ""
        workingWidth = monitor.width || 0
        workingHeight = monitor.height || 0
        workingRefreshRate = monitor.refreshRate || 0
        workingScale = monitor.scale || 1.0
        workingTransform = monitor.transform !== undefined ? monitor.transform : 0
        workingDisabled = monitor.disabled || false
        workingX = monitor.x || 0
        workingY = monitor.y || 0

        updateResolutions()
    }

    property string _lastMonitorName: ""
    property bool _applyingLocal: false

    onMonitorChanged: {
        var newName = monitor ? monitor.name : ""
        if (newName !== _lastMonitorName) {
            _lastMonitorName = newName
            _applyingLocal = false
            syncWithMonitor()
        } else if (!_applyingLocal) {
            // External refresh for the same monitor (hotplug/config event) - resync.
            syncWithMonitor()
        }
        // If _applyingLocal is true and name is same, ignore the echo refresh so
        // the UI doesn't snap back while Hyprland settles; next explicit action clears it.
    }
    Component.onCompleted: { _lastMonitorName = monitor ? monitor.name : ""; syncWithMonitor() }

    function updateResolutions() {
        if (!monitor || !monitor.availableModes) {
            resolutions = []
            refreshRates = []
            return
        }
        var resMap = {}
        for (var i = 0; i < monitor.availableModes.length; ++i) {
            var m = monitor.availableModes[i]
            var key = m.width + "x" + m.height
            if (!resMap[key]) {
                resMap[key] = { width: m.width, height: m.height }
            }
        }
        var list = Object.values(resMap)
        // Sort descending by resolution size
        list.sort(function(a, b) {
            return (b.width * b.height) - (a.width * a.height)
        })
        resolutions = list
        updateRefreshRatesForCurrent()
    }

    function updateRefreshRatesForCurrent() {
        if (!monitor || !monitor.availableModes) {
            refreshRates = []
            return
        }
        var filtered = []
        for (var i = 0; i < monitor.availableModes.length; ++i) {
            var m = monitor.availableModes[i]
            if (m.width === workingWidth && m.height === workingHeight) {
                filtered.push(m)
            }
        }
        filtered.sort(function(a, b) {
            return b.refreshRate - a.refreshRate
        })
        refreshRates = filtered

        if (filtered.length > 0) {
            var found = filtered.findIndex(function(r) {
                return Math.abs(r.refreshRate - workingRefreshRate) < 0.1
            })
            if (found < 0) {
                workingRefreshRate = filtered[0].refreshRate
            }
        }
    }

    // Helpers
    function resLabel(r) {
        if (!r) return ""
        return r.width + "×" + r.height
    }

    function rateLabel(r) {
        if (!r) return ""
        return (Math.round(r.refreshRate * 100) / 100) + " Hz"
    }

    function scaleLabel(s) {
        if (s === undefined || s === null) return "100%"
        return (s * 100).toFixed(0) + "%"
    }

    readonly property var orientations: [
        { key: 0, label: "0°" },
        { key: 1, label: "90°" },
        { key: 2, label: "180°" },
        { key: 3, label: "270°" }
    ]

    readonly property bool hasChanges: monitor !== null && (
        workingWidth !== monitor.width ||
        workingHeight !== monitor.height ||
        Math.abs(workingRefreshRate - monitor.refreshRate) > 0.05 ||
        Math.abs(workingScale - monitor.scale) > 0.01 ||
        workingTransform !== monitor.transform ||
        workingDisabled !== monitor.disabled
    )

    function apply() {
        if (!monitor || !manager) return
        if (!manager._snapshot) manager.snapshot()
        var updated = {
            name: workingName,
            description: workingDesc,
            width: workingWidth,
            height: workingHeight,
            refreshRate: workingRefreshRate,
            scale: workingScale,
            transform: workingTransform,
            disabled: workingDisabled,
            x: workingX,
            y: workingY
        }
        root._applyingLocal = true
        manager.pending(updated)
        manager.applyMonitor(updated)
        // Clear local-apply guard after Hyprland settles; manager refresh will update monitors.
        Qt.callLater(function() { _applyClearTimer.restart() })
    }

    property Timer _applyClearTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: {
            root._applyingLocal = false
            // Accept applied state as new baseline.
            if (root.manager) root.manager.snapshot()
        }
    }

    function cancel() {
        root._applyingLocal = false
        if (manager && manager._snapshot) {
            manager.rollback()
        }
        // Resync working state from current monitor after rollback settles.
        Qt.callLater(function() { syncWithMonitor() })
        if (_cancelResync) _cancelResync.restart()
    }

    property Timer _cancelResync: Timer {
        interval: 500
        repeat: false
        onTriggered: root.syncWithMonitor()
    }

    // --- Header / Empty State ---
    Text {
        visible: !monitor
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Оберіть дисплей зі списку вище"
        color: Theme.textMuted
        font.pixelSize: 13
        font.family: Theme.fontMono
    }

    // --- GROUP 1: Monitor Selector (if multi) ---
    Rectangle {
        visible: root.multi && monitor !== null
        Layout.fillWidth: true
        implicitHeight: group1Col.implicitHeight + 20
        radius: Theme.radiusMd
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            id: group1Col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ВИБІР ДИСПЛЕЯ"
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    font.family: Theme.fontMono
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.workingDesc || root.workingName
                    color: Theme.textSub
                    font.pixelSize: 11
                    font.family: Theme.fontMono
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: manager ? manager.monitors : []
                    delegate: Rectangle {
                        implicitWidth: pillContent.implicitWidth + 18
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        color: (root.monitor && modelData.name === root.monitor.name) ? Theme.accent : Theme.glassCardHover
                        border.color: (root.monitor && modelData.name === root.monitor.name) ? Theme.accent : Theme.glassBorder
                        border.width: 1

                        RowLayout {
                            id: pillContent
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.name
                                color: (root.monitor && modelData.name === root.monitor.name) ? Theme.textDark : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Text {
                                visible: modelData.focused
                                text: "●"
                                color: (root.monitor && modelData.name === root.monitor.name) ? Theme.textDark : Theme.accent
                                font.pixelSize: 9
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (manager) manager.selectMonitor(modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }

    // --- GROUP 2: Screen (Resolution & Refresh Rate) ---
    Rectangle {
        visible: monitor !== null
        Layout.fillWidth: true
        implicitHeight: group2Col.implicitHeight + 24
        radius: Theme.radiusMd
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            id: group2Col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            Text {
                text: "ЕКРАН"
                color: Theme.textMuted
                font.pixelSize: 10
                font.bold: true
                font.family: Theme.fontMono
            }

            // Resolution Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Роздільна здатність"
                    color: Theme.textSub
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    Layout.preferredWidth: 140
                }

                ComboBox {
                    id: resCombo
                    Layout.fillWidth: true
                    model: root.resolutions
                    displayText: currentIndex >= 0 && currentIndex < root.resolutions.length
                        ? root.resLabel(root.resolutions[currentIndex])
                        : (root.workingWidth > 0 ? (root.workingWidth + "×" + root.workingHeight) : "—")

                    currentIndex: {
                        for (var i = 0; i < root.resolutions.length; ++i) {
                            if (root.resolutions[i].width === root.workingWidth && root.resolutions[i].height === root.workingHeight) {
                                return i
                            }
                        }
                        return -1
                    }

                    onActivated: function(index) {
                        if (index >= 0 && index < root.resolutions.length) {
                            root.workingWidth = root.resolutions[index].width
                            root.workingHeight = root.resolutions[index].height
                            root.updateRefreshRatesForCurrent()
                        }
                    }

                    background: Rectangle {
                        implicitHeight: 32
                        color: Theme.glassCardHover
                        border.color: resCombo.activeFocus ? Theme.accent : Theme.glassBorder
                        border.width: 1
                        radius: Theme.radiusSm
                    }

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 10
                        text: resCombo.displayText
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.text
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    delegate: ItemDelegate {
                        width: resCombo.width
                        implicitHeight: 30
                        contentItem: Text {
                            text: root.resLabel(modelData)
                            color: highlighted ? Theme.accent : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: highlighted ? Theme.glassCardHover : "transparent"
                            radius: Theme.radiusSm
                        }
                    }

                    popup: Popup {
                        y: resCombo.height + 4
                        width: resCombo.width
                        implicitHeight: Math.min(220, contentItem.implicitHeight + 8)
                        padding: 4
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: resCombo.delegateModel
                            currentIndex: resCombo.highlightedIndex
                        }
                        background: Rectangle {
                            color: Theme.glassPopupSolid
                            border.color: Theme.glassBorder
                            border.width: 1
                            radius: Theme.radiusSm
                        }
                    }
                }
            }

            // Refresh Rate Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Частота оновлення"
                    color: Theme.textSub
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    Layout.preferredWidth: 140
                }

                ComboBox {
                    id: rateCombo
                    Layout.fillWidth: true
                    model: root.refreshRates
                    displayText: currentIndex >= 0 && currentIndex < root.refreshRates.length
                        ? root.rateLabel(root.refreshRates[currentIndex])
                        : (root.workingRefreshRate > 0 ? (Math.round(root.workingRefreshRate) + " Hz") : "—")

                    currentIndex: {
                        for (var i = 0; i < root.refreshRates.length; ++i) {
                            if (Math.abs(root.refreshRates[i].refreshRate - root.workingRefreshRate) < 0.1) {
                                return i
                            }
                        }
                        return -1
                    }

                    onActivated: function(index) {
                        if (index >= 0 && index < root.refreshRates.length) {
                            root.workingRefreshRate = root.refreshRates[index].refreshRate
                        }
                    }

                    background: Rectangle {
                        implicitHeight: 32
                        color: Theme.glassCardHover
                        border.color: rateCombo.activeFocus ? Theme.accent : Theme.glassBorder
                        border.width: 1
                        radius: Theme.radiusSm
                    }

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 10
                        text: rateCombo.displayText
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.text
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    delegate: ItemDelegate {
                        width: rateCombo.width
                        implicitHeight: 30
                        contentItem: Text {
                            text: root.rateLabel(modelData)
                            color: highlighted ? Theme.accent : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: highlighted ? Theme.glassCardHover : "transparent"
                            radius: Theme.radiusSm
                        }
                    }

                    popup: Popup {
                        y: rateCombo.height + 4
                        width: rateCombo.width
                        implicitHeight: Math.min(200, contentItem.implicitHeight + 8)
                        padding: 4
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: rateCombo.delegateModel
                            currentIndex: rateCombo.highlightedIndex
                        }
                        background: Rectangle {
                            color: Theme.glassPopupSolid
                            border.color: Theme.glassBorder
                            border.width: 1
                            radius: Theme.radiusSm
                        }
                    }
                }
            }
        }
    }

    // --- GROUP 3: Scale and Orientation ---
    Rectangle {
        visible: monitor !== null
        Layout.fillWidth: true
        implicitHeight: group3Col.implicitHeight + 24
        radius: Theme.radiusMd
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            id: group3Col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            Text {
                text: "МАСШТАБ ТА ОРІЄНТАЦІЯ"
                color: Theme.textMuted
                font.pixelSize: 10
                font.bold: true
                font.family: Theme.fontMono
            }

            // Scale Slider Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Масштаб"
                    color: Theme.textSub
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    Layout.preferredWidth: 140
                }

                Slider {
                    id: scaleSlider
                    Layout.fillWidth: true
                    from: 0.5
                    to: 3.0
                    stepSize: 0.05
                    value: root.workingScale
                    onMoved: {
                        root.workingScale = Math.round(value * 100) / 100
                    }

                    background: Rectangle {
                        x: scaleSlider.leftPadding
                        y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                        width: scaleSlider.availableWidth
                        height: 6
                        radius: 3
                        color: Theme.bgSurface

                        Rectangle {
                            width: scaleSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: scaleSlider.leftPadding + scaleSlider.visualPosition * (scaleSlider.availableWidth - width)
                        y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: scaleSlider.pressed ? Theme.accentHover : Theme.text
                        border.color: Theme.accent
                        border.width: 2
                    }
                }

                Text {
                    text: root.scaleLabel(root.workingScale)
                    color: Theme.text
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    font.bold: true
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Quick Scale Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item { Layout.preferredWidth: 140 }

                Repeater {
                    model: [1.0, 1.25, 1.5, 1.6, 1.75, 2.0]
                    delegate: Rectangle {
                        implicitWidth: 38
                        implicitHeight: 26
                        radius: Theme.radiusSm
                        color: Math.abs(root.workingScale - modelData) < 0.01 ? Theme.accent : Theme.glassCardHover
                        border.color: Math.abs(root.workingScale - modelData) < 0.01 ? Theme.accent : Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: (modelData * 100).toFixed(0) + "%"
                            color: Math.abs(root.workingScale - modelData) < 0.01 ? Theme.textDark : Theme.textSub
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            font.bold: Math.abs(root.workingScale - modelData) < 0.01
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.workingScale = modelData
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Orientation Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Орієнтація"
                    color: Theme.textSub
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    Layout.preferredWidth: 140
                }

                Repeater {
                    model: root.orientations
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: root.workingTransform === modelData.key ? Theme.accent : Theme.glassCardHover
                        border.color: root.workingTransform === modelData.key ? Theme.accent : Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.workingTransform === modelData.key ? Theme.textDark : Theme.textSub
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.bold: root.workingTransform === modelData.key
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.workingTransform = modelData.key
                            }
                        }
                    }
                }
            }
        }
    }

    // --- GROUP 4: Position (multi-monitor) ---
    Rectangle {
        visible: root.multi && monitor !== null
        Layout.fillWidth: true
        implicitHeight: group4Col.implicitHeight + 24
        radius: Theme.radiusMd
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            id: group4Col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Text {
                text: "РОЗТАШУВАННЯ"
                color: Theme.textMuted
                font.pixelSize: 10
                font.bold: true
                font.family: Theme.fontMono
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Координати X / Y"
                    color: Theme.textSub
                    font.pixelSize: 12
                    font.family: Theme.fontMono
                    Layout.preferredWidth: 140
                }

                Text {
                    text: "X: " + root.workingX + "    Y: " + root.workingY
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }
    }

    // --- GROUP 5: Management (Enable / Disable) ---
    Rectangle {
        visible: monitor !== null
        Layout.fillWidth: true
        implicitHeight: group5Col.implicitHeight + 20
        radius: Theme.radiusMd
        color: Theme.glassCard
        border.color: Theme.glassBorder
        border.width: 1

        ColumnLayout {
            id: group5Col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            ToggleTile {
                Layout.fillWidth: true
                icon: "󰍹"
                title: root.workingDisabled ? "Увімкнути дисплей" : "Вимкнути дисплей"
                subtitle: root.workingDisabled ? "Дисплей деактивовано" : "Дисплей активний"
                active: !root.workingDisabled
                onClicked: {
                    if (root.multi && !root.workingDisabled) {
                        var activeCount = 0
                        if (manager) {
                            for (var i = 0; i < manager.monitors.length; ++i) {
                                if (!manager.monitors[i].disabled) activeCount++
                            }
                        }
                        if (activeCount <= 1) return
                    }
                    root.workingDisabled = !root.workingDisabled
                }
            }
        }
    }

    // --- Action Buttons ---
    RowLayout {
        visible: monitor !== null
        Layout.fillWidth: true
        spacing: 10

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 110
            height: 34
            radius: Theme.radiusSm
            color: cancelMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
            border.color: Theme.glassBorder
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰐜"; color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 12 }
                Text { text: "Скасувати"; color: Theme.text; font.pixelSize: 11; font.bold: true }
            }

            MouseArea {
                id: cancelMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancel()
            }
        }

        Rectangle {
            width: 120
            height: 34
            radius: Theme.radiusSm
            color: root.hasChanges ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7)

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰄬"; color: Theme.textDark; font.family: Theme.fontMono; font.pixelSize: 12 }
                Text { text: "Застосувати"; color: Theme.textDark; font.pixelSize: 11; font.bold: true }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.apply()
            }
        }
    }
}
