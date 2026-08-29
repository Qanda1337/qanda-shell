import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var settingsService
    required property var systemService
    required property var wallpaperService
    required property var immersiveService

    readonly property int currentSection: settingsService.currentSection
    readonly property var sections: [
        { label: "Система", icon: "\uf0ad" },
        { label: "Экран", icon: "\uf108" },
        { label: "Оболочка", icon: "\uf013" },
        { label: "Данные", icon: "\uf2bb" }
    ]

    focus: enabled
    clip: true
    Keys.onEscapePressed: settingsService.close()
    onEnabledChanged: if (enabled) Qt.callLater(() => forceActiveFocus())

    function dependencyCount() {
        const values = Object.values(settingsService.dependencies || {});
        return values.filter(Boolean).length + "/" + values.length;
    }

    function schemeLabel(value) {
        const labels = {
            "scheme-content": "Content",
            "scheme-expressive": "Expressive",
            "scheme-fidelity": "Fidelity",
            "scheme-fruit-salad": "Fruit",
            "scheme-monochrome": "Mono",
            "scheme-neutral": "Neutral",
            "scheme-rainbow": "Rainbow",
            "scheme-tonal-spot": "Tonal",
            "scheme-vibrant": "Vibrant"
        };
        return labels[value] || value;
    }

    function cycleScheme(delta) {
        const values = Config.Preferences.matugenSchemes;
        const index = values.indexOf(Config.Preferences.matugenScheme);
        Config.Preferences.updateMatugenScheme(values[(index + delta + values.length) % values.length]);
    }

    component SectionTitle: Item {
        property string title: ""
        property string detail: ""
        width: parent?.width ?? 0
        height: 48

        Text {
            text: parent.title
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        Text {
            anchors.top: parent.top
            anchors.topMargin: 24
            text: parent.detail
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 11
        }
    }

    component ControlCard: Rectangle {
        id: card
        property string icon: ""
        property string title: ""
        property string detail: ""
        property bool selected: false
        property bool available: true
        property bool interactive: true
        property bool showSwitch: false
        property bool showChevron: false
        property string trailingText: ""
        signal triggered()

        height: 58
        radius: 9
        color: selected && !showSwitch
            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.13)
            : (mouse.containsMouse && available && interactive ? Config.Theme.surfaceHover : "transparent")
        opacity: available ? 1 : 0.48

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 22
            radius: 2
            visible: card.selected && !card.showSwitch
            color: Config.Theme.accent
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 10
            color: card.selected
                ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.2)
                : Config.Theme.track
            Text {
                anchors.centerIn: parent
                text: card.icon
                color: card.selected ? Config.Theme.accent : Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 14
            }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: trailing.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: card.detail === "" ? 20 : 10
            text: card.title
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: trailing.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 31
            text: card.detail
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: card.showSwitch ? 38 : Math.max(18, trailingLabel.implicitWidth)
            height: 24

            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 20
                radius: 10
                visible: card.showSwitch
                color: card.selected ? Config.Theme.accent : Config.Theme.track
                Rectangle {
                    x: card.selected ? 18 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: card.selected ? Config.Theme.island : Config.Theme.textMuted
                    Behavior on x { NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                id: trailingLabel
                anchors.centerIn: parent
                visible: !card.showSwitch
                text: card.trailingText !== "" ? card.trailingText : (card.showChevron ? "›" : "")
                color: card.showChevron ? Config.Theme.textMuted : Config.Theme.text
                font.family: card.showChevron ? Config.Theme.uiFont : Config.Theme.monoFont
                font.pixelSize: card.showChevron ? 22 : 11
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: card.available && card.interactive
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: card.triggered()
        }
    }

    component StepperRow: Item {
        id: stepper
        property string icon: ""
        property string title: ""
        property string detail: ""
        property string valueText: ""
        property bool available: true
        property bool decrementEnabled: true
        property bool incrementEnabled: true
        signal decrement()
        signal increment()

        height: 60
        opacity: available ? 1 : 0.48
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 10
            color: Config.Theme.track
            Text { anchors.centerIn: parent; text: stepper.icon; color: Config.Theme.text; font.family: Config.Theme.monoFont; font.pixelSize: 13 }
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 58; anchors.top: parent.top; anchors.topMargin: 10
            text: stepper.title; color: Config.Theme.text; font.family: Config.Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 58; anchors.top: parent.top; anchors.topMargin: 31
            text: stepper.detail; color: Config.Theme.textMuted; font.family: Config.Theme.uiFont; font.pixelSize: 10
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Rectangle {
                width: 30; height: 30; radius: 8
                color: minusMouse.containsMouse && minusMouse.enabled ? Config.Theme.surfaceActive : Config.Theme.track
                opacity: minusMouse.enabled ? 1 : 0.4
                Text { anchors.centerIn: parent; text: "−"; color: Config.Theme.text; font.family: Config.Theme.uiFont; font.pixelSize: 18 }
                MouseArea { id: minusMouse; anchors.fill: parent; enabled: stepper.available && stepper.decrementEnabled; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: stepper.decrement() }
            }
            Text {
                width: 68; height: 30
                text: stepper.valueText
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                width: 30; height: 30; radius: 8
                color: plusMouse.containsMouse && plusMouse.enabled ? Config.Theme.surfaceActive : Config.Theme.track
                opacity: plusMouse.enabled ? 1 : 0.4
                Text { anchors.centerIn: parent; text: "+"; color: Config.Theme.text; font.family: Config.Theme.uiFont; font.pixelSize: 17 }
                MouseArea { id: plusMouse; anchors.fill: parent; enabled: stepper.available && stepper.incrementEnabled; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: stepper.increment() }
            }
        }
    }

    component ThemePresetOption: Rectangle {
        id: presetOption
        property string title: ""
        property var palette: ({})
        property bool selected: false
        signal triggered()

        height: 58
        radius: 10
        color: selected
            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.13)
            : (presetMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")
        border.width: selected ? 1 : 0
        border.color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.45)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: -5
            Repeater {
                model: [presetOption.palette.accent, presetOption.palette.success,
                    presetOption.palette.warning, presetOption.palette.danger]
                delegate: Rectangle {
                    required property var modelData
                    width: 20
                    height: 20
                    radius: 10
                    color: modelData || "transparent"
                    border.width: 2
                    border.color: presetOption.palette.raised || Config.Theme.islandRaised
                }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 80
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: presetOption.title
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        MouseArea {
            id: presetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: presetOption.triggered()
        }
    }

    component BinaryChoiceRow: Item {
        id: choice
        property string icon: ""
        property string title: ""
        property string firstLabel: ""
        property string secondLabel: ""
        property bool secondSelected: false
        signal selected(bool second)

        height: 60
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 10
            color: Config.Theme.track
            Text { anchors.centerIn: parent; text: choice.icon; color: Config.Theme.text; font.family: Config.Theme.monoFont; font.pixelSize: 13 }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.verticalCenter: parent.verticalCenter
            text: choice.title
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [choice.firstLabel, choice.secondLabel]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool active: choice.secondSelected === (index === 1)
                    width: 70; height: 30; radius: 8
                    color: active
                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.2)
                        : Config.Theme.track
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.active ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 10
                        font.weight: parent.active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choice.selected(index === 1)
                    }
                }
            }
        }
    }

    component ConfigInputRow: Item {
        id: inputRow
        property string icon: ""
        property string title: ""
        property string detail: ""
        property string value: ""
        property string placeholder: ""
        property var pattern: /.*/
        signal committed(string value)

        height: 56

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 10
            color: Config.Theme.track
            Text {
                anchors.centerIn: parent
                text: inputRow.icon
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
            }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.top: parent.top
            anchors.topMargin: 8
            text: inputRow.title
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.top: parent.top
            anchors.topMargin: 29
            text: inputRow.detail
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 9
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 248
            height: 34
            radius: 8
            color: Config.Theme.track
            border.width: editor.activeFocus ? 1 : 0
            border.color: editor.acceptableInput ? Config.Theme.accent : Config.Theme.danger

            TextInput {
                id: editor
                property bool edited: false
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                text: inputRow.value
                color: acceptableInput ? Config.Theme.text : Config.Theme.danger
                selectionColor: Config.Theme.accent
                selectedTextColor: Config.Theme.island
                font.family: Config.Theme.monoFont
                font.pixelSize: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                validator: RegularExpressionValidator { regularExpression: inputRow.pattern }
                onTextEdited: edited = true
                onEditingFinished: {
                    if (edited && acceptableInput)
                        inputRow.committed(text.trim());
                    edited = false;
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: editor.text === "" && !editor.activeFocus
                text: inputRow.placeholder
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 10
            }
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
            anchors.leftMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 14
            text: "CONTROL CENTER"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 9
            font.letterSpacing: 1
        }
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 38
            spacing: 3
            Repeater {
                model: root.sections
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 38
                    radius: 12
                    color: root.currentSection === index
                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)
                        : (navMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 16
                        radius: 2
                        visible: root.currentSection === index
                        color: Config.Theme.accent
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        color: root.currentSection === index ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 37
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: root.currentSection === index ? Config.Theme.text : Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 11
                        font.weight: root.currentSection === index ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.settingsService.setSection(index)
                    }
                }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            text: "qanda shell"
            color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.5)
            font.family: Config.Theme.monoFont
            font.pixelSize: 9
        }
    }

    Item {
        id: pageArea
        anchors.left: navigation.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 14

        Flickable {
            anchors.fill: parent
            visible: root.currentSection === 1
            contentWidth: width
            contentHeight: displayColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: displayColumn
                width: parent.width
                spacing: 9
                SectionTitle { title: "Экран"; detail: "Монитор, яркость и цвет" }
                ControlCard {
                    width: parent.width
                    icon: "\uf108"
                    title: root.settingsService.monitorName || "Монитор"
                    detail: Math.round(root.settingsService.refreshRate) + " Гц · scale " + root.settingsService.monitorScale.toFixed(2)
                    interactive: false
                }
                StepperRow {
                    width: parent.width
                    visible: root.settingsService.brightnessAvailable
                    icon: "\uf185"
                    title: "Яркость"
                    detail: "Шаг 5%"
                    valueText: root.settingsService.brightness + "%"
                    decrementEnabled: root.settingsService.brightness > 0
                    incrementEnabled: root.settingsService.brightness < 100
                    onDecrement: root.settingsService.runAction(["brightness", "-5%"])
                    onIncrement: root.settingsService.runAction(["brightness", "+5%"])
                }
                ControlCard {
                    width: parent.width
                    visible: root.settingsService.nightLightAvailable
                    icon: "\uf186"; title: "Night Light"
                    detail: root.settingsService.nightLightAvailable
                        ? (root.settingsService.nightLight ? "4500K · включён" : "Выключен")
                        : "hyprsunset/wlsunset не установлен"
                    selected: root.settingsService.nightLight
                    showSwitch: true
                    available: root.settingsService.nightLightAvailable
                    onTriggered: root.settingsService.runAction(["night-light"])
                }
                ControlCard {
                    width: parent.width
                    icon: root.systemService.themeMode === "dark" ? "\uf186" : "\uf185"
                    title: "Цветовой режим"
                    detail: root.systemService.themeMode === "dark" ? "Тёмный" : "Светлый"
                    selected: root.systemService.themeMode === "dark"
                    showSwitch: true
                    available: Config.Preferences.themeSource === "matugen"
                    onTriggered: root.settingsService.toggleThemeMode()
                }
                BinaryChoiceRow {
                    width: parent.width
                    icon: "\uf53f"
                    title: "Движок темы"
                    firstLabel: "Matugen"
                    secondLabel: "Готовая"
                    secondSelected: Config.Preferences.themeSource === "preset"
                    onSelected: second => {
                        if (second)
                            root.settingsService.applyPresetTheme(Config.Preferences.themePreset);
                        else
                            root.settingsService.applyTheme();
                    }
                }
                Flow {
                    readonly property int rowCount: Math.ceil(Config.Preferences.themePresets.length / 2)
                    width: parent.width
                    height: Config.Preferences.themeSource === "preset"
                        ? rowCount * 58 + Math.max(0, rowCount - 1) * spacing : 0
                    visible: height > 0
                    spacing: 7
                    clip: true
                    Repeater {
                        model: Config.Preferences.themePresets
                        delegate: ThemePresetOption {
                            required property var modelData
                            width: (displayColumn.width - 7) / 2
                            title: modelData.label
                            palette: Config.Theme.preset(modelData.id)
                            selected: Config.Preferences.themePreset === modelData.id
                            onTriggered: root.settingsService.applyPresetTheme(modelData.id)
                        }
                    }
                }
                BinaryChoiceRow {
                    width: parent.width
                    icon: "\uf03e"
                    title: "Источник Matugen"
                    firstLabel: "Обои"
                    secondLabel: "Цвет"
                    secondSelected: Config.Preferences.matugenSource === "color"
                    onSelected: second => Config.Preferences.updateMatugenSource(second ? "color" : "wallpaper")
                }
                StepperRow {
                    width: parent.width
                    icon: "\uf1fc"
                    title: "Цветовая схема"
                    detail: "Вариант генерации палитры"
                    valueText: root.schemeLabel(Config.Preferences.matugenScheme)
                    onDecrement: root.cycleScheme(-1)
                    onIncrement: root.cycleScheme(1)
                }
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 9
                    color: Config.Theme.islandRaised
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 8
                        color: themeColorInput.acceptableInput ? themeColorInput.text : Config.Theme.danger
                    }
                    TextInput {
                        id: themeColorInput
                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.right: applyThemeButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.Preferences.matugenColor
                        color: Config.Theme.text
                        selectionColor: Config.Theme.accent
                        selectedTextColor: Config.Theme.island
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 12
                        validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{6}$/ }
                        onEditingFinished: if (acceptableInput) Config.Preferences.updateMatugenColor(text)
                    }
                    Text {
                        id: applyThemeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78; height: 30
                        text: root.settingsService.busy ? "…" : "Применить"
                        color: Config.Theme.accent
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.settingsService.busy && themeColorInput.acceptableInput
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                Config.Preferences.updateMatugenColor(themeColorInput.text);
                                root.settingsService.applyTheme();
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            anchors.fill: parent
            visible: root.currentSection === 2
            contentWidth: width
            contentHeight: shellColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: shellColumn
                width: parent.width
                spacing: 9
                SectionTitle { title: "Оболочка"; detail: "Поведение и оформление qanda-shell" }
                ControlCard {
                    width: parent.width
                    icon: "\uf065"; title: "Immersive bar"
                    detail: root.immersiveService.enabled ? "Активен" : "Обычная панель"
                    selected: root.immersiveService.enabled
                    showSwitch: true
                    onTriggered: root.immersiveService.toggle()
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf135"; title: "Анимации"; detail: Config.Preferences.animationsEnabled ? "Включены" : "Отключены"
                    selected: Config.Preferences.animationsEnabled
                    showSwitch: true
                    onTriggered: Config.Preferences.updateAnimationsEnabled(!Config.Preferences.animationsEnabled)
                }
                StepperRow {
                    width: parent.width
                    icon: "\uf0e7"
                    title: "Скорость анимаций"
                    detail: "Применяется ко всей оболочке"
                    valueText: Config.Preferences.animationSpeed.toFixed(2).replace(/0$/, "") + "×"
                    available: Config.Preferences.animationsEnabled
                    decrementEnabled: Config.Preferences.animationSpeed > 0.5
                    incrementEnabled: Config.Preferences.animationSpeed < 2
                    onDecrement: Config.Preferences.updateAnimationSpeed(Config.Preferences.animationSpeed - 0.25)
                    onIncrement: Config.Preferences.updateAnimationSpeed(Config.Preferences.animationSpeed + 0.25)
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf005"; title: "Визуальные эффекты"; detail: Config.Preferences.effectsEnabled ? "Тени включены" : "Тени отключены"
                    selected: Config.Preferences.effectsEnabled
                    showSwitch: true
                    onTriggered: Config.Preferences.updateEffectsEnabled(!Config.Preferences.effectsEnabled)
                }
                StepperRow {
                    width: parent.width
                    icon: "\uf0f3"
                    title: "Время уведомления"
                    detail: "Как долго баннер остаётся на экране"
                    valueText: (Config.Preferences.notificationDuration / 1000).toFixed(1).replace(".0", "") + " с"
                    decrementEnabled: Config.Preferences.notificationDuration > 1000
                    incrementEnabled: Config.Preferences.notificationDuration < 15000
                    onDecrement: Config.Preferences.updateNotificationDuration(Config.Preferences.notificationDuration - 500)
                    onIncrement: Config.Preferences.updateNotificationDuration(Config.Preferences.notificationDuration + 500)
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf0a5"; title: "Рабочие столы"; detail: "Левая часть панели"
                    selected: Config.Preferences.showLeftCluster
                    showSwitch: true
                    onTriggered: Config.Preferences.updateShowLeftCluster(!Config.Preferences.showLeftCluster)
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf0a4"; title: "Системные статусы"; detail: "Правая часть панели"
                    selected: Config.Preferences.showRightCluster
                    showSwitch: true
                    onTriggered: Config.Preferences.updateShowRightCluster(!Config.Preferences.showRightCluster)
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf03e"; title: "Обои"; detail: "Открыть коллекцию"
                    showChevron: true
                    onTriggered: { root.settingsService.close(); root.wallpaperService.open(); }
                }
            }
        }

        Flickable {
            anchors.fill: parent
            visible: root.currentSection === 0
            contentWidth: width
            contentHeight: maintenanceColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: maintenanceColumn
                width: parent.width
                spacing: 9
                SectionTitle { title: "Система"; detail: "Диагностика и обслуживание shell" }
                ControlCard {
                    width: parent.width
                    icon: "\uf058"; title: "Зависимости"
                    detail: root.dependencyCount() + " доступно · nmcli, PipeWire, Hyprland, cliphist, waypaper, qalc"
                    selected: root.dependencyCount().startsWith("6/")
                    interactive: false
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf021"; title: "Обновить состояние"
                    detail: root.settingsService.busy ? "Выполняется…" : "Перечитать системные backend'ы"
                    available: !root.settingsService.busy
                    showChevron: true
                    onTriggered: root.settingsService.refresh()
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf15c"; title: "Логи Quickshell"; detail: "Открыть последние 200 строк"
                    showChevron: true
                    onTriggered: root.settingsService.openLogs()
                }
                ControlCard {
                    width: parent.width
                    icon: "\uf2f9"; title: "Перезапустить shell"; detail: "Мягкий перезапуск конфигурации"
                    showChevron: true
                    onTriggered: root.settingsService.restartShell()
                }
                Text {
                    width: parent.width
                    visible: root.settingsService.error !== "" || Config.Preferences.error !== ""
                    text: root.settingsService.error || Config.Preferences.error
                    color: Config.Theme.danger
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }

        Flickable {
            anchors.fill: parent
            visible: root.currentSection === 3
            contentWidth: width
            contentHeight: dataColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: dataColumn
                width: parent.width
                spacing: 7
                SectionTitle { title: "Личные данные"; detail: "Хранятся локально и не попадают в Git" }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf041"; title: "Город"; detail: "Название в виджете погоды"
                    value: Config.Preferences.weatherCity; placeholder: "Например, Berlin"
                    pattern: /^[^:\x00-\x1f\x7f]{0,80}$/
                    onCommitted: value => Config.Preferences.updateWeatherCity(value)
                }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf124"; title: "Широта"; detail: "От -90 до 90"
                    value: Config.Preferences.weatherLatitude; placeholder: "52.5200"
                    pattern: /^$|^-?(?:[0-8]?\d(?:\.\d+)?|90(?:\.0+)?)$/
                    onCommitted: value => Config.Preferences.updateWeatherLatitude(value)
                }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf124"; title: "Долгота"; detail: "От -180 до 180"
                    value: Config.Preferences.weatherLongitude; placeholder: "13.4050"
                    pattern: /^$|^-?(?:(?:[0-9]?\d|1[0-7]\d)(?:\.\d+)?|180(?:\.0+)?)$/
                    onCommitted: value => Config.Preferences.updateWeatherLongitude(value)
                }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf017"; title: "Timezone"; detail: "IANA-зона или auto"
                    value: Config.Preferences.weatherTimezone; placeholder: "Europe/Berlin"
                    pattern: /^(?:auto|[A-Za-z_+-]+(?:\/[A-Za-z0-9_+.-]+)*)$/
                    onCommitted: value => Config.Preferences.updateWeatherTimezone(value)
                }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf555"; title: "Tron"; detail: "Публичный адрес, только чтение"
                    value: Config.Preferences.tronAddress; placeholder: "T..."
                    pattern: /^$|^T[1-9A-HJ-NP-Za-km-z]{33}$/
                    onCommitted: value => Config.Preferences.updateTronAddress(value)
                }
                ConfigInputRow {
                    width: parent.width
                    icon: "\uf555"; title: "Hyperliquid"; detail: "Публичный EVM-адрес, только чтение"
                    value: Config.Preferences.hyperliquidAddress; placeholder: "0x..."
                    pattern: /^$|^0x[0-9a-fA-F]{40}$/
                    onCommitted: value => Config.Preferences.updateHyperliquidAddress(value)
                }
            }
        }
    }
}
