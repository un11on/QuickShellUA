pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

QtObject {
    id: root

    // ================= PUBLIC SIGNALS =================
    signal openPickerRequested()
    signal scanFinished()
    signal applyFinished(bool success)

    // ================= BACKEND / COLLECTION =================
    property bool initialized: false
    property bool backendReady: false
    property string backendError: ""

    property bool avifChecked: false
    property bool supportsAvif: false

    property string folder: Config.wallpaperFolder
    property string resolvedFolder: ""
    property string scannedSource: ""
    property var images: []
    property int totalCount: 0
    property bool truncated: false
    property bool loading: false
    property bool hasScanned: false
    property string error: ""

    property var activePaths: ({})
    property string currentPath: Config.wallpaperCurrentPath
    property string currentMonitorName: ""
    property int monitorRevision: 0

    // ================= APPLY STATE =================
    property bool applying: false
    property string applyStatus: ""
    property string applyError: ""
    property bool lastApplyOk: false
    property var pendingApply: null
    property int verifyAttempts: 0
    property int restoreAttempts: 0
    property bool restorePending: false

    readonly property string cacheFolder: Quickshell.cacheDir + "/wallpaper-studio"

    // ================= MONITORS =================
    // monitorRevision змушує перерахувати список після зміни екранів.
    readonly property var monitorNames: {
        root.monitorRevision
        var out = []
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; ++i) {
            if (screens[i] && screens[i].name)
                out.push(screens[i].name)
        }
        return out
    }

    property Connections screenConnections: Connections {
        target: Quickshell
        function onScreensChanged() {
            root.monitorRevision++
        }
    }

    function allMonitors() {
        var out = []
        var seen = {}
        var primary = root.monitorNames
        for (var i = 0; i < primary.length; ++i) {
            if (!seen[primary[i]]) {
                seen[primary[i]] = true
                out.push(primary[i])
            }
        }
        if (out.length > 0)
            return out
        // Якщо Quickshell ще не отримав екранів — беремо те, що знає hyprpaper.
        var keys = Object.keys(root.activePaths || {})
        for (var j = 0; j < keys.length; ++j) {
            if (!seen[keys[j]]) {
                seen[keys[j]] = true
                out.push(keys[j])
            }
        }
        return out
    }

    function monitorOptions() {
        var out = ["Усі монітори"]
        var names = root.allMonitors()
        for (var i = 0; i < names.length; ++i)
            out.push(names[i])
        return out
    }

    function monitorIndex(value) {
        if (!value || value === "All")
            return 0
        var names = root.allMonitors()
        var idx = names.indexOf(value)
        return idx >= 0 ? idx + 1 : 0
    }

    function monitorValueAt(index) {
        if (index <= 0)
            return "All"
        var names = root.allMonitors()
        return names[index - 1] || "All"
    }

    function targetMonitors(monitor) {
        if (!monitor || monitor === "All")
            return root.allMonitors()
        return [monitor]
    }

    function setMonitor(name) {
        Config.setProp("Wallpaper.monitor", name || "All")
    }

    function setFillMode(mode) {
        var m = String(mode || "fill").toLowerCase()
        if (["fill", "fit", "stretch", "center"].indexOf(m) < 0)
            m = "fill"
        Config.setProp("Wallpaper.fillMode", m)
    }

    // ================= PATH HELPERS =================
    function expandPath(p) {
        var s = String(p || "").trim()
        if (s === "")
            return ""
        var home = String(Quickshell.env("HOME") || "")
        if (s === "~")
            return home
        if (s.indexOf("~/") === 0)
            return home + s.substring(1)
        if (s.charAt(0) !== "/")
            return home + "/" + s
        return s
    }

    function baseName(p) {
        var s = String(p || "")
        var idx = s.lastIndexOf("/")
        return idx >= 0 ? s.substring(idx + 1) : s
    }

    function fileUrl(p) {
        return p ? "file://" + p : ""
    }

    function isCurrent(p) {
        return p && root.currentPath === p
    }

    function _isCenterCache(p) {
        return String(p || "").indexOf(root.cacheFolder + "/") === 0
    }

    function _monitorShowsSaved(monitor, saved) {
        var actual = String((root.activePaths || {})[monitor] || "")
        if (actual === "")
            return false
        if (actual === saved)
            return true
        if (Config.wallpaperFillMode === "center")
            return actual === root.cacheFolder + "/center-" + monitor + ".jpg"
        return false
    }

    function _savedIsActive() {
        var saved = Config.wallpaperCurrentPath
        if (!saved)
            return true
        var mons = root.targetMonitors(Config.wallpaperCurrentMonitor || "All")
        if (mons.length === 0)
            return false
        for (var i = 0; i < mons.length; ++i) {
            if (!root._monitorShowsSaved(mons[i], saved))
                return false
        }
        return true
    }

    // ================= INIT / RESTORE =================
    function initialize() {
        if (root.initialized)
            return
        root.initialized = true
        root._detectAvif()
        root.refreshCurrent()
        restoreTimer.restart()
        startupOpenTimer.restart()
    }

    function _detectAvif() {
        if (root.avifChecked || avifProc.running)
            return
        avifProc.running = true
    }

    function requestOpenPicker() {
        root.openPickerRequested()
    }

    // ================= FOLDER SCAN =================
    function setFolder(path) {
        var p = String(path || "").trim()
        if (p === "") {
            root.error = "Папку не вибрано"
            return
        }
        Config.setProp("Wallpaper.folder", p)
        root.images = []
        root.totalCount = 0
        root.truncated = false
        root.hasScanned = false
        root.scannedSource = ""
        root.error = ""
        root.scan()
    }

    function ensureScanned() {
        if (root.loading)
            return
        var src = root.expandPath(root.folder)
        if (root.hasScanned && root.scannedSource === src)
            return
        root.scan()
    }

    function refresh() {
        root.scan()
    }

    function scan() {
        root.scanGeneration++
        var gen = root.scanGeneration
        root.error = ""
        root.loading = true
        root.truncated = false
        root.resolvedFolder = ""

        var raw = root.expandPath(root.folder)
        root.scannedSource = raw
        if (raw === "") {
            root._finishScanError(gen, "Папку з обоями не вибрано")
            return
        }

        if (checkProc.running)
            checkProc.running = false
        checkProc.generation = gen
        checkProc.command = ["sh", "-c",
            "[ -e \"$1\" ] || exit 1; [ -d \"$1\" ] || exit 2; " +
            "p=$(readlink -f -- \"$1\" 2>/dev/null) || exit 1; " +
            "[ -r \"$p\" ] || exit 3; printf '%s' \"$p\"",
            "sh", raw]
        checkProc.running = true
    }

    function _startFind(gen, canonicalFolder) {
        var exts = ["png", "jpg", "jpeg", "webp"]
        if (root.supportsAvif)
            exts.push("avif")

        var patterns = []
        for (var i = 0; i < exts.length; ++i)
            patterns.push("-iname '*." + exts[i] + "'")

        var script = "find \"$1\" -maxdepth 1 -type f \\( "
                + patterns.join(" -o ") + " \\) -print | head -n 2000"

        if (scanProc.running)
            scanProc.running = false
        scanProc.generation = gen
        scanProc.folder = canonicalFolder
        scanProc.command = ["sh", "-c", script, "sh", canonicalFolder]
        scanProc.running = true
    }

    function _finishScanError(gen, message) {
        if (gen !== root.scanGeneration)
            return
        root.loading = false
        root.hasScanned = true
        root.images = []
        root.totalCount = 0
        root.resolvedFolder = ""
        root.error = message
        root.scanFinished()
    }

    function _finishScan(gen, canonicalFolder, output, stderrText, exitCode) {
        if (gen !== root.scanGeneration)
            return

        var lines = String(output || "").split("\n")
        var result = []
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line === "")
                continue
            result.push({
                path: line,
                name: root.baseName(line)
            })
        }

        result.sort(function(a, b) {
            var an = String(a.name).toLowerCase()
            var bn = String(b.name).toLowerCase()
            if (an < bn) return -1
            if (an > bn) return 1
            return 0
        })

        root.images = result
        root.totalCount = result.length
        root.truncated = result.length >= 2000
        root.resolvedFolder = canonicalFolder
        root.loading = false
        root.hasScanned = true

        if (exitCode !== 0) {
            root.error = "Не вдалося прочитати папку: " + String(stderrText || "").trim()
        } else if (result.length === 0) {
            root.error = "У папці не знайдено зображень (png, jpg, jpeg, webp"
                    + (root.supportsAvif ? ", avif" : "") + ")"
        } else {
            root.error = ""
        }
        root.scanFinished()
    }

    property int scanGeneration: 0

    property Process avifProc: Process {
        command: ["sh", "-c",
            "p=$(qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null); " +
            "[ -n \"$p\" ] || p=$(qtpaths6 --query QT_INSTALL_PLUGINS 2>/dev/null); " +
            "[ -n \"$p\" ] || exit 1; ls \"$p\"/imageformats/*avif* >/dev/null 2>&1"]
        onExited: function(code, status) {
            root.avifChecked = true
            root.supportsAvif = (code === 0)
        }
    }

    property Process checkProc: Process {
        property int generation: -1
        stdout: StdioCollector { id: checkOut; waitForEnd: true }
        stderr: StdioCollector { id: checkErr; waitForEnd: true }
        onExited: function(code, status) {
            if (checkProc.generation !== root.scanGeneration)
                return
            if (code !== 0) {
                var msg = "Папка недоступна"
                if (code === 1) msg = "Папка не існує"
                else if (code === 2) msg = "Шлях не є папкою"
                else if (code === 3) msg = "Немає прав на читання папки"
                root._finishScanError(root.scanGeneration, msg)
                return
            }
            var canonical = String(checkOut.text || "").trim()
            if (canonical === "") {
                root._finishScanError(root.scanGeneration, "Не вдалося визначити шлях до папки")
                return
            }
            root.resolvedFolder = canonical
            root._startFind(root.scanGeneration, canonical)
        }
    }

    property Process scanProc: Process {
        property int generation: -1
        property string folder: ""
        stdout: StdioCollector { id: scanOut; waitForEnd: true }
        stderr: StdioCollector { id: scanErr; waitForEnd: true }
        onExited: function(code, status) {
            root._finishScan(scanProc.generation, scanProc.folder,
                             scanOut.text, scanErr.text, code)
        }
    }

    // ================= CURRENT WALLPAPER =================
    function refreshCurrent() {
        if (!currentProc.running)
            currentProc.running = true
    }

    function _ingestActive(text) {
        var map = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line === "")
                continue
            var idx = line.indexOf(": ")
            if (idx < 0)
                continue
            map[line.substring(0, idx)] = line.substring(idx + 2)
        }
        root.activePaths = map

        var focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        var candidate = map[focused] || ""
        if (!candidate) {
            var keys = Object.keys(map)
            if (keys.length > 0)
                candidate = map[keys[0]]
        }

        if (candidate !== "") {
            root.currentMonitorName = focused && map[focused] ? focused : ""
            if (root._isCenterCache(candidate) && Config.wallpaperCurrentPath !== "")
                root.currentPath = Config.wallpaperCurrentPath
            else
                root.currentPath = candidate
        }
    }

    property Process currentProc: Process {
        command: ["hyprctl", "hyprpaper", "listactive"]
        stdout: StdioCollector { id: currentOut; waitForEnd: true }
        stderr: StdioCollector { id: currentErr; waitForEnd: true }
        onExited: function(code, status) {
            if (code !== 0) {
                root.backendReady = false
                root.backendError = "hyprpaper недоступний: "
                        + String(currentErr.text || "").trim()
                return
            }
            root.backendReady = true
            root.backendError = ""
            root._ingestActive(currentOut.text)
        }
    }

    // ================= APPLY =================
    function applyWallpaper(path, monitor, mode, silent) {
        if (root.applying) {
            root.applyError = "Застосування вже виконується"
            return
        }

        var p = String(path || "")
        if (p === "") {
            root.applyError = "Не вибрано зображення"
            return
        }
        if (p.indexOf(",") >= 0) {
            root.applyError = "Шлях містить кому — hyprpaper не підтримує такий шлях"
            return
        }
        if (!root.backendReady) {
            root.applyError = root.backendError || "hyprpaper недоступний"
            return
        }

        var mons = root.targetMonitors(monitor)
        if (mons.length === 0) {
            root.applyError = "Немає доступних моніторів"
            return
        }

        var modeKey = String(mode || "fill").toLowerCase()
        if (["fill", "fit", "stretch", "center"].indexOf(modeKey) < 0)
            modeKey = "fill"

        root.applying = true
        root.applyError = ""
        root.applyStatus = "Застосування…"
        root.lastApplyOk = false
        root.verifyAttempts = 0
        applyTimeout.restart()
        root.pendingApply = {
            path: p,
            monitor: String(monitor || "All"),
            mode: modeKey,
            monitors: mons,
            sizes: ({}),
            expected: ({}),
            silent: silent === true
        }

        if (modeKey === "center") {
            root.applyStatus = "Підготовка центрованого зображення…"
            root._fetchMonitorSizes()
            return
        }

        var fit = modeKey === "fit" ? "contain"
                : modeKey === "stretch" ? "stretch" : "cover"
        var specs = []
        var expected = {}
        for (var i = 0; i < mons.length; ++i) {
            specs.push(mons[i] + "," + p + "," + fit)
            expected[mons[i]] = p
        }
        root.pendingApply.expected = expected
        root._runApplyProcess(root._normalApplyCommand(specs))
    }

    function _normalApplyCommand(specs) {
        var cmd = ["sh", "-c",
            "for spec in \"$@\"; do hyprctl hyprpaper wallpaper \"$spec\" || exit $?; done",
            "sh"]
        for (var i = 0; i < specs.length; ++i)
            cmd.push(specs[i])
        return cmd
    }

    function _fetchMonitorSizes() {
        if (monitorsProc.running)
            monitorsProc.running = false
        monitorsProc.running = true
    }

    function _startCenterApply() {
        var pending = root.pendingApply
        if (!pending) {
            root._failApply("Внутрішня помилка: немає даних для застосування")
            return
        }

        var outdir = root.cacheFolder
        var specs = []
        var expected = {}
        for (var i = 0; i < pending.monitors.length; ++i) {
            var mon = pending.monitors[i]
            var size = pending.sizes[mon]
            if (!size || !size.width || !size.height) {
                root._failApply("Немає розмірів для монітора " + mon)
                return
            }
            specs.push(mon + "|" + size.width + "x" + size.height)
            expected[mon] = outdir + "/center-" + mon + ".jpg"
        }
        pending.expected = expected

        var script = "set -e; src=\"$1\"; outdir=\"$2\"; shift 2; mkdir -p \"$outdir\"; "
                + "for spec in \"$@\"; do "
                + "mon=\"${spec%%|*}\"; size=\"${spec##*|}\"; "
                + "out=\"$outdir/center-${mon}.jpg\"; "
                + "magick \"$src\" -background \"#000000\" -alpha remove -alpha off "
                + "-gravity center -extent \"$size\" \"$out\"; "
                + "hyprctl hyprpaper wallpaper \"${mon},${out},cover\"; "
                + "done"

        var cmd = ["sh", "-c", script, "sh", pending.path, outdir]
        for (var j = 0; j < specs.length; ++j)
            cmd.push(specs[j])

        root.applyStatus = "Застосування центрованого зображення…"
        root._runApplyProcess(cmd)
    }

    function _runApplyProcess(cmd) {
        if (applyProc.running)
            applyProc.running = false
        applyProc.command = cmd
        applyProc.running = true
    }

    function _commitApply() {
        var pending = root.pendingApply
        if (!pending)
            return
        applyTimeout.stop()
        root.applying = false
        root.lastApplyOk = true
        root.currentPath = pending.path
        root.currentMonitorName = pending.monitor === "All" ? "" : pending.monitor
        root.applyStatus = pending.silent ? ""
                : pending.monitor === "All"
                  ? "Обої застосовано на всі монітори"
                  : "Обої застосовано на " + pending.monitor
        root.applyError = ""
        root.pendingApply = null
        root.restorePending = false
        Config.setProp("Wallpaper.currentPath", pending.path)
        Config.setProp("Wallpaper.currentMonitor", pending.monitor)
        Config.setProp("Wallpaper.fillMode", pending.mode)
        root.refreshCurrent()
        root.applyFinished(true)
    }

    function _failApply(message) {
        var pending = root.pendingApply
        applyTimeout.stop()
        root.applying = false
        root.lastApplyOk = false
        root.applyStatus = ""
        root.applyError = String(message || "Не вдалося застосувати обої")
        root.pendingApply = null
        root.applyFinished(false)

        if (root.restorePending && root.restoreAttempts < 3) {
            root.restorePending = false
            restoreRetryTimer.restart()
        } else {
            root.restorePending = false
        }
        if (pending && pending.silent) {
            // Автоматичне відновлення не повинно вважатися успішним.
            root.lastApplyOk = false
        }
    }

    function _parseActiveMap(text) {
        var map = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line === "")
                continue
            var idx = line.indexOf(": ")
            if (idx < 0)
                continue
            map[line.substring(0, idx)] = line.substring(idx + 2)
        }
        return map
    }

    property Process applyProc: Process {
        stdout: StdioCollector { id: applyOut; waitForEnd: true }
        stderr: StdioCollector { id: applyErr; waitForEnd: true }
        onExited: function(code, status) {
            if (!root.applying)
                return
            if (code !== 0) {
                var detail = String(applyErr.text || "").trim()
                if (detail === "")
                    detail = String(applyOut.text || "").trim()
                root._failApply("hyprpaper: " + (detail || "невідома помилка"))
                return
            }
            root.applyStatus = "Перевірка результату…"
            root.verifyAttempts = 0
            verifyDelay.restart()
        }
    }

    property Process verifyProc: Process {
        command: ["hyprctl", "hyprpaper", "listactive"]
        stdout: StdioCollector { id: verifyOut; waitForEnd: true }
        stderr: StdioCollector { id: verifyErr; waitForEnd: true }
        onExited: function(code, status) {
            if (!root.applying || !root.pendingApply)
                return
            if (code !== 0) {
                root._failApply("Не вдалося перевірити стан hyprpaper")
                return
            }

            var actual = root._parseActiveMap(verifyOut.text)
            var expected = root.pendingApply.expected || {}
            var missing = []
            var keys = Object.keys(expected)
            for (var i = 0; i < keys.length; ++i) {
                var mon = keys[i]
                if (actual[mon] !== expected[mon])
                    missing.push(mon)
            }

            if (missing.length > 0) {
                if (root.verifyAttempts < 2) {
                    root.verifyAttempts++
                    verifyDelay.restart()
                    return
                }
                root._failApply("hyprpaper не підтвердив зміну для: " + missing.join(", "))
                return
            }
            root._commitApply()
        }
    }

    property Process monitorsProc: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { id: monitorsOut; waitForEnd: true }
        stderr: StdioCollector { id: monitorsErr; waitForEnd: true }
        onExited: function(code, status) {
            if (!root.applying || !root.pendingApply
                    || root.pendingApply.mode !== "center")
                return
            if (code !== 0) {
                root._failApply("Не вдалося отримати розміри моніторів")
                return
            }
            try {
                var arr = JSON.parse(String(monitorsOut.text || "[]"))
                var sizes = {}
                for (var i = 0; i < arr.length; ++i) {
                    var m = arr[i]
                    if (!m || !m.name)
                        continue
                    sizes[m.name] = {
                        width: Number(m.width) || 0,
                        height: Number(m.height) || 0
                    }
                }
                root.pendingApply.sizes = sizes
            } catch (e) {
                root._failApply("Не вдалося розібрати розміри моніторів")
                return
            }
            root._startCenterApply()
        }
    }

    // ================= TIMERS =================
    property Timer restoreTimer: Timer {
        interval: 1600
        repeat: false
        onTriggered: root._tryRestore()
    }

    property Timer restoreRetryTimer: Timer {
        interval: 1200
        repeat: false
        onTriggered: root._tryRestore()
    }

    property Timer startupOpenTimer: Timer {
        interval: 1400
        repeat: false
        onTriggered: {
            if (Config.wallpaperOpenOnStartup)
                root.openPickerRequested()
        }
    }

    property Timer applyTimeout: Timer {
        interval: 20000
        repeat: false
        onTriggered: {
            if (root.applying)
                root._failApply("Час очікування застосування вичерпано")
        }
    }

    property Timer verifyDelay: Timer {
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.applying)
                return
            if (root.verifyProc.running)
                root.verifyProc.running = false
            root.verifyProc.running = true
        }
    }

    function _tryRestore() {
        if (!Config.wallpaperRestoreOnStartup)
            return
        var saved = Config.wallpaperCurrentPath
        if (!saved)
            return

        if (!root.backendReady) {
            if (root.restoreAttempts < 6) {
                root.restoreAttempts++
                restoreTimer.restart()
            }
            return
        }

        if (root.applying) {
            if (root.restoreAttempts < 6) {
                root.restoreAttempts++
                restoreTimer.restart()
            }
            return
        }

        // Перевіряємо всі цільові монітори, а не лише сфокусований:
        // інакше відновлення пропускається, якщо збігається один екран.
        if (root._savedIsActive())
            return

        root.restoreAttempts++
        root.restorePending = true
        root.applyWallpaper(saved,
                            Config.wallpaperCurrentMonitor || "All",
                            Config.wallpaperFillMode || "fill",
                            true)
    }

    Component.onCompleted: {
        // Lazy: initialize() викликається з shell.qml, щоб не сканувати
        // колекцію під час старту без потреби.
        root._detectAvif()
    }
}
