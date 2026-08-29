import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var bindingsService
    readonly property int preferredHeight: 462

    Keys.onEscapePressed: bindingsService.close()
    onVisibleChanged: if (visible) Qt.callLater(() => forceActiveFocus())

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
                text: "\uf11c"
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
                text: "Бинды оболочки"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: "Быстрый доступ к модулям qanda-shell"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
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

    Grid {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 10
        columns: 2
        columnSpacing: 8
        rowSpacing: 2

        Repeater {
            model: bindingsService.bindings

            delegate: Rectangle {
                required property var modelData
                width: (parent.width - parent.columnSpacing) / 2
                height: 42
                radius: 12
                color: bindMouse.containsMouse ? Config.Theme.islandRaised : "transparent"

                Rectangle {
                    id: keyBadge
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(118, shortcutText.implicitWidth + 18)
                    height: 28
                    radius: 9
                    color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.11)

                    Text {
                        id: shortcutText
                        anchors.centerIn: parent
                        text: modelData.keys
                        color: Config.Theme.accent
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: keyBadge.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.title
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: modelData.detail
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: bindMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Super + F2 открывает эту подсказку"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Esc закрыть"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
