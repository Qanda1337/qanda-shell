import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property bool loading: false
    property bool removing: false
    property int selectedIndex: 0
    property var containers: []
    property string error: ""
    property string lastRemoved: ""

    function open() {
        isOpen = true;
        selectedIndex = 0;
        refresh();
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    function refresh() {
        if (listProcess.running)
            return;
        loading = true;
        error = "";
        listProcess.running = true;
    }

    function selectNext() {
        if (containers.length > 0)
            selectedIndex = (selectedIndex + 1) % containers.length;
    }

    function selectPrevious() {
        if (containers.length > 0)
            selectedIndex = (selectedIndex - 1 + containers.length) % containers.length;
    }

    function remove(index) {
        const targetIndex = index === undefined ? selectedIndex : index;
        const container = containers[targetIndex];
        if (!container || removing)
            return;

        removing = true;
        error = "";
        lastRemoved = container.Names || container.ID;
        removeProcess.command = ["docker", "rm", "-f", container.ID];
        removeProcess.running = true;
    }

    Process {
        id: listProcess
        command: ["docker", "ps", "--format", "{{json .}}"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.loading = false;
            if (exitCode !== 0) {
                root.error = stderr.text.trim() || "Docker недоступен";
                return;
            }

            try {
                root.containers = stdout.text.split("\n")
                    .filter(line => line.trim() !== "")
                    .map(line => JSON.parse(line));
                root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.containers.length - 1));
            } catch (error) {
                root.error = "Не удалось разобрать список контейнеров";
                console.warn("Docker container list could not be parsed:", error);
            }
        }
    }

    Process {
        id: removeProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.removing = false;
            if (exitCode !== 0) {
                root.error = stderr.text.trim() || "Не удалось удалить контейнер";
                return;
            }
            root.refresh();
        }
    }

    IpcHandler {
        target: "docker"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function refresh(): void { root.refresh(); }
        function status(): bool { return root.isOpen; }
        function count(): int { return root.containers.length; }
    }
}
