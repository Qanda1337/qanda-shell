import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var quickSettingsService
    required property var settingsService
    required property var systemService
    required property var audioService

    focus: enabled
    clip: true
    Keys.onEscapePressed: quickSettingsService.close()
    onEnabledChanged: if (enabled) Qt.callLater(() => forceActiveFocus())

    readonly property var powerProfiles: [
        { id: "power-saver", label: "Экономия", icon: "\uf06c" },
        { id: "balanced", label: "Баланс", icon: "\uf24e" },
        { id: "performance", label: "Мощность", icon: "\uf0e7" }
    ]
    readonly property int controlCount: 4

    function percent(value) {
        return Math.round(Math.max(0, Math.min(1, Number(value || 0))) * 100) + "%";
    }

    function cycleDevice(devices, current, setter) {
        if (devices.length < 1)
            return;
        const index = devices.findIndex(device => device?.id === current?.id);
        setter(devices[(index + 1 + devices.length) % devices.length]);
    }

    component Choice: Item {
        id: choice

        property string icon: ""
        property string label: ""
        property bool selected: false
        property bool available: true
        signal triggered()

        height: 50
        opacity: available ? 1 : 0.38

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 7
            text: choice.icon
            color: choice.selected ? Config.Theme.accent : Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13

            Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: choice.label
            color: choice.selected ? Config.Theme.text : Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 10
            font.weight: choice.selected ? Font.DemiBold : Font.Normal

            Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: choice.selected ? Config.Theme.accent : "transparent"

            Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: choice.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: choice.triggered()
        }
    }

    component AudioRow: Item {
        id: audioRow

        property string icon: ""
        property string device: ""
        property real value: 0
        property bool muted: false
        property bool available: true
        signal adjusted(real value)
        signal muteTriggered()
        signal deviceTriggered()

        height: 62
        opacity: available ? 1 : 0.38

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8
            width: 24
            text: audioRow.icon
            color: audioRow.muted ? Config.Theme.textMuted : Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: levelLabel.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 6
            text: audioRow.device
            color: deviceMouse.containsMouse ? Config.Theme.text : Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight

            MouseArea {
                id: deviceMouse
                anchors.fill: parent
                enabled: audioRow.available
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: audioRow.deviceTriggered()
            }
        }

        Text {
            id: levelLabel
            anchors.right: muteButton.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 6
            width: 38
            text: root.percent(audioRow.value)
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
        }

        Text {
            id: muteButton
            anchors.right: parent.right
            anchors.top: parent.top
            width: 28
            height: 28
            text: audioRow.muted ? "\uf6a9" : audioRow.icon
            color: audioRow.muted ? Config.Theme.danger : Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                enabled: audioRow.available
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: audioRow.muteTriggered()
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            height: 4
            radius: 2
            color: Config.Theme.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, audioRow.value))
                height: parent.height
                radius: parent.radius
                color: audioRow.muted ? Config.Theme.textMuted : Config.Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                enabled: audioRow.available
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                function apply(mouseX) {
                    audioRow.adjusted(Math.max(0, Math.min(1, mouseX / width)));
                }

                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 7

        Row {
            id: controlsRow
            width: parent.width

            Choice {
                width: controlsRow.width / root.controlCount
                icon: "\uf023"
                label: "VPN"
                selected: root.systemService.vpnConnected
                onTriggered: root.settingsService.toggleVpn()
            }

            Repeater {
                model: root.powerProfiles

                delegate: Choice {
                    required property var modelData
                    width: controlsRow.width / root.controlCount
                    icon: modelData.icon
                    label: modelData.label
                    selected: root.settingsService.powerProfile === modelData.id
                    available: root.settingsService.powerProfilesAvailable
                        && root.settingsService.availablePowerProfiles.indexOf(modelData.id) !== -1
                        && !root.settingsService.busy
                    onTriggered: root.settingsService.runAction(["power-profile", modelData.id])
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Config.Theme.surfaceEdge
        }

        AudioRow {
            width: parent.width
            icon: "\uf028"
            device: root.audioService.deviceName(root.audioService.defaultSink) + "  ›"
            value: root.audioService.outputVolume
            muted: root.audioService.outputMuted
            available: root.audioService.defaultSink !== null
            onAdjusted: value => root.audioService.setOutputVolume(value)
            onMuteTriggered: root.audioService.toggleOutputMute()
            onDeviceTriggered: root.cycleDevice(
                root.audioService.outputDevices,
                root.audioService.defaultSink,
                device => root.audioService.setDefaultOutput(device)
            )
        }

        AudioRow {
            width: parent.width
            icon: "\uf130"
            device: root.audioService.deviceName(root.audioService.defaultSource) + "  ›"
            value: root.audioService.inputVolume
            muted: root.audioService.inputMuted
            available: root.audioService.defaultSource !== null
            onAdjusted: value => root.audioService.setInputVolume(value)
            onMuteTriggered: root.audioService.toggleInputMute()
            onDeviceTriggered: root.cycleDevice(
                root.audioService.inputDevices,
                root.audioService.defaultSource,
                device => root.audioService.setDefaultInput(device)
            )
        }
    }
}
