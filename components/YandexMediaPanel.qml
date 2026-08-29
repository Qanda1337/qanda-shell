import QtQuick
import Quickshell
import "../config" as Config

FocusScope {
    id: root

    required property var mediaService
    property bool panelOpen: false
    property bool contentReady: false
    readonly property int preferredHeight: 470
    property string openWaveSetting: ""
    property string contentMode: "queue"

    function formatTime(value) {
        const seconds = Math.max(0, Math.floor(Number(value || 0)));
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }

    component PlayerButton: Rectangle {
        id: button

        property string icon: ""
        property bool primary: false
        property bool active: false
        property bool available: true
        signal triggered()

        width: primary ? 46 : 34
        height: width
        radius: width / 2
        color: primary
            ? (buttonMouse.containsMouse ? Config.Theme.accent : Config.Theme.text)
            : (active
                ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                : (buttonMouse.containsMouse ? Config.Theme.surfaceHover : "transparent"))
        opacity: available ? 1 : 0.3
        scale: buttonMouse.pressed ? 0.94 : 1

        Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }
        Behavior on scale { NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: button.icon === "\uf04b" ? 1 : 0
            text: button.icon
            color: button.primary ? Config.Theme.island : (button.active ? Config.Theme.accent : Config.Theme.textMuted)
            font.family: Config.Theme.monoFont
            font.pixelSize: button.primary ? 15 : 13
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.triggered()
        }
    }

    function focusContent() {
        if (!visible || !panelOpen)
            return;
        Qt.callLater(() => {
            if (contentMode === "search") searchInput.forceActiveFocus();
            else root.forceActiveFocus();
        });
    }

    function showContent(mode) {
        contentMode = mode;
        openWaveSetting = "";
        if (mode !== "search" && mediaService.query !== "")
            mediaService.setQuery("");
        focusContent();
    }

    function applyWaveSetting(key, value) {
        mediaService.setWaveSettings(
            key === "moodEnergy" ? value : mediaService.waveSettings.moodEnergy,
            key === "diversity" ? value : mediaService.waveSettings.diversity,
            key === "language" ? value : mediaService.waveSettings.language
        );
        openWaveSetting = "";
    }

    onVisibleChanged: {
        if (!visible) {
            openWaveSetting = "";
            contentMode = "queue";
        }
        focusContent();
    }

    onPanelOpenChanged: {
        contentReadyTimer.stop();
        contentReady = false;
        if (panelOpen) {
            if (Config.Theme.motionFast > 0)
                contentReadyTimer.start();
            else
                contentReady = true;
        }
    }

    Timer {
        id: contentReadyTimer
        interval: Config.Theme.motionFast
        onTriggered: root.contentReady = root.panelOpen
    }

    Connections {
        target: mediaService
        function onIsOpenChanged() { root.focusContent(); }
        function onUpcomingChanged() { root.syncTrackModel(queueModel, mediaService.upcoming); }
        function onResultsChanged() { root.syncTrackModel(searchModel, mediaService.results); }
    }

    ListModel {
        id: queueModel
        dynamicRoles: true
    }

    ListModel {
        id: searchModel
        dynamicRoles: true
    }

    function trackKey(track) {
        if (!track) return "";
        return String(track.queueIndex ?? "") + ":" + String(track.id ?? "") + ":" + String(track.title ?? "");
    }

    function syncTrackModel(target, source) {
        const tracks = source || [];
        let keepsPrefix = target.count <= tracks.length;
        for (let i = 0; keepsPrefix && i < target.count; ++i)
            keepsPrefix = trackKey(target.get(i).track) === trackKey(tracks[i]);

        if (!keepsPrefix)
            target.clear();

        for (let i = 0; i < tracks.length; ++i) {
            if (i < target.count) target.setProperty(i, "track", tracks[i]);
            else target.append({ track: tracks[i] });
        }
        while (target.count > tracks.length)
            target.remove(target.count - 1);
    }

    Component.onCompleted: {
        syncTrackModel(queueModel, mediaService.upcoming);
        syncTrackModel(searchModel, mediaService.results);
    }

    Keys.onEscapePressed: mediaService.close()
    Keys.onUpPressed: if (contentMode === "queue") mediaService.moveSelection(-1)
    Keys.onDownPressed: if (contentMode === "queue") mediaService.moveSelection(1)
    Keys.onReturnPressed: if (contentMode === "queue") mediaService.activateSelected()
    Keys.onEnterPressed: if (contentMode === "queue") mediaService.activateSelected()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && mediaService.current !== null
                && contentMode !== "search" && !searchInput.activeFocus) {
            mediaService.runAction(["play_pause"]);
            event.accepted = true;
        }
    }

    Item {
        anchors.fill: parent
        visible: root.contentReady && !mediaService.authenticated

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf001"
                color: Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 28
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Подключить Яндекс Музыку"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mediaService.authError || "Требуется авторизация"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 130
                height: 38
                radius: 12
                color: loginMouse.containsMouse ? Config.Theme.text : Config.Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "Войти"
                    color: Config.Theme.island
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mediaService.close();
                        Quickshell.execDetached([
                            "kitty", "--detach", "--title", "Yandex Music Login",
                            Quickshell.env("HOME") + "/.local/share/qanda-ymusic/venv/bin/python",
                            Quickshell.env("HOME") + "/.local/bin/ymusic-auth"
                        ]);
                    }
                }
            }
        }

    }

    Item {
        anchors.fill: parent
        visible: root.contentReady && mediaService.authenticated

        Item {
            id: nowPlaying
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 14
            height: 146

            Rectangle {
                id: artworkFrame
                width: 146
                height: 146
                radius: 24
                color: Config.Theme.islandRaised
                border.width: 1
                border.color: Config.Theme.surfaceEdge
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: "\uf001"
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 28
                    visible: cover.status !== Image.Ready
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.contentReady ? (mediaService.current?.artUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }
            }

            Item {
                anchors.left: artworkFrame.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 7

                    Rectangle {
                        width: sourceLabel.width + 16
                        height: 23
                        radius: 11.5
                        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.13)

                        Text {
                            id: sourceLabel
                            anchors.centerIn: parent
                            text: mediaService.queueKind === "wave" ? "МОЯ ВОЛНА" : "ЯНДЕКС МУЗЫКА"
                            color: Config.Theme.accent
                            font.family: Config.Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.7
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: mediaService.playback === "playing" ? "сейчас играет" : "на паузе"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 11
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: reactionControls.left
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    spacing: 2

                    Text {
                        width: parent.width
                        text: mediaService.current?.title || "Ничего не играет"
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: mediaService.current
                            ? mediaService.current.artist + (mediaService.current.album ? " · " + mediaService.current.album : "")
                            : "Запустите Мою волну или найдите трек"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: reactionControls
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    spacing: 2

                    PlayerButton {
                        icon: "\uf165"
                        active: mediaService.current?.disliked ?? false
                        available: mediaService.current !== null
                        onTriggered: mediaService.runAction(["dislike"])
                    }
                    PlayerButton {
                        icon: mediaService.current?.liked ? "\uf004" : "\uf08a"
                        active: mediaService.current?.liked ?? false
                        available: mediaService.current !== null
                        onTriggered: mediaService.runAction(["like"])
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: progressArea.top
                    anchors.bottomMargin: 8
                    height: 46
                    spacing: 8

                    PlayerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "\uf048"
                        available: mediaService.current !== null
                        onTriggered: mediaService.runAction(["previous"])
                    }
                    PlayerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        primary: true
                        icon: mediaService.playback === "playing" ? "\uf04c" : "\uf04b"
                        available: mediaService.current !== null
                        onTriggered: mediaService.runAction(["play_pause"])
                    }
                    PlayerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "\uf051"
                        available: mediaService.current !== null
                        onTriggered: mediaService.runAction(["next"])
                    }
                }

                Item {
                    id: progressArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 18

                    Text {
                        id: elapsedTime
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(mediaService.position)
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 9
                    }

                    Rectangle {
                        anchors.left: elapsedTime.right
                        anchors.leftMargin: 9
                        anchors.right: totalTime.left
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        height: progressMouse.containsMouse ? 5 : 3
                        radius: height / 2
                        color: Config.Theme.track

                        Rectangle {
                            width: parent.width * Math.min(1, mediaService.position / Math.max(1, mediaService.duration))
                            height: parent.height
                            radius: parent.radius
                            color: Config.Theme.accent
                        }

                        MouseArea {
                            id: progressMouse
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            enabled: mediaService.current !== null && mediaService.duration > 0
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: mouse => mediaService.runAction(["seek", (mouse.x / width) * mediaService.duration])
                        }

                        Behavior on height { NumberAnimation { duration: Config.Theme.motionFast } }
                    }

                    Text {
                        id: totalTime
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(mediaService.duration)
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 9
                    }
                }
            }
        }

        Item {
            id: contentToolbar
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 176
            height: 42

            Item {
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.contentMode === "queue" ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Config.Theme.motionFast } }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ДАЛЕЕ В МОЕЙ ВОЛНЕ"
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Rectangle {
                        width: waveButtonLabel.width + 30
                        height: 34
                        radius: 12
                        color: waveMouse.containsMouse ? Config.Theme.text : Config.Theme.accent
                        opacity: mediaService.waveRequestPending ? 0.55 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: "\uf001"
                                color: Config.Theme.island
                                font.family: Config.Theme.monoFont
                                font.pixelSize: 10
                            }
                            Text {
                                id: waveButtonLabel
                                text: mediaService.waveRequestPending ? "Обновляем…" : "Обновить волну"
                                color: Config.Theme.island
                                font.family: Config.Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: waveMouse
                            anchors.fill: parent
                            enabled: !mediaService.waveRequestPending
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: mediaService.runAction(["play_wave"])
                        }
                    }

                    PlayerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "\uf1de"
                        onTriggered: root.showContent("settings")
                    }

                    PlayerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "\uf002"
                        onTriggered: root.showContent("search")
                    }
                }
            }

            Row {
                anchors.fill: parent
                spacing: 8
                visible: opacity > 0
                opacity: root.contentMode === "search" ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Config.Theme.motionFast } }

                PlayerButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf060"
                    onTriggered: root.showContent("queue")
                }

                Rectangle {
                    width: parent.width - 42
                    height: parent.height
                    radius: 14
                    color: searchInput.activeFocus ? Config.Theme.surfaceActive : Config.Theme.islandRaised

                    Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf002"
                        color: searchInput.activeFocus ? Config.Theme.accent : Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 12
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 39
                        anchors.rightMargin: 13
                        verticalAlignment: TextInput.AlignVCenter
                        color: Config.Theme.text
                        selectionColor: Config.Theme.accent
                        selectedTextColor: Config.Theme.island
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        text: mediaService.query
                        onTextEdited: mediaService.setQuery(text)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) mediaService.close();
                            else if (event.key === Qt.Key_Down) mediaService.moveSelection(1);
                            else if (event.key === Qt.Key_Up) mediaService.moveSelection(-1);
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) mediaService.activateSelected();
                            else return;
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 39
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Найти трек, артиста или альбом"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                    }
                }
            }

            Row {
                anchors.fill: parent
                spacing: 10
                visible: opacity > 0
                opacity: root.contentMode === "settings" ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Config.Theme.motionFast } }

                PlayerButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\uf060"
                    onTriggered: root.showContent("queue")
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: "Настроить Мою волну"
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Музыка изменится сразу после выбора"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 10
                    }
                }
            }
        }

        Row {
            id: waveSettings
            z: 20
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 228
            height: 32
            spacing: 7
            visible: opacity > 0
            opacity: root.contentMode === "settings" ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Config.Theme.motionFast } }

            Repeater {
                model: [
                    {
                        key: "moodEnergy",
                        values: ["all", "fun", "active", "calm", "sad"],
                        labels: { all: "Любое настроение", fun: "Весёлое", active: "Бодрое", calm: "Спокойное", sad: "Грустное" }
                    },
                    {
                        key: "diversity",
                        values: ["default", "favorite", "discover", "popular"],
                        labels: { default: "Всё подряд", favorite: "Любимое", discover: "Незнакомое", popular: "Популярное" }
                    },
                    {
                        key: "language",
                        values: ["any", "russian", "not-russian"],
                        labels: { any: "Любой язык", russian: "Русский", "not-russian": "Иностранный" }
                    }
                ]

                Rectangle {
                    id: settingButton
                    required property var modelData
                    readonly property var setting: modelData
                    width: (waveSettings.width - waveSettings.spacing * 2) / 3
                    height: waveSettings.height
                    radius: 11
                    color: root.openWaveSetting === setting.key || settingMouse.containsMouse
                        ? Config.Theme.surfaceActive : Config.Theme.islandRaised
                    border.width: root.openWaveSetting === setting.key ? 1 : 0
                    border.color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.28)

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        text: settingButton.setting.labels[mediaService.waveSettings[settingButton.setting.key]] || "По умолчанию"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 11
                        font.weight: root.openWaveSetting === settingButton.setting.key ? Font.DemiBold : Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: settingMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWaveSetting = root.openWaveSetting === settingButton.setting.key
                            ? "" : settingButton.setting.key
                    }

                    Rectangle {
                        id: settingMenu
                        z: 30
                        anchors.top: parent.bottom
                        anchors.topMargin: 5
                        width: parent.width
                        height: settingButton.setting.values.length * 31 + 8
                        radius: 11
                        visible: root.openWaveSetting === settingButton.setting.key
                        color: Config.Theme.islandRaised
                        border.width: 1
                        border.color: Config.Theme.surfaceEdge

                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 1

                            Repeater {
                                model: settingButton.setting.values

                                Rectangle {
                                    required property string modelData
                                    readonly property bool selected: mediaService.waveSettings[settingButton.setting.key] === modelData
                                    width: settingMenu.width - 8
                                    height: 30
                                    radius: 8
                                    color: selected
                                        ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                                        : (optionMouse.containsMouse ? Config.Theme.surfaceHover : "transparent")

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: optionCheck.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: settingButton.setting.labels[parent.modelData]
                                        color: parent.selected ? Config.Theme.accent : Config.Theme.text
                                        font.family: Config.Theme.uiFont
                                        font.pixelSize: 12
                                        font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: optionCheck
                                        anchors.right: parent.right
                                        anchors.rightMargin: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.selected ? "✓" : ""
                                        color: Config.Theme.accent
                                        font.family: Config.Theme.uiFont
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: optionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyWaveSetting(settingButton.setting.key, parent.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: resultList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 226
            anchors.bottomMargin: 12
            visible: opacity > 0
            opacity: root.contentMode === "settings" ? 0 : 1
            readonly property bool showingSearch: root.contentMode === "search"
            model: root.contentReady ? (showingSearch ? searchModel : queueModel) : null
            spacing: 3
            clip: true
            currentIndex: mediaService.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            Behavior on opacity { NumberAnimation { duration: Config.Theme.motionFast } }
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            function maybeLoadMore() {
                if (!showingSearch && atYEnd && !mediaService.loadingMore && count > 0)
                    mediaService.loadMore();
            }

            onMovementEnded: maybeLoadMore()

            delegate: Rectangle {
                required property var track
                required property int index
                width: resultList.width
                height: 52
                radius: 13
                color: index === mediaService.selectedIndex || resultMouse.containsMouse
                    ? Config.Theme.islandRaised : "transparent"

                Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: index === mediaService.selectedIndex ? 22 : 0
                    radius: 1.5
                    color: Config.Theme.accent

                    Behavior on height { NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: resultArtwork
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 9
                    color: Config.Theme.track
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: resultCover.status !== Image.Ready
                        text: "\uf001"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                    }

                    Image {
                        id: resultCover
                        anchors.fill: parent
                        source: root.contentReady ? (track.artUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }

                Column {
                    anchors.left: resultArtwork.right
                    anchors.leftMargin: 12
                    anchors.right: resultMeta.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: track.title
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: track.artist + (track.album ? " · " + track.album : "")
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: resultMeta
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        text: root.formatTime(track.duration)
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 24
                        height: 22
                        radius: 8
                        visible: (!resultList.showingSearch && index === 0) || track.liked
                        color: !resultList.showingSearch && index === 0
                            ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.16)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: !resultList.showingSearch && index === 0 ? "\uf051" : "\uf004"
                            color: Config.Theme.accent
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 10
                        }
                    }
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (resultList.showingSearch) {
                            mediaService.selectedIndex = index;
                            mediaService.activateSelected();
                        } else {
                            mediaService.selectedIndex = index;
                            mediaService.runAction(["play_queue_index", track.queueIndex]);
                        }
                    }
                }
            }

            header: Item {
                width: resultList.width
                height: !resultList.showingSearch && mediaService.upcoming.length > 0 ? 24 : 0
                visible: !resultList.showingSearch && mediaService.upcoming.length > 0

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: mediaService.queueLength + " треков"
                    color: Config.Theme.textMuted
                    opacity: 0.7
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 11
                }
            }

            footer: Item {
                width: resultList.width
                height: !resultList.showingSearch && mediaService.loadingMore ? 110 : 0
                visible: !resultList.showingSearch && mediaService.loadingMore

                Column {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: 2

                        Rectangle {
                            width: resultList.width
                            height: 52
                            radius: 13
                            color: Config.Theme.islandRaised
                            opacity: 0.65

                            SequentialAnimation on opacity {
                                running: mediaService.loadingMore && Config.Preferences.animationsEnabled
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 0.48
                                    to: 0.82
                                    duration: Math.round(620 / Config.Preferences.animationSpeed)
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 0.82
                                    to: 0.48
                                    duration: Math.round(620 / Config.Preferences.animationSpeed)
                                    easing.type: Easing.InOutSine
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38
                                height: 38
                                radius: 9
                                color: Config.Theme.surfaceActive
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 61
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7

                                Rectangle {
                                    width: 176
                                    height: 8
                                    radius: 4
                                    color: Config.Theme.surfaceActive
                                }
                                Rectangle {
                                    width: 118
                                    height: 7
                                    radius: 3.5
                                    color: Config.Theme.track
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 7
                                radius: 3.5
                                color: Config.Theme.surfaceActive
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: resultList.count === 0
                text: mediaService.searching ? "Ищем…"
                    : (mediaService.error || (resultList.showingSearch
                        ? (mediaService.query.trim() === "" ? "Начните вводить название трека или исполнителя" : "Ничего не найдено")
                        : "Запустите Мою волну, чтобы увидеть очередь"))
                color: mediaService.error ? Config.Theme.danger : Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }
    }
}
