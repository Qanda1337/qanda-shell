import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    required property var settingsService

    property bool isOpen: false
    property bool clusterHovered: false
    property bool panelHovered: false

    function open() {
        closeTimer.stop();
        isOpen = true;
        refreshTimer.restart();
    }

    function close() {
        closeTimer.stop();
        isOpen = false;
        refreshTimer.stop();
    }

    function toggle() { isOpen ? close() : open(); }

    function updateHover() {
        if (clusterHovered || panelHovered)
            open();
        else
            closeTimer.restart();
    }

    function setClusterHovered(value) {
        clusterHovered = value;
        updateHover();
    }

    function setPanelHovered(value) {
        panelHovered = value;
        updateHover();
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: if (!root.clusterHovered && !root.panelHovered) root.close()
    }

    Timer {
        id: refreshTimer
        interval: Math.max(1, Config.Theme.motionNormal)
        onTriggered: root.settingsService.refresh()
    }

    Timer {
        interval: 5000
        running: root.isOpen
        repeat: true
        onTriggered: root.settingsService.refresh()
    }

    IpcHandler {
        target: "quickSettings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
    }
}
