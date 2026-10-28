pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// ===== volume / mic =====
// ===== brightness =====
// ===== showing it =====
Singleton {
    id: root

    // ===== what's showing =====
    property bool open: false
    property string kind: "volume"   // "volume" | "mic" | "brightness"
    property int hideDelay: 1600

    // Which monitor OSDPopup.qml should show on — decided fresh every
    // time show() is called (not continuously tracked), the same "decide
    // once per prompt" rule PolkitPrompt.qml uses, just stored here
    // instead of latched locally in each window, so the popup can stay
    // one persistent window per screen (see OSDPopup.qml) rather than
    // being torn down and recreated on every open/close.
    property string targetMonitorName: ""

    function show(newKind) {
        kind = newKind
        targetMonitorName = root.focusedMonitorName()
        open = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        open = false
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.open = false
    }

    // ===== volume / mic =====
    readonly property real volumeStep: 0.05   // 5%, matches the usual key step

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(n => n)
    }

    readonly property var sinkAudio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var sourceAudio: Pipewire.defaultAudioSource?.audio ?? null

    readonly property real speakerVolume: sinkAudio ? sinkAudio.volume * 100 : 0
    readonly property bool speakerMuted: sinkAudio ? sinkAudio.muted : true
    readonly property real micVolume: sourceAudio ? sourceAudio.volume * 100 : 0
    readonly property bool micMuted: sourceAudio ? sourceAudio.muted : true

    // Guards against showing the OSD once for the initial binding as
    // PipeWire connects (both onVolumeChanged/onMutedChanged can fire
    // once during startup as sinkAudio first resolves).
    property bool settledOnce: false
    Timer {
        interval: 400
        running: true
        onTriggered: root.settledOnce = true
    }

    Connections {
        target: root.sinkAudio
        function onVolumeChanged() {
            if (root.settledOnce)
                root.show("volume")
        }
        function onMutedChanged() {
            if (root.settledOnce)
                root.show("volume")
        }
    }

    Connections {
        target: root.sourceAudio
        function onMutedChanged() {
            if (root.settledOnce)
                root.show("mic")
        }
    }

    function volumeUp() {
        if (!root.sinkAudio)
            return
        root.sinkAudio.muted = false
        root.sinkAudio.volume = Math.min(1.0, root.sinkAudio.volume + root.volumeStep)
    }

    function volumeDown() {
        if (!root.sinkAudio)
            return
        root.sinkAudio.volume = Math.max(0.0, root.sinkAudio.volume - root.volumeStep)
    }

    function toggleMute() {
        if (root.sinkAudio)
            root.sinkAudio.muted = !root.sinkAudio.muted
    }

    function toggleMicMute() {
        if (root.sourceAudio)
            root.sourceAudio.muted = !root.sourceAudio.muted
    }

    function focusedMonitorName() {
        return Compositor.focusedOutput
    }

    // ===== brightness =====
    // The monitors themselves live in BrightnessService now — one entry
    // per controllable monitor, and the keyboard step scales every one
    // of them by the same factor so their relative ratios hold (KDE
    // style). This side only shows the OSD, which displays the global
    // value: the brightest monitor's percent.
    readonly property real brightness: BrightnessService.brightness

    function brightnessUp() {
        BrightnessService.brightnessUp()
        root.show("brightness")
    }

    function brightnessDown() {
        BrightnessService.brightnessDown()
        root.show("brightness")
    }

    IpcHandler {
        target: "osd"

        function volumeUp(): void { root.volumeUp() }
        function volumeDown(): void { root.volumeDown() }
        function toggleMute(): void { root.toggleMute() }
        function toggleMicMute(): void { root.toggleMicMute() }
        function brightnessUp(): void { root.brightnessUp() }
        function brightnessDown(): void { root.brightnessDown() }
        function hide(): void { root.hide() }
    }
}
