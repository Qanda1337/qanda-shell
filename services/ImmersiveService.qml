import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool enabled: false

    function enable() { enabled = true; }
    function disable() { enabled = false; }
    function toggle() { enabled = !enabled; }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.toggle(); }
        function enable(): void { root.enable(); }
        function disable(): void { root.disable(); }
        function status(): bool { return root.enabled; }
    }
}
