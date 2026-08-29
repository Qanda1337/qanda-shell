import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false

    function open() { isOpen = true; }
    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    IpcHandler {
        target: "weather"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
}
