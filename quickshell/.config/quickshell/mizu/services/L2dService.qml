pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
    readonly property string socketPath: root.runtimeDir + "/mizu-l2d-wall.sock"
    readonly property string configPath: root.home + "/.config/mizu-l2d/config.toml"
    readonly property string mappingPath: root.home + "/.local/share/mizu/data/l2d_mapping.json"
    readonly property string l2dDir: root.home + "/.local/share/mizu/l2d"
    readonly property string mizuL2dDir: root.home + "/Projects/Tools/mizu-l2d"
    readonly property string ctlScript: root.mizuL2dDir + "/wall/mizu-l2d-ctl.py"
    readonly property string fetchScript: root.mizuL2dDir + "/scripts/fetch-model.sh"

    // State machine: off | starting | running | stopping | error
    property string state: "off"
    property string statusText: "Stopped"
    property string currentModel: SettingsService.get("wallpaper.liveModel") || "gaoxiong_7"
    property string currentOutputs: SettingsService.get("wallpaper.liveOutputs") || ""
    property bool tips: SettingsService.flag("wallpaper.liveTips")
    property bool placementLocked: SettingsService.flag("wallpaper.placementLocked")
    property bool gaze: SettingsService.flag("wallpaper.gazeFollow") !== false

    readonly property string previewDir: root.home + "/.local/share/mizu/verify-shots"

    function previewFor(prefab) {
        return "file://" + root.previewDir + "/" + prefab + ".png"
    }

    readonly property var currentSkinInfo: {
        const p = root.currentModel || "gaoxiong_7"
        for (let i = 0; i < root.catalog.length; i++) {
            const ship = root.catalog[i]
            for (let j = 0; j < (ship.skins || []).length; j++) {
                const s = ship.skins[j]
                if (s.prefab === p) {
                    return {
                        shipName: ship.name,
                        shipSub: [ship.cnName, ship.jpName].filter(Boolean).join(" · "),
                        skinName: s.name,
                        skinSub: [s.cnName, s.jpName].filter(Boolean).join(" · "),
                        prefab: p
                    }
                }
            }
        }
        return {
            shipName: p,
            shipSub: "",
            skinName: p,
            skinSub: "",
            prefab: p
        }
    }

    property var catalog: []
    property var downloadedModels: []
    property string downloadingPrefab: ""
    property string downloadProgress: ""
    property int consecutiveFailures: 0
    property var onDownloadFinished: null

    readonly property bool running: state === "running"
    readonly property bool isDownloading: downloadingPrefab !== ""

    // Read l2d_mapping.json for ship/skin catalog
    FileView {
        id: mappingFile
        path: root.mappingPath
        watchChanges: false
        onLoaded: {
            try {
                const data = JSON.parse(mappingFile.text())
                const list = []
                for (const shipId in data) {
                    const ship = data[shipId]
                    const enName = (ship.names && ship.names.EN) ? ship.names.EN : ("Ship " + shipId)
                    const skins = (ship.skins || []).map(s => ({
                        prefab: s.prefab,
                        name: (s.names && s.names.EN) ? s.names.EN : s.prefab,
                        cnName: (s.names && s.names.CN) ? s.names.CN : "",
                        jpName: (s.names && s.names.JP) ? s.names.JP : "",
                        bg: s.bg || ""
                    }))
                    list.push({
                        id: shipId,
                        name: enName,
                        cnName: (ship.names && ship.names.CN) ? ship.names.CN : "",
                        jpName: (ship.names && ship.names.JP) ? ship.names.JP : "",
                        skins: skins
                    })
                }
                list.sort((a, b) => a.name.localeCompare(b.name))
                root.catalog = list
            } catch (err) {
                console.warn("[L2dService] Failed to parse l2d_mapping.json:", err)
            }
        }
        onLoadFailed: error => {
            console.warn("[L2dService] Failed to load l2d_mapping.json:", error)
        }
    }

    // Process: Scan downloaded models on disk
    Process {
        id: diskScanner
        command: [
            "sh", "-c",
            "for d in \"$HOME/.local/share/mizu/l2d\"/*; do [ -d \"$d\" ] && [ -f \"$d/$(basename \"$d\").model3.json\" ] && basename \"$d\"; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(s => s.trim()).filter(Boolean)
                root.downloadedModels = lines
            }
        }
    }

    function refreshDownloaded() {
        if (!diskScanner.running) {
            diskScanner.running = true
        }
    }

    function isDownloaded(prefab) {
        return root.downloadedModels.indexOf(prefab) >= 0
    }

    // Process: Download model via fetch-model.sh <prefab> --bg
    Process {
        id: downloader
        stdout: StdioCollector {
            onStreamFinished: {
                root.downloadProgress = "100%"
            }
        }
        onExited: exitCode => {
            const finishedPrefab = root.downloadingPrefab
            root.downloadingPrefab = ""
            root.downloadProgress = ""
            root.refreshDownloaded()
            if (exitCode === 0) {
                if (root.onDownloadFinished) {
                    const cb = root.onDownloadFinished
                    root.onDownloadFinished = null
                    cb(true, finishedPrefab)
                }
            } else {
                root.statusText = "Download failed for " + finishedPrefab
                if (root.state === "starting") {
                    root.state = "error"
                }
                if (root.onDownloadFinished) {
                    const cb = root.onDownloadFinished
                    root.onDownloadFinished = null
                    cb(false, finishedPrefab)
                }
            }
        }
    }

    function downloadModel(prefab, callback) {
        if (root.isDownloading) {
            console.warn("[L2dService] Download already in progress for " + root.downloadingPrefab)
            return
        }
        root.downloadingPrefab = prefab
        root.downloadProgress = "0%"
        root.statusText = "Downloading " + prefab + "..."
        root.onDownloadFinished = callback || null
        downloader.exec(["bash", root.fetchScript, prefab, "--bg"])
    }

    // Process: Write ~/.config/mizu-l2d/config.toml
    Process {
        id: configSaver
        property var onSaved: null
        function writeConfig(model, outputs, callback) {
            configSaver.onSaved = callback || null
            configSaver.exec([
                "python3", "-c",
                "import sys, pathlib\npath, model, outputs = sys.argv[1:4]\np = pathlib.Path(path)\np.parent.mkdir(parents=True, exist_ok=True)\nlines = ['schema = 1\\n', '\\n', '[wall]\\n', f'model = \"{model}\"\\n']\nif outputs.strip():\n    outs = [o.strip() for o in outputs.split(',') if o.strip()]\n    lines.append('outputs = [' + ', '.join(f'\"{o}\"' for o in outs) + ']\\n')\np.write_text(''.join(lines), encoding='utf-8')",
                root.configPath, model, outputs
            ])
        }
        onExited: {
            if (configSaver.onSaved) {
                const cb = configSaver.onSaved
                configSaver.onSaved = null
                cb()
            }
        }
    }

    // Process: Control CLI execution (model switch, ping, status)
    Process {
        id: ctlProc
        property var onReply: null
        property string rawOutput: ""
        stdout: StdioCollector {
            onStreamFinished: {
                ctlProc.rawOutput = text
            }
        }
        onExited: exitCode => {
            if (ctlProc.onReply) {
                const cb = ctlProc.onReply
                ctlProc.onReply = null
                let parsed = null
                try {
                    parsed = JSON.parse(ctlProc.rawOutput.trim())
                } catch (_) {}
                cb(exitCode === 0, parsed)
            }
        }
    }

    function sendCtl(args, callback) {
        ctlProc.rawOutput = ""
        ctlProc.onReply = callback || null
        ctlProc.exec(["python3", "-I", "-B", root.ctlScript].concat(args))
    }

    // Process: Systemctl supervisor
    Process {
        id: systemctlProc
        property var onFinished: null
        onExited: exitCode => {
            if (systemctlProc.onFinished) {
                const cb = systemctlProc.onFinished
                systemctlProc.onFinished = null
                cb(exitCode === 0)
            }
        }
    }

    function runSystemctl(action, callback) {
        systemctlProc.onFinished = callback || null
        systemctlProc.exec(["systemctl", "--user", action, "mizu-l2d-wall.service"])
    }

    // Supervisor logic:
    function setEnabled(enabled) {
        SettingsService.set("wallpaper.live", enabled)
        if (enabled) {
            root.start()
        } else {
            root.stop()
        }
    }

    function toggle() {
        root.setEnabled(!SettingsService.flag("wallpaper.live"))
    }

    function start() {
        if (root.state === "running" || root.state === "starting") return
        root.state = "starting"
        root.statusText = "Preparing Live2D..."

        const model = root.currentModel || "gaoxiong_7"
        if (!root.isDownloaded(model)) {
            root.statusText = "Downloading model " + model + "..."
            root.downloadModel(model, (success, _) => {
                if (success) {
                    root.doStart()
                } else {
                    root.state = "error"
                    root.statusText = "Failed to download model " + model
                }
            })
        } else {
            root.doStart()
        }
    }

    function doStart() {
        root.statusText = "Starting Live2D wallpaper..."
        configSaver.writeConfig(root.currentModel, root.currentOutputs, () => {
            runSystemctl("start", success => {
                if (success) {
                    pollTimer.startPollCount = 0
                    pollTimer.restart()
                } else {
                    root.state = "error"
                    root.statusText = "Failed to start mizu-l2d-wall service"
                }
            })
        })
    }

    function stop() {
        if (root.state === "off" || root.state === "stopping") return
        root.state = "stopping"
        root.statusText = "Stopping Live2D wallpaper..."
        runSystemctl("stop", _success => {
            root.state = "off"
            root.statusText = "Stopped"
            root.consecutiveFailures = 0
        })
    }

    function setModel(prefab) {
        if (!prefab) return
        if (root.state === "running") {
            if (!root.isDownloaded(prefab)) {
                root.statusText = "Downloading model " + prefab + "..."
                root.downloadModel(prefab, (success, _) => {
                    if (success) {
                        root.applyModel(prefab)
                    } else {
                        root.statusText = "Failed to download " + prefab
                    }
                })
            } else {
                root.applyModel(prefab)
            }
        } else {
            root.currentModel = prefab
            SettingsService.set("wallpaper.liveModel", prefab)
            configSaver.writeConfig(root.currentModel, root.currentOutputs, null)
            root.statusText = "Ready (" + prefab + ")"
        }
    }

    function applyModel(prefab) {
        root.statusText = "Switching to " + prefab + "..."
        sendCtl(["model", prefab], (ok, reply) => {
            if (ok && reply && reply.ok) {
                root.currentModel = prefab
                SettingsService.set("wallpaper.liveModel", prefab)
                configSaver.writeConfig(root.currentModel, root.currentOutputs, null)
                root.statusText = "Running (" + prefab + ")"
                if (root.tips) {
                    sendCtl(["tips", "true"], null)
                }
            } else {
                root.statusText = "Model switch failed"
            }
        })
    }

    function setOutputs(outputs) {
        root.currentOutputs = outputs
        SettingsService.set("wallpaper.liveOutputs", outputs)
        configSaver.writeConfig(root.currentModel, root.currentOutputs, () => {
            if (root.state === "running") {
                runSystemctl("restart", null)
            }
        })
    }

    function setTips(enabled) {
        root.tips = enabled
        SettingsService.set("wallpaper.liveTips", enabled)
        if (root.state === "running") {
            sendCtl(["tips", enabled ? "true" : "false"], null)
        }
    }

    function toggleTips() {
        root.setTips(!root.tips)
    }

    function setPlacementLocked(locked) {
        root.placementLocked = locked
        SettingsService.set("wallpaper.placementLocked", locked)
        if (root.state === "running") {
            sendCtl(["lock", locked ? "on" : "off"], null)
        }
    }

    function togglePlacementLocked() {
        root.setPlacementLocked(!root.placementLocked)
    }

    function setGaze(enabled) {
        root.gaze = enabled
        SettingsService.set("wallpaper.gazeFollow", enabled)
        if (root.state === "running") {
            sendCtl(["gaze", enabled ? "on" : "off"], null)
        }
    }

    function toggleGaze() {
        root.setGaze(!root.gaze)
    }

    function setLanguage(lang) {
        if (root.state === "running") {
            sendCtl(["lang", lang], null)
        }
    }

    function resetCamera() {
        if (root.state === "running") {
            sendCtl(["camera", "reset"], null)
        }
    }

    function zoomCamera(factor) {
        if (root.state === "running") {
            sendCtl(["camera", "zoom", String(factor)], null)
        }
    }

    function moveCamera(dx, dy) {
        if (root.state === "running") {
            sendCtl(["camera", "pos", String(dx), String(dy)], null)
        }
    }

    // Startup & Adoption check
    Timer {
        id: initTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            root.refreshDownloaded()
            sendCtl(["status"], (ok, reply) => {
                if (ok && reply && reply.ok) {
                    root.state = "running"
                    root.statusText = "Running (" + root.currentModel + ")"
                    SettingsService.set("wallpaper.live", true)
                } else {
                    if (SettingsService.flag("wallpaper.live")) {
                        root.start()
                    } else {
                        root.state = "off"
                        root.statusText = "Stopped"
                    }
                }
            })
        }
    }

    // Post-start polling to verify host came online
    Timer {
        id: pollTimer
        interval: 300
        repeat: true
        property int startPollCount: 0
        onTriggered: {
            startPollCount++
            sendCtl(["status"], (ok, reply) => {
                if (ok && reply && reply.ok) {
                    pollTimer.stop()
                    root.state = "running"
                    root.statusText = "Running (" + root.currentModel + ")"
                    root.consecutiveFailures = 0
                    if (root.tips) {
                        sendCtl(["tips", "true"], null)
                    }
                } else if (startPollCount >= 15) {
                    pollTimer.stop()
                    root.state = "error"
                    root.statusText = "Timeout waiting for Live2D host"
                }
            })
        }
    }

    // Watchdog timer (every 30 seconds)
    Timer {
        id: watchdogTimer
        interval: 30000
        running: root.state === "running"
        repeat: true
        onTriggered: {
            sendCtl(["ping"], (ok, reply) => {
                if (ok && reply && reply.ok) {
                    root.consecutiveFailures = 0
                } else {
                    root.consecutiveFailures++
                    console.warn("[L2dService] Watchdog ping failed (" + root.consecutiveFailures + "/3)")
                    if (root.consecutiveFailures === 1) {
                        runSystemctl("restart", null)
                    } else if (root.consecutiveFailures >= 3) {
                        root.state = "error"
                        root.statusText = "Error: Live2D host unresponsive"
                    }
                }
            })
        }
    }
}
