import QtQuick
import Quickshell
import "../config" as Config

FocusScope {
    id: root

    required property var audioService
    property int currentTab: 0
    property int selectedIndex: 0

    readonly property var outputDevices: audioService.outputDevices
    readonly property var inputDevices: audioService.inputDevices
    readonly property var activeDevices: currentTab === 0 ? outputDevices : inputDevices
    readonly property int preferredHeight: Math.max(176, Math.min(390, 94 + activeDevices.length * 68))

    signal closeRequested()

    function moveSelection(offset) {
        if (activeDevices.length > 0)
            selectedIndex = (selectedIndex + offset + activeDevices.length) % activeDevices.length;
    }

    function selectCurrent() {
        const node = activeDevices[selectedIndex];
        if (!node)
            return;
        if (currentTab === 0)
            audioService.setDefaultOutput(node);
        else
            audioService.setDefaultInput(node);
    }

    function adjustVolume(offset) {
        const audio = activeDevices[selectedIndex]?.audio;
        if (audio)
            audio.volume = Math.max(0, Math.min(1, audio.volume + offset));
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) audioService.close();
        else if (event.key === Qt.Key_Up) moveSelection(-1);
        else if (event.key === Qt.Key_Down) moveSelection(1);
        else if (event.key === Qt.Key_Left) adjustVolume(-0.05);
        else if (event.key === Qt.Key_Right) adjustVolume(0.05);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) selectCurrent();
        else if (event.key === Qt.Key_Tab) {
            currentTab = currentTab === 0 ? 1 : 0;
            selectedIndex = 0;
        } else return;
        event.accepted = true;
    }
    onVisibleChanged: if (visible) {
        selectedIndex = 0;
        Qt.callLater(() => forceActiveFocus());
    }
    onCurrentTabChanged: selectedIndex = 0
    onActiveDevicesChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, activeDevices.length - 1))

    function deviceName(node) {
        return node?.description || node?.nickname || node?.name || "Аудиоустройство";
    }

    function deviceIcon(node) {
        const value = (String(node?.name || "") + " " + String(node?.description || "")).toLowerCase();
        if (value.includes("head") || value.includes("науш"))
            return "\uf025";
        if (value.includes("bluetooth") || value.includes("bluez"))
            return "\uf293";
        if (value.includes("hdmi") || value.includes("display"))
            return "\uf108";
        if (value.includes("usb"))
            return "\uf287";
        return root.currentTab === 1 ? "\uf130" : "\uf028";
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 17
        spacing: 6
        Repeater {
            model: [{ label: "Воспроизведение", tab: 0 }, { label: "Запись", tab: 1 }]
            delegate: Rectangle {
                required property var modelData
                width: modelData.tab === 0 ? 142 : 78
                height: 32
                radius: 10
                color: root.currentTab === modelData.tab
                    ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: root.currentTab === modelData.tab ? Config.Theme.accent : Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = modelData.tab }
            }
        }
    }

    Text {
        id: settingsButton
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 28
        height: 28
        text: "\uf1de"
        color: settingsMouse.containsMouse ? Config.Theme.text : Config.Theme.textMuted
        font.family: Config.Theme.monoFont
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["pavucontrol"])
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 70
        height: 1
        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.18)
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 78
        anchors.bottomMargin: 12
        contentWidth: width
        contentHeight: deviceColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: deviceColumn
            width: parent.width

            Repeater {
                model: root.activeDevices

                delegate: Rectangle {
                    id: deviceRow

                    required property var modelData
                    required property int index
                    readonly property bool isDefault: root.currentTab === 0
                        ? audioService.defaultSink?.id === modelData.id
                        : audioService.defaultSource?.id === modelData.id
                    readonly property real level: modelData.audio?.volume ?? 0

                    width: deviceColumn.width
                    height: 68
                    radius: 15
                    color: root.selectedIndex === index
                        ? Config.Theme.surfaceActive
                        : (isDefault
                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.1)
                        : (selectMouse.containsMouse ? Config.Theme.surfaceHover : "transparent"))

                    Behavior on color {
                        ColorAnimation { duration: Config.Theme.motionFast }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: 13
                        color: deviceRow.isDefault ? Config.Theme.accent : Config.Theme.track

                        Text {
                            anchors.centerIn: parent
                            text: root.currentTab === 1 ? "\uf130" : root.deviceIcon(deviceRow.modelData)
                            color: deviceRow.isDefault ? Config.Theme.island : Config.Theme.text
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 58
                        anchors.right: volumeLabel.left
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        text: root.deviceName(deviceRow.modelData)
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: deviceRow.isDefault ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        id: volumeLabel
                        anchors.right: muteButton.left
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        width: 38
                        text: Math.round(deviceRow.level * 100) + "%"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                    }

                    Rectangle {
                        id: volumeTrack
                        anchors.left: parent.left
                        anchors.leftMargin: 58
                        anchors.right: muteButton.left
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 15
                        height: 5
                        radius: 2.5
                        color: Config.Theme.track

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, deviceRow.level))
                            height: parent.height
                            radius: parent.radius
                            color: deviceRow.modelData.audio?.muted ? Config.Theme.textMuted : Config.Theme.accent
                        }

                        Rectangle {
                            x: Math.max(0, Math.min(parent.width - width, parent.width * deviceRow.level - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            radius: 6.5
                            color: Config.Theme.text
                            border.width: 2
                            border.color: Config.Theme.islandRaised
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            cursorShape: Qt.PointingHandCursor

                            function applyVolume(mouseX) {
                                if (deviceRow.modelData.audio)
                                    deviceRow.modelData.audio.volume = Math.max(0, Math.min(1, mouseX / width));
                            }

                            onPressed: mouse => applyVolume(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    applyVolume(mouse.x);
                            }
                        }
                    }

                    Text {
                        id: muteButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        text: deviceRow.modelData.audio?.muted ? "\uf6a9" : (root.currentTab === 1 ? "\uf130" : "\uf028")
                        color: deviceRow.modelData.audio?.muted ? Config.Theme.danger : Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (deviceRow.modelData.audio) deviceRow.modelData.audio.muted = !deviceRow.modelData.audio.muted
                        }
                    }

                    MouseArea {
                        id: selectMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 48
                        height: 34
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = deviceRow.index;
                            if (root.currentTab === 0)
                                audioService.setDefaultOutput(deviceRow.modelData);
                            else
                                audioService.setDefaultInput(deviceRow.modelData);
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 58
                visible: root.activeDevices.length === 0
                text: audioService.ready
                    ? (root.currentTab === 0 ? "Устройства вывода не найдены" : "Микрофоны не найдены")
                    : "Подключение к PipeWire…"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
