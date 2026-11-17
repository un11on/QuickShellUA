import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root

    // -------- Public state --------
    property var monitors: []          // [{name, description, x, y, width, height, scale, refreshRate, transform, focused, disabled, availableModes, logicalWidth, logicalHeight}]
    property var selectedMonitor: null // currently selected monitor object
    property bool loading: true
    property string errorMessage: ""

    // -------- Internal --------
    property var _snapshot: null       // snapshot for rollback
    property var _pending: null        // pending changes awaiting confirmation
    // Persisted/merged cache of all known outputs (including disabled) keyed by name.
    property var _known: ({})
    property bool _allLoaded: false
    property string _statePath: Quickshell.env("HOME") + "/.local/state/quickshell/monitor-manager.json"
    property var _pendingEnable: ({})  // name -> timestamp; prevents stale monitors-all from forcing disabled
    property var _lastCmdResult: ""

    // -------- Initialization --------
    Component.onCompleted: {
        root._loadState()
        root.refresh()
    }

    // Startup retry timer: Hyprland IPC connects asynchronously after QML init
    property Timer _initTimer: Timer {
        interval: 120
        repeat: true
        running: root.monitors.length === 0 || !root._allLoaded
        property int _tries: 0
        onTriggered: {
            _tries++
            if (Hyprland.monitors && Hyprland.monitors.values && Hyprland.monitors.values.length > 0) {
                root.refresh()
            }
            if (!root._allLoaded) root._refreshAll()
            if (root._allLoaded && root.monitors.length > 0) _initTimer.stop()
            if (_tries > 40) _initTimer.stop()
        }
    }

    property Connections monitorConnections: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && (event.name === "monitoradded" || event.name === "monitorremoved" || event.name === "monitorconfig")) {
                // Don't auto-refresh while applying; apply flow triggers a single refresh.
                if (!_applying) root._debounce.restart()
            }
        }
    }

    property Timer _debounce: Timer {
        interval: 320
        repeat: false
        onTriggered: {
            root._refreshAll()
            root._rebuild()
        }
    }
    property Timer _identifyTimer: Timer { interval: 3000; repeat: false; onTriggered: { } }

    // -------- Discover all outputs (including disabled) --------
    property var _saveTimer: null
    property Process _allProc: Process {
        id: allProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    if (Array.isArray(arr)) root._ingestAll(arr)
                } catch (e) {
                    // keep previous known state
                }
                root._allLoaded = true
                root._rebuild()
            }
        }
        onExited: function(code, status) {
            if (code !== 0) {
                root._allLoaded = true
                root._rebuild()
            }
        }
    }

    function _refreshAll() {
        if (!_allProc.running) _allProc.running = true
    }

    function _isVirtualOutput(name) {
        if (!name) return true
        var n = String(name).toUpperCase()
        return n === "FALLBACK" || n.indexOf("HEADLESS") === 0
    }

    function _ingestAll(arr) {
        if (!Array.isArray(arr)) return
        var prevKnown = root._known || {}
        var known = {}
        var now = Date.now()
        var seen = {}
        for (var i = 0; i < arr.length; ++i) {
            var raw = arr[i]
            if (!raw || !raw.name || root._isVirtualOutput(raw.name)) continue
            seen[raw.name] = true
            var prev = prevKnown[raw.name] || {}
            var modes = root._extractModesFromRaw(raw)
            if (!modes || modes.length === 0) modes = prev.availableModes || []
            var w = raw.width || prev.width || 0
            var h = raw.height || prev.height || 0
            var rr = raw.refreshRate || prev.refreshRate || 0
            var sc = raw.scale || prev.scale || 1
            var tr = (raw.transform !== undefined ? raw.transform : (prev.transform !== undefined ? prev.transform : 0))
            var x = (raw.x !== undefined ? raw.x : (prev.x !== undefined ? prev.x : 0))
            var y = (raw.y !== undefined ? raw.y : (prev.y !== undefined ? prev.y : 0))
            var disabled = !!raw.disabled
            var pe = root._pendingEnable ? root._pendingEnable[raw.name] : 0
            if (pe && (now - pe) < 7000) {
                if (!disabled) {
                    var npe = root._pendingEnable || {}; delete npe[raw.name]; root._pendingEnable = npe
                } else {
                    disabled = false
                }
            }
            known[raw.name] = {
                name: raw.name,
                description: raw.description || prev.description || raw.name,
                x: x, y: y,
                width: w, height: h,
                scale: sc,
                refreshRate: rr,
                transform: tr,
                focused: disabled ? false : !!raw.focused,
                disabled: disabled,
                availableModes: modes,
                logicalWidth: root._logicalWidth(w, h, sc, tr),
                logicalHeight: root._logicalHeight(w, h, sc, tr)
            }
        }
        // Keep only outputs Hyprland currently reports (all). This removes stale FALLBACK/
        // phantom entries and prevents duplicate cards. Missing physical outputs will reappear
        // when Hyprland reports them again.
        root._known = known
        root._saveStateLater()
    }

    function _extractModesFromRaw(raw) {
        return root._extractModes(raw)
    }

    property Process _saveProc: Process { id: saveProc }
    function _saveStateLater() {
        if (!_saveTimer) {
            _saveTimer = Qt.createQmlObject(
                'import QtQuick 2.15; Timer { interval: 400; repeat: false }',
                root, "mmSaveTimer"
            )
            _saveTimer.triggered.connect(function() { root._saveState() })
        }
        _saveTimer.restart()
    }
    function _saveState() {
        try {
            var dir = Quickshell.env("HOME") + "/.local/state/quickshell"
            var payload = JSON.stringify({ known: root._known || {} })
            _saveProc.command = ["sh", "-c", "mkdir -p " + dir + " && cat > " + root._statePath + " <<'QSJSON'\n" + payload + "\nQSJSON\n"]
            _saveProc.running = true
        } catch (e) {}
    }
    property Process _loadProc: Process {
        id: loadProc
        command: ["sh", "-c", "cat " + root._statePath + " 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (text && text.trim().length > 0) {
                        var obj = JSON.parse(text)
                        if (obj && obj.known) {
                            var k = obj.known
                            var cleaned = {}
                            for (var n in k) {
                                if (!root._isVirtualOutput(n) && k[n] && k[n].name) cleaned[n] = k[n]
                            }
                            root._known = cleaned
                        }
                    }
                } catch (e) {}
                // Do not auto-enable anything; discovery (monitors all) will reconcile.
                root._refreshAll()
                root._rebuild()
            }
        }
    }
    function _loadState() {
        if (!_loadProc.running) _loadProc.running = true
    }

    function activeCount() {
        var n = 0
        var list = root.monitors || []
        for (var i = 0; i < list.length; ++i) {
            if (!list[i].disabled) n++
        }
        return n
    }

    // -------- Command execution (Hyprland 0.57 Lua config) --------
    // `hyprctl keyword` IPC returns "unknown request" on this build; use `hyprctl eval`
    // with hl.monitor({...}) which applies dynamically on Lua-configured Hyprland.
    property var _cmdQueue: []
    property bool _applying: false
    property var _applyRefresh: null

    property Process _cmdProc: Process {
        id: cmdProc
        stdout: StdioCollector {
            onStreamFinished: { root._lastCmdResult = (text || "").trim() }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var t = (text || "").trim()
                if (t.length > 0) root._lastCmdResult = t
            }
        }
        onExited: function(code, status) {
            root._cmdQueue.shift()
            if (root._cmdQueue.length > 0) {
                root._runNext()
            } else {
                root._applying = false
                if (!root._applyRefresh) {
                    root._applyRefresh = Qt.createQmlObject(
                        'import QtQuick 2.15; Timer { interval: 650; repeat: false }',
                        root, "mmApplyRefresh"
                    )
                    root._applyRefresh.triggered.connect(function() { root.refresh() })
                }
                root._applyRefresh.restart()
            }
        }
    }

    function _enqueueEval(lua) {
        if (!lua) return
        _cmdQueue.push(lua)
        if (!_cmdProc.running) _runNext()
    }

    function _runNext() {
        if (_cmdQueue.length === 0) return
        _applying = true
        _cmdProc.command = ["hyprctl", "eval", _cmdQueue[0]]
        _cmdProc.running = true
    }

    function _luaStr(v) {
        return '"' + String(v).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    // -------- Refresh monitor list (keeps disabled known outputs) --------
    function refresh() {
        loading = true
        errorMessage = ""
        var source = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : []
        var known = root._known || {}
        var activeNames = {}
        for (var i = 0; i < source.length; ++i) {
            var m = source[i]
            if (m && root._isVirtualOutput(m.name)) continue
            var raw = m.lastIpcObject || {}
            var modes = root._extractModes(raw)
            var prev = known[m.name] || {}
            if (!modes || modes.length === 0) modes = prev.availableModes || []
            var tr = (m.transform !== undefined ? m.transform : (raw.transform !== undefined ? raw.transform : (prev.transform !== undefined ? prev.transform : 0)))
            var rr = raw.refreshRate || m.refreshRate || prev.refreshRate || 0
            var w = m.width || prev.width || 0
            var h = m.height || prev.height || 0
            var sc = m.scale || prev.scale || 1
            var x = (m.x !== undefined ? m.x : (prev.x !== undefined ? prev.x : 0))
            var y = (m.y !== undefined ? m.y : (prev.y !== undefined ? prev.y : 0))
            known[m.name] = {
                name: m.name,
                description: m.description || raw.description || prev.description || m.name,
                x: x, y: y,
                width: w, height: h,
                scale: sc,
                refreshRate: rr,
                transform: tr,
                focused: !!m.focused,
                disabled: !!raw.disabled,
                availableModes: modes,
                logicalWidth: root._logicalWidth(w, h, sc, tr),
                logicalHeight: root._logicalHeight(w, h, sc, tr)
            }
            activeNames[m.name] = true
        }
        // Only merge active updates here. Do not invent/enable absent outputs.
        // Authoritative full list (including disabled) comes from monitors-all.
        root._known = known
        root._saveStateLater()
        root._refreshAll()
        root._rebuild()
    }

    function _rebuild() {
        var known = root._known || {}
        var list = []
        var names = Object.keys(known)
        // Stable order: active first by x/y/name, then disabled by name.
        names.sort(function(a, b) {
            var A = known[a] || {}, B = known[b] || {}
            var ad = A.disabled ? 1 : 0, bd = B.disabled ? 1 : 0
            if (ad !== bd) return ad - bd
            var ax = A.x || 0, bx = B.x || 0
            if (ax !== bx) return ax - bx
            var ay = A.y || 0, by = B.y || 0
            if (ay !== by) return ay - by
            return String(a).localeCompare(String(b))
        })
        for (var i = 0; i < names.length; ++i) {
            var it = known[names[i]]
            if (it && it.name) list.push(JSON.parse(JSON.stringify(it)))
        }
        monitors = list
        loading = false

        var prevName = (selectedMonitor ? selectedMonitor.name : null)
        if (monitors.length > 0) {
            if (!prevName || !root.selectMonitor(prevName)) {
                var pick = null
                for (var j = 0; j < monitors.length; ++j) { if (!monitors[j].disabled) { pick = monitors[j].name; break } }
                selectMonitor(pick || monitors[0].name)
            }
        } else {
            selectedMonitor = null
        }
        if (!_snapshot) _snapshot = JSON.parse(JSON.stringify(monitors))
    }

    // -------- Extract available modes from raw IPC object --------
    function _extractModes(raw) {
        var modes = []
        var rawModes = []
        if (raw.availableModes) {
            if (Array.isArray(raw.availableModes)) {
                rawModes = raw.availableModes
            } else if (typeof raw.availableModes === "string") {
                rawModes = [raw.availableModes]
            }
        }
        for (var i = 0; i < rawModes.length; ++i) {
            var entry = rawModes[i]
            var width = 0, height = 0, refreshRate = 0
            if (typeof entry === "object" && entry !== null) {
                width = entry.width || 0
                height = entry.height || 0
                refreshRate = entry.refreshRate || 0
            } else if (typeof entry === "string") {
                // Parse "2560x1600@240.00Hz" or "1920x1080@60.00Hz"
                var parts = entry.split("@")
                if (parts.length === 2) {
                    var res = parts[0].split("x")
                    width = parseInt(res[0], 10) || 0
                    height = parseInt(res[1], 10) || 0
                    var rateStr = parts[1].replace("Hz", "").replace("hz", "")
                    refreshRate = parseFloat(rateStr) || 0
                }
            }
            if (width > 0 && height > 0 && refreshRate > 0) {
                modes.push({ width: width, height: height, refreshRate: refreshRate })
            }
        }
        var seen = {}
        var unique = []
        for (var i = 0; i < modes.length; ++i) {
            var key = modes[i].width + "x" + modes[i].height + "@" + (Math.round(modes[i].refreshRate * 100) / 100)
            if (!seen[key]) {
                seen[key] = true
                unique.push(modes[i])
            }
        }
        return unique
    }

    // -------- Logical size calculation (accounts for scale and rotation) --------
    function _logicalWidth(w, h, scale, transform) {
        if (!scale || scale <= 0) scale = 1
        var lw = w / scale
        var lh = h / scale
        if (transform === 1 || transform === 3) return lh
        return lw
    }
    function _logicalHeight(w, h, scale, transform) {
        if (!scale || scale <= 0) scale = 1
        var lw = w / scale
        var lh = h / scale
        if (transform === 1 || transform === 3) return lw
        return lh
    }

    // -------- Select monitor --------
    function selectMonitor(name) {
        for (var i = 0; i < monitors.length; ++i) {
            if (monitors[i].name === name) {
                selectedMonitor = JSON.parse(JSON.stringify(monitors[i]))
                return true
            }
        }
        return false
    }

    // -------- Get monitor by name --------
    function getMonitor(name) {
        for (var i = 0; i < monitors.length; ++i) {
            if (monitors[i].name === name) return monitors[i]
        }
        return null
    }

    function _monitorEval(mon) {
        if (!mon || !mon.name) return ""
        var name = _luaStr(mon.name)
        // Disable: set disabled only (Hyprland keeps output known).
        if (mon.disabled) {
            return 'hl.monitor({output=' + name + ',disabled=true})'
        }
        // Enable/apply: on Hyprland 0.57 Lua config, setting mode/position/scale/transform
        // alone can leave `disabled=true` (eval returned ok but output stayed disabled).
        // Explicitly clear disabled first, then apply the full rule with last known params.
        var known = (root._known && root._known[mon.name]) ? root._known[mon.name] : {}
        var w = mon.width || known.width || 0
        var h = mon.height || known.height || 0
        var rr = (mon.refreshRate !== undefined && mon.refreshRate > 0) ? mon.refreshRate : (known.refreshRate || 0)
        var sc = (mon.scale !== undefined && mon.scale > 0) ? mon.scale : (known.scale || 1)
        var tr = (mon.transform !== undefined) ? mon.transform : (known.transform !== undefined ? known.transform : 0)
        var x = (mon.x !== undefined) ? mon.x : (known.x !== undefined ? known.x : 0)
        var y = (mon.y !== undefined) ? mon.y : (known.y !== undefined ? known.y : 0)
        var mode = (w > 0 && h > 0 && rr > 0)
            ? (w + "x" + h + "@" + (Math.round(rr * 1000) / 1000).toString())
            : "preferred"
        var pos = (w > 0 || h > 0 || x !== 0 || y !== 0) ? (x + "x" + y) : "auto"
        var apply = 'hl.monitor({output=' + name
            + ',mode=' + _luaStr(mode)
            + ',position=' + _luaStr(pos)
            + ',scale=' + sc
            + ',transform=' + tr + '})'
        var clear = 'hl.monitor({output=' + name + ',disabled=false})'
        // Run both in one eval; apply after clear so final rule is authoritative.
        return clear + '; ' + apply
    }

    // -------- Toggle monitor enabled/disabled --------
    function toggleMonitor(name) {
        var m = root.getMonitor(name)
        if (!m) return
        // Do not disable the last active monitor.
        if (!m.disabled && root.activeCount() <= 1) return
        var copy = JSON.parse(JSON.stringify(m))
        copy.disabled = !copy.disabled
        // Optimistic local state: keep card visible with new status.
        var known = root._known || {}
        var base = known[name] ? JSON.parse(JSON.stringify(known[name])) : copy
        for (var k in copy) base[k] = copy[k]
        base.disabled = copy.disabled
        if (!base.disabled) base.focused = base.focused || false
        known[name] = base
        root._known = known
        if (!copy.disabled) {
            var pe = root._pendingEnable || {}; pe[name] = Date.now(); root._pendingEnable = pe
        } else {
            var pe2 = root._pendingEnable || {}; delete pe2[name]; root._pendingEnable = pe2
        }
        root._rebuild()
        root._saveStateLater()
        root._enqueueEval(root._monitorEval(base))
        root._refreshAll()
    }

    // -------- Update monitor position (from drag) --------
    function updateMonitorPosition(name, x, y) {
        for (var i = 0; i < monitors.length; ++i) {
            if (monitors[i].name === name) {
                monitors[i].x = x
                monitors[i].y = y
                break
            }
        }
        if (selectedMonitor && selectedMonitor.name === name) {
            selectedMonitor.x = x
            selectedMonitor.y = y
        }
        _debounce.restart()
    }

    // -------- Apply changes to a monitor --------
    function applyMonitor(mon) {
        if (!mon || !mon.name) return
        var cur = root.getMonitor(mon.name)
        var target = mon.disabled ? true : false
        // Protect last active monitor from being disabled via settings apply.
        if (target && cur && !cur.disabled && root.activeCount() <= 1) return
        if (target && root.activeCount() <= 1 && (!cur || !cur.disabled)) return
        var known = root._known || {}
        var base = known[mon.name] ? JSON.parse(JSON.stringify(known[mon.name])) : {}
        var merged = base
        for (var k in mon) merged[k] = mon[k]
        merged.disabled = target
        if ((!merged.availableModes || merged.availableModes.length === 0) && base.availableModes)
            merged.availableModes = base.availableModes
        if (!merged.description && base.description) merged.description = base.description
        known[mon.name] = merged
        root._known = known
        root._rebuild()
        root._saveStateLater()
        root._enqueueEval(root._monitorEval(merged))
        // Mark pending enable so stale monitors-all can't force disabled; do NOT auto-reissue enable.
        if (!target) {
            var pe = root._pendingEnable || {}; pe[mon.name] = Date.now(); root._pendingEnable = pe
            root._refreshAll()
        } else {
            var pe2 = root._pendingEnable || {}; delete pe2[mon.name]; root._pendingEnable = pe2
        }
    }

    // -------- Apply all pending changes --------
    function applyAll() {
        for (var i = 0; i < monitors.length; ++i) {
            root.applyMonitor(monitors[i])
        }
        _snapshot = null
        _pending = null
    }

    // -------- Identify monitors --------
    function identify() {
        // Best-effort: dynamic "identify" is not exposed via hl.monitor eval on this setup.
        // Keep method callable so UI wiring remains intact.
        _identifyTimer.restart()
    }

    // -------- Safe apply with confirmation --------
    function snapshot() { _snapshot = JSON.parse(JSON.stringify(monitors)) }
    function pending(updated) { _pending = updated }
    function confirm() { _snapshot = null; _pending = null }
    function rollback() {
        if (!_snapshot) return
        var snap = JSON.parse(JSON.stringify(_snapshot))
        var known = {}
        for (var i = 0; i < snap.length; ++i) {
            if (snap[i] && snap[i].name) known[snap[i].name] = snap[i]
        }
        root._known = known
        root._rebuild()
        for (var j = 0; j < snap.length; ++j) {
            root._enqueueEval(root._monitorEval(snap[j]))
        }
        _snapshot = null
        _pending = null
        root._saveStateLater()
    }
    function hasChanges() {
        if (!_snapshot) return false
        var cur = JSON.stringify(monitors)
        var snap = JSON.stringify(_snapshot)
        return cur !== snap
    }
}
