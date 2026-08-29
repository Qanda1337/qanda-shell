import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var timerService
    readonly property int preferredHeight: 270
    readonly property var presetMinutes: [5, 10, 25, 45, 60]
    property int selectedIndex: 0

    function activateSelected() {
        if (timerService.active) {
            if (selectedIndex === 0) timerService.togglePause();
            else timerService.cancel();
        } else if (selectedIndex < presetMinutes.length) {
            timerService.startMinutes(presetMinutes[selectedIndex]);
        } else if (selectedIndex === 5) {
            customInput.forceActiveFocus();
        } else {
            timerService.startMinutes(customInput.text);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) timerService.close();
        else if (event.key === Qt.Key_Space && timerService.active) timerService.togglePause();
        else if (event.key === Qt.Key_Left)
            selectedIndex = timerService.active ? (selectedIndex + 1) % 2 : (selectedIndex + 6) % 7;
        else if (event.key === Qt.Key_Right)
            selectedIndex = timerService.active ? (selectedIndex + 1) % 2 : (selectedIndex + 1) % 7;
        else if (event.key === Qt.Key_Up && !timerService.active) selectedIndex = Math.min(4, selectedIndex);
        else if (event.key === Qt.Key_Down && !timerService.active) selectedIndex = selectedIndex < 5 ? 5 : selectedIndex;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) activateSelected();
        else return;
        event.accepted = true;
    }
    onVisibleChanged: if (visible) {
        selectedIndex = 0;
        Qt.callLater(() => forceActiveFocus());
    }
    Connections {
        target: timerService
        function onActiveChanged() { root.selectedIndex = 0; }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.top: parent.top
        anchors.topMargin: 17
        spacing: 10
        Text {
            text: "\uf017"
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 15
        }
        Column {
            spacing: 2
            Text {
                text: "Таймер"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                text: timerService.active ? (timerService.state === "paused" ? "На паузе" : "Обратный отсчёт") : "Выберите длительность"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 64
        height: 1
        color: Config.Theme.track
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 76
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 18
        visible: !timerService.active

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: "Быстрый запуск"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }

        Row {
            id: presets
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 27
            height: 54
            spacing: 8
            Repeater {
                model: root.presetMinutes
                delegate: Rectangle {
                    id: presetButton
                    required property int modelData
                    required property int index
                    width: (presets.width - presets.spacing * 4) / 5
                    height: presets.height
                    radius: 14
                    color: root.selectedIndex === index
                        ? Config.Theme.surfaceActive
                        : (presetMouse.containsMouse ? Config.Theme.surfaceHover : Config.Theme.islandRaised)
                    Text {
                        anchors.centerIn: parent
                        text: modelData + " мин"
                        color: Config.Theme.text
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = presetButton.index;
                            timerService.startMinutes(modelData);
                        }
                    }
                }
            }
        }

        Rectangle {
            id: customBox
            anchors.left: parent.left
            anchors.right: startButton.left
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            height: 46
            radius: 13
            color: customInput.activeFocus || root.selectedIndex === 5 ? Config.Theme.surfaceActive : Config.Theme.islandRaised
            TextInput {
                id: customInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                validator: IntValidator { bottom: 1; top: 1440 }
                onAccepted: timerService.startMinutes(text)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: customInput.text === ""
                text: "Свои минуты"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }

        Rectangle {
            id: startButton
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 130
            height: 46
            radius: 13
            color: Config.Theme.accent
            scale: root.selectedIndex === 6 ? 1.035 : 1

            Behavior on scale {
                NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutCubic }
            }
            Text {
                anchors.centerIn: parent
                text: "Запустить"
                color: Config.Theme.island
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = 6;
                    timerService.startMinutes(customInput.text);
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 76
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 18
        visible: timerService.active

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: timerService.displayText
            color: timerService.state === "paused" ? Config.Theme.textMuted : Config.Theme.text
            font.family: Config.Theme.monoFont
            font.pixelSize: 38
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 64
            height: 7
            radius: 3.5
            color: Config.Theme.track
            Rectangle {
                width: parent.width * timerService.progress
                height: parent.height
                radius: parent.radius
                color: timerService.state === "paused" ? Config.Theme.textMuted : Config.Theme.accent
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10
            Rectangle {
                id: pauseButton
                width: 150
                height: 46
                radius: 13
                color: root.selectedIndex === 0 ? Config.Theme.surfaceActive : Config.Theme.islandRaised
                Text {
                    anchors.centerIn: parent
                    text: timerService.state === "paused" ? "Продолжить" : "Пауза"
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: timerService.togglePause() }
            }
            Rectangle {
                id: cancelButton
                width: 150
                height: 46
                radius: 13
                color: Qt.rgba(Config.Theme.danger.r, Config.Theme.danger.g, Config.Theme.danger.b, root.selectedIndex === 1 ? 0.24 : 0.14)
                Text {
                    anchors.centerIn: parent
                    text: "Отменить"
                    color: Config.Theme.danger
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: timerService.cancel() }
            }
        }
    }
}
