import QtQuick
import QtQuick.Shapes
import "../config" as Config

Item {
    id: root

    required property var settingsService
    required property var systemService
    required property var wallpaperService
    required property var immersiveService
    property real workspaceContentWidth: 0

    readonly property bool expanded: settingsService.isOpen
    readonly property real outerEar: 16
    readonly property real preferredLeftMargin: 0
    readonly property real preferredTopMargin: 0
    readonly property int barHeight: Config.Theme.barHeight
    readonly property real compactWidth: 46
    readonly property real compactHeight: barHeight
    readonly property real expandedWidth: 590
    readonly property real expandedHeight: 500
    readonly property real liquidModuleWidth: 64 + workspaceContentWidth + outerEar
    readonly property real liquidModuleHeight: barHeight + outerEar
    readonly property real moduleVisualWidth: compactWidth
        + (liquidModuleWidth - compactWidth) * moduleReveal
    readonly property real moduleVisualHeight: compactHeight
        + (liquidModuleHeight - compactHeight) * moduleReveal
    readonly property real expansionProgress: smoothstep(0.08, 1, transitionProgress)
    readonly property real moduleReveal: smoothstep(0, 0.22, transitionProgress)
    readonly property real moduleBlend: moduleReveal
        * (1 - smoothstep(0.18, 0.5, transitionProgress))
    readonly property real headerContentStart: liquidModuleWidth - outerEar + 8
    readonly property real surfaceOpacity: smoothstep(0, 0.08, transitionProgress)
    readonly property real visualWidth: (width + outerEar * expansionProgress)
        * (1 - moduleBlend) + moduleVisualWidth * moduleBlend
    readonly property real visualHeight: (height + outerEar * expansionProgress)
        * (1 - moduleBlend) + moduleVisualHeight * moduleBlend
    readonly property real visualOverflowRight: Math.max(0, visualWidth - width)
    readonly property real visualOverflowBottom: Math.max(0, visualHeight - height)
    readonly property int moduleMotionDuration: Math.round(Config.Theme.motionFast * 0.55)
    readonly property int panelMotionDuration: Config.Theme.motionNormal
    readonly property int transitionDuration: panelMotionDuration + moduleMotionDuration
    property real transitionProgress: expanded ? 1 : 0

    implicitWidth: compactWidth + (expandedWidth - compactWidth) * expansionProgress
    implicitHeight: compactHeight + (expandedHeight - compactHeight) * expansionProgress
    width: implicitWidth
    height: implicitHeight

    function smoothstep(start, end, value) {
        const t = Math.max(0, Math.min(1, (value - start) / (end - start)));
        return t * t * (3 - 2 * t);
    }

    Behavior on transitionProgress {
        NumberAnimation {
            duration: root.transitionDuration
            easing.type: Easing.InOutCubic
        }
    }

    Item {
        id: backgroundLayer
        x: 0
        y: 0
        width: root.width + root.visualOverflowRight
        height: root.height + root.visualOverflowBottom
        clip: true

        Shape {
            id: liquidBackground
            x: 0
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
                startX: 0
                startY: liquidBackground.height

                PathCubic {
                    x: root.outerEar
                    y: liquidBackground.height - root.outerEar
                    control1X: 0
                    control1Y: liquidBackground.height - root.outerEar * 0.42
                    control2X: root.outerEar * 0.42
                    control2Y: liquidBackground.height - root.outerEar
                }
                PathLine { x: liquidBackground.width - root.outerEar - 25; y: liquidBackground.height - root.outerEar }
                PathQuad {
                    x: liquidBackground.width - root.outerEar
                    y: liquidBackground.height - root.outerEar - 25
                    controlX: liquidBackground.width - root.outerEar
                    controlY: liquidBackground.height - root.outerEar
                }
                PathLine { x: liquidBackground.width - root.outerEar; y: root.outerEar }
                PathCubic {
                    x: liquidBackground.width
                    y: 0
                    control1X: liquidBackground.width - root.outerEar
                    control1Y: root.outerEar * 0.45
                    control2X: liquidBackground.width - root.outerEar * 0.58
                    control2Y: 0
                }
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: liquidBackground.height }
            }
        }

        Shape {
            id: liquidModuleBackground
            width: root.liquidModuleWidth
            height: root.liquidModuleHeight
            opacity: root.moduleBlend
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1
                strokeColor: Config.Theme.surfaceEdge
                fillColor: Config.Theme.island
                startX: 0
                startY: liquidModuleBackground.height

                PathQuad {
                    x: root.outerEar
                    y: liquidModuleBackground.height - root.outerEar
                    controlX: 0
                    controlY: liquidModuleBackground.height - root.outerEar
                }
                PathLine {
                    x: liquidModuleBackground.width - root.outerEar - 14
                    y: liquidModuleBackground.height - root.outerEar
                }
                PathQuad {
                    x: liquidModuleBackground.width - root.outerEar
                    y: liquidModuleBackground.height - root.outerEar - 14
                    controlX: liquidModuleBackground.width - root.outerEar
                    controlY: liquidModuleBackground.height - root.outerEar
                }
                PathLine {
                    x: liquidModuleBackground.width - root.outerEar
                    y: root.outerEar
                }
                PathQuad {
                    x: liquidModuleBackground.width
                    y: 0
                    controlX: liquidModuleBackground.width - root.outerEar
                    controlY: 0
                }
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: liquidModuleBackground.height }
            }
        }

    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.barHeight

        Rectangle {
            id: qButton
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 4
            width: 38
            height: 34
            radius: 12
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "Q"
                color: Config.Theme.accent
                font.family: Config.Theme.uiFont
                font.pixelSize: 17
                font.weight: Font.Bold
            }

            MouseArea {
                id: qMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsService.toggle()
            }
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.headerContentStart
            anchors.right: closeButton.left
            y: 0
            height: header.height
            opacity: root.expansionProgress

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Control Center"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

        }

        Text {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 9
            y: (header.height - height) / 2
            width: 28
            height: 28
            opacity: root.expansionProgress
            text: "×"
            color: closeMouse.containsMouse ? Config.Theme.text : Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                enabled: root.expanded
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsService.close()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.barHeight - 1
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        opacity: root.expansionProgress
        color: Config.Theme.surfaceEdge
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Config.Theme.barHeight
        clip: true
        enabled: root.expansionProgress > 0
        opacity: root.expansionProgress

        ControlCenterPanel {
            width: 590
            height: 458
            enabled: root.expansionProgress > 0
            settingsService: root.settingsService
            systemService: root.systemService
            wallpaperService: root.wallpaperService
            immersiveService: root.immersiveService
        }
    }
}
