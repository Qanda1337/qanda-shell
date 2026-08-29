import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var clipboardService
    readonly property int preferredHeight: 430

    function focusInput() {
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    onVisibleChanged: if (visible) focusInput()

    Connections {
        target: clipboardService
        function onIsOpenChanged() {
            if (clipboardService.isOpen)
                root.focusInput();
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64

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
                text: "\uf0ea"
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 14
            }
        }

        Column {
            anchors.left: headerIcon.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Буфер обмена"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: clipboardService.error !== ""
                    ? clipboardService.error
                    : (clipboardService.loading ? "Обновляем историю" : clipboardService.entries.length + " последних записей")
                color: clipboardService.error !== "" ? Config.Theme.danger : Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }

    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        height: 44
        radius: 14
        color: searchInput.activeFocus ? Config.Theme.surfaceActive : Config.Theme.islandRaised

        Behavior on color {
            ColorAnimation { duration: Config.Theme.motionFast }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf002"
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }

        TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 43
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: clipboardService.query
            color: Config.Theme.text
            selectionColor: Config.Theme.accent
            selectedTextColor: Config.Theme.island
            font.family: Config.Theme.uiFont
            font.pixelSize: 14
            clip: true

            onTextEdited: clipboardService.setQuery(text)

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    clipboardService.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    clipboardService.selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    clipboardService.selectPrevious();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    clipboardService.activate();
                    event.accepted = true;
                }
            }
        }

        Text {
            anchors.left: searchInput.left
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Найти в истории"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }

    ListView {
        id: historyList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.bottom: footer.top
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 10
        anchors.bottomMargin: 6
        model: clipboardService.results
        currentIndex: clipboardService.selectedIndex
        clip: true
        spacing: 3
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: historyRow
            required property var modelData
            required property int index
            readonly property bool selected: index === clipboardService.selectedIndex

            width: ListView.view.width
            height: 48
            radius: 13
            color: selected
                ? Config.Theme.surfaceActive
                : (rowMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

            Rectangle {
                id: typeIcon
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 10
                color: Config.Theme.islandRaised

                Text {
                    anchors.centerIn: parent
                    text: historyRow.modelData.binary ? "\uf03e" : "\uf15c"
                    color: Config.Theme.accent
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                }
            }

            Column {
                anchors.left: typeIcon.right
                anchors.leftMargin: 10
                anchors.right: copyHint.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: historyRow.modelData.binary ? "Изображение" : historyRow.modelData.preview
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: historyRow.modelData.binary ? historyRow.modelData.preview : "Текст · #" + historyRow.modelData.id
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Text {
                id: copyHint
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: historyRow.selected ? "ENTER" : ""
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: clipboardService.selectedIndex = index
                onClicked: clipboardService.activate(index)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !clipboardService.loading && clipboardService.results.length === 0
            text: clipboardService.query === "" ? "История пуста" : "Ничего не найдено"
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
        height: 27

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Super + F1"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "↑↓ выбрать   Enter скопировать   Esc закрыть"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
