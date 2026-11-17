import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "."

// ============================================================================
// MediaPlayerPanel — повноцінна панель керування активним MPRIS-плеєром.
//
// Відкривається лише з LEGO-модуля BarMediaPlayer. Це окреме PopupWindow,
// не DashboardMenu і не ControlCenter.
//
// Дані та керування беруться з того самого player, який обрав BarMediaPlayer
// (TopBar.mediaPlayer): жодного другого MPRIS-контролера тут немає. Кнопки, які
// плеєр не підтримує, приховані або вимкнені; фіктивних дій немає.
//
// Lyrics: локальний .lrc поруч із файлом (якщо xesam:url вказує на файл) або
// lrclib.net — тільки після явного натискання користувача, без API-ключів.
// ============================================================================
PopupWindow {
    id: root

    // Активний MPRIS-плеєр (той самий, що й у BarMediaPlayer).
    property var player: null
    // "music" | "video" — публікується з BarMediaPlayer.detectMediaType().
    property string mediaType: "music"

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isVideo: mediaType === "video"
    readonly property bool playing: hasPlayer
        && (player.isPlaying === true || player.playbackState === MprisPlaybackState.Playing)

    readonly property bool canToggle: hasPlayer
        && (player.canTogglePlaying || player.canPlay || player.canPause)

    readonly property string trackTitle: {
        if (!hasPlayer)
            return ""
        var t = String(player.trackTitle || "").trim()
        if (t.length > 0)
            return t
        return isVideo ? "Відео" : "Невідомий трек"
    }
    readonly property string trackArtist: {
        if (!hasPlayer || isVideo)
            return ""
        var a = String(player.trackArtist || "").trim()
        if (a.length === 0)
            a = String(player.trackAlbumArtist || "").trim()
        return a
    }
    readonly property string trackAlbum: hasPlayer && !isVideo
        ? String(player.trackAlbum || "").trim() : ""
    readonly property string appName: hasPlayer
        ? String(player.identity || player.desktopEntry || "").trim() : ""
    readonly property string artUrl: hasPlayer && player.trackArtUrl
        ? String(player.trackArtUrl) : ""
    readonly property string mediaIcon: isVideo ? "󰕧" : "󰝚"

    readonly property real trackLength: hasPlayer && player.lengthSupported
        && player.length > 0 ? Number(player.length) : 0
    readonly property real trackPosition: hasPlayer && player.positionSupported
        ? Math.max(0, Math.min(root.trackLength > 0 ? root.trackLength : Number(player.position),
                               Number(player.position))) : 0
    readonly property bool progressAvailable: hasPlayer && !isVideo
        && player.canSeek && player.positionSupported
        && player.lengthSupported && root.trackLength > 0

    readonly property bool showLoop: hasPlayer && !isVideo
        && player.loopSupported && player.canControl
    readonly property bool showShuffle: hasPlayer && !isVideo
        && player.shuffleSupported && player.canControl

    // Lyrics доступні лише для музики та коли увімкнено у вкладці «Медіаплеєр».
    readonly property bool lyricsAvailable: !root.isVideo
        && Config.mediaPlayerLyricsEnabled

    readonly property string loopIcon: hasPlayer
        && player.loopState === MprisLoopState.Track ? "󰑗" : "󰑖"
    readonly property bool loopActive: hasPlayer
        && player.loopState !== MprisLoopState.None
    readonly property bool shuffleActive: hasPlayer && player.shuffle === true

    // ------------------------------------------------------------------
    // Геометрія popup фіксована (без окремої секції налаштувань).
    // З Config береться лише висота області Lyrics.
    // ------------------------------------------------------------------
    readonly property int cfgLyricsHeight: Math.max(72, Math.min(320,
        Number(Config.mediaPlayerLyricsHeight) || 112))

    // --- Lyrics Presets: оформлення тексту (Config.MediaPlayer) ---
    // Валідація на місці: пошкоджене/відсутнє значення => коректний дефолт.
    function _lyrColor(v, fallback) {
        var s = String(v || "")
        return /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(s) ? s : fallback
    }
    function _lyrNum(v, fallback, lo, hi) {
        var n = Number(v)
        return (!isNaN(n) && n >= lo && n <= hi) ? n : fallback
    }
    // Базовий розмір рядка (px)
    readonly property int cfgLyricsFontSize: Math.round(_lyrNum(Config.mediaPlayerLyricsFontSize, 11, 9, 24))
    // Колір звичайного тексту; "" = автоколір із Theme
    readonly property color cfgLyricsText: _lyrColor(Config.mediaPlayerLyricsTextColor, Theme.textSub)
    // Колір активного рядка (Karaoke); "" = accent із Theme
    readonly property color cfgLyricsActive: _lyrColor(Config.mediaPlayerLyricsActiveColor, Theme.accent)
    // Прозорість підложки 0..1 (0 = без підложки)
    readonly property real cfgLyricsBgOpacity: _lyrNum(Config.mediaPlayerLyricsBgOpacity, 0.6, 0, 1)
    readonly property bool cfgLyricsAlignLeft: Config.mediaPlayerLyricsAlign === "left"
    // Міжрядковий інтервал (множник)
    readonly property real cfgLyricsLineSpacing: _lyrNum(Config.mediaPlayerLyricsLineSpacing, 1.25, 1.0, 2.0)
    // Підложка області: скло з-custom прозорістю; 0 => повністю прозоро
    readonly property color cfgLyricsBoxColor: cfgLyricsBgOpacity > 0.01
        ? Qt.rgba(Theme.cfgSurface.r, Theme.cfgSurface.g, Theme.cfgSurface.b,
                  cfgLyricsBgOpacity * Theme.glassOpacity)
        : "transparent"

    implicitWidth: 368
    implicitHeight: contentCol.implicitHeight + 24
    color: "transparent"
    grabFocus: true
    visible: false

    // ------------------------------------------------------------------
    // Відкриття / закриття
    // ------------------------------------------------------------------
    property double _lastClose: -10000

    function openPanel() {
        if (root.visible)
            return
        // Захист від повторного відкриття тим самим кліком, якщо Wayland
        // встиг закрити grab-popup як "клік ззовні".
        if (Date.now() - root._lastClose < 220)
            return

        var dir = PanelController.popupDirection
        if (dir === "down") { panelTranslate.y = -root.implicitHeight; panelTranslate.x = 0 }
        else if (dir === "up") { panelTranslate.y = root.implicitHeight; panelTranslate.x = 0 }
        else if (dir === "right") { panelTranslate.x = -root.implicitWidth; panelTranslate.y = 0 }
        else { panelTranslate.x = root.implicitWidth; panelTranslate.y = 0 }

        panel.opacity = 0.35
        panel.scale = 0.97
        root.visible = true
        openAnim.restart()
    }

    function closePanel() {
        if (!root.visible)
            return
        openAnim.stop()
        root.abortLyricsRequest()
        root.visible = false
        panelTranslate.y = -9999
        panelTranslate.x = 0
        panel.opacity = 0
        panel.scale = 0.97
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: panelTranslate; property: "y"
            to: 0
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panelTranslate; property: "x"
            to: 0
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panel; property: "opacity"
            to: 1
            duration: Theme.animNormal; easing.type: Theme.easingStandard
        }
        NumberAnimation {
            target: panel; property: "scale"
            to: 1
            duration: Theme.animNormal; easing.type: Theme.easingSpring; easing.overshoot: 1.05
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible && Config.mediaPlayerCloseOnEscape
        onActivated: root.closePanel()
    }

    onVisibleChanged: {
        if (!root.visible) {
            root._lastClose = Date.now()
            root.abortLyricsRequest()
        }
    }

    onPlayerChanged: {
        root.resetLyrics()
        if (!root.hasPlayer && root.visible)
            root.closePanel()
    }

    onMediaTypeChanged: {
        if (root.isVideo) {
            root.lyricsOpen = false
            root.abortLyricsRequest()
        }
    }

    onLyricsAvailableChanged: {
        if (!root.lyricsAvailable) {
            root.lyricsOpen = false
            root.abortLyricsRequest()
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true

        function onTrackChanged() {
            root.resetLyrics()
            if (root.lyricsOpen && root.lyricsAvailable
                    && Config.mediaPlayerLyricsAutoFetch)
                root.requestLyrics()
        }
        function onPlayingChanged() {
            if (root.player)
                root.player.positionChanged()
        }
        function onPositionSupportedChanged() {
            if (root.player)
                root.player.positionChanged()
        }
    }

    // Позиція оновлюється лише поки панель відкрита (без фонового опитування).
    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.hasPlayer && root.playing
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // ------------------------------------------------------------------
    // Керування
    // ------------------------------------------------------------------
    function togglePlayback() {
        if (!root.hasPlayer)
            return
        // Один клик = одна явная команда (play или pause), а не слепое togglePlaying().
        // togglePlaying() расится: повторный клик до прихода ответа MPRIS посылает
        // вторую команду toggle, которая отменяет первую (toggle×2 = без изменений).
        // Явные play()/pause() идемпотентны — повторный клик до ответа посылает ту же
        // команду и не ломает состояние. Иконка берётся из root.playing (player.isPlaying),
        // что отражает фактическое состояние MPRIS, а не предполагаемое UI.
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

    function seekTo(value) {
        if (!root.hasPlayer || !root.player.canSeek)
            return
        if (root.isVideo && !root.player.canControl)
            return
        var target = Math.max(0, root.trackLength > 0
            ? Math.min(root.trackLength, Number(value)) : Number(value))
        if (root.player.positionSupported) {
            root.player.position = target
            root.player.positionChanged()
        } else {
            root.player.seek(target - Number(root.player.position))
        }
    }

    function cycleLoop() {
        if (!root.hasPlayer || !root.player.loopSupported || !root.player.canControl)
            return
        if (root.player.loopState === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Playlist
        else if (root.player.loopState === MprisLoopState.Playlist)
            root.player.loopState = MprisLoopState.Track
        else
            root.player.loopState = MprisLoopState.None
    }

    function toggleShuffle() {
        if (!root.hasPlayer || !root.player.shuffleSupported || !root.player.canControl)
            return
        root.player.shuffle = !root.player.shuffle
    }

    function pad2(n) {
        return n < 10 ? "0" + n : String(n)
    }

    function timeText(seconds) {
        var s = Number(seconds)
        if (!isFinite(s) || s < 0)
            return "0:00"
        s = Math.floor(s)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        return (h > 0 ? h + ":" + root.pad2(m) : String(m)) + ":" + root.pad2(sec)
    }

    // ------------------------------------------------------------------
    // Lyrics: локальний .lrc → lrclib.net (лише за запитом)
    // ------------------------------------------------------------------
    property bool lyricsOpen: false
    property string lyricsState: "idle" // idle | loading | ready | unavailable | error
    property bool lyricsTimed: false
    property var lyricsLines: []
    property var lyricsCache: ({})
    property var lyricsRequest: null

    readonly property bool lyricsActionVisible: root.lyricsState === "idle"
        || root.lyricsState === "unavailable" || root.lyricsState === "error"
    readonly property string lyricsMessage: {
        if (root.lyricsState === "loading")
            return "Шукаю текст…"
        if (root.lyricsState === "unavailable")
            return "Текст пісні не знайдено"
        if (root.lyricsState === "error")
            return "Не вдалося завантажити текст"
        return "Текст пісні ще не завантажено"
    }
    readonly property string lyricsActionText:
        root.lyricsState === "idle" ? "Знайти текст" : "Спробувати ще"

    readonly property string plainLyricsText: {
        var out = []
        for (var i = 0; i < root.lyricsLines.length; ++i)
            out.push(root.lyricsLines[i].text)
        return out.join("\n")
    }

    readonly property int activeLyricIndex: {
        if (!root.lyricsTimed || root.lyricsLines.length === 0 || !root.hasPlayer)
            return -1
        if (!root.player.positionSupported)
            return -1
        var pos = Number(root.player.position)
        if (!isFinite(pos))
            pos = 0
        var idx = 0
        for (var i = 0; i < root.lyricsLines.length; ++i) {
            if (root.lyricsLines[i].time <= pos + 0.08)
                idx = i
            else
                break
        }
        return idx
    }

    function lyricWindowLine(offset) {
        if (root.lyricsLines.length === 0)
            return ""
        var base = root.activeLyricIndex
        if (base < 0)
            base = 0
        var i = base + offset
        return (i >= 0 && i < root.lyricsLines.length)
            ? root.lyricsLines[i].text : ""
    }

    function lyricKey() {
        if (!root.hasPlayer)
            return ""
        return [
            String(root.player.trackArtist || ""),
            String(root.player.trackTitle || ""),
            String(root.player.trackAlbum || ""),
            String(root.trackLength)
        ].join("|")
    }

    function localLyricsPath() {
        if (!root.hasPlayer)
            return ""
        var meta = root.player.metadata || ({})
        var url = String(meta["xesam:url"] || "")
        if (url.indexOf("file://") !== 0)
            return ""
        var path = url.substring(7)
        try {
            path = decodeURIComponent(path)
        } catch (e) {}
        if (path.length === 0)
            return ""
        var slash = path.lastIndexOf("/")
        var dot = path.lastIndexOf(".")
        if (dot > slash)
            path = path.substring(0, dot)
        return path + ".lrc"
    }

    function resetLyrics() {
        root.abortLyricsRequest()
        root.lyricsState = "idle"
        root.lyricsTimed = false
        root.lyricsLines = []
    }

    function abortLyricsRequest() {
        if (root.lyricsRequest) {
            try {
                root.lyricsRequest.abort()
            } catch (e) {}
            root.lyricsRequest = null
        }
        if (root.lyricsState === "loading")
            root.lyricsState = "idle"
    }

    function toggleLyrics() {
        if (!root.lyricsAvailable || !root.hasPlayer)
            return
        if (root.lyricsOpen) {
            root.lyricsOpen = false
            root.abortLyricsRequest()
            return
        }
        root.lyricsOpen = true
        if (root.lyricsState !== "ready" && root.lyricsState !== "loading"
                && Config.mediaPlayerLyricsAutoFetch)
            root.requestLyrics()
    }

    // Повторний пошук без кешу — для кнопки у вкладці «Медіаплеєр» та
    // кнопки «Спробувати ще» у самій панелі.
    function refreshLyrics() {
        if (!root.hasPlayer || root.isVideo || !Config.mediaPlayerLyricsEnabled)
            return
        var key = root.lyricKey()
        if (key && root.lyricsCache[key] !== undefined)
            delete root.lyricsCache[key]
        root.lyricsState = "idle"
        root.lyricsTimed = false
        root.lyricsLines = []
        root.requestLyrics()
    }

    function requestLyrics() {
        if (!root.hasPlayer)
            return
        var key = root.lyricKey()
        var cached = root.lyricsCache[key]
        if (cached) {
            root.applyLyrics(cached.raw)
            return
        }

        root.lyricsState = "loading"
        root.lyricsTimed = false
        root.lyricsLines = []

        var localPath = root.localLyricsPath()
        if (localPath.length > 0) {
            localLyricsFile.path = ""
            localLyricsFile.path = localPath
            var txt = ""
            try {
                txt = localLyricsFile.text()
            } catch (e) {
                txt = ""
            }
            if (txt && String(txt).trim().length > 0) {
                root.applyLyrics(txt)
                return
            }
        }

        root.fetchNetworkLyrics(key, true)
    }

    function fetchNetworkLyrics(key, detailed) {
        var artist = root.hasPlayer ? String(root.player.trackArtist || "").trim() : ""
        if (artist.length === 0 && root.hasPlayer)
            artist = String(root.player.trackAlbumArtist || "").trim()
        var title = root.hasPlayer ? String(root.player.trackTitle || "").trim() : ""

        if (artist.length === 0 || title.length === 0) {
            root.lyricsState = "unavailable"
            return
        }

        var url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist)
                + "&track_name=" + encodeURIComponent(title)
        if (detailed) {
            var album = root.hasPlayer ? String(root.player.trackAlbum || "").trim() : ""
            if (album.length > 0)
                url += "&album_name=" + encodeURIComponent(album)
            if (root.trackLength > 0)
                url += "&duration=" + String(Math.round(root.trackLength))
        }

        var xhr = new XMLHttpRequest()
        root.lyricsRequest = xhr
        xhr.open("GET", url)
        xhr.timeout = 8000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (root.lyricsRequest !== xhr)
                return
            root.lyricsRequest = null
            if (root.lyricKey() !== key)
                return

            if (xhr.status === 200) {
                var data = null
                try {
                    data = JSON.parse(xhr.responseText)
                } catch (e) {
                    data = null
                }
                if (!data) {
                    root.lyricsState = "error"
                    return
                }
                var synced = String(data.syncedLyrics || "")
                var plain = String(data.plainLyrics || "")
                if (synced.length > 0)
                    root.applyLyrics(synced)
                else if (plain.length > 0)
                    root.applyLyrics(plain)
                else
                    root.lyricsState = "unavailable"
            } else if (xhr.status === 404 && detailed) {
                // Другий запит — без альбому/тривалості, але з тими самими
                // точними виконавцем і назвою. Жодного "першого-ліпшого" результату.
                root.fetchNetworkLyrics(key, false)
            } else if (xhr.status === 404) {
                root.fetchLyricsOvh(key)
            } else {
                root.fetchLyricsOvh(key)
            }
        }
        xhr.ontimeout = function() {
            if (root.lyricsRequest === xhr) {
                root.lyricsRequest = null
                root.fetchLyricsOvh(key)
            }
        }
        xhr.onerror = function() {
            if (root.lyricsRequest === xhr) {
                root.lyricsRequest = null
                root.fetchLyricsOvh(key)
            }
        }
        xhr.send()
    }

    function fetchLyricsOvh(key) {
        if (!root.hasPlayer)
            return
        var artist = String(root.player.trackArtist || "").trim()
        if (artist.length === 0)
            artist = String(root.player.trackAlbumArtist || "").trim()
        var title = String(root.player.trackTitle || "").trim()

        if (artist.length === 0 || title.length === 0) {
            root.lyricsState = "unavailable"
            return
        }

        var url = "https://api.lyrics.ovh/v1/"
            + encodeURIComponent(artist) + "/"
            + encodeURIComponent(title)

        var xhr = new XMLHttpRequest()
        root.lyricsRequest = xhr
        xhr.open("GET", url)
        xhr.timeout = 8000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (root.lyricsRequest !== xhr)
                return
            root.lyricsRequest = null
            if (root.lyricKey() !== key)
                return

            if (xhr.status === 200) {
                var data = null
                try {
                    data = JSON.parse(xhr.responseText)
                } catch (e) {
                    data = null
                }
                var text = data && String(data.lyrics || "")
                if (text.trim().length > 0)
                    root.applyLyrics(text)
                else
                    root.lyricsState = "unavailable"
            } else if (xhr.status === 404) {
                root.lyricsState = "unavailable"
            } else if (xhr.status === 429) {
                root.lyricsState = "error"
            } else {
                root.lyricsState = "error"
            }
        }
        xhr.ontimeout = function() {
            if (root.lyricsRequest === xhr) {
                root.lyricsRequest = null
                root.lyricsState = "error"
            }
        }
        xhr.onerror = function() {
            if (root.lyricsRequest === xhr) {
                root.lyricsRequest = null
                root.lyricsState = "error"
            }
        }
        xhr.send()
    }

    function parseLyrics(raw) {
        var text = String(raw || "")
        var rows = text.split(/\r?\n/)
        var out = []
        var timed = false
        var re = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g

        for (var i = 0; i < rows.length; ++i) {
            var line = rows[i]
            var times = []
            var m
            re.lastIndex = 0
            while ((m = re.exec(line)) !== null) {
                var min = parseInt(m[1], 10)
                var sec = parseInt(m[2], 10)
                var frac = m[3] || ""
                var ms = 0
                if (frac.length === 1)
                    ms = parseInt(frac, 10) * 100
                else if (frac.length === 2)
                    ms = parseInt(frac, 10) * 10
                else if (frac.length >= 3)
                    ms = parseInt(frac.slice(0, 3), 10)
                times.push(min * 60 + sec + ms / 1000)
            }

            if (times.length > 0) {
                timed = true
                var content = line.replace(re, "").trim()
                for (var j = 0; j < times.length; ++j)
                    out.push({ time: times[j], text: content })
            } else if (line.trim().length > 0) {
                out.push({ time: -1, text: line.trim() })
            }
        }

        if (timed) {
            var synced = []
            for (var k = 0; k < out.length; ++k) {
                if (out[k].time >= 0)
                    synced.push(out[k])
            }
            synced.sort(function(a, b) { return a.time - b.time })
            return { timed: true, lines: synced }
        }
        return { timed: false, lines: out }
    }

    function applyLyrics(raw) {
        var parsed = root.parseLyrics(raw)
        if (!parsed.lines || parsed.lines.length === 0) {
            root.lyricsState = "unavailable"
            return
        }
        root.lyricsCache[root.lyricKey()] = { raw: String(raw) }
        root.lyricsTimed = parsed.timed
        root.lyricsLines = parsed.lines
        root.lyricsState = "ready"
    }

    FileView {
        id: localLyricsFile
        path: ""
        blockLoading: true
        printErrors: false
    }

    // ------------------------------------------------------------------
    // Інтерфейс
    // ------------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
            ? "transparent" : Theme.glassPopupSolid
        border.color: Theme.glassBorder
        border.width: 1

        GradientBg {
            anchors.fill: parent
            enabled: Theme.cfgGradientEnabled && Theme.cfgGradientApplyBg
            intensity: Theme.cfgGradientIntensity
            target: "bg"
            solidColor: Theme.glassPopupSolid
            radius: Theme.radiusXl
            clip: true
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        opacity: 0
        scale: 0.97
        transformOrigin: Item.Center
        transform: Translate {
            id: panelTranslate
            y: -9999
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 9

            // ---------- Шапка ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                                   (root.playing ? 0.20 : 0.10) * Theme.glassOpacity)
                    border.color: root.playing ? Theme.glassBorderFocus : Theme.glassBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: root.mediaIcon
                        color: root.playing ? Theme.accent : Theme.textSub
                        font.family: Theme.fontMono
                        font.pixelSize: 13

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: root.isVideo ? "ВІДЕО" : "МУЗИКА"
                        color: Theme.text
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.appName
                        color: Theme.textMuted
                        font.pixelSize: 8
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: closeMa.containsMouse
                        ? Qt.rgba(Theme.accentRed.r, Theme.accentRed.g, Theme.accentRed.b,
                                  0.18 * Theme.glassOpacity) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMa.containsMouse ? Theme.accentRed : Theme.textMuted
                        font.pixelSize: 11

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePanel()
                    }
                }
            }

            // ---------- Обкладинка / прев'ю + основна інформація ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    implicitWidth: 84
                    implicitHeight: 84
                    radius: Theme.radiusMd
                    color: Theme.bgSurface
                    border.color: Theme.glassBorder
                    border.width: 1
                    clip: true

                    Image {
                        id: artImage
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.artUrl
                        sourceSize.width: 168
                        sourceSize.height: 168
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: root.mediaIcon
                        color: root.playing ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 28

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: root.trackTitle
                        color: Theme.text
                        font.pixelSize: 15
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.trackArtist.length > 0
                        text: root.trackArtist
                        color: Theme.accent
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.trackAlbum.length > 0
                        text: root.trackAlbum
                        color: Theme.textMuted
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.isVideo && root.appName.length > 0
                        text: "Плеєр: " + root.appName
                        color: Theme.textSub
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            // ---------- Прогрес + час ----------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                visible: root.progressAvailable

                SeekBar {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    external: root.trackPosition
                    total: root.trackLength
                    onSeeked: value => root.seekTo(value)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: root.timeText(root.trackPosition)
                        color: Theme.textSub
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.timeText(root.trackLength)
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                    }
                }
            }

            // ---------- Транспорт ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: 6

                Item { Layout.fillWidth: true }

                IconButton {
                    icon: root.loopIcon
                    active: root.loopActive
                    iconSize: 15
                    visible: root.showLoop
                    onClicked: root.cycleLoop()
                }

                IconButton {
                    icon: "󰒮"
                    iconSize: 17
                    usable: root.hasPlayer && root.player.canGoPrevious
                    onClicked: if (root.hasPlayer && root.player.canGoPrevious) root.player.previous()
                }

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20

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
                        font.pixelSize: 19

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

                IconButton {
                    icon: "󰒭"
                    iconSize: 17
                    usable: root.hasPlayer && root.player.canGoNext
                    onClicked: if (root.hasPlayer && root.player.canGoNext) root.player.next()
                }

                IconButton {
                    icon: "󰒝"
                    active: root.shuffleActive
                    iconSize: 15
                    visible: root.showShuffle
                    onClicked: root.toggleShuffle()
                }

                Item { Layout.fillWidth: true }
            }



            // ---------- Кнопка Lyrics (лише музика та дозвіл налаштувань) ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: root.lyricsAvailable
                radius: Theme.radiusMd

                color: lyricsMa.containsMouse ? Theme.glassCardHover : Theme.glassCard
                border.color: root.lyricsOpen ? Theme.glassBorderFocus : Theme.glassBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 7

                    Text {
                        text: "󰈙"
                        color: root.lyricsOpen ? Theme.accent : Theme.textSub
                        font.family: Theme.fontMono
                        font.pixelSize: 13

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.lyricsOpen ? "Сховати текст" : "Текст пісні"
                        color: root.lyricsOpen ? Theme.text : Theme.textSub
                        font.pixelSize: 10
                        font.bold: root.lyricsOpen
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.lyricsState === "loading"
                        text: "…"
                        color: Theme.accent
                        font.pixelSize: 13
                    }
                }

                MouseArea {
                    id: lyricsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleLyrics()
                }
            }

            // ---------- Вікно Lyrics ----------
            Rectangle {
                id: lyricsBox
                Layout.fillWidth: true
                Layout.preferredHeight: root.cfgLyricsHeight
                visible: root.lyricsAvailable && root.lyricsOpen
                radius: Theme.radiusMd
                color: root.cfgLyricsBoxColor
                border.color: root.cfgLyricsBgOpacity > 0.01 ? Theme.glassBorder : "transparent"
                border.width: 1
                clip: true

                // Стани без готового тексту
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 5
                    visible: root.lyricsState !== "ready"

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.lyricsMessage
                        color: root.lyricsState === "error" ? Theme.accentRed : Theme.textSub
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 104
                        implicitHeight: 24
                        radius: 8
                        visible: root.lyricsActionVisible
                        color: retryMa.containsMouse ? Theme.glassCardHover : Theme.bgSurface
                        border.color: retryMa.containsMouse ? Theme.glassBorderFocus : Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.lyricsActionText
                            color: retryMa.containsMouse ? Theme.accent : Theme.textSub
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            id: retryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshLyrics()
                        }
                    }
                }

                // Синхронізований LRC: 5 рядків навколо поточної позиції
                // Karaoke-виділення працює лише коли є часові мітки; для
                // звичайного тексту — статичний fallback (активного рядка немає).
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    visible: root.lyricsState === "ready" && root.lyricsTimed
                    spacing: Math.max(0, Math.round((root.cfgLyricsLineSpacing - 1.0) * 8))

                    Repeater {
                        model: 5

                        Text {
                            required property int index
                            readonly property int slot: index - 2
                            readonly property bool current: root.activeLyricIndex >= 0 && slot === 0

                            width: parent.width
                            height: Math.round(root.cfgLyricsFontSize * 1.7)
                            text: root.lyricWindowLine(slot)
                            color: current ? root.cfgLyricsActive : root.cfgLyricsText
                            font.pixelSize: current
                                ? root.cfgLyricsFontSize
                                : Math.max(8, root.cfgLyricsFontSize - 1)
                            font.bold: current
                            horizontalAlignment: root.cfgLyricsAlignLeft
                                ? Text.AlignLeft : Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            opacity: text.length > 0
                                ? (current ? 1 : (Math.abs(slot) === 1 ? 0.75 : 0.5)) : 0

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }
                }

                // Звичайний текст без часових міток
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: root.lyricsState === "ready" && !root.lyricsTimed
                    contentWidth: width
                    contentHeight: plainText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    Text {
                        id: plainText
                        width: parent.width
                        text: root.plainLyricsText
                        color: root.cfgLyricsText
                        font.pixelSize: root.cfgLyricsFontSize
                        lineHeight: root.cfgLyricsLineSpacing
                        horizontalAlignment: root.cfgLyricsAlignLeft
                            ? Text.AlignLeft : Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // ================= ЛОКАЛЬНІ КОМПОНЕНТИ =================

    // Кругла кнопка з іконкою: hover/press/active — як в Island/IconBtn.
    component IconButton: Rectangle {
        id: ib

        property string icon
        property int iconSize: 15
        property bool active: false
        property bool usable: true

        signal clicked()

        implicitWidth: 28
        implicitHeight: 28
        radius: width / 2

        color: ib.active
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                      0.16 * Theme.glassOpacity)
            : (ibMa.containsMouse && ib.usable ? Theme.glassCardHover : "transparent")
        border.width: ib.active ? 1 : 0
        border.color: ib.active ? Theme.glassBorderFocus : "transparent"
        opacity: ib.usable ? 1 : 0.32
        scale: ibMa.pressed && ib.usable ? 0.9
            : (ibMa.containsMouse && ib.usable ? 1.06 : 1.0)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingSpring; easing.overshoot: 1.1 }
        }

        Text {
            anchors.centerIn: parent
            text: ib.icon
            color: ib.active ? Theme.accent : Theme.textSub
            font.family: Theme.fontMono
            font.pixelSize: ib.iconSize

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: ib.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ib.usable) ib.clicked()
        }
    }

    // Тонкий слайдер у стилі DashboardMenu: перемотка та гучність.
    component SeekBar: Slider {
        id: sb

        property real external: 0
        property real total: 1

        signal seeked(real value)

        from: 0
        to: Math.max(1, sb.total)
        live: false
        topPadding: 4
        bottomPadding: 4

        Binding on value {
            value: Math.max(sb.from, Math.min(sb.to, sb.external))
            when: !sb.pressed
        }

        onMoved: sb.seeked(value)

        background: Rectangle {
            x: sb.leftPadding
            y: sb.topPadding + sb.availableHeight / 2 - height / 2
            width: sb.availableWidth
            height: 6
            radius: 3
            color: Theme.bgSurface
            border.color: Theme.glassBorder
            border.width: 1

            Rectangle {
                width: Math.min(parent.width, sb.visualPosition * parent.width)
                height: parent.height
                radius: 3
                color: sb.pressed ? Theme.accentHover : Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        handle: Rectangle {
            x: sb.leftPadding + sb.visualPosition * (sb.availableWidth - width)
            y: sb.topPadding + sb.availableHeight / 2 - height / 2
            implicitWidth: sb.pressed ? 14 : 10
            implicitHeight: sb.pressed ? 14 : 10
            radius: height / 2
            color: Theme.accent
            border.color: Theme.accentHover
            border.width: 2

            Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast } }
            Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast } }
        }
    }
}
