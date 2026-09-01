import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id: root

    required property var systemService
    required property var notificationService
    required property var launcherService
    required property var clipboardService
    required property var bindingsService
    required property var dockerService
    required property var timerService
    required property var calendarService
    required property var mediaService
    required property var weatherService
    required property var audioService
    required property var powerService
    required property var performanceService
    required property var walletService
    required property var wallpaperService
    required property var settingsService
    required property var quickSettingsService
    required property var immersiveService
    property bool immersivePresentation: false

    readonly property int effectiveBarHeight: Config.Theme.barHeight
    readonly property bool presentationActive: immersivePresentation
        ? immersiveService.enabled
        : !immersiveService.enabled
    readonly property bool immersiveActive: presentationActive && immersivePresentation
    readonly property bool centerShown: presentationActive
    readonly property bool settingsShown: presentationActive
        && (!immersiveActive || settingsService.isOpen
            || leftSettingsIsland.expansionProgress > 0)
    readonly property bool quickSettingsShown: presentationActive
        && (quickSettingsService.isOpen || rightSettingsIsland.transitionProgress > 0
            || (Config.Preferences.showRightCluster
                && !immersiveActive))

    readonly property bool anyOtherWidgetOpen: launcherService.isOpen
        || clipboardService.isOpen
        || bindingsService.isOpen
        || dockerService.isOpen
        || timerService.isOpen
        || notificationService.isOpen
        || calendarService.isOpen
        || mediaService.isOpen
        || weatherService.isOpen
        || audioService.isOpen
        || powerService.isOpen
        || performanceService.isOpen
        || walletService.isOpen
        || wallpaperService.isOpen
        || settingsService.isOpen
    readonly property bool anyWidgetOpen: anyOtherWidgetOpen || quickSettingsService.isOpen

    function closeAllWidgets() {
        launcherService.close();
        clipboardService.close();
        bindingsService.close();
        dockerService.close();
        timerService.close();
        notificationService.close();
        calendarService.close();
        mediaService.close();
        weatherService.close();
        audioService.close();
        powerService.close();
        performanceService.close();
        walletService.close();
        wallpaperService.close();
        settingsService.close();
        quickSettingsService.close();
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 560
    color: "transparent"

    WlrLayershell.namespace: root.immersivePresentation
        ? "qanda-shell-immersive"
        : "qanda-shell-bar"
    WlrLayershell.layer: root.immersivePresentation ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: root.presentationActive && root.anyWidgetOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    mask: Region {
        regions: [topRegion, centerRegion, settingsRegion, quickSettingsRegion]

        Region {
            id: topRegion
            x: 0
            y: 0
            width: root.width
            height: root.presentationActive && !root.immersiveActive
                ? root.effectiveBarHeight
                : 0
        }

        Region {
            id: centerRegion
            x: centerIsland.x - centerIsland.outerEar
            y: centerIsland.y
            width: root.centerShown ? centerIsland.width + centerIsland.outerEar * 2 : 0
            height: root.centerShown ? centerIsland.height : 0
        }

        Region {
            id: settingsRegion
            x: leftSettingsIsland.x
            y: leftSettingsIsland.y
            width: root.settingsShown
                ? leftSettingsIsland.width + leftSettingsIsland.visualOverflowRight
                : 0
            height: root.settingsShown
                ? leftSettingsIsland.height + leftSettingsIsland.visualOverflowBottom
                : 0
        }

        Region {
            id: quickSettingsRegion
            x: rightSettingsIsland.x - rightSettingsIsland.visualOverflowLeft
            y: rightSettingsIsland.y
            width: root.quickSettingsShown
                ? rightSettingsIsland.width + rightSettingsIsland.visualOverflowLeft
                : 0
            height: root.quickSettingsShown
                ? rightSettingsIsland.height + rightSettingsIsland.visualOverflowBottom
                : 0
        }

    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Config.Theme.barHeight + 22
        visible: root.presentationActive && !root.immersiveActive

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Config.Theme.barMaterial }
            GradientStop { position: 0.4; color: Config.Theme.barMaterial }
            GradientStop { position: 0.72; color: Config.Theme.barMaterialSoft }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.max(0, centerIsland.x - centerIsland.outerEar)
        height: 1
        color: Config.Theme.surfaceEdge
        visible: root.presentationActive && !root.immersiveActive
            && !centerIsland.floatingMode
        opacity: 1
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(0, root.width - centerIsland.x - centerIsland.width - centerIsland.outerEar)
        height: 1
        color: Config.Theme.surfaceEdge
        visible: root.presentationActive && !root.immersiveActive
            && !centerIsland.floatingMode
        opacity: 1
    }

    LeftSettingsIsland {
        id: leftSettingsIsland
        anchors.left: parent.left
        anchors.leftMargin: preferredLeftMargin
        anchors.top: parent.top
        anchors.topMargin: preferredTopMargin
        visible: root.settingsShown
        z: 20
        settingsService: root.settingsService
        systemService: root.systemService
        wallpaperService: root.wallpaperService
        immersiveService: root.immersiveService
        workspaceContentWidth: root.immersiveActive || !Config.Preferences.showLeftCluster
            ? 0 : leftCluster.workspaceContentWidth
    }

    LeftCluster {
        id: leftCluster
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 0
        height: root.effectiveBarHeight
        contentLeftMargin: leftSettingsIsland.preferredLeftMargin + 52
        concealed: root.immersiveActive || root.settingsService.isOpen
        visible: root.presentationActive && Config.Preferences.showLeftCluster
        z: 21

    }

    CenterIsland {
        id: centerIsland
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 0
        visible: root.presentationActive
        opacity: root.centerShown ? 1 : 0
        enabled: root.centerShown
        immersiveMode: root.immersiveActive
        systemService: root.systemService
        notificationService: root.notificationService
        launcherService: root.launcherService
        clipboardService: root.clipboardService
        bindingsService: root.bindingsService
        dockerService: root.dockerService
        timerService: root.timerService
        calendarService: root.calendarService
        mediaService: root.mediaService
        weatherService: root.weatherService
        audioService: root.audioService
        powerService: root.powerService
        performanceService: root.performanceService
        walletService: root.walletService
        wallpaperService: root.wallpaperService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    RightQuickSettingsIsland {
        id: rightSettingsIsland
        anchors.right: parent.right
        anchors.rightMargin: preferredRightMargin
        anchors.top: parent.top
        anchors.topMargin: preferredTopMargin
        visible: root.quickSettingsShown
        z: 20
        compactContentWidth: rightCluster.contentWidth
        hoverAllowed: !root.anyOtherWidgetOpen
        quickSettingsService: root.quickSettingsService
        settingsService: root.settingsService
        systemService: root.systemService
        audioService: root.audioService

    }

    RightCluster {
        id: rightCluster
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 0
        height: root.effectiveBarHeight
        systemService: root.systemService
        audioService: root.audioService
        powerService: root.powerService
        performanceService: root.performanceService
        quickSettingsService: root.quickSettingsService
        settingsService: root.settingsService
        quickSettingsHoverAllowed: !root.anyOtherWidgetOpen
        concealed: root.immersiveActive
        visible: root.presentationActive && Config.Preferences.showRightCluster
        z: 21

    }
}
