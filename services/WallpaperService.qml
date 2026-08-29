import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property var wallpapers: []
    property int selectedIndex: 0
    property string currentWallpaper: ""
    property bool applying: applyProcess.running

    readonly property string selectedWallpaper: wallpapers[selectedIndex] || ""

    function open() {
        isOpen = true;
        load();
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    function load() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    function move(offset) {
        if (wallpapers.length === 0)
            return;
        selectedIndex = (selectedIndex + offset + wallpapers.length) % wallpapers.length;
    }

    function select(index) {
        if (index >= 0 && index < wallpapers.length)
            selectedIndex = index;
    }

    function applySelected() {
        if (!selectedWallpaper || applyProcess.running)
            return;
        currentWallpaper = selectedWallpaper;
        applyProcess.command = ["waypaper", "--wallpaper", selectedWallpaper];
        close();
        applyProcess.running = true;
    }

    Process {
        id: listProcess
        command: [Quickshell.shellDir + "/scripts/wallpaper-list"]
        stdout: StdioCollector {}

        onExited: {
            try {
                const data = JSON.parse(stdout.text);
                root.wallpapers = data.wallpapers || [];
                root.currentWallpaper = data.current || "";
                const currentIndex = root.wallpapers.indexOf(root.currentWallpaper);
                root.selectedIndex = currentIndex >= 0 ? currentIndex : 0;
            } catch (error) {
                console.warn("Wallpaper list could not be parsed:", error);
                root.wallpapers = [];
                root.selectedIndex = 0;
            }
        }
    }

    Process {
        id: applyProcess
        command: []
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function next(): void { root.move(1); }
        function previous(): void { root.move(-1); }
        function apply(): void { root.applySelected(); }
    }
}
