import QtQuick
import QtQuick.Shapes
import "../config" as Config

Item {
    id: root

    required property var quickSettingsService
    required property var settingsService
    required property var systemService
    required property var audioService
    property real compactContentWidth: 160
    property bool hoverAllowed: true
    readonly property bool hovered: panelHover.hovered

    readonly property bool expanded: quickSettingsService.isOpen
    readonly property int barHeight: Config.Theme.barHeight
    readonly property real outerEar: 16
    readonly property real preferredRightMargin: 0
    readonly property real preferredTopMargin: 0
    readonly property real compactWidth: compactContentWidth
    readonly property real compactHeight: barHeight
    readonly property real expandedWidth: 470
    readonly property real expandedHeight: barHeight + 218
    readonly property real visualOverflowLeft: outerEar * transitionProgress
    readonly property real visualOverflowBottom: outerEar * transitionProgress
    readonly property real surfaceOpacity: smoothstep(0, 0.12, transitionProgress)
    readonly property real contentOpacity: smoothstep(0.14, 0.55, transitionProgress)
    property real transitionProgress: expanded ? 1 : 0

    implicitWidth: compactWidth + (expandedWidth - compactWidth) * transitionProgress
    implicitHeight: compactHeight + (expandedHeight - compactHeight) * transitionProgress
    width: implicitWidth
    height: implicitHeight

    function smoothstep(start, end, value) {
        const t = Math.max(0, Math.min(1, (value - start) / (end - start)));
        return t * t * (3 - 2 * t);
    }

    Behavior on transitionProgress {
        NumberAnimation {
            duration: Config.Theme.motionNormal
            easing.type: Easing.InOutCubic
        }
    }

    Item {
        id: backgroundViewport
        x: -root.visualOverflowLeft
        width: root.width + root.visualOverflowLeft
        height: root.height + root.visualOverflowBottom
        clip: true

        Shape {
            id: attachedBackground
            anchors.right: parent.right
            y: 0
            width: root.expandedWidth + root.outerEar
            height: root.expandedHeight + root.outerEar - y
            opacity: root.surfaceOpacity
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1
                strokeColor: Config.Theme.surfaceEdge
                fillColor: Config.Theme.island
                startX: attachedBackground.width
                startY: attachedBackground.height

                PathCubic {
                    x: attachedBackground.width - root.outerEar
                    y: attachedBackground.height - root.outerEar
                    control1X: attachedBackground.width
                    control1Y: attachedBackground.height - root.outerEar * 0.42
                    control2X: attachedBackground.width - root.outerEar * 0.42
                    control2Y: attachedBackground.height - root.outerEar
                }
                PathLine {
                    x: root.outerEar + 25
                    y: attachedBackground.height - root.outerEar
                }
                PathQuad {
                    x: root.outerEar
                    y: attachedBackground.height - root.outerEar - 25
                    controlX: root.outerEar
                    controlY: attachedBackground.height - root.outerEar
                }
                PathLine { x: root.outerEar; y: root.outerEar }
                PathCubic {
                    x: 0
                    y: 0
                    control1X: root.outerEar
                    control1Y: root.outerEar * 0.45
                    control2X: root.outerEar * 0.58
                    control2Y: 0
                }
                PathLine { x: attachedBackground.width; y: 0 }
                PathLine { x: attachedBackground.width; y: attachedBackground.height }
            }
        }

    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: root.barHeight + 10
        anchors.bottomMargin: 12
        clip: true
        enabled: root.transitionProgress > 0
        opacity: root.contentOpacity

        RightQuickSettingsPanel {
            width: root.expandedWidth - 28
            height: 196
            enabled: root.transitionProgress > 0
            quickSettingsService: root.quickSettingsService
            settingsService: root.settingsService
            systemService: root.systemService
            audioService: root.audioService
        }
    }

    HoverHandler {
        id: panelHover
        enabled: root.hoverAllowed
        onHoveredChanged: root.quickSettingsService.setPanelHovered(hovered)
    }

    onHoverAllowedChanged: if (!hoverAllowed) root.quickSettingsService.setPanelHovered(false)
}
