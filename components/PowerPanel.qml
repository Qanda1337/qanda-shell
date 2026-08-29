import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var powerService
    readonly property int preferredHeight: 176
    readonly property var actions: [
        { action: "suspend", icon: "\uf186", label: "Сон", danger: false },
        { action: "logout", icon: "\uf2f5", label: "Выйти", danger: false },
        { action: "reboot", icon: "\uf2f9", label: "Перезапуск", danger: true },
        { action: "poweroff", icon: "\uf011", label: "Выключить", danger: true }
    ]
    property int selectedIndex: 0

    Keys.onEscapePressed: powerService.close()
    Keys.onLeftPressed: selectedIndex = (selectedIndex + actions.length - 1) % actions.length
    Keys.onRightPressed: selectedIndex = (selectedIndex + 1) % actions.length
    Keys.onReturnPressed: powerService.execute(actions[selectedIndex].action)
    Keys.onEnterPressed: powerService.execute(actions[selectedIndex].action)
    onVisibleChanged: if (visible) {
        selectedIndex = 0;
        Qt.callLater(() => forceActiveFocus());
    }

    Item {
        anchors.fill: parent
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 8

            Text {
                text: "\uf011"
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 14
            }

            Text {
                text: "Питание"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Row {
            id: actionRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottomMargin: 16
            height: 112
            spacing: 8

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionButton

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.selectedIndex
                    width: (actionRow.width - actionRow.spacing * 3) / 4
                    height: actionRow.height
                    radius: 19
                    color: actionMouse.containsMouse || selected
                        ? (modelData.danger
                            ? Qt.rgba(Config.Theme.danger.r, Config.Theme.danger.g, Config.Theme.danger.b, 0.16)
                            : Config.Theme.surfaceActive)
                        : Config.Theme.islandRaised

                    Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.icon
                            color: actionButton.modelData.danger ? Config.Theme.danger : Config.Theme.text
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 22
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.label
                            color: Config.Theme.text
                            font.family: Config.Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = actionButton.index;
                            root.powerService.execute(actionButton.modelData.action);
                        }
                    }
                }
            }
        }
    }
}
