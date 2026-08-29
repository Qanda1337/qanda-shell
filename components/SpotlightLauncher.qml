import QtQuick
import Quickshell
import Quickshell.Widgets
import "../config" as Config

FocusScope {
    id: root

    required property var launcherService

    function focusInput() {
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    onVisibleChanged: if (visible) focusInput()

    Connections {
        target: launcherService
        function onIsOpenChanged() {
            if (launcherService.isOpen)
                root.focusInput();
        }
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 52
        radius: 17
        color: searchInput.activeFocus ? Config.Theme.surfaceActive : Config.Theme.islandRaised

        Behavior on color {
            ColorAnimation { duration: Config.Theme.motionFast }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf002"
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 15
        }

        TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: modeHint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Config.Theme.text
            selectionColor: Config.Theme.accent
            selectedTextColor: "#141414"
            font.family: Config.Theme.uiFont
            font.pixelSize: 16
            clip: true
            text: launcherService.query

            onTextEdited: launcherService.setQuery(text)

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    launcherService.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
                    launcherService.selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
                    launcherService.selectPrevious();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    launcherService.activate();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) {
                    launcherService.selectedIndex = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) {
                    launcherService.selectedIndex = Math.max(0, launcherService.results.length - 1);
                    event.accepted = true;
                }
            }
        }

        Text {
            id: modeHint
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: launcherService.filesOnly ? "ФАЙЛЫ"
                : (launcherService.calculatorOnly ? "CALC"
                : (launcherService.commandOnly ? "КОМАНДА" : "ВСЁ"))
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: searchInput.left
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Приложения, действия, математика, > команда"
            color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.7)
            font.family: Config.Theme.uiFont
            font.pixelSize: 15
        }
    }

    ListView {
        id: resultsList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.topMargin: 10
        anchors.bottom: footer.top
        anchors.bottomMargin: 8
        model: launcherService.results
        clip: true
        spacing: 3
        currentIndex: launcherService.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: resultDelegate
            required property var modelData
            required property int index

            width: ListView.view.width
            height: 50
            radius: 14
            color: index === launcherService.selectedIndex
                ? Config.Theme.surfaceActive
                : (resultMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

            Rectangle {
                id: resultIconBackground
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 11
                color: Config.Theme.islandRaised

                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph || (modelData.kind === "file" ? "\uf15b" : "\uf135")
                    color: Config.Theme.accent
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 5
                    visible: modelData.kind === "app" && modelData.icon !== ""
                    source: modelData.icon ? "image://icon/" + modelData.icon : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            Column {
                anchors.left: resultIconBackground.right
                anchors.leftMargin: 11
                anchors.right: kindLabel.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: modelData.title
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: modelData.subtitle
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }
            }

            Text {
                id: kindLabel
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label || (modelData.kind === "file" ? "ФАЙЛ" : "APP")
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: resultMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: launcherService.selectedIndex = index
                onClicked: launcherService.activate(index)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: launcherService.results.length === 0
            text: launcherService.calculatorOnly
                ? "Нажмите Enter, чтобы вычислить"
                : (launcherService.effectiveQuery.length < 2 ? "Начните вводить запрос" : "Ничего не найдено")
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
        height: 23

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "/ файлы   > команда"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: launcherService.calculatorOnly
                ? "↑↓ история   ↵ вычислить   esc закрыть"
                : "↑↓ выбрать   ↵ открыть   esc закрыть"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
