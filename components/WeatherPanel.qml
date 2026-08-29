import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var systemService
    required property var weatherService

    signal hoveredChanged(bool hovered)
    signal closeRequested()

    Keys.onEscapePressed: weatherService.close()
    onVisibleChanged: if (visible && weatherService.isOpen)
        Qt.callLater(() => forceActiveFocus())

    Item {
        id: currentWeather
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.top: parent.top
        anchors.topMargin: 16
        height: 82

        Text {
            id: weatherIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            text: root.systemService.weatherIcon
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 38
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: temperature
            anchors.left: weatherIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.systemService.weatherTemperature
            color: Config.Theme.text
            font.family: Config.Theme.monoFont
            font.pixelSize: 34
            font.weight: Font.DemiBold
        }

        Column {
            anchors.left: temperature.right
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            spacing: 3

            Text {
                width: parent.width
                text: root.systemService.weatherCity
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.systemService.weatherCondition
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Text {
                anchors.right: parent.right
                text: "Ощущается  " + root.systemService.weatherFeelsLike
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                text: "Ветер  " + root.systemService.weatherWind
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.top: currentWeather.bottom
        height: 1
        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.18)
    }

    Row {
        id: forecastRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.top: currentWeather.bottom
        anchors.topMargin: 12
        height: 118

        Repeater {
            model: root.systemService.weatherForecast

            delegate: Item {
                required property var modelData
                required property int index

                width: forecastRow.width / Math.max(1, root.systemService.weatherForecast.length)
                height: forecastRow.height

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 76
                    color: Qt.rgba(Config.Theme.text.r, Config.Theme.text.g, Config.Theme.text.b, 0.09)
                    visible: index > 0
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.day
                        color: index === 0 ? Config.Theme.text : Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: index === 0 ? Font.DemiBold : Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.date
                        color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.62)
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: Config.Theme.accent
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 18
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.minimum + "°  " + modelData.maximum + "°"
                        color: Config.Theme.text
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰖌 " + modelData.precipitation + "%"
                        color: Number(modelData.precipitation) >= 40 ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: root.hoveredChanged(hovered)
    }
}
