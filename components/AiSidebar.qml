import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: sidebarWindow

    signal closeRequested()

    anchors {
        top: true
        bottom: true
        right: true
    }

    // Сайдбар живёт на мониторе панели. Margins layer-shell отсчитываются от
    // usable area, где exclusive zone панели уже учтён compositor'ом, поэтому
    // достаточно обычного отступа — толщину панели добавлять не нужно.
    screen: PanelController.panelScreen
        ? PanelController.panelScreen
        : Quickshell.screens[0]

    margins {
        top: 8
        bottom: 8
        right: 8
    }

    implicitWidth: 420
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-ai"

    // Локальна модель LM Studio
    property string apiEndpoint: "http://127.0.0.1:1234/v1/chat/completions"
    property string modelName: "gemma-4-e4b-uncensored-hauhaucs-aggressive"
    property bool isLoading: false
    property bool opened: false

    onVisibleChanged: {
        if (visible) {
            opened = true;
        } else {
            opened = false;
        }
    }

    function closeWithAnimation() {
        opened = false;
        closeTimer.start();
    }

    Timer {
        id: closeTimer
        // Интервал должен быть ≥ длительности анимации выезда (animSlow = 350 мс),
        // иначе панель резко срывается до завершения Translate.x
        interval: Theme.animSlow
        onTriggered: sidebarWindow.closeRequested()
    }

    Rectangle {
        id: drawer
        anchors.fill: parent
        radius: Theme.radiusXl

        // Матове скло
        color: Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        // Плавний виїзд справа наліво
        transform: Translate {
            x: sidebarWindow.opened ? 0 : 440
            Behavior on x {
                NumberAnimation {
                    duration: Theme.animSlow
                    easing.type: Theme.easingStandard
                }
            }
        }

        opacity: sidebarWindow.opened ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Заголовок
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "❄ Local AI"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }

                // Кнопка "Очистити"
                Rectangle {
                    implicitWidth: clearLabel.implicitWidth + 18
                    implicitHeight: 28
                    radius: Theme.radiusSm
                    color: clearMa.containsMouse ? Theme.glassBgHover : Theme.glassCard
                    border.color: clearMa.containsMouse ? Theme.glassBorderHover : Theme.glassBorder
                    border.width: 1

                    scale: clearMa.pressed ? 0.94 : (clearMa.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Очистити"
                        color: clearMa.containsMouse ? Theme.text : Theme.textSub
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !sidebarWindow.isLoading
                        onClicked: clearChat()
                    }
                }

                // Кнопка закриття
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: closeMa.containsMouse ? Theme.glassBgHover : "transparent"
                    border.color: closeMa.containsMouse ? Theme.glassBorderHover : "transparent"
                    border.width: 1

                    scale: closeMa.pressed ? 0.9 : (closeMa.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMa.containsMouse ? Theme.accentRed : Theme.textSub
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebarWindow.closeWithAnimation()
                    }
                }
            }

            // Список повідомлень
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: chatView
                    width: parent.width
                    spacing: 10
                    model: ListModel { id: chatModel }

                    delegate: Rectangle {
                        id: bubble
                        width: chatView.width - 8
                        implicitHeight: msgText.implicitHeight + 22
                        radius: Theme.radiusMd

                        color: model.role === "user"
                            ? Theme.glassCardActive
                            : Theme.glassCard

                        border.color: model.role === "user"
                            ? Theme.glassBorderFocus
                            : Theme.glassBorder
                        border.width: 1

                        anchors.right: model.role === "user" ? parent.right : undefined
                        anchors.left: model.role === "user" ? undefined : parent.left

                        scale: 0.95
                        opacity: 0
                        Component.onCompleted: msgInAnim.start()

                        ParallelAnimation {
                            id: msgInAnim
                            NumberAnimation { target: bubble; property: "scale"; to: 1.0; duration: Theme.animNormal; easing.type: Theme.easingSpring }
                            NumberAnimation { target: bubble; property: "opacity"; to: 1.0; duration: Theme.animFast }
                        }

                        Text {
                            id: msgText
                            anchors.fill: parent
                            anchors.margins: 12
                            text: model.content
                            color: Theme.text
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                            lineHeight: 1.2
                        }
                    }
                }
            }

            // Індикатор статусу / пульсація
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: sidebarWindow.isLoading ? Theme.accentYellow : Theme.accentGreen

                    SequentialAnimation on opacity {
                        running: sidebarWindow.isLoading
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 450 }
                        NumberAnimation { to: 1.0; duration: 450 }
                    }
                }

                Text {
                    text: sidebarWindow.isLoading
                        ? "Local AI думає..."
                        : "LM Studio Local"
                    color: sidebarWindow.isLoading ? Theme.accentYellow : Theme.accentGreen
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // Поле вводу + кнопка відправки
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    implicitHeight: 40
                    placeholderText: "Напишіть запит..."
                    placeholderTextColor: Theme.textMuted
                    color: Theme.text
                    font.pixelSize: 13
                    enabled: !sidebarWindow.isLoading

                    background: Rectangle {
                        color: Theme.glassCard
                        radius: Theme.radiusMd
                        border.color: inputField.activeFocus ? Theme.accent : Theme.glassBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                    }

                    onAccepted: sendPrompt()
                }

                Rectangle {
                    id: sendBtn
                    implicitWidth: 92
                    implicitHeight: 40
                    radius: Theme.radiusMd

                    property bool canSend: !sidebarWindow.isLoading && inputField.text.trim() !== ""

                    color: canSend ? Theme.accent : Theme.glassCard
                    border.color: canSend ? Theme.accentHover : Theme.glassBorder
                    border.width: 1

                    scale: sendMa.pressed ? 0.94 : (sendMa.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Надіслати"
                        color: sendBtn.canSend ? Theme.textDark : Theme.textMuted
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: sendMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !sidebarWindow.isLoading
                        onClicked: sendPrompt()
                    }
                }
            }
        }
    }

    function getMessageHistory() {
        var history = [
            {
                role: "system",
                content: "You are a helpful assistant integrated into a Hyprland desktop shell. Answer in the user's language."
            }
        ]

        for (var i = 0; i < chatModel.count; i++) {
            var item = chatModel.get(i)
            history.push({
                role: item.role,
                content: item.content
            })
        }

        return history
    }

    function clearChat() {
        if (isLoading) return
        chatModel.clear()
    }

    function sendPrompt() {
        var prompt = inputField.text.trim()
        if (prompt === "" || sidebarWindow.isLoading)
            return

        chatModel.append({
            role: "user",
            content: prompt
        })

        inputField.text = ""
        chatView.positionViewAtEnd()
        sidebarWindow.isLoading = true

        var http = new XMLHttpRequest()
        var payload = {
            model: sidebarWindow.modelName,
            messages: getMessageHistory()
        }

        http.open("POST", sidebarWindow.apiEndpoint, true)
        http.setRequestHeader("Content-Type", "application/json")

        http.onreadystatechange = function() {
            if (http.readyState !== XMLHttpRequest.DONE)
                return

            sidebarWindow.isLoading = false

            if (http.status >= 200 && http.status < 300) {
                try {
                    var response = JSON.parse(http.responseText)
                    var replyText = response.choices[0].message.content

                    chatModel.append({
                        role: "assistant",
                        content: replyText
                    })
                } catch (e) {
                    chatModel.append({
                        role: "assistant",
                        content: "Помилка обробки відповіді: " + e
                    })
                }
            } else {
                chatModel.append({
                    role: "assistant",
                    content: "Помилка LM Studio [" + http.status + "]: " + http.responseText
                })
            }

            chatView.positionViewAtEnd()
        }

        http.send(JSON.stringify(payload))
    }
}
