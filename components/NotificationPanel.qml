import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var notificationService
    readonly property int preferredHeight: 420
    readonly property int actionCount: 2 + notificationService.history.length
    property int selectedIndex: 0

    function moveSelection(offset) {
        selectedIndex = (selectedIndex + offset + actionCount) % actionCount;
        if (selectedIndex >= 2)
            notificationList.positionViewAtIndex(selectedIndex - 2, ListView.Contain);
    }

    function activateSelection() {
        if (selectedIndex === 0)
            notificationService.toggleDoNotDisturb();
        else if (selectedIndex === 1)
            notificationService.clearHistory();
        else {
            const entry = notificationService.history[selectedIndex - 2];
            if (entry)
                notificationService.invokeFirstAction(entry.key);
        }
    }

    Keys.onUpPressed: moveSelection(-1)
    Keys.onDownPressed: moveSelection(1)
    Keys.onReturnPressed: activateSelection()
    Keys.onEnterPressed: activateSelection()
    Keys.onEscapePressed: notificationService.close()
    onVisibleChanged: if (visible) {
        selectedIndex = 0;
        Qt.callLater(() => forceActiveFocus());
    }
    onActionCountChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, actionCount - 1))

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68

        Rectangle {
            id: iconBox
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 12
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)

            Text {
                anchors.centerIn: parent
                text: "\uf0f3"
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 15
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Уведомления"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                text: notificationService.history.length + " в истории"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }

        Rectangle {
            id: dndButton
            anchors.right: clearButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 34
            radius: 11
            color: notificationService.doNotDisturb
                ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                : (root.selectedIndex === 0 ? Config.Theme.surfaceActive : Config.Theme.islandRaised)

            Text {
                anchors.centerIn: parent
                text: notificationService.doNotDisturb ? "Не беспокоить: вкл" : "Не беспокоить"
                color: notificationService.doNotDisturb ? Config.Theme.accent : Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = 0;
                    notificationService.toggleDoNotDisturb();
                }
            }
        }

        Text {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            text: "\uf1f8"
            color: clearMouse.containsMouse || root.selectedIndex === 1 ? Config.Theme.danger : Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = 1;
                    notificationService.clearHistory();
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            height: 1
            color: Config.Theme.track
        }
    }

    ListView {
        id: notificationList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 18
        anchors.topMargin: 10
        model: notificationService.history
        clip: true
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entryRow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 72
            radius: 14
            color: root.selectedIndex === index + 2
                ? Config.Theme.surfaceActive
                : (entryMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

            Rectangle {
                id: appIconBox
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                radius: 13
                color: Config.Theme.islandRaised
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    color: Config.Theme.accent
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 14
                }
                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    source: modelData.image || (modelData.appIcon ? "image://icon/" + modelData.appIcon : "")
                    fillMode: Image.PreserveAspectFit
                    visible: source !== ""
                }
            }

            Column {
                anchors.left: appIconBox.right
                anchors.leftMargin: 11
                anchors.right: removeButton.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    text: modelData.summary
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: modelData.body || modelData.appName
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Text {
                id: removeButton
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                text: "×"
                color: removeMouse.containsMouse ? Config.Theme.danger : Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 17
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notificationService.removeEntry(modelData.key)
                }
            }

            MouseArea {
                id: entryMouse
                anchors.left: parent.left
                anchors.right: removeButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: notificationService.liveNotifications[modelData.key]?.actions?.length > 0
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.selectedIndex = entryRow.index + 2;
                    notificationService.invokeFirstAction(modelData.key);
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: notificationService.history.length === 0
            text: notificationService.doNotDisturb ? "Уведомлений нет · DND включён" : "Уведомлений пока нет"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
