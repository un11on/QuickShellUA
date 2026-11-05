
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

    implicitWidth: 420

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-ai"

    // Локальная модель LM Studio
    property string apiEndpoint: "http://127.0.0.1:1234/v1/chat/completions"
    property string modelName: "gemma-4-e4b-uncensored-hauhaucs-aggressive"

    property bool isLoading: false

    Rectangle {
        anchors.fill: parent
        color: "#181825"
        border.color: "#313244"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "❄ Local AI (" + sidebarWindow.modelName + ")"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }

                Button {
                    text: "✕"
                    onClicked: sidebarWindow.closeRequested()
                }
                Button {
    text: "Очистить"
    enabled: !isLoading
    onClicked: clearChat()
}
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: chatView
                    width: parent.width
                    spacing: 8
                    model: ListModel { id: chatModel }

                    delegate: Rectangle {
                        width: chatView.width - 12
                        implicitHeight: msgText.implicitHeight + 20
                        color: model.role === "user" ? "#313244" : "#45475a"
                        radius: 8

                        anchors.right: model.role === "user" ? parent.right : undefined
                        anchors.left: model.role === "user" ? undefined : parent.left

                        Text {
                            id: msgText
                            anchors.fill: parent
                            anchors.margins: 10
                            text: model.content
                            color: "#cdd6f4"
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Text {
                text: sidebarWindow.isLoading
                    ? "Gemma думает..."
                    : "● LM Studio Local"
                color: sidebarWindow.isLoading ? "#f9e2af" : "#a6e3a1"
                font.italic: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    placeholderText: "Напишите запрос..."
                    color: "#cdd6f4"
                    enabled: !sidebarWindow.isLoading

                    background: Rectangle {
                        color: "#313244"
                        radius: 6
                    }

                    onAccepted: sendPrompt()
                }

                Button {
                    text: "Отправить"
                    enabled: !sidebarWindow.isLoading
                    onClicked: sendPrompt()
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
                        content: "Ошибка обработки ответа: " + e
                    })
                }
            } else {
                chatModel.append({
                    role: "assistant",
                    content: "Ошибка LM Studio [" + http.status + "]: " + http.responseText
                })
            }

            chatView.positionViewAtEnd()
        }

        http.send(JSON.stringify(payload))
    }
}
