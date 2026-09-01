import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var systemService
    property bool isOpen: false
    property int cpuUsage: 0
    property int gpuUsage: 0
    property int memoryUsage: 0
    property int swapUsage: 0
    property int cpuTemperature: 0
    property int gpuTemperature: 0
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int gpuMemoryUsed: 0
    property int gpuMemoryTotal: 0
    property var disk: ({})
    property var network: ({})
    property var processes: []

    function applyMetrics(data) {
        const metrics = data || {};
        cpuUsage = Number(metrics.cpu || 0);
        gpuUsage = Number(metrics.gpu || 0);
        memoryUsage = Number(metrics.memory || 0);
        swapUsage = Number(metrics.swap || 0);
        cpuTemperature = Number(metrics.cpuTemp || 0);
        gpuTemperature = Number(metrics.gpuTemp || 0);
        memoryUsed = Number(metrics.memoryUsed || 0);
        memoryTotal = Number(metrics.memoryTotal || 0);
        swapUsed = Number(metrics.swapUsed || 0);
        swapTotal = Number(metrics.swapTotal || 0);
        gpuMemoryUsed = Number(metrics.gpuMemoryUsed || 0);
        gpuMemoryTotal = Number(metrics.gpuMemoryTotal || 0);
        disk = metrics.disk || {};
        network = metrics.network || {};
        processes = Array.isArray(metrics.processes) ? metrics.processes : [];
    }

    function refresh() {
        if (systemService.backendConnected)
            systemService.requestBackendRefresh();
        else if (!statsProcess.running)
            statsProcess.running = true;
    }

    function open() {
        isOpen = true;
        refresh();
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    Process {
        id: statsProcess
        command: [Quickshell.shellDir + "/scripts/performance-stats"]
        stdout: StdioCollector {}

        onExited: {
            try {
                root.applyMetrics(JSON.parse(stdout.text));
            } catch (error) {
                console.warn("Performance metrics could not be parsed:", error);
            }
        }
    }

    Connections {
        target: root.systemService
        function onPerformanceDataChanged() {
            root.applyMetrics(root.systemService.performanceData);
        }
        function onBackendConnectedChanged() {
            if (root.systemService.backendConnected)
                root.applyMetrics(root.systemService.performanceData);
        }
    }

    Timer {
        interval: 1500
        running: !root.systemService.backendConnected
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "performance"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
    }
}
