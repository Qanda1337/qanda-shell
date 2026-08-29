import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var settingsService
    required property var notificationService
    required property var systemService
    required property var wallpaperService

    property int currentPage: 0
    readonly property var pages: [
        { label: "Быстро", icon: "\uf0e7" },
        { label: "Тема", icon: "\uf53f" }
    ]
    readonly property var paletteColors: [
        Qt.darker(Config.Theme.accent, 1.8),
        Qt.darker(Config.Theme.accent, 1.35),
        Config.Theme.accent,
        Qt.lighter(Config.Theme.accent, 1.25),
        Qt.lighter(Config.Theme.accent, 1.6)
    ]

    focus: visible
    clip: true
    Keys.onEscapePressed: settingsService.close()
    onVisibleChanged: if (visible) Qt.callLater(() => forceActiveFocus())

    function schemeLabel(value) {
        return String(value).replace("scheme-", "").replace(/-/g, " ");
    }

    function applyThemeSettings() {
        if (!colorInput.colorValid) {
            colorInput.forceActiveFocus();
            return;
        }
        Config.Preferences.updateMatugenColor(colorInput.text);
        settingsService.applyTheme();
    }

    component ActionTile: Rectangle {
        id: tile

        required property string icon
        required property string label
        required property string detail
        property bool active: false
        signal triggered

        radius: 17
        color: tileMouse.containsMouse
            ? Config.Theme.surfaceActive
            : (active
                ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)
                : Config.Theme.islandRaised)
        border.width: 1
        border.color: active
            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.42)
            : Config.Theme.surfaceEdge

        Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: 13
            color: tile.active
                ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.2)
                : Config.Theme.track

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Config.Theme.accent : Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 16
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.right: stateDot.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: tile.label
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.detail
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: stateDot
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: tile.active ? Config.Theme.accent : Config.Theme.track
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.triggered()
        }
    }

    Rectangle {
        id: navigation
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 142
        color: Qt.rgba(Config.Theme.islandRaised.r, Config.Theme.islandRaised.g, Config.Theme.islandRaised.b, 0.72)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 18
            text: "НАСТРОЙКИ"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 10
            font.letterSpacing: 1.2
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 46
            spacing: 5

            Repeater {
                model: root.pages

                delegate: Rectangle {
                    id: navButton

                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 42
                    radius: 13
                    color: root.currentPage === index
                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)
                        : (navMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 2
                        color: Config.Theme.accent
                        visible: root.currentPage === navButton.index
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: navButton.modelData.icon
                        color: root.currentPage === navButton.index ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: navButton.modelData.label
                        color: root.currentPage === navButton.index ? Config.Theme.text : Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 12
                        font.weight: root.currentPage === navButton.index ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = navButton.index
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            text: "qanda shell"
            color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.55)
            font.family: Config.Theme.monoFont
            font.pixelSize: 10
        }
    }

    Rectangle {
        anchors.left: navigation.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Config.Theme.surfaceEdge
    }

    Item {
        id: pageArea
        anchors.left: navigation.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 16
        anchors.bottomMargin: 16

        Item {
            anchors.fill: parent
            visible: root.currentPage === 0

            Text {
                id: quickTitle
                text: "Быстрые действия"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Text {
                anchors.left: quickTitle.left
                anchors.top: quickTitle.bottom
                anchors.topMargin: 3
                text: "Часто используемые переключатели"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 11
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 58
                spacing: 9

                Row {
                    width: parent.width
                    spacing: 9

                    ActionTile {
                        width: (parent.width - parent.spacing) / 2
                        height: 82
                        icon: "\uf1f6"
                        label: "Не беспокоить"
                        detail: active ? "Уведомления скрыты" : "Уведомления включены"
                        active: root.notificationService.doNotDisturb
                        onTriggered: root.settingsService.toggleDnd()
                    }

                    ActionTile {
                        width: (parent.width - parent.spacing) / 2
                        height: 82
                        icon: "\uf023"
                        label: "VPN"
                        detail: active ? "Подключен" : "Отключен"
                        active: root.systemService.vpnConnected
                        onTriggered: root.settingsService.toggleVpn()
                    }
                }

                Row {
                    width: parent.width
                    spacing: 9

                    ActionTile {
                        width: (parent.width - parent.spacing) / 2
                        height: 82
                        icon: root.systemService.themeMode === "dark" ? "\uf186" : "\uf185"
                        label: root.systemService.themeMode === "dark" ? "Темная тема" : "Светлая тема"
                        detail: "Сменить режим оформления"
                        active: root.systemService.themeMode === "dark"
                        onTriggered: root.settingsService.toggleThemeMode()
                    }

                    ActionTile {
                        width: (parent.width - parent.spacing) / 2
                        height: 82
                        icon: active ? "\uf6a9" : "\uf028"
                        label: "Звук"
                        detail: active ? "Выключен" : "Включен"
                        active: root.settingsService.sink && root.settingsService.sink.audio
                            ? root.settingsService.sink.audio.muted : false
                        onTriggered: root.settingsService.toggleMute()
                    }
                }

                ActionTile {
                    width: parent.width
                    height: 82
                    icon: "\uf03e"
                    label: "Обои"
                    detail: "Открыть коллекцию и выбрать фон"
                    onTriggered: {
                        root.settingsService.close();
                        root.wallpaperService.open();
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.currentPage === 1

            Text {
                text: "Генератор темы"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 36
                spacing: 7

                Repeater {
                    model: [
                        { value: "wallpaper", label: "Из обоев", icon: "\uf03e" },
                        { value: "color", label: "Из цвета", icon: "\uf53f" }
                    ]

                    delegate: Rectangle {
                        id: sourceButton

                        required property var modelData
                        required property int index
                        readonly property bool selected: Config.Preferences.matugenSource === modelData.value
                        width: 112
                        height: 31
                        radius: 10
                        color: selected
                            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                            : (sourceMouse.containsMouse ? Config.Theme.surfaceHover : Config.Theme.islandRaised)
                        border.width: 1
                        border.color: selected ? Config.Theme.accent : Config.Theme.surfaceEdge

                        Text {
                            anchors.centerIn: parent
                            text: sourceButton.modelData.icon + "  " + sourceButton.modelData.label
                            color: sourceButton.selected ? Config.Theme.accent : Config.Theme.textMuted
                            font.family: Config.Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.Preferences.updateMatugenSource(sourceButton.modelData.value)
                        }
                    }
                }
            }

            Rectangle {
                id: colorField
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 36
                width: 148
                height: 31
                radius: 10
                color: Config.Theme.islandRaised
                border.width: 1
                border.color: colorInput.colorValid
                    ? (colorInput.activeFocus ? Config.Theme.accent : Config.Theme.surfaceEdge)
                    : Config.Theme.danger

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    radius: 5
                    color: colorInput.colorValid ? colorInput.text : Config.Theme.danger
                }

                TextInput {
                    id: colorInput
                    readonly property bool colorValid: /^#[0-9a-fA-F]{6}$/.test(text)
                    anchors.left: parent.left
                    anchors.leftMargin: 31
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.Preferences.matugenColor
                    color: Config.Theme.text
                    selectionColor: Config.Theme.accent
                    selectedTextColor: Config.Theme.island
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 11
                    selectByMouse: true
                    maximumLength: 7
                    onEditingFinished: if (colorValid) Config.Preferences.updateMatugenColor(text)
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 82
                text: "СХЕМА"
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            ListView {
                id: schemeList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 100
                height: 34
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Config.Preferences.matugenSchemes

                delegate: Rectangle {
                    id: schemeButton

                    required property string modelData
                    required property int index
                    readonly property bool selected: Config.Preferences.matugenScheme === modelData
                    width: schemeText.implicitWidth + 22
                    height: 30
                    radius: 10
                    color: selected
                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                        : (schemeMouse.containsMouse ? Config.Theme.surfaceHover : Config.Theme.islandRaised)
                    border.width: 1
                    border.color: selected ? Config.Theme.accent : Config.Theme.surfaceEdge

                    Text {
                        id: schemeText
                        anchors.centerIn: parent
                        text: root.schemeLabel(schemeButton.modelData)
                        color: schemeButton.selected ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: schemeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.Preferences.updateMatugenScheme(schemeButton.modelData)
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        schemeList.contentX = Math.max(0, Math.min(schemeList.contentWidth - schemeList.width,
                            schemeList.contentX - event.angleDelta.y - event.angleDelta.x));
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 147
                text: "КОНТРАСТ"
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 144
                text: Config.Preferences.matugenContrast.toFixed(2)
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 11
            }

            Item {
                id: contrastSlider
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 168
                height: 24

                function setValue(x) {
                    const normalized = Math.max(0, Math.min(1, x / width));
                    Config.Preferences.updateMatugenContrast(Math.round((normalized * 2 - 1) * 100) / 100);
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Config.Theme.track
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: (Config.Preferences.matugenContrast + 1) * 0.5 * parent.width
                    height: 4
                    radius: 2
                    color: Config.Theme.accent
                }

                Rectangle {
                    x: (Config.Preferences.matugenContrast + 1) * 0.5 * parent.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    radius: 8
                    color: Config.Theme.text
                    border.width: 3
                    border.color: Config.Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => contrastSlider.setValue(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            contrastSlider.setValue(mouse.x);
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 207
                text: "ПРИОРИТЕТ"
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 225
                spacing: 5

                Repeater {
                    model: Config.Preferences.matugenPreferences

                    delegate: Rectangle {
                        id: preferButton

                        required property string modelData
                        required property int index
                        readonly property bool selected: Config.Preferences.matugenPrefer === modelData
                        width: (pageArea.width - 20) / 5
                        height: 31
                        radius: 9
                        color: selected
                            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                            : (preferMouse.containsMouse ? Config.Theme.surfaceHover : Config.Theme.islandRaised)
                        border.width: 1
                        border.color: selected ? Config.Theme.accent : Config.Theme.surfaceEdge

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 6
                            text: preferButton.modelData.replace(/-/g, " ")
                            color: preferButton.selected ? Config.Theme.accent : Config.Theme.textMuted
                            font.family: Config.Theme.uiFont
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: preferMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.Preferences.updateMatugenPrefer(preferButton.modelData)
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 273
                text: "ПАЛИТРА АКЦЕНТА"
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 291
                spacing: 7

                Repeater {
                    model: root.paletteColors
                    Rectangle {
                        required property color modelData
                        required property int index
                        width: 42
                        height: 27
                        radius: 9
                        color: modelData
                        border.width: 1
                        border.color: Config.Theme.surfaceEdge
                    }
                }
            }

            Rectangle {
                id: applyButton
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 339
                height: 39
                radius: 13
                color: root.settingsService.busy
                    ? Config.Theme.track
                    : (applyMouse.containsMouse ? Qt.lighter(Config.Theme.accent, 1.12) : Config.Theme.accent)

                Text {
                    anchors.centerIn: parent
                    text: root.settingsService.busy ? "Применение…" : "Применить тему"
                    color: Config.Theme.island
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    enabled: !root.settingsService.busy
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.applyThemeSettings()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: applyButton.bottom
                anchors.topMargin: 7
                visible: root.settingsService.error !== "" || !colorInput.colorValid
                text: !colorInput.colorValid ? "Цвет должен быть в формате #RRGGBB" : root.settingsService.error
                color: Config.Theme.danger
                font.family: Config.Theme.uiFont
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
