import QtQuick
import "../config" as Config

Item {
    id: root

    property date shownMonth: new Date()
    readonly property real cellWidth: width / 7

    function changeMonth(offset) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + offset, 1);
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.22)
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: 13
        spacing: 8

        Row {
            width: parent.width
            height: 28

            Text {
                width: parent.width - 64
                height: parent.height
                text: {
                    const months = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
                    return months[root.shownMonth.getMonth()] + " " + root.shownMonth.getFullYear();
                }
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: ["‹", "›"]

                Rectangle {
                    required property int index
                    required property string modelData
                    width: 32
                    height: 28
                    radius: 9
                    color: navMouse.containsMouse ? Config.Theme.islandRaised : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.changeMonth(parent.index === 0 ? -1 : 1)
                    }
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            rowSpacing: 2

            Repeater {
                model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

                Text {
                    required property string modelData
                    width: root.cellWidth
                    height: 20
                    text: modelData
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Repeater {
                model: 42

                Rectangle {
                    required property int index

                    readonly property int firstDay: (new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth(), 1).getDay() + 6) % 7
                    readonly property int dayNumber: index - firstDay + 1
                    readonly property int daysInMonth: new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + 1, 0).getDate()
                    readonly property bool validDay: dayNumber > 0 && dayNumber <= daysInMonth
                    readonly property date today: new Date()
                    readonly property bool isToday: validDay && dayNumber === today.getDate()
                        && root.shownMonth.getMonth() === today.getMonth()
                        && root.shownMonth.getFullYear() === today.getFullYear()

                    width: root.cellWidth
                    height: 27
                    radius: 9
                    color: isToday ? Config.Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.validDay ? parent.dayNumber : ""
                        color: parent.isToday ? "#161616" : Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
