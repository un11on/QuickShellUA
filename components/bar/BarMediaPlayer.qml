import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell.Services.Mpris
import ".."

// ============================================================================
// BarMediaPlayer — LEGO-модуль медіаплеєра для TopBar.
//
// Використовує глобальний MPRIS-сервіс Quickshell: жодного другого сервісу
// чи фонового процесу немає. Активний плеєр вибирається один раз тут:
// спочатку playing, потім перший paused. MediaPlayerPanel отримує цей самий
// об'єкт через TopBar, тому MPRIS-логіка не дублюється.
//
// Стани:
//   compact  — компактні кнопки керування та (за display) назва треку;
//   normal   — обкладинка/іконка, назва, виконавець і кнопки;
//   expanded — більша обкладинка, назва, виконавець і кнопки.
//
// Без активного плеєра модуль не показує зламаних кнопок: лише коректний
// стан «Нет воспроизведения». Налаштування зберігаються у Panel.layout
// через існуючий Config (showArt / showArtist / maxTitleLength).
// ============================================================================
Item {
    id: root

    property var config: ({})
    property var barWindow: null

    readonly property string modSize: config && config.size ? config.size : "normal"
    readonly property string modDisplay: config && config.display ? config.display : "both"

    readonly property bool showArt: !(config && config.showArt === false)
    readonly property bool showArtist: !(config && config.showArtist === false)
    readonly property bool showTitle: !(config && config.showTitle === false)
    readonly property bool showControls: !(config && config.showControls === false)
    readonly property int maxTitleLength: {
        if (!config || config.maxTitleLength === undefined)
            return 28
        var n = Number(config.maxTitleLength)
        return isFinite(n) && n >= 0 ? Math.round(n) : 28
    }

    readonly property bool compact: modSize === "compact"
    readonly property bool expanded: modSize === "expanded"

    readonly property int h: barWindow ? barWindow.btnSize : 28
    readonly property int controlSize: compact ? 18 : (expanded ? 24 : 21)
    readonly property int controlIconSize: compact ? 11 : (expanded ? 14 : 12)
    readonly property int controlSpacing: compact ? 1 : 2
    readonly property int controlsWidth: controlSize * 3 + controlSpacing * 2
    readonly property int coverSize: {
        var auto = compact ? Math.max(18, h - 8)
            : (expanded ? h : Math.max(22, h - 4))
        var n = config && config.coverSize !== undefined ? Number(config.coverSize) : 0
        if (!isFinite(n) || n <= 0)
            return auto
        return Math.max(16, Math.min(64, Math.round(n)))
    }
    readonly property int titleWidth: {
        var auto = compact ? 84 : (expanded ? 172 : 118)
        var n = config && config.titleWidth !== undefined ? Number(config.titleWidth) : 0
        if (!isFinite(n) || n <= 0)
            return auto
        return Math.max(48, Math.min(320, Math.round(n)))
    }
    readonly property int padH: compact ? 5 : 7
    readonly property int innerGap: compact ? 4 : 6

    // ------------------------------------------------------------------
    // MPRIS: єдиний вибір плеєра для модуля та MediaPlayerPanel
    // ------------------------------------------------------------------
    readonly property var player: {
        var list = Mpris.players.values
        var paused = null
        for (var i = 0; i < list.length; ++i) {
            var p = list[i]
            if (!p)
                continue
            if (p.isPlaying || p.playbackState === MprisPlaybackState.Playing)
                return p
            if (p.playbackState === MprisPlaybackState.Paused && paused === null)
                paused = p
        }
        return paused
    }

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer
        && (player.isPlaying === true || player.playbackState === MprisPlaybackState.Playing)
    readonly property bool canToggle: hasPlayer
        && (player.canTogglePlaying || player.canPlay || player.canPause)

    // "music" | "video" для MediaPlayerPanel. Визначається один раз тут —
    // панель лише споживає це значення, власної MPRIS-логіки не має.
    readonly property string mediaType: root.detectMediaType(player)

    function detectMediaType(p) {
        if (!p)
            return "music"

        var meta = p.metadata || ({})
        var url = String(meta["xesam:url"] || "")
        var lurl = url.toLowerCase()
        var mime = String(meta["xesam:mimeType"] || meta["mpris:mimeType"]
                          || meta["xesam:contentType"] || "").toLowerCase()

        if (mime.indexOf("video/") === 0)
            return "video"
        if (mime.indexOf("audio/") === 0)
            return "music"

        var videoExt = /\.(mkv|mp4|m4v|webm|avi|mov|mpg|mpeg|m2ts|ts|flv|wmv|ogv|3gp|divx|vob)([?#].*)?$/
        var audioExt = /\.(mp3|flac|ogg|oga|opus|m4a|aac|wav|wma|alac|aiff?|mid|midi|ape|wv)([?#].*)?$/
        if (videoExt.test(lurl))
            return "video"
        if (audioExt.test(lurl))
            return "music"
        if (/(youtube\.com|youtu\.be|vimeo\.com|twitch\.tv|netflix\.com|hulu\.com|dailymotion\.com|rutube\.ru|kick\.com|odysee\.com|bitchute\.com)/.test(lurl))
            return "video"

        var id = (String(p.identity || "") + " " + String(p.desktopEntry || "")).toLowerCase()
        var videoApps = ["mpv", "celluloid", "haruna", "totem", "dragon", "smplayer",
                         "mplayer", "kodi", "plex", "clapper", "showtime", "parole",
                         "xine", "gst-play", "bomi", "kmplayer"]
        for (var i = 0; i < videoApps.length; ++i) {
            if (id.indexOf(videoApps[i]) >= 0)
                return "video"
        }
        if (id.indexOf("vlc") >= 0)
            return lurl.length > 0 ? "video" : "music"

        return "music"
    }

    // TopBar зберігає лише посилання для MediaPlayerPanel; окремого
    // MPRIS-сервісу чи другого екземпляра плеєра не створюється.
    function publishMedia() {
        if (!barWindow)
            return
        barWindow.mediaAnchorItem = root
        barWindow.mediaPlayer = root.player
        barWindow.mediaType = root.mediaType
    }

    onBarWindowChanged: root.publishMedia()
    // Оновлюємо TopBar лише якщо саме цей модуль є поточним джерелом.
    // Це захищає від гонки при переміщенні/перестворенні модуля в конструкторі.
    onPlayerChanged: if (barWindow && barWindow.mediaAnchorItem === root)
        barWindow.mediaPlayer = root.player
    onMediaTypeChanged: if (barWindow && barWindow.mediaAnchorItem === root)
        barWindow.mediaType = root.mediaType
    Component.onCompleted: root.publishMedia()
    Component.onDestruction: {
        // Модуль прибрали з розкладки: прибираємо його якір і дані з TopBar,
        // щоб відкрита панель закрилася, а popup не тримався за видалений Item.
        if (barWindow && barWindow.mediaAnchorItem === root) {
            barWindow.mediaAnchorItem = null
            barWindow.mediaPlayer = null
            barWindow.mediaType = "music"
        }
    }

    readonly property string trackTitle: {
        if (!hasPlayer)
            return ""
        var t = String(player.trackTitle || "").trim()
        if (t.length === 0)
            t = String(player.identity || "").trim()
        return t.length > 0 ? t : "Невідомий трек"
    }
    readonly property string trackArtist: {
        if (!hasPlayer)
            return ""
        var a = String(player.trackArtist || "").trim()
        if (a.length === 0)
            a = String(player.trackAlbumArtist || "").trim()
        return a
    }
    readonly property string artUrl:
        hasPlayer && player.trackArtUrl ? String(player.trackArtUrl) : ""

    readonly property bool showText: modDisplay !== "icon" && root.showTitle
    readonly property bool showLead: modDisplay !== "text"
    readonly property bool showArtistText: root.showArtist && !root.compact
        && root.showText && root.trackArtist.length > 0
    readonly property string displayTitle: root.hasPlayer
        ? root.clipTitle(root.trackTitle) : "Нет воспроизведения"
    readonly property string leadIcon: root.hasPlayer ? "󰝚" : "󰝛"

    readonly property bool controlsVisible: root.hasPlayer && root.showControls
    readonly property int visibleParts: (root.showLead ? 1 : 0)
        + (root.showText ? 1 : 0) + (root.controlsVisible ? 1 : 0)
    implicitWidth: root.padH * 2
        + (root.showLead ? root.coverSize : 0)
        + (root.showText ? root.titleWidth : 0)
        + (root.controlsVisible ? root.controlsWidth : 0)
        + root.innerGap * Math.max(0, root.visibleParts - 1)
    implicitHeight: root.h

    // ------------------------------------------------------------------
    // Дії
    // ------------------------------------------------------------------
    function clipTitle(value) {
        var s = String(value || "")
        if (root.maxTitleLength > 0 && s.length > root.maxTitleLength)
            return s.substring(0, root.maxTitleLength) + "…"
        return s
    }

    function togglePlayback() {
        if (!root.hasPlayer || !root.canToggle)
            return
        // Явні play()/pause() замість togglePlaying(), щоб подвійний клік
        // до відповіді MPRIS не скасовував сам себе.
        if (root.playing) {
            if (root.player.canPause)
                root.player.pause()
            else if (root.player.canTogglePlaying)
                root.player.togglePlaying()
        } else {
            if (root.player.canPlay)
                root.player.play()
            else if (root.player.canTogglePlaying)
                root.player.togglePlaying()
        }
    }

    function goPrevious() {
        if (root.hasPlayer && root.player.canGoPrevious)
            root.player.previous()
    }

    function goNext() {
        if (root.hasPlayer && root.player.canGoNext)
            root.player.next()
    }

    // ------------------------------------------------------------------
    // Фон / hover
    // ------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hoverMa.containsMouse ? Theme.glassBgHover : "transparent"
        border.color: hoverMa.containsMouse ? Theme.glassBorderHover : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.hasPlayer && Config.mediaPlayerOpenOnClick
            ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.hasPlayer && root.barWindow && Config.mediaPlayerOpenOnClick)
                root.barWindow.togglePopup("media")
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        width: root.implicitWidth - root.padH * 2
        spacing: root.innerGap
        z: 1

        // ---------- Обкладинка / іконка ----------
        Item {
            id: lead
            visible: root.showLead
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.coverSize
            implicitHeight: root.coverSize

            Rectangle {
                id: coverFrame
                anchors.fill: parent
                radius: root.compact ? Theme.radiusSm : Math.min(Theme.radiusSm, height / 2)
                color: Theme.bgSurface
                border.color: root.playing ? Theme.glassBorderFocus : Theme.glassBorder
                border.width: 1
                clip: true

                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
            }

            Image {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 1
                source: root.showArt ? root.artUrl : ""
                sourceSize.width: root.coverSize * 2
                sourceSize.height: root.coverSize * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: (root.showArt && status === Image.Ready) ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.showArt || coverImage.status !== Image.Ready
                text: root.leadIcon
                color: root.playing ? Theme.accent : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: root.compact ? 12 : (root.expanded ? 18 : 15)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        // ---------- Назва + виконавець ----------
        ColumnLayout {
            visible: root.showText
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.titleWidth
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: root.titleWidth
                text: root.displayTitle
                color: root.hasPlayer ? Theme.text : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: root.compact ? 10 : (root.expanded ? 12 : 11)
                font.bold: root.hasPlayer
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: root.titleWidth
                visible: root.showArtistText
                text: root.trackArtist
                color: root.playing ? Theme.accent : Theme.textSub
                font.family: Theme.fontMono
                font.pixelSize: root.expanded ? 10 : 9
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        // ---------- Керування (лише за наявності плеєра та дозволу) ----------
        RowLayout {
            visible: root.controlsVisible
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.controlsWidth
            spacing: root.controlSpacing

            MediaButton {
                icon: "󰒮"
                iconSize: root.controlIconSize
                size: root.controlSize
                usable: root.hasPlayer && root.player.canGoPrevious
                onClicked: root.goPrevious()
            }

            Rectangle {
                id: playBtn
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.controlSize
                implicitHeight: root.controlSize
                radius: height / 2

                color: !root.canToggle ? Theme.bgSurface
                    : (playMa.containsMouse ? Theme.accentHover : Theme.accent)
                opacity: root.canToggle ? 1 : 0.35
                scale: playMa.pressed && root.canToggle ? 0.9
                    : (playMa.containsMouse && root.canToggle ? 1.06 : 1.0)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.playing ? "󰏤" : "󰐊"
                    color: Theme.textDark
                    font.family: Theme.fontMono
                    font.pixelSize: root.controlIconSize + 2

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.togglePlayback()
                }
            }

            MediaButton {
                icon: "󰒭"
                iconSize: root.controlIconSize
                size: root.controlSize
                usable: root.hasPlayer && root.player.canGoNext
                onClicked: root.goNext()
            }
        }
    }

    // Невелика кнопка транспорту в стилі IconBtn.
    component MediaButton: Rectangle {
        id: mb

        property string icon
        property int iconSize: 12
        property int size: 20
        property bool usable: true

        signal clicked()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: mb.size
        implicitHeight: mb.size
        radius: height / 2

        color: mbMa.containsMouse && mb.usable ? Theme.glassCardHover : "transparent"
        opacity: mb.usable ? 1 : 0.32
        scale: mbMa.pressed && mb.usable ? 0.9
            : (mbMa.containsMouse && mb.usable ? 1.08 : 1.0)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }

        Text {
            anchors.centerIn: parent
            text: mb.icon
            color: Theme.textSub
            font.family: Theme.fontMono
            font.pixelSize: mb.iconSize
        }

        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: mb.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (mb.usable) mb.clicked()
        }
    }
}
