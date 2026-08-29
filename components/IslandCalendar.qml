import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var calendarService
    readonly property var monthNames: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    readonly property var weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    property int selectedYearIndex: 0

    function moveDay(offset) {
        const next = new Date(calendarService.selectedDate);
        next.setDate(next.getDate() + offset);
        calendarService.selectedDate = next;
        calendarService.visibleMonth = new Date(next.getFullYear(), next.getMonth(), 1);
    }

    function moveYear(offset) {
        selectedYearIndex = (selectedYearIndex + offset + 12) % 12;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) calendarService.close();
        else if (event.key === Qt.Key_PageUp) calendarService.previous();
        else if (event.key === Qt.Key_PageDown) calendarService.next();
        else if (calendarService.yearPickerOpen && event.key === Qt.Key_Left) moveYear(-1);
        else if (calendarService.yearPickerOpen && event.key === Qt.Key_Right) moveYear(1);
        else if (calendarService.yearPickerOpen && event.key === Qt.Key_Up) moveYear(-3);
        else if (calendarService.yearPickerOpen && event.key === Qt.Key_Down) moveYear(3);
        else if (calendarService.yearPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            calendarService.chooseYear(calendarService.yearPageStart + selectedYearIndex);
        else if (!calendarService.yearPickerOpen && event.key === Qt.Key_Left) moveDay(-1);
        else if (!calendarService.yearPickerOpen && event.key === Qt.Key_Right) moveDay(1);
        else if (!calendarService.yearPickerOpen && event.key === Qt.Key_Up) moveDay(-7);
        else if (!calendarService.yearPickerOpen && event.key === Qt.Key_Down) moveDay(7);
        else if (!calendarService.yearPickerOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            calendarService.close();
        else return;
        event.accepted = true;
    }
    onVisibleChanged: if (visible) Qt.callLater(() => forceActiveFocus())

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 54
        radius: 17
        color: Config.Theme.islandRaised
        border.width: 1
        border.color: Config.Theme.surfaceEdge

        Text {
            id: previousButton
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            text: "‹"
            color: Config.Theme.textMuted
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarService.previous()
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: calendarService.yearPickerOpen
                    ? calendarService.yearPageStart + " — " + (calendarService.yearPageStart + 11)
                    : root.monthNames[calendarService.visibleMonth.getMonth()] + " " + calendarService.visibleMonth.getFullYear()
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: calendarService.yearPickerOpen ? "Выберите год" : "Нажмите, чтобы выбрать год"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }

        MouseArea {
            anchors.centerIn: parent
            width: 240
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                calendarService.yearPageStart = Math.floor(calendarService.visibleMonth.getFullYear() / 12) * 12;
                root.selectedYearIndex = calendarService.visibleMonth.getFullYear() - calendarService.yearPageStart;
                calendarService.yearPickerOpen = !calendarService.yearPickerOpen;
            }
        }

        Text {
            id: nextButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            text: "›"
            color: Config.Theme.textMuted
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarService.next()
            }
        }

        Rectangle {
            anchors.right: nextButton.left
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 28
            radius: 10
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.13)
            Text {
                anchors.centerIn: parent
                text: "Сегодня"
                color: Config.Theme.accent
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarService.showToday()
            }
        }
    }

    Item {
        id: monthView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.bottom: footer.top
        anchors.bottomMargin: 8
        visible: !calendarService.yearPickerOpen

        Grid {
            id: calendarGrid
            anchors.fill: parent
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: root.weekdays
                Text {
                    required property string modelData
                    width: Math.floor((calendarGrid.width - 24) / 7)
                    height: 24
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
                    readonly property int firstDay: (new Date(calendarService.visibleMonth.getFullYear(), calendarService.visibleMonth.getMonth(), 1).getDay() + 6) % 7
                    readonly property date cellDate: new Date(calendarService.visibleMonth.getFullYear(), calendarService.visibleMonth.getMonth(), index - firstDay + 1)
                    readonly property bool currentMonth: cellDate.getMonth() === calendarService.visibleMonth.getMonth()
                    readonly property date today: new Date()
                    readonly property bool isToday: cellDate.getDate() === today.getDate() && cellDate.getMonth() === today.getMonth() && cellDate.getFullYear() === today.getFullYear()
                    readonly property bool isSelected: cellDate.getDate() === calendarService.selectedDate.getDate() && cellDate.getMonth() === calendarService.selectedDate.getMonth() && cellDate.getFullYear() === calendarService.selectedDate.getFullYear()

                    width: Math.floor((calendarGrid.width - 24) / 7)
                    height: Math.floor((calendarGrid.height - 48) / 6)
                    radius: 13
                    color: isSelected
                        ? Config.Theme.accent
                        : (dayMouse.containsMouse || isToday ? Config.Theme.surfaceHover : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: parent.cellDate.getDate()
                        color: parent.isSelected ? "#161616" : (parent.isToday ? Config.Theme.accent : (parent.currentMonth ? Config.Theme.text : Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.42)))
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: parent.isToday || parent.isSelected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calendarService.selectedDate = parent.cellDate;
                            if (!parent.currentMonth)
                                calendarService.visibleMonth = new Date(parent.cellDate.getFullYear(), parent.cellDate.getMonth(), 1);
                        }
                    }
                }
            }
        }
    }

    Grid {
        id: yearView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 20
        anchors.bottom: footer.top
        anchors.bottomMargin: 14
        columns: 3
        rowSpacing: 9
        columnSpacing: 9
        visible: calendarService.yearPickerOpen

        Repeater {
            model: 12
            Rectangle {
                required property int index
                readonly property int year: calendarService.yearPageStart + index
                readonly property bool currentYear: year === new Date().getFullYear()
                readonly property bool selectedYear: year === calendarService.visibleMonth.getFullYear()
                readonly property bool keyboardSelected: index === root.selectedYearIndex
                width: Math.floor((yearView.width - 18) / 3)
                height: Math.floor((yearView.height - 27) / 4)
                radius: 16
                color: selectedYear
                    ? Config.Theme.accent
                    : (keyboardSelected ? Config.Theme.surfaceActive : (yearMouse.containsMouse || currentYear ? Config.Theme.surfaceHover : "transparent"))
                Text {
                    anchors.centerIn: parent
                    text: parent.year
                    color: parent.selectedYear ? "#161616" : Config.Theme.text
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 16
                    font.weight: parent.currentYear || parent.selectedYear ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: yearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calendarService.chooseYear(parent.year)
                }
            }
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 20
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(calendarService.selectedDate, "dd.MM.yyyy")
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Стрелки: выбрать   PgUp/PgDn: месяц   Enter: готово"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
        }
    }
}
