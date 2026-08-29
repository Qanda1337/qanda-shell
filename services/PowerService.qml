import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    function open() { isOpen = true; }
    function close() { isOpen = false; }

    function toggle() { isOpen ? close() : open(); }
    function execute(action) {
        close();
        Qt.callLater(() => {
            switch (action) {
            case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); break;
            case "logout": Quickshell.execDetached(["hyprctl", "dispatch", "exit"]); break;
            case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); break;
            case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
            }
        });
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
    }
}
