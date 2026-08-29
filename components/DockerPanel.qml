import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var dockerService
    readonly property int preferredHeight: Math.max(250, Math.min(440, 132 + dockerService.containers.length * 64))

    function takeFocus() {
        Qt.callLater(() => root.forceActiveFocus());
    }

    onVisibleChanged: if (visible) takeFocus()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            dockerService.close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            dockerService.selectNext();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            dockerService.selectPrevious();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            dockerService.remove();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            dockerService.refresh();
            event.accepted = true;
        }
    }

    Connections {
        target: dockerService
        function onIsOpenChanged() {
            if (dockerService.isOpen)
                root.takeFocus();
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 66

        Rectangle {
            id: headerIcon
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 11
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)

            Text {
                anchors.centerIn: parent
                text: "\uf308"
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 15
            }
        }

        Column {
            anchors.left: headerIcon.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Docker"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: dockerService.error !== ""
                    ? dockerService.error
                    : (dockerService.loading ? "Обновляем контейнеры" : dockerService.containers.length + " запущено")
                color: dockerService.error !== "" ? Config.Theme.danger : Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                elide: Text.ElideRight
                width: 460
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.18)
        }
    }

    ListView {
        id: containerList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 9
        anchors.bottomMargin: 6
        model: dockerService.containers
        currentIndex: dockerService.selectedIndex
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: containerRow
            required property var modelData
            required property int index
            readonly property bool selected: index === dockerService.selectedIndex

            width: ListView.view.width
            height: 60
            radius: 14
            color: selected
                ? Config.Theme.surfaceActive
                : (rowMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

            Rectangle {
                id: stateMark
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 11
                color: Config.Theme.islandRaised

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Config.Theme.success
                }
            }

            Column {
                anchors.left: stateMark.right
                anchors.leftMargin: 11
                anchors.right: statusColumn.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: containerRow.modelData.Names || containerRow.modelData.ID
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: (containerRow.modelData.Image || "Образ") + "  ·  " + (containerRow.modelData.ID || "")
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Column {
                id: statusColumn
                anchors.right: removeHint.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                spacing: 3

                Text {
                    anchors.right: parent.right
                    width: parent.width
                    text: containerRow.modelData.Status || "running"
                    color: containerRow.modelData.HealthStatus === "healthy" ? Config.Theme.success : Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }

                Text {
                    anchors.right: parent.right
                    width: parent.width
                    text: containerRow.modelData.Ports || "Порты не опубликованы"
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }

            Text {
                id: removeHint
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                text: dockerService.removing && containerRow.selected ? "..." : (containerRow.selected ? "ENTER" : "")
                color: Config.Theme.danger
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: dockerService.selectedIndex = index
                onClicked: dockerService.remove(index)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !dockerService.loading && dockerService.containers.length === 0
            text: dockerService.error !== "" ? "Docker недоступен" : "Запущенных контейнеров нет"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        height: 29

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Super + F3  ·  R обновить"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "↑↓ выбрать   Enter удалить принудительно   Esc закрыть"
            color: Config.Theme.danger
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
