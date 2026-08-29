import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    required property var immersiveService

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: immersiveService.enabled
        ? 0
        : Config.Theme.barHeight
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "qanda-shell-exclusion"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: immersiveService.enabled
        ? ExclusionMode.Ignore
        : ExclusionMode.Auto
}
