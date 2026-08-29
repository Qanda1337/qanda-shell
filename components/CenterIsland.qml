import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import "../config" as Config

Item {
    id: root

    required property var systemService
    required property var notificationService
    required property var launcherService
    required property var clipboardService
    required property var bindingsService
    required property var dockerService
    required property var timerService
    required property var calendarService
    required property var mediaService
    required property var weatherService
    required property var audioService
    required property var powerService
    required property var performanceService
    required property var walletService
    required property var wallpaperService
    property bool immersiveMode: false

    property var retainedNotification: null
    readonly property var notification: notificationService.currentNotification || retainedNotification
    readonly property bool launcherOpen: launcherService.isOpen
    readonly property bool calendarOpen: calendarService.isOpen
    readonly property bool notificationCenterOpen: notificationService.isOpen && !launcherOpen && !calendarOpen
    readonly property bool timerPanelOpen: timerService.isOpen && !notificationCenterOpen && !launcherOpen && !calendarOpen
    readonly property bool clipboardPanelOpen: clipboardService.isOpen && !launcherOpen && !calendarOpen
    readonly property bool bindingsPanelOpen: bindingsService.isOpen && !clipboardPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool dockerPanelOpen: dockerService.isOpen && !clipboardPanelOpen && !bindingsPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool powerPanelOpen: powerService.isOpen && !notificationCenterOpen && !timerPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool wallpaperPanelOpen: wallpaperService.isOpen && !powerPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool performancePanelOpen: performanceService.isOpen && !powerPanelOpen && !wallpaperPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool walletPanelOpen: walletService.isOpen && !powerPanelOpen && !wallpaperPanelOpen && !performancePanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool audioPanelOpen: audioService.isOpen && !powerPanelOpen && !wallpaperPanelOpen && !performancePanelOpen && !walletPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool mediaPanelOpen: mediaService.isOpen && !weatherService.isOpen && !powerPanelOpen && !wallpaperPanelOpen && !performancePanelOpen && !walletPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !audioPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool weatherPanelOpen: weatherService.isOpen && !mediaService.isOpen && !powerPanelOpen && !wallpaperPanelOpen && !performancePanelOpen && !walletPanelOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !audioPanelOpen && !mediaPanelOpen && !launcherOpen && !calendarOpen
    readonly property bool notificationExpanded: notificationService.currentNotification !== null && !notificationCenterOpen && !timerPanelOpen && !launcherOpen && !calendarOpen && !clipboardPanelOpen && !bindingsPanelOpen && !dockerPanelOpen && !powerPanelOpen && !wallpaperPanelOpen && !performancePanelOpen && !walletPanelOpen && !audioPanelOpen && !mediaPanelOpen && !weatherPanelOpen
    readonly property bool hoverExpanded: false
    readonly property bool calendarPreviewOpen: false
    property int visualizerPhase: 0
    readonly property bool yandexPlaying: mediaService.current !== null && mediaService.playback === "playing"
    readonly property bool mprisPlaying: currentPlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool musicPlaying: yandexPlaying || mprisPlaying
    readonly property bool hasMedia: mediaService.current !== null || currentPlayer !== null
    readonly property int barHeight: Config.Theme.barHeight
    readonly property bool surfaceActive: launcherOpen || calendarOpen || notificationCenterOpen
        || timerPanelOpen || clipboardPanelOpen || bindingsPanelOpen || dockerPanelOpen
        || powerPanelOpen || wallpaperPanelOpen || performancePanelOpen || walletPanelOpen
        || audioPanelOpen || mediaPanelOpen || weatherPanelOpen || notificationExpanded
    readonly property int compactWidth: timerService.active ? 250 : 214
    readonly property real outerEar: 14

    Connections {
        target: root.notificationService
        function onCurrentNotificationChanged() {
            if (root.notificationService.currentNotification) {
                notificationReleaseTimer.stop();
                const notification = root.notificationService.currentNotification;
                root.retainedNotification = {
                    appName: notification.appName || "",
                    appIcon: notification.appIcon || "",
                    summary: notification.summary || "",
                    body: notification.body || "",
                    image: notification.image || "",
                    urgency: notification.urgency,
                    actions: []
                };
            } else if (root.retainedNotification) {
                notificationReleaseTimer.restart();
            }
        }
    }

    Timer {
        id: notificationReleaseTimer
        interval: Config.Theme.motionNormal
        onTriggered: root.retainedNotification = null
    }

    implicitWidth: {
        if (calendarOpen) return 760;
        if (launcherOpen || notificationCenterOpen || clipboardPanelOpen || bindingsPanelOpen || dockerPanelOpen) return 680;
        if (timerPanelOpen) return 500;
        if (powerPanelOpen) return 500;
        if (wallpaperPanelOpen) return 780;
        if (performancePanelOpen) return 560;
        if (walletPanelOpen) return 600;
        if (audioPanelOpen) return 520;
        if (mediaPanelOpen) return mediaService.mode === "yandex" ? 760 : 460;
        if (weatherPanelOpen) return 540;
        if (notificationExpanded) return 500;
        return hoverExpanded ? Config.Theme.islandWidth : root.compactWidth;
    }
    implicitHeight: {
        if (calendarOpen) return 470;
        if (launcherOpen) return 430;
        if (notificationCenterOpen) return notificationPanel.preferredHeight;
        if (timerPanelOpen) return timerPanel.preferredHeight;
        if (clipboardPanelOpen) return clipboardPanel.preferredHeight;
        if (bindingsPanelOpen) return bindingsPanel.preferredHeight;
        if (dockerPanelOpen) return dockerPanel.preferredHeight;
        if (powerPanelOpen) return powerPanel.preferredHeight;
        if (wallpaperPanelOpen) return wallpaperPanel.preferredHeight;
        if (performancePanelOpen) return performancePanel.preferredHeight;
        if (walletPanelOpen) return walletPanel.preferredHeight;
        if (audioPanelOpen) return audioPanel.preferredHeight;
        if (mediaPanelOpen) return mediaService.mode === "yandex" ? yandexMediaPanel.preferredHeight : 174;
        if (weatherPanelOpen) return 246;
        if (notificationExpanded) return 154 - Config.Theme.barHeight + root.barHeight;
        if (calendarPreviewOpen) return 344;
        if (root.immersiveMode) return 34;
        return root.barHeight;
    }
    width: implicitWidth
    height: implicitHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.Theme.motionNormal
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Config.Theme.motionNormal
            easing.type: Easing.InOutCubic
        }
    }

    readonly property var currentPlayer: {
        const players = Mpris.players?.values ?? [];
        let fallback = null;
        for (let i = 0; i < players.length; ++i) {
            if (players[i]?.playbackState === MprisPlaybackState.Playing)
                return players[i];
            if (!fallback && players[i])
                fallback = players[i];
        }
        return fallback;
    }

    property date now: new Date()

    function weekday(date) {
        return ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"][date.getDay()];
    }

    function fullDate(date) {
        const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
        return date.getDate() + " " + months[date.getMonth()] + " " + date.getFullYear();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 150
        running: root.musicPlaying
        repeat: true
        onTriggered: root.visualizerPhase = (root.visualizerPhase + 1) % 8
    }

    MultiEffect {
        readonly property var target: islandBackground

        visible: Config.Preferences.effectsEnabled
        x: target.x
        y: target.y
        width: target.width
        height: target.height
        source: target
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: root.surfaceActive ? 0.58 : 0
        shadowBlur: root.surfaceActive ? 0.72 : 0
        blurMax: 36
        shadowVerticalOffset: root.surfaceActive ? 8 : 0

        Behavior on shadowOpacity { NumberAnimation { duration: Config.Theme.motionNormal } }
        Behavior on shadowVerticalOffset { NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart } }
    }

    Shape {
        id: islandBackground

        readonly property real ear: root.outerEar
        readonly property real bottomRadius: Math.min(height / 2,
            (root.launcherOpen || root.calendarOpen) ? 32
            : ((root.notificationExpanded || root.notificationCenterOpen || root.timerPanelOpen
                || root.calendarPreviewOpen || root.clipboardPanelOpen || root.bindingsPanelOpen
                || root.dockerPanelOpen || root.powerPanelOpen || root.wallpaperPanelOpen
                || root.performancePanelOpen || root.walletPanelOpen || root.audioPanelOpen
                || root.mediaPanelOpen || root.weatherPanelOpen) ? 28
                : (root.hoverExpanded ? 22 : 20)))
        readonly property string outlinePath: ear > 0
            ? `M 0 0 Q ${ear} 0 ${ear} ${ear}`
                + ` L ${ear} ${height - bottomRadius}`
                + ` Q ${ear} ${height} ${ear + bottomRadius} ${height}`
                + ` L ${width - ear - bottomRadius} ${height}`
                + ` Q ${width - ear} ${height} ${width - ear} ${height - bottomRadius}`
                + ` L ${width - ear} ${ear}`
                + ` Q ${width - ear} 0 ${width} 0 Z`
            : `M 0 0 L ${width} 0 L ${width} ${height - bottomRadius}`
                + ` Q ${width} ${height} ${width - bottomRadius} ${height}`
                + ` L ${bottomRadius} ${height}`
                + ` Q 0 ${height} 0 ${height - bottomRadius} Z`

        x: -ear
        y: 0
        width: parent.width + ear * 2
        height: parent.height - 2
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Config.Theme.island

            PathSvg {
                path: islandBackground.outlinePath
            }
        }

        ShapePath {
            strokeWidth: 1
            strokeColor: Config.Theme.surfaceEdge
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.FlatCap

            PathSvg {
                path: islandBackground.outlinePath
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.launcherOpen || root.calendarOpen || root.notificationCenterOpen
            || root.timerPanelOpen || root.clipboardPanelOpen || root.bindingsPanelOpen
            || root.dockerPanelOpen || root.powerPanelOpen || root.wallpaperPanelOpen
            || root.performancePanelOpen || root.walletPanelOpen || root.audioPanelOpen
            || root.mediaPanelOpen || root.weatherPanelOpen
    }

    Item {
        id: notificationHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.barHeight
        visible: opacity > 0
        opacity: root.notificationExpanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 166
            spacing: 8

            Rectangle {
                width: 26
                height: 26
                radius: 9
                color: Config.Theme.islandRaised

                Text {
                    anchors.centerIn: parent
                    text: timerService.active ? "\uf017" : (root.hasMedia ? "\uf001" : "\uf073")
                    color: Config.Theme.accent
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 132
                spacing: 0

                Text {
                    width: parent.width
                    text: timerService.active ? timerService.displayText
                        : (mediaService.current ? mediaService.current.title
                        : (root.currentPlayer ? (root.currentPlayer.trackTitle || "Сейчас играет")
                        : root.weekday(root.now)))
                    color: Config.Theme.text
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: timerService.active ? (timerService.state === "paused" ? "Пауза" : "Таймер")
                        : (mediaService.current ? mediaService.current.artist
                        : (root.currentPlayer ? (root.currentPlayer.trackArtist || root.currentPlayer.identity || "Медиаплеер")
                        : root.fullDate(root.now)))
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(root.now, "HH:mm:ss")
            color: Config.Theme.text
            font.family: Config.Theme.monoFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            spacing: 0

            Text {
                anchors.right: parent.right
                text: systemService.weatherText
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                width: parent.width
                text: String(systemService.weatherCondition || "погода").toLowerCase()
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: compactRow
        x: 0
        width: parent.width
        anchors.top: parent.top
        height: root.barHeight
        visible: !root.notificationExpanded && !root.launcherOpen && !root.calendarOpen
            && !root.notificationCenterOpen && !root.timerPanelOpen && !root.clipboardPanelOpen
            && !root.bindingsPanelOpen && !root.dockerPanelOpen && !root.powerPanelOpen
            && !root.wallpaperPanelOpen && !root.performancePanelOpen && !root.walletPanelOpen
            && !root.audioPanelOpen && !root.mediaPanelOpen && !root.weatherPanelOpen
        opacity: (root.notificationExpanded || root.launcherOpen || root.calendarOpen
            || root.notificationCenterOpen || root.timerPanelOpen || root.clipboardPanelOpen
            || root.bindingsPanelOpen || root.dockerPanelOpen || root.powerPanelOpen
            || root.wallpaperPanelOpen || root.performancePanelOpen || root.walletPanelOpen
            || root.audioPanelOpen || root.mediaPanelOpen || root.weatherPanelOpen) ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }

        Item {
            id: leftContent
            anchors.left: parent.left
            anchors.leftMargin: root.hoverExpanded ? 14 : 12
            width: root.hoverExpanded ? 128 : (timerService.active ? 82 : 48)
            height: parent.height

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Behavior on width {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Item {
                anchors.fill: parent
                visible: !root.hoverExpanded
                opacity: root.hoverExpanded ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: root.musicPlaying && !timerService.active

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 4 + ((root.visualizerPhase + index * 3) % 5) * 2
                            radius: 1.5
                            color: index === 1 ? Config.Theme.text : Config.Theme.accent
                            opacity: 0.72 + index * 0.07

                            Behavior on height {
                                NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.musicPlaying && !timerService.active
                    text: String(root.now.getDate()).padStart(2, "0") + "."
                        + String(root.now.getMonth() + 1).padStart(2, "0")
                    color: Config.Theme.text
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.centerIn: parent
                    visible: timerService.active
                    text: timerService.displayText
                    color: timerService.state === "paused" ? Config.Theme.textMuted : Config.Theme.accent
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 7
                visible: root.hoverExpanded
                opacity: root.hoverExpanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 8
                    color: (timerService.active || root.hasMedia) ? Config.Theme.islandRaised : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: timerService.active ? "\uf017" : (root.hasMedia ? "\uf001" : "\uf073")
                        color: Config.Theme.accent
                        font.family: Config.Theme.monoFont
                        font.pixelSize: 13
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: timerService.active ? timerService.displayText
                            : (mediaService.current ? mediaService.current.title : (currentPlayer ? (currentPlayer.trackTitle || "Сейчас играет") : root.weekday(root.now)))
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: timerService.active ? (timerService.state === "paused" ? "Пауза" : "Идёт")
                            : (mediaService.current ? mediaService.current.artist : (currentPlayer ? (currentPlayer.trackArtist || currentPlayer.identity || "Медиаплеер") : root.fullDate(root.now)))
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: timerService.active || root.hasMedia
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (timerService.active)
                        timerService.open();
                    else if (mediaService.current)
                        mediaService.runAction(["play_pause"]);
                    else
                        currentPlayer?.togglePlaying();
                }
            }
        }

        Item {
            id: clockTarget
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.hoverExpanded ? 112 : 92
            height: parent.height

            Behavior on width {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatTime(root.now, "HH:mm:ss")
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.right: clockText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: clockText.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                visible: systemService.screenRecording
                color: Config.Theme.danger
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    launcherService.close();
                    calendarService.toggle();
                }
            }
        }

        Item {
            id: weatherTarget
            anchors.right: parent.right
            anchors.rightMargin: root.hoverExpanded ? 15 : 12
            width: root.hoverExpanded ? 76 : 36
            height: parent.height


            Behavior on anchors.rightMargin {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Behavior on width {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Text {
                anchors.centerIn: parent
                text: systemService.weatherText
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                visible: !root.hoverExpanded
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: -1
                visible: root.hoverExpanded
                opacity: visible ? 1 : 0

                Text {
                    anchors.right: parent.right
                    text: systemService.weatherText
                    color: Config.Theme.text
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.right: parent.right
                    width: 76
                    text: String(systemService.weatherCondition || "погода").toLowerCase()
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Behavior on opacity {
                    NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: weatherService.toggle()
            }
        }
    }

    MediaPanel {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.mediaPanelOpen && mediaService.mode === "generic" ? 1 : 0
        player: root.currentPlayer
        mediaService: root.mediaService
        onCloseRequested: mediaService.close()

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    YandexMediaPanel {
        id: yandexMediaPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.mediaPanelOpen && mediaService.mode === "yandex" ? 1 : 0
        panelOpen: root.mediaPanelOpen && mediaService.mode === "yandex"
        mediaService: root.mediaService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    AudioPanel {
        id: audioPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.audioPanelOpen ? 1 : 0
        audioService: root.audioService
        onCloseRequested: root.audioService.close()

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    PowerPanel {
        id: powerPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.powerPanelOpen ? 1 : 0
        powerService: root.powerService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    PerformancePanel {
        id: performancePanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.performancePanelOpen ? 1 : 0
        performanceService: root.performanceService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    WalletOverviewPanel {
        id: walletPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.walletPanelOpen ? 1 : 0
        walletService: root.walletService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    WallpaperPanel {
        id: wallpaperPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.wallpaperPanelOpen ? 1 : 0
        wallpaperService: root.wallpaperService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    WeatherPanel {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.weatherPanelOpen ? 1 : 0
        systemService: root.systemService
        weatherService: root.weatherService
        onCloseRequested: weatherService.close()

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    IslandCalendarPreview {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: compactRow.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 14
        visible: opacity > 0
        opacity: root.calendarPreviewOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    Item {
        id: notificationArea

        x: 18
        y: root.barHeight
        width: parent.width - 36
        height: Math.max(0, parent.height - root.barHeight - 10)
        visible: opacity > 0 && !root.launcherOpen
        opacity: root.notificationExpanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.InOutCubic }
        }

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.28)
        }

        Rectangle {
            id: notificationIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 13
            color: Config.Theme.islandRaised
            clip: true

            Text {
                anchors.centerIn: parent
                text: root.notification?.urgency === NotificationUrgency.Critical ? "\uf071" : "\uf0f3"
                color: root.notification?.urgency === NotificationUrgency.Critical ? Config.Theme.danger : Config.Theme.accent
                font.family: Config.Theme.monoFont
                font.pixelSize: 15
            }

            Image {
                anchors.fill: parent
                source: {
                    if (!root.notification)
                        return "";
                    if (root.notification.image)
                        return root.notification.image;
                    if (root.notification.appIcon)
                        return "image://icon/" + root.notification.appIcon;
                    return "";
                }
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
        }

        Column {
            anchors.left: notificationIcon.right
            anchors.leftMargin: 12
            anchors.right: closeButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.notification?.summary || root.notification?.appName || "Уведомление"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.notification?.body || root.notification?.appName || ""
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }

        Text {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: (root.barHeight - height) / 2
            width: 25
            height: 25
            text: "×"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationService.closeCurrent(true)
            }
        }

        MouseArea {
            anchors.left: notificationIcon.left
            anchors.right: closeButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            cursorShape: root.notification?.actions?.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.notification?.actions?.length > 0) {
                    root.notification.actions[0].invoke();
                    notificationService.closeCurrent(true);
                }
            }
        }
    }

    SpotlightLauncher {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 18
        anchors.bottomMargin: 14
        visible: root.launcherOpen
        opacity: root.launcherOpen ? 1 : 0
        launcherService: root.launcherService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    ClipboardPanel {
        id: clipboardPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.clipboardPanelOpen ? 1 : 0
        clipboardService: root.clipboardService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    BindingsPanel {
        id: bindingsPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.bindingsPanelOpen ? 1 : 0
        bindingsService: root.bindingsService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    DockerPanel {
        id: dockerPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.dockerPanelOpen ? 1 : 0
        dockerService: root.dockerService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    NotificationPanel {
        id: notificationPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.notificationCenterOpen ? 1 : 0
        notificationService: root.notificationService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    TimerPanel {
        id: timerPanel
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.timerPanelOpen ? 1 : 0
        timerService: root.timerService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

    IslandCalendar {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.topMargin: 18
        anchors.bottomMargin: 14
        visible: root.calendarOpen
        opacity: root.calendarOpen ? 1 : 0
        calendarService: root.calendarService

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
        }
    }

}
