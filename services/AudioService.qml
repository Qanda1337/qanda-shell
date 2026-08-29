import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    property bool isOpen: false
    readonly property bool ready: Pipewire.ready
    readonly property var outputDevices: ready ? (Pipewire.nodes?.values ?? []).filter(node =>
        node && node.audio && node.isSink && !node.isStream
    ) : []
    readonly property var inputDevices: ready ? (Pipewire.nodes?.values ?? []).filter(node =>
        node && node.audio && !node.isSink && !node.isStream
            && String(node.properties?.["media.class"] || "") === "Audio/Source"
    ) : []
    readonly property var yandexPlaybackStream: {
        if (!ready)
            return null;
        const nodes = Pipewire.nodes?.values ?? [];
        for (let i = 0; i < nodes.length; ++i) {
            const node = nodes[i];
            if (node && node.audio && node.isSink && node.isStream && node.name === "mpv")
                return node;
        }
        return null;
    }
    readonly property var defaultSink: ready ? Pipewire.defaultAudioSink : null
    readonly property var defaultSource: ready ? Pipewire.defaultAudioSource : null
    readonly property real outputVolume: defaultSink?.audio?.volume ?? 0
    readonly property real inputVolume: defaultSource?.audio?.volume ?? 0
    readonly property bool outputMuted: defaultSink?.audio?.muted ?? true
    readonly property bool inputMuted: defaultSource?.audio?.muted ?? true
    readonly property bool outputIsHeadphones: isHeadphoneDevice(defaultSink)
    readonly property real yandexPlaybackVolume: yandexPlaybackStream?.audio?.volume ?? 1
    function isHeadphoneDevice(node) {
        if (!node)
            return false;
        const properties = node.properties || {};
        const description = [
            node.name, node.nickname, node.description,
            properties["device.form-factor"], properties["media.icon-name"],
            properties["node.nick"], properties["device.description"]
        ].join(" ").toLowerCase();
        return description.includes("headphone") || description.includes("headset")
            || description.includes("bluez");
    }

    function open() { isOpen = true; }
    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    function setDefaultOutput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function setOutputVolume(value) {
        if (defaultSink?.audio)
            defaultSink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setInputVolume(value) {
        if (defaultSource?.audio)
            defaultSource.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setYandexPlaybackVolume(value) {
        if (yandexPlaybackStream?.audio)
            yandexPlaybackStream.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleOutputMute() {
        if (defaultSink?.audio)
            defaultSink.audio.muted = !defaultSink.audio.muted;
    }

    function toggleInputMute() {
        if (defaultSource?.audio)
            defaultSource.audio.muted = !defaultSource.audio.muted;
    }

    function deviceName(node) {
        return node?.description || node?.nickname || node?.name || "Аудиоустройство";
    }

    PwObjectTracker {
        objects: root.outputDevices.concat(root.inputDevices).concat([root.yandexPlaybackStream])
    }

    IpcHandler {
        target: "audio"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
}
