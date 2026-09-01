import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../config" as Config

Item {
    id: root

    required property var systemService
    required property var audioService
    required property var powerService
    required property var performanceService
    required property var quickSettingsService
    required property var settingsService
    property bool concealed: false
    property bool quickSettingsHoverAllowed: true
    readonly property bool quickSettingsHovered: quickSettingsHover.hovered

    width: contentWidth
    opacity: concealed ? 0 : 1
    enabled: !concealed

    Behavior on opacity {
        NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
    }

    readonly property real volume: audioService.outputVolume
    readonly property bool muted: audioService.outputMuted
    readonly property real contentWidth: controlRow.implicitWidth + 24
    readonly property string speakerPath: "M7 1.007812c-.296875-.003906-.578125.125-.769531.351563L3 5H2C.90625 5 0 5.84375 0 7v2c0 1.089844.910156 2 2 2h1l3.230469 3.640625c.210937.253906.492187.363281.769531.359375z"
    readonly property string volumeLowPath: speakerPath + " M9.957031 3.988281c-.199219.011719-.394531.074219-.5625.203125-.441406.332032-.53125.960938-.195312 1.402344 1.074219 1.425781 1.074219 3.386719 0 4.8125-.335938.441406-.246094 1.070312.195312 1.402344.441407.332031 1.066407.242187 1.398438-.195313C11.597656 10.542969 12 9.273437 12 8s-.402344-2.542969-1.207031-3.613281c-.183594-.246094-.464844-.382813-.753907-.398438z"
    readonly property string volumeMediumPath: volumeLowPath + " M13.460938 1.96875c-.191407-.003906-.386719.054688-.558594.167969-.457032.3125-.578125.933593-.269532 1.390625 1.824219 2.707031 1.824219 6.238281 0 8.945312-.308593.457032-.1875 1.078125.269532 1.390625.457031.308594 1.078125.1875 1.390625-.269531C15.429688 11.902344 16 9.953125 16 8s-.570312-3.902344-1.707031-5.59375c-.195313-.285156-.511719-.4375-.832031-.4375z"
    readonly property string volumeMutedPath: speakerPath + " M10 5c-.265625 0-.519531.105469-.707031.292969-.390625.390625-.390625 1.023437 0 1.414062L10.585938 8l-1.292969 1.292969c-.390625.390625-.390625 1.023437 0 1.414062s1.023437.390625 1.414062 0L12 9.414062l1.292969 1.292969c.390625.390625 1.023437.390625 1.414062 0s.390625-1.023437 0-1.414062L13.414062 8l1.292969-1.292969c.390625-.390625.390625-1.023437 0-1.414062-.1875-.1875-.441406-.292969-.707031-.292969s-.519531.105469-.707031.292969L12 6.585938l-1.292969-1.292969C10.519531 5.105469 10.265625 5 10 5z"
    readonly property string volumePath: muted ? volumeMutedPath
        : (volume < 0.05 ? speakerPath
        : (volume <= 0.35 ? volumeLowPath
        : (volume <= 0.50 ? volumeMediumPath : volumeMediumPath)))
    readonly property string vpnPath: "M1.996094 1.140625v4.484375c0 2.214844 1.199218 4.253906 3.132812 5.335938l2.867188 1.605468 2.871094-1.605468c1.933593-1.082032 3.128906-3.121094 3.128906-5.335938V1.140625l-6-1.1992188z M6.996094 12.257812c-.292969.171876-.535156.414063-.710938.703126H3c-.550781 0-1 .449218-1 1s.449219 1 1 1h3.25C6.601562 15.601562 7.269531 15.996094 8 16c.730469-.003906 1.402344-.398438 1.75-1.039062h3.261719c.550781 0 1-.449219 1-1s-.449219-1-1-1H9.71875c-.175781-.289063-.417969-.53125-.710938-.703126-.675781-.398437-1.347656-.398437-2.011718 0z"
    readonly property string wifiPath: "M8 1.992188c-2.617188 0-5.238281.933593-7.195312 2.808593l-.496094.480469c-.3984378.378906-.410156 1.011719-.03125 1.410156.382812.398438 1.015625.410156 1.414062.03125l.5-.476562c3.085938-2.957032 8.53125-2.957032 11.617188 0l.5.476562c.398437.378906 1.03125.367188 1.414062-.03125.378906-.398437.367188-1.03125-.03125-1.410156l-.496094-.484375C13.238281 2.925781 10.617188 1.992188 8 1.992188z M7.96875 6c-1.570312.011719-3.128906.628906-4.207031 1.8125l-.5.550781c-.179688.195313-.277344.453125-.261719.71875.011719.265625.128906.515625.328125.695313.195313.179687.453125.273437.71875.257812.265625-.011718.515625-.128906.695313-.328125l.496093-.546875c1.277344-1.402344 4.160157-1.496094 5.523438.003906l.5.542969c.175781.199219.425781.316407.691406.328125.265625.015625.523437-.078125.722656-.257812.195313-.179688.3125-.429688.324219-.695313.011719-.261719-.082031-.523437-.261719-.71875l-.5-.546875C11.105469 6.582031 9.523438 5.988281 7.96875 6z M8 10c-.511719 0-1.023438.195312-1.414062.585938-.78125.78125-.78125 2.046874 0 2.828124s2.046874.78125 2.828124 0 .78125-2.046874 0-2.828124C9.023438 10.195312 8.511719 10 8 10z"
    readonly property string wiredPath: "M6 .015625c-.554688 0-1 .445313-1 1v3c0 .554687.445312 1 1 1h1v2H0v2h2v2H1c-.554688 0-1 .445313-1 1v3c0 .554687.445312 1 1 1h4c.554688 0 1-.445313 1-1v-3c0-.554687-.445312-1-1-1H4v-2h8v2h-1c-.554688 0-1 .445313-1 1v3c0 .554687.445312 1 1 1h4c.554688 0 1-.445313 1-1v-3c0-.554687-.445312-1-1-1h-1v-2h2v-2H9v-2h1c.554688 0 1-.445313 1-1v-3c0-.554687-.445312-1-1-1z"
    readonly property string networkPath: systemService.vpnConnected ? vpnPath
        : (systemService.networkType === "wifi" ? wifiPath : wiredPath)
    readonly property string powerPath: "M8 0c-.550781 0-1 .449219-1 1v5c0 .550781.449219 1 1 1s1-.449219 1-1V1c0-.550781-.449219-1-1-1z M4.863281 1.816406c-.128906.015625-.253906.058594-.367187.125C1.761719 3.523438.421875 6.757812 1.238281 9.8125 2.058594 12.863281 4.832031 14.996094 7.988281 15c3.160157.003906 5.941407-2.121094 6.765625-5.167969.828125-3.050781-.5-6.289062-3.230468-7.878906-.476563-.28125-1.089844-.121094-1.367188.359375-.132812.226562-.171875.5-.105469.757812.070313.257813.234375.476563.464844.609376 1.957031 1.140624 2.902344 3.441406 2.3125 5.628906-.59375 2.183594-2.570313 3.695312-4.832031 3.691406-2.265625-.003906-4.238282-1.519531-4.824219-3.707031s.363281-4.488281 2.324219-5.621094c.476562-.277344.640625-.886719.363281-1.363281-.132813-.230469-.347656-.398438-.605469-.464844-.125-.035156-.257812-.042969-.390625-.027344z"
    readonly property string memoryPath: "M0 13c0 .554.446 1 1 1h5v-2H0zm0-2h16V8a1 1 0 0 0-2 0v1H2V8a1 1 0 0 0-2 0zm0-5a1 1 0 0 0 2 0V5h2v4h2V5h2v4h2V5h2v4h2V5h2v1a1 1 0 0 0 2 0V4c0-.554-.446-1-1-1H1C.446 3 0 3.446 0 4zm8 8h8v-2H8z"

    function usageColor(value) {
        if (value > 90)
            return Config.Theme.danger;
        if (value > 80)
            return Config.Theme.warning;
        return Config.Theme.text;
    }

    function temperatureColor(value) {
        if (value > 80)
            return Config.Theme.danger;
        if (value > 70)
            return Config.Theme.warning;
        return Config.Theme.text;
    }

    component SystemIcon: Rectangle {
        id: iconButton

        property string glyph: ""
        property string pathData: ""
        property string badge: ""
        property color glyphColor: Config.Theme.text
        property real glyphSize: 15
        property real pathSize: 16
        property bool interactive: true
        property bool shown: true
        property real revealProgress: 0
        signal triggered()

        Layout.preferredWidth: 27 * revealProgress
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        visible: revealProgress > 0
        clip: true
        opacity: revealProgress
        radius: 10
        color: iconMouse.containsMouse && interactive ? Config.Theme.track : "transparent"

        Component.onCompleted: revealProgress = shown ? 1 : 0
        onShownChanged: revealProgress = shown ? 1 : 0

        Behavior on revealProgress {
            NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: Config.Theme.motionFast }
        }

        Text {
            anchors.centerIn: parent
            visible: iconButton.pathData === ""
            text: iconButton.glyph
            color: iconButton.glyphColor
            font.family: Config.Theme.monoFont
            font.pixelSize: iconButton.glyphSize
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            scale: 0.72 + iconButton.revealProgress * 0.28
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            visible: iconButton.badge !== ""
            text: iconButton.badge
            color: iconButton.glyphColor
            font.family: Config.Theme.monoFont
            font.pixelSize: 8
            font.weight: Font.Bold
        }

        Shape {
            anchors.centerIn: parent
            width: iconButton.pathSize
            height: iconButton.pathSize
            visible: iconButton.pathData !== ""
            preferredRendererType: Shape.CurveRenderer
            scale: 0.72 + iconButton.revealProgress * 0.28

            ShapePath {
                strokeWidth: 0
                fillColor: iconButton.glyphColor
                PathSvg { path: iconButton.pathData }
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            enabled: iconButton.interactive && iconButton.shown
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: iconButton.triggered()
        }
    }

    RowLayout {
        id: controlRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 1

        Row {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 3

            Repeater {
                model: SystemTray.items?.values ?? []

                delegate: Item {
                    required property var modelData
                    readonly property bool shown: modelData.status !== SystemTray.Passive
                    property real revealProgress: 0
                    width: 18 * revealProgress
                    height: 24
                    visible: revealProgress > 0
                    clip: true
                    opacity: revealProgress

                    Component.onCompleted: revealProgress = shown ? 1 : 0
                    onShownChanged: revealProgress = shown ? 1 : 0

                    Behavior on revealProgress {
                        NumberAnimation {
                            duration: Config.Theme.motionNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: modelData.icon
                        scale: 0.72 + parent.revealProgress * 0.28
                    }

                    TrayMenuPopup {
                        id: trayMenu
                        anchorItem: trayMouse
                        menu: modelData.menu
                        title: modelData.title || modelData.tooltipTitle || modelData.id
                        icon: modelData.icon
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        enabled: parent.shown
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                        function openMenu() { trayMenu.open(); }

                        hoverEnabled: true
                        onEntered: trayMenu.cancelClose()
                        onExited: trayMenu.scheduleClose()
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton)
                                modelData.secondaryActivate();
                            else if (mouse.button === Qt.RightButton && modelData.hasMenu)
                                openMenu();
                            else if (mouse.button === Qt.LeftButton) {
                                if (modelData.onlyMenu && modelData.hasMenu)
                                    openMenu();
                                else
                                    modelData.activate();
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.preferredWidth: 28
            Layout.fillHeight: true
            text: systemService.keyboardLayout
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        SystemIcon {
            glyph: systemService.themeMode === "light" ? "\uf185" : "\uf186"
            interactive: Config.Preferences.themeSource === "matugen"
            onTriggered: root.settingsService.toggleThemeMode()
        }

        SystemIcon {
            shown: root.performanceService.cpuUsage > 60
            glyph: "\uf2db"
            glyphSize: 17
            glyphColor: root.usageColor(root.performanceService.cpuUsage)
            interactive: false
        }

        SystemIcon {
            shown: root.performanceService.gpuUsage > 60
            glyph: "\uf26c"
            glyphSize: 17
            glyphColor: root.usageColor(root.performanceService.gpuUsage)
            interactive: false
        }

        SystemIcon {
            shown: root.performanceService.memoryUsage > 60
            pathData: root.memoryPath
            pathSize: 17
            glyphColor: root.usageColor(root.performanceService.memoryUsage)
            interactive: false
        }

        SystemIcon {
            shown: root.performanceService.cpuTemperature > 60
            glyph: "\uf2c7"
            glyphSize: 17
            badge: "C"
            glyphColor: root.temperatureColor(root.performanceService.cpuTemperature)
            interactive: false
        }

        SystemIcon {
            shown: root.performanceService.gpuTemperature > 60
            glyph: "\uf2c7"
            glyphSize: 17
            badge: "G"
            glyphColor: root.temperatureColor(root.performanceService.gpuTemperature)
            interactive: false
        }

        SystemIcon {
            shown: root.audioService.defaultSink !== null
            glyph: root.audioService.outputIsHeadphones ? "\uf025" : ""
            pathData: root.audioService.outputIsHeadphones ? "" : root.volumePath
            glyphColor: root.muted ? Config.Theme.textMuted : Config.Theme.text
            onTriggered: root.quickSettingsService.open()
        }

        SystemIcon {
            shown: root.systemService.vpnConnected
                || root.systemService.networkType !== "disconnected"
            pathData: root.networkPath
            glyphColor: systemService.networkType === "disconnected" ? Config.Theme.textMuted : Config.Theme.text
            onTriggered: root.quickSettingsService.open()
        }

        SystemIcon {
            shown: root.systemService.screenRecording
            glyph: "\uf111"
            glyphColor: Config.Theme.danger
            interactive: false
        }

        SystemIcon {
            shown: root.systemService.directCameraInUse
            glyph: "\uf03d"
            glyphColor: Config.Theme.warning
            interactive: false
        }

        SystemIcon {
            shown: root.systemService.powerProfile !== "balanced"
            glyph: root.systemService.powerProfile === "performance" ? "\uf0e7" : "\uf06c"
            glyphColor: root.systemService.powerProfile === "performance"
                ? Config.Theme.warning : Config.Theme.success
            onTriggered: root.quickSettingsService.open()
        }

        SystemIcon {
            pathData: root.powerPath
            glyphColor: Config.Theme.accent
            onTriggered: root.powerService.toggle()
        }
    }

    HoverHandler {
        id: quickSettingsHover
        enabled: root.quickSettingsHoverAllowed
        onHoveredChanged: root.quickSettingsService.setClusterHovered(hovered)
    }

    onQuickSettingsHoverAllowedChanged: if (!quickSettingsHoverAllowed)
        root.quickSettingsService.setClusterHovered(false)
}
