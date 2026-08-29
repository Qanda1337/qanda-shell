import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property string state: "idle"
    property int durationMs: 0
    property int remainingMs: 0
    property double endTimestamp: 0
    readonly property bool active: state === "running" || state === "paused"
    readonly property real progress: durationMs > 0 ? Math.max(0, Math.min(1, remainingMs / durationMs)) : 0
    readonly property string displayText: formatTime(remainingMs)

    function formatTime(milliseconds) {
        const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const remainder = seconds % 60;
        if (hours > 0)
            return hours + ":" + String(minutes).padStart(2, "0") + ":" + String(remainder).padStart(2, "0");
        return String(minutes).padStart(2, "0") + ":" + String(remainder).padStart(2, "0");
    }

    function open() { isOpen = true; }
    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    function startMinutes(minutes) {
        const value = Math.floor(Number(minutes));
        if (!isFinite(value) || value < 1 || value > 1440)
            return;
        durationMs = value * 60000;
        remainingMs = durationMs;
        endTimestamp = Date.now() + durationMs;
        state = "running";
        isOpen = true;
    }

    function pause() {
        if (state !== "running")
            return;
        remainingMs = Math.max(0, endTimestamp - Date.now());
        endTimestamp = 0;
        state = "paused";
    }

    function resume() {
        if (state !== "paused")
            return;
        endTimestamp = Date.now() + remainingMs;
        state = "running";
    }

    function togglePause() { state === "running" ? pause() : resume(); }

    function cancel() {
        state = "idle";
        durationMs = 0;
        remainingMs = 0;
        endTimestamp = 0;
    }

    function complete() {
        cancel();
        close();
        Quickshell.execDetached([
            "notify-send", "--app-name=qanda-shell", "--icon=alarm-symbolic",
            "Таймер завершён", "Время вышло"
        ]);
    }

    Timer {
        interval: 250
        running: root.state === "running"
        repeat: true
        onTriggered: {
            root.remainingMs = Math.max(0, root.endTimestamp - Date.now());
            if (root.remainingMs <= 0)
                root.complete();
        }
    }

    IpcHandler {
        target: "timer"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function start(minutes: int): void { root.startMinutes(minutes); }
        function pause(): void { root.pause(); }
        function resume(): void { root.resume(); }
        function cancel(): void { root.cancel(); }
        function status(): bool { return root.isOpen; }
    }
}
