import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "."

// ============================================================================
// MusicIsland — компактна MPRIS-капсула TopBar.
//
// Згорнуто: нота + назва треку + реальний CAVA.
// Розгорнуто: обкладинка, назва/виконавець, CAVA, Previous / Play-Pause / Next.
// Розмір перемикається лише Super+X; hover на нього не впливає.
//
// Поверхня, радіус, фон і рамка успадковані від Island.qml — жодної окремої
// візуальної системи. Керування йде напряму через Quickshell.Services.Mpris.
// ============================================================================
Island {
    id: root

    // Клік по назві треку (у будь-якому стані) відкриває/закриває панель
    // медіаплеєра у TopBar. Круглий індикатор ліворуч — не кнопка.
    signal titleClicked()

    // ------------------------------------------------------------------
    // MPRIS
    // ------------------------------------------------------------------
    // Пріоритет: активний (playing) плеєр, інакше перший paused.
    // Stopped-плеєри ігноруються, тому без музики капсула повністю схована.
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

    // ------------------------------------------------------------------
    // Тип медіа
    // ------------------------------------------------------------------
    // MPRIS не має окремого поля "music/video". Визначаємо тип за URL/MIME
    // у метаданих, потім за відомим відеоплеєром. Якщо достовірно визначити
    // неможливо — стандартна іконка музики (вимога UX).
    readonly property string mediaType: root.detectMediaType(player)
    readonly property string mediaIcon: mediaType === "video" ? "󰕧" : "󰝚"

    function detectMediaType(p) {
        if (!p)
            return "music"

        var meta = p.metadata || ({})
        var url = String(meta["xesam:url"] || "")
        var lurl = url.toLowerCase()
        var mime = String(meta["xesam:mimeType"] || meta["mpris:mimeType"]
                          || meta["xesam:contentType"] || "").toLowerCase()

        // Найнадійніше: явний MIME або розширення файлу/URL.
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

        // Відомі відеоплеєри. Portable-варіанти (mpv/VLC) перевіряються нижче
        // після розширення, щоб музичний файл у VLC лишався музикою.
        var id = (String(p.identity || "") + " " + String(p.desktopEntry || "")).toLowerCase()
        var videoApps = ["mpv", "celluloid", "haruna", "totem", "dragon", "smplayer",
                         "mplayer", "kodi", "plex", "clapper", "showtime", "parole",
                         "xine", "gst-play", "bomi", "kmplayer"]
        for (var i = 0; i < videoApps.length; ++i) {
            if (id.indexOf(videoApps[i]) >= 0)
                return "video"
        }
        // VLC може грати і музику, і відео: без розширення — відео.
        if (id.indexOf("vlc") >= 0)
            return lurl.length > 0 ? "video" : "music"

        return "music"
    }

    readonly property string trackTitle: {
        if (!hasPlayer)
            return ""
        var t = String(player.trackTitle || "").trim()
        return t.length > 0 ? t : String(player.identity || "")
    }
    readonly property string trackArtist: {
        if (!hasPlayer)
            return ""
        var a = String(player.trackArtist || "").trim()
        if (a.length === 0)
            a = String(player.trackAlbumArtist || "").trim()
        return a.length > 0 ? a : String(player.identity || "")
    }
    readonly property string artUrl:
        hasPlayer && player.trackArtUrl ? String(player.trackArtUrl) : ""

    readonly property bool playbackUsable: hasPlayer
        && (player.canTogglePlaying || player.canPlay || player.canPause)

    function togglePlayback() {
        if (!hasPlayer)
            return
        // Один клик = одна явная команда (play или pause), а не слепое togglePlaying().
        // togglePlaying() расится: повторный клик до прихода ответа MPRIS посылает
        // вторую команду toggle, которая отменяет первую (toggle×2 = без изменений).
        // Явные play()/pause() идемпотентны — повторный клик до ответа посылает ту же
        // команду и не ломает состояние. Иконка берётся из playing (player.isPlaying),
        // что отражает фактическое состояние MPRIS, а не предполагаемое UI.
        if (playing) {
            if (player.canPause)
                player.pause()
            else if (player.canTogglePlaying)
                player.togglePlaying()
        } else {
            if (player.canPlay)
                player.play()
            else if (player.canTogglePlaying)
                player.togglePlaying()
        }
    }

    // ------------------------------------------------------------------
    // Стан капсули
    // ------------------------------------------------------------------
    // false = Expanded (стан за замовчуванням), true = Compact.
    // Перемикається лише Super+X; hover більше не впливає на розмір,
    // а вибір зберігається при зміні треку та паузі.
    property bool compactMode: false
    readonly property bool expanded: !compactMode

    IpcHandler {
        target: "music"

        function toggle() {
            if (!root.hasPlayer)
                return
            root.compactMode = !root.compactMode
            console.log("MusicIsland:", root.compactMode ? "compact" : "expanded")
        }

        function getMode(): string {
            return root.compactMode ? "compact" : "expanded"
        }
    }

    // Без плеєра (або в вертикальній панелі) капсула плавно зникає.
    opacity: hasPlayer && PanelController.isHorizontal ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }

    // ------------------------------------------------------------------
    // Геометрія: компактна ↔ розгорнута
    // ------------------------------------------------------------------
    readonly property int padH: Config.panelIslandPadH
    readonly property int leadSize: 28
    readonly property int controlSize: 24
    readonly property int controlGap: 2
    readonly property int controlsWidth: controlSize * 3 + controlGap * 2
    readonly property int cavaWidth: expanded ? 32 : 30
    readonly property int cavaHeight: expanded ? 18 : 16
    readonly property int titleWidth: expanded ? 140 : 118

    readonly property real targetWidth: padH * 2
        + leadSize + 7
        + titleWidth + 8
        + cavaWidth
        + (expanded ? 6 + controlsWidth : 0)

    width: targetWidth
    implicitWidth: targetWidth

    Behavior on width {
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
    }

    // М'яка активна рамка з існуючої палітри (без нових кольорів).
    border.color: flat ? "transparent"
        : (expanded ? Theme.glassBorderFocus : Theme.glassBorder)

    // ------------------------------------------------------------------
    // Вміст
    // ------------------------------------------------------------------
    Item {
        id: contentRow
        anchors.right: parent.right
        anchors.rightMargin: root.padH
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.padH * 2
        height: root.leadSize

        // --- Нота (компактно) / обкладинка (розгорнуто) ---
        Item {
            id: lead
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.leadSize
            height: root.leadSize

            // Круглий індикатор типу медіа — не кнопка, не перехоплює кліки.
            // Активна підсвітка при відтворенні береться лише з Theme.
            Rectangle {
                id: compactBadge
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: width / 2

                color: root.playing
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                              0.16 * Theme.glassOpacity)
                    : (Config.panelBackground ? Theme.glassCard : "transparent")
                border.width: 1
                border.color: root.playing ? Theme.glassBorderFocus : Theme.glassBorder

                opacity: root.expanded ? 0 : 1
                scale: root.expanded ? 0.82 : 1.0

                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    id: noteIcon
                    anchors.centerIn: parent
                    text: root.mediaIcon
                    color: root.playing ? Theme.accent : Theme.textSub
                    font.family: Theme.fontMono
                    font.pixelSize: 14

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }

            Rectangle {
                id: coverFrame
                anchors.fill: parent
                radius: Theme.radiusSm
                color: Theme.bgSurface
                border.color: Theme.glassBorder
                border.width: 1
                clip: true
                opacity: root.expanded ? 1 : 0
                scale: root.expanded ? 1.0 : 0.84

                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    anchors.margins: coverFrame.border.width
                    source: root.artUrl
                    sourceSize.width: 56
                    sourceSize.height: 56
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                }

                Text {
                    anchors.centerIn: parent
                    visible: coverImage.status !== Image.Ready
                    text: root.trackArtist.length > 0
                        ? root.trackArtist.charAt(0).toUpperCase() : "♪"
                    color: root.trackArtist.length > 0 ? Theme.accent : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: root.trackArtist.length > 0 ? 12 : 14
                    font.bold: true

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        // --- Назва + виконавець ---
        Column {
            id: textCol
            anchors.left: lead.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: root.titleWidth
            spacing: 0

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }

            Text {
                id: titleText
                width: parent.width
                height: 15
                text: root.trackTitle
                color: titleMa.containsMouse ? Theme.accent : Theme.text
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // Назва треку — єдина точка відкриття панелі плеєра.
                // Кнопки керування та круглий індикатор не перекриваються.
                MouseArea {
                    id: titleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.titleClicked()
                }
            }

            Text {
                id: artistText
                width: parent.width
                height: root.expanded ? 13 : 0
                clip: true
                text: root.trackArtist
                color: Theme.textSub
                font.pixelSize: 10
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                opacity: root.expanded ? 1 : 0
                visible: height > 0.5

                Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
        }

        // --- Реальний CAVA (один процес, без дублювання на hover) ---
        CavaBars {
            id: cava
            anchors.left: textCol.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: root.cavaWidth
            height: root.leadSize
            active: root.playing && root.visible && root.opacity > 0.01
            barCount: 10
            barWidth: 2
            barGap: 1
            maxBarHeight: root.cavaHeight
            barColor: Theme.accent

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
        }

        // --- Анімований проміжок перед керуванням ---
        Item {
            id: controlsGap
            anchors.left: cava.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.expanded ? 6 : 0
            height: 1

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
        }

        // --- Previous / Play-Pause / Next (лише розгорнуто) ---
        Item {
            id: controlsSlot
            anchors.left: controlsGap.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.expanded ? root.controlsWidth : 0
            height: root.leadSize
            clip: true
            opacity: root.expanded ? 1 : 0

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.controlGap

                IconBtn {
                    width: root.controlSize
                    height: root.controlSize
                    iconSize: 13
                    icon: "󰒮"
                    iconColor: Theme.textSub
                    opacity: root.hasPlayer && root.player.canGoPrevious ? 1 : 0.35

                    onClicked: if (root.hasPlayer && root.player.canGoPrevious) root.player.previous()
                }

                Rectangle {
                    id: playBtn
                    width: root.controlSize
                    height: root.controlSize
                    radius: height / 2

                    color: !root.playbackUsable ? Theme.bgSurface
                        : (playMa.containsMouse ? Theme.accentHover : Theme.accent)
                    opacity: root.playbackUsable ? 1 : 0.35
                    scale: playMa.pressed && root.playbackUsable ? 0.9
                        : (playMa.containsMouse && root.playbackUsable ? 1.06 : 1.0)

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
                        font.pixelSize: 15

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: playMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayback()
                    }
                }

                IconBtn {
                    width: root.controlSize
                    height: root.controlSize
                    iconSize: 13
                    icon: "󰒭"
                    iconColor: Theme.textSub
                    opacity: root.hasPlayer && root.player.canGoNext ? 1 : 0.35

                    onClicked: if (root.hasPlayer && root.player.canGoNext) root.player.next()
                }
            }
        }
    }
}
