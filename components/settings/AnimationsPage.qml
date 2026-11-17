import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

Item {
    id: animRoot

    // ============ Скидання анімацій до дефолтів ============
    function resetAnimations() {
        var d = Config.defaults.Animations
        var keys = [
            "enabled", "duration",
            "springEnabled", "springStiffness", "springDamping",
            "overshoot",
            "window", "popup", "element", "tab", "hover", "panel"
        ]
        for (var i = 0; i < keys.length; ++i)
            Config.setProp("Animations." + keys[i], d[keys[i]])
    }

    // ============ Переиспользуемый slider-ряд ============
    component AnimSlider: RowLayout {
        id: asRoot

        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property string prop: ""
        property real step: 1
        property var format: null
        property bool enabled: true

        spacing: 10

        onValueChanged: Qt.callLater(function() { asCtrl.value = asRoot.value })

        Text {
            text: asRoot.label
            color: Theme.textSub
            font.pixelSize: 12
            Layout.preferredWidth: 150
            elide: Text.ElideRight
        }

        Slider {
            id: asCtrl
            Layout.fillWidth: true
            from: asRoot.from
            to: asRoot.to
            stepSize: asRoot.step
            value: asRoot.value
            enabled: asRoot.enabled
            onMoved: {
                Config.setProp(asRoot.prop, asCtrl.value)
            }

            background: Rectangle {
                x: asCtrl.leftPadding
                y: asCtrl.topPadding + asCtrl.availableHeight / 2 - height / 2
                width: asCtrl.availableWidth
                height: 6
                radius: 3
                color: asCtrl.enabled ? Theme.bgSurface : Theme.textMuted
                Rectangle {
                    width: asCtrl.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: asCtrl.enabled ? Theme.accent : Theme.textMuted
                }
            }
            handle: Rectangle {
                x: asCtrl.leftPadding + asCtrl.visualPosition * (asCtrl.availableWidth - width)
                y: asCtrl.topPadding + asCtrl.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: asCtrl.pressed ? Theme.accentHover : Theme.text
                border.color: Theme.accent
                border.width: 2
                enabled: asCtrl.enabled
            }
        }

        Text {
            text: asRoot.format
                ? String(asRoot.format(asRoot.value))
                : String(Math.round(asRoot.value * 10) / 10)
            color: Theme.textSub
            font.pixelSize: 11
            font.family: Theme.fontMono
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 52
            elide: Text.ElideRight
        }
    }

    // ============ Перемикач (toggle) ============
    component AnimToggle: RowLayout {
        id: atRoot

        property string label: ""
        property string prop: ""
        property bool value: false

        spacing: 10

        Text {
            text: atRoot.label
            color: Theme.textSub
            font.pixelSize: 12
            Layout.preferredWidth: 150
            elide: Text.ElideRight
        }

        Rectangle {
            width: 44; height: 24; radius: 12
            color: atRoot.value ? Theme.accent : Theme.textMuted
            border.color: Theme.glassBorder; border.width: 1
            MouseArea {
                anchors.fill: parent
                onClicked: Config.setProp(atRoot.prop, !atRoot.value)
            }
            Text {
                anchors.centerIn: parent
                text: atRoot.value ? "✓" : ""
                color: Theme.textDark
                font.pixelSize: 11
                font.bold: true
            }
        }

        Text {
            text: atRoot.value ? "УВІМКНЕНО" : "ВИМКНЕНО"
            color: atRoot.value ? Theme.accent : Theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.family: Theme.fontMono
        }
    }

    // ============ Сторінка ============
    Flickable {
        id: pageScroll
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.textMuted
                opacity: 0.4
            }
        }

        ColumnLayout {
            id: contentCol
            x: 20
            y: 20
            width: pageScroll.width - 40
            spacing: 16

            // --- Заголовок ---
            Text {
                text: "Анімації"
                color: Theme.text
                font.pixelSize: 22
                font.bold: true
                font.family: Theme.fontMono
            }
            Text {
                text: "Налаштуйте швидкість та стиль переходів оболочки"
                color: Theme.textSub
                font.pixelSize: 12
            }

            // --- Загальні налаштування ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: generalCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: generalCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "ЗАГАЛЬНІ"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    // Увімкнути анімації
                    AnimToggle {
                        label: "Увімкнути анімації"
                        prop: "Animations.enabled"
                        value: Config.animationsEnabled
                    }

                    // Тривалість (ms)
                    AnimSlider {
                        label: "Тривалість (мс)"
                        prop: "Animations.duration"
                        from: 50
                        to: 1000
                        step: 10
                        value: Config.animationsDuration
                        enabled: Config.animationsEnabled
                        format: function(v) { return Math.round(v) + " мс" }
                    }

                    // Тип поведінки
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Text {
                            text: "Тип поведінки"
                            color: Theme.textSub
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: Theme.radiusSm
                            color: Config.animationsSpringEnabled ? Theme.accent : Theme.bgSurface
                            border.color: Theme.glassBorder; border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                Rectangle {
                                    id: stdBtn
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusSm - 2
                                    color: !Config.animationsSpringEnabled ? Theme.accent : "transparent"
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Config.setProp("Animations.springEnabled", false)
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Стандартна"
                                        color: !Config.animationsSpringEnabled ? Theme.textDark : Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Theme.fontMono
                                    }
                                }

                                Rectangle {
                                    id: springBtn
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusSm - 2
                                    color: Config.animationsSpringEnabled ? Theme.accent : "transparent"
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Config.setProp("Animations.springEnabled", true)
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Spring"
                                        color: Config.animationsSpringEnabled ? Theme.textDark : Theme.textSub
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Theme.fontMono
                                    }
                                }
                            }
                        }
                    }

                    // Spring параметри (активні лише для Spring)
                    AnimSlider {
                        label: "Spring Stiffness"
                        prop: "Animations.springStiffness"
                        from: 50
                        to: 500
                        step: 10
                        value: Config.animationsSpringStiffness
                        enabled: Config.animationsSpringEnabled
                    }

                    AnimSlider {
                        label: "Spring Damping"
                        prop: "Animations.springDamping"
                        from: 5
                        to: 60
                        step: 1
                        value: Config.animationsSpringDamping
                        enabled: Config.animationsSpringEnabled
                    }

                    AnimSlider {
                        label: "Overshoot"
                        prop: "Animations.overshoot"
                        from: 50
                        to: 200
                        step: 5
                        value: Config.animationsOvershoot * 100
                        format: function(v) { return (v / 100).toFixed(2) }
                    }
                }
            }

            // --- Категорії ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: catsCol.implicitHeight + 28
                radius: Theme.radiusMd
                color: Theme.glassCard
                border.color: Theme.glassBorder
                border.width: 1

                ColumnLayout {
                    id: catsCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "КАТЕГОРІЇ"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.fontMono
                    }

                    AnimSlider {
                        label: "Окна"
                        prop: "Animations.window"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsWindow * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }

                    AnimSlider {
                        label: "Попапи та меню"
                        prop: "Animations.popup"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsPopup * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }

                    AnimSlider {
                        label: "Появлення елементів"
                        prop: "Animations.element"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsElement * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }

                    AnimSlider {
                        label: "Переключення вкладок"
                        prop: "Animations.tab"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsTab * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }

                    AnimSlider {
                        label: "Hover та нажаття"
                        prop: "Animations.hover"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsHover * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }

                    AnimSlider {
                        label: "Панелі"
                        prop: "Animations.panel"
                        from: 25
                        to: 200
                        step: 5
                        value: Config.animationsPanel * 100
                        format: function(v) { return (v / 100).toFixed(2) + " ×" }
                    }
                }
            }

            // --- Скидання ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: Theme.radiusSm
                    color: Theme.bgSurface
                    border.color: Theme.glassBorder; border.width: 1
                    MouseArea {
                        anchors.fill: parent
                        onClicked: animRoot.resetAnimations()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Скинути до за замовчуванням"
                        color: Theme.textSub
                        font.pixelSize: 11
                        font.family: Theme.fontMono
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
