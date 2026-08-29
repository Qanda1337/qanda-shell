import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property bool loading: false
    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property string error: ""

    readonly property var results: {
        const needle = query.trim().toLowerCase();
        if (needle === "")
            return entries.slice(0, 12);
        return entries.filter(entry => String(entry.preview || "").toLowerCase().includes(needle)).slice(0, 12);
    }

    function open() {
        query = "";
        selectedIndex = 0;
        isOpen = true;
        refresh();
    }

    function close() {
        isOpen = false;
        query = "";
        selectedIndex = 0;
    }

    function toggle() { isOpen ? close() : open(); }

    function refresh() {
        if (!listProcess.running) {
            loading = true;
            error = "";
            listProcess.running = true;
        }
    }

    function setQuery(value) {
        query = value;
        selectedIndex = 0;
    }

    function selectNext() {
        if (results.length > 0)
            selectedIndex = (selectedIndex + 1) % results.length;
    }

    function selectPrevious() {
        if (results.length > 0)
            selectedIndex = (selectedIndex - 1 + results.length) % results.length;
    }

    function activate(index) {
        const target = results[index === undefined ? selectedIndex : index];
        if (!target || copyProcess.running)
            return;
        copyProcess.command = [Quickshell.shellDir + "/scripts/clipboard-copy", target.id];
        copyProcess.running = true;
    }

    Process {
        id: listProcess
        command: [Quickshell.shellDir + "/scripts/clipboard-list"]
        stdout: StdioCollector {}

        onExited: exitCode => {
            root.loading = false;
            if (exitCode !== 0) {
                root.error = "Не удалось прочитать историю";
                return;
            }
            try {
                root.entries = JSON.parse(stdout.text);
                if (root.selectedIndex >= root.results.length)
                    root.selectedIndex = Math.max(0, root.results.length - 1);
            } catch (error) {
                root.error = "Не удалось разобрать историю";
                console.warn("Clipboard history could not be parsed:", error);
            }
        }
    }

    Process {
        id: copyProcess
        onExited: exitCode => {
            if (exitCode === 0)
                root.close();
            else
                root.error = "Не удалось скопировать запись";
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function refresh(): void { root.refresh(); }
        function status(): bool { return root.isOpen; }
    }
}
