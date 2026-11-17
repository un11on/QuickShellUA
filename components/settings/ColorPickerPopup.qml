import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ".."

// ================= COLOR PICKER =================
// Photoshop-style палітра: Saturation/Value область, Hue-смуга,
// HEX / RGB, Apply/Cancel. Працює поверх Control Center БЕЗ
// затемнення: modal-оверлей замінений на прозорий Item.
Popup {
    id: picker

    // Куди застосувати: "Theme.background" | "Theme.surface" | "Theme.accent"
    property string targetProp: ""
    property string targetLabel: ""

    // HSV-стан пікетера (h: 0..360, s/v: 0..1)
    property real hue: 210
    property real sat: 0.5
    property real val: 0.5

    readonly property string liveHex: picker.hsvToHex(picker.hue, picker.sat, picker.val)

    width: 304
    height: contentCol.implicitHeight + topPadding + bottomPadding

    modal: true
    closePolicy: Popup.CloseOnEscape
    // Заміняємо стандартний напівпрозорий modal-оверлей на порожній Item:
    // модальність лишається (кліки поза пікетером блокуються), але нічого не темніє
    Overlay.modal: Item { }
    background: null
    padding: 14

    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? Math.max(8, (parent.height - height) / 2) : 0

    // ================= HELPERS =================
    function _clamp(x, lo, hi) { return x < lo ? lo : (x > hi ? hi : x) }

    function hsvToHex(h, s, v) {
        h = ((h % 360) + 360) % 360
        var c = Qt.hsva(h / 360, _clamp(s, 0, 1), _clamp(v, 0, 1), 1)
        var arr = [c.r, c.g, c.b]
        var out = "#"
        for (var i = 0; i < 3; i++) {
            var hx = Math.round(_clamp(arr[i], 0, 1) * 255).toString(16)
            out += (hx.length < 2 ? "0" + hx : hx)
        }
        return out.toLowerCase()
    }

    function hexToHsv(hex) {
        var s = String(hex || "").trim()
        if (!/^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/.test(s)) return null
        if (s.length === 4)
            s = "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]
        var c = Qt.color(s)
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var d = max - min
        var h = 0
        if (d > 0) {
            if (max === r)      h = 60 * (((g - b) / d) % 6)
            else if (max === g) h = 60 * ((b - r) / d + 2)
            else                h = 60 * ((r - g) / d + 4)
        }
        if (h < 0) h += 360
        return { h: h, s: max === 0 ? 0 : d / max, v: max }
    }

    function openFor(prop, label, initialHex) {
        targetProp = prop
        targetLabel = label
        var hsv = hexToHsv(initialHex)
        if (hsv) { hue = hsv.h; sat = hsv.s; val = hsv.v }
        open()
    }

    // ================= CONTENT =================
    contentItem: ColumnLayout {
        id: contentCol
        spacing: 12

        // --- Заголовок ---
        Text {
            text: picker.targetLabel + " — вибір кольору"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontMono
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // --- Область Saturation / Value ---
        Rectangle {
            id: svArea
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            radius: 8
            clip: true
            // базовий колір: чистий Hue при S=1, V=1
            color: Qt.hsva(picker.hue / 360, 1, 1, 1)

            // Шар 1: white → transparent (горизонтально, S: 0 → 1)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ffffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }
            // Шар 2: transparent → black (вертикально, V: 1 → 0)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#ff000000" }
                }
            }

            // Маркер
            Rectangle {
                x: picker.sat * svArea.width - width / 2
                y: (1 - picker.val) * svArea.height - height / 2
                width: 14; height: 14; radius: 7
                color: "transparent"
                border.color: "white"; border.width: 2
            }

            MouseArea {
                id: svMa
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                function update(mouse) {
                    picker.sat = picker._clamp(mouse.x / svArea.width, 0, 1)
                    picker.val = 1 - picker._clamp(mouse.y / svArea.height, 0, 1)
                }
                onPressed: function(mouse) { update(mouse) }
                onPositionChanged: function(mouse) { if (pressed) update(mouse) }
            }
        }

        // --- Смуга Hue ---
        Rectangle {
            id: hueBar
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            radius: 7
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;    color: Qt.hsva(0.0,    1, 1, 1) }
                GradientStop { position: 0.0833; color: Qt.hsva(0.0833, 1, 1, 1) }
                GradientStop { position: 0.1667; color: Qt.hsva(0.1667, 1, 1, 1) }
                GradientStop { position: 0.25;   color: Qt.hsva(0.25,   1, 1, 1) }
                GradientStop { position: 0.3333; color: Qt.hsva(0.3333, 1, 1, 1) }
                GradientStop { position: 0.4167; color: Qt.hsva(0.4167, 1, 1, 1) }
                GradientStop { position: 0.5;    color: Qt.hsva(0.5,    1, 1, 1) }
                GradientStop { position: 0.5833; color: Qt.hsva(0.5833, 1, 1, 1) }
                GradientStop { position: 0.6667; color: Qt.hsva(0.6667, 1, 1, 1) }
                GradientStop { position: 0.75;   color: Qt.hsva(0.75,   1, 1, 1) }
                GradientStop { position: 0.8333; color: Qt.hsva(0.8333, 1, 1, 1) }
                GradientStop { position: 0.9167; color: Qt.hsva(0.9167, 1, 1, 1) }
                GradientStop { position: 1.0;    color: Qt.hsva(1.0,    1, 1, 1) }
            }

            Rectangle {
                x: (picker.hue / 360) * hueBar.width - 2
                y: -2
                width: 4; height: parent.height + 4; radius: 2
                color: "transparent"
                border.color: "white"; border.width: 2
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function update(mouse) {
                    picker.hue = picker._clamp(mouse.x / hueBar.width, 0, 1) * 360
                }
                onPressed: function(mouse) { update(mouse) }
                onPositionChanged: function(mouse) { if (pressed) update(mouse) }
            }
        }

        // --- Прев'ю + HEX + RGB ---
        RowLayout {
            spacing: 10

            Rectangle {
                width: 48; height: 48; radius: 10
                color: picker.liveHex
                border.color: Theme.glassBorder; border.width: 1
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                text: picker.liveHex
                color: Theme.text
                font.pixelSize: 12
                font.family: Theme.fontMono
                selectByMouse: true
                background: Rectangle {
                    radius: 6
                    color: Theme.bgSurface
                    border.color: hexField.activeFocus ? Theme.borderFocus : Theme.glassBorder
                    border.width: 1
                }
                onAccepted: {
                    var hsv = picker.hexToHsv(hexField.text)
                    if (hsv) {
                        picker.hue = hsv.h
                        picker.sat = hsv.s
                        picker.val = hsv.v
                    }
                    // відновлюємо валідний показ (жорсткий показ HSV-стану)
                    hexField.text = picker.liveHex
                }

                // Слідкуємо за зміною HSV-стану (drag мишкою) — показуємо у полі
                Connections {
                    target: picker
                    function onLiveHexChanged() { hexField.text = picker.liveHex }
                }
            }

            Text {
                // RGB: "R, G, B" (тільки перегляд)
                text: {
                    var c = Qt.color(picker.liveHex)
                    return Math.round(c.r * 255) + ", " +
                           Math.round(c.g * 255) + ", " +
                           Math.round(c.b * 255)
                }
                color: Theme.textSub
                font.pixelSize: 11
                font.family: Theme.fontMono
                Layout.preferredWidth: 92
                elide: Text.ElideRight
            }
        }

        // --- Кнопки ---
        RowLayout {
            spacing: 10
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Rectangle {
                width: cancelRow.implicitWidth + 24
                height: 32
                radius: Theme.radiusSm
                color: cancelMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                border.color: Theme.glassBorder; border.width: 1

                RowLayout {
                    id: cancelRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "Скасувати"; color: Theme.textSub; font.pixelSize: 11; font.bold: true }
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.close()
                }
            }

            Rectangle {
                width: applyRow.implicitWidth + 24
                height: 32
                radius: Theme.radiusSm
                color: applyMa.containsMouse ? Theme.accentHover : Theme.accent
                border.color: Theme.glassBorder; border.width: 1

                RowLayout {
                    id: applyRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "Застосувати"; color: Theme.textDark; font.pixelSize: 11; font.bold: true }
                }

                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (picker.targetProp !== "")
                            Config.setProp(picker.targetProp, String(picker.liveHex))
                        picker.close()
                    }
                }
            }
        }
    }
}
