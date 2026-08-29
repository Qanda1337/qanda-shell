import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    required property var notificationService
    required property var audioService

    property bool isOpen: false
    property string mode: "yandex"
    property bool authenticated: false
    property string authError: ""
    property string error: ""
    property string query: ""
    property var results: []
    property int selectedIndex: 0
    property bool searching: false
    property var current: null
    property string playback: "stopped"
    property real position: 0
    property real duration: 0
    property int queueLength: 0
    property var upcoming: []
    property string queueKind: ""
    property bool waveRefreshing: false
    property bool waveRequestPending: false
    property bool loadingMore: false
    property var waveSettings: ({ moodEnergy: "all", diversity: "default", language: "any" })
    property int requestId: 0
    property var pendingRequests: ({})
    property bool statusInitialized: false
    property string lastPlayingTrackKey: ""
    property string currentSignature: "null"
    property string upcomingSignature: "[]"
    property string waveSettingsSignature: "[\"all\",\"default\",\"any\"]"
    property var interruptedPlayer: null
    property real volumeBeforeInterruption: 1
    property real interruptionVolume: 1
    property bool pausedForTelegram: false
    property string interruptionPhase: "idle"
    readonly property var yandexPlayer: {
        const players = Mpris.players?.values ?? [];
        for (let i = 0; i < players.length; ++i) {
            const player = players[i];
            if (String(player?.dbusName || "").startsWith("org.mpris.MediaPlayer2.qanda_ymusic"))
                return player;
        }
        return null;
    }
    readonly property var telegramPlayer: {
        const players = Mpris.players?.values ?? [];
        for (let i = 0; i < players.length; ++i) {
            const player = players[i];
            if (String(player?.dbusName || "").startsWith("org.mpris.MediaPlayer2.TelegramDesktop"))
                return player;
        }
        return null;
    }
    readonly property bool telegramPlaybackActive:
        telegramPlayer?.playbackState === MprisPlaybackState.Playing

    function clampVolume(value) {
        return Math.max(0, Math.min(1, Number(value)));
    }

    function startInterruptionFade(target, phase) {
        interruptionFade.stop();
        interruptionPhase = phase;
        interruptionFade.from = interruptionVolume;
        interruptionFade.to = clampVolume(target);
        if (interruptionFade.duration === 0
                || Math.abs(interruptionFade.from - interruptionFade.to) < 0.001) {
            interruptionVolume = interruptionFade.to;
            finishInterruptionFade();
        } else {
            interruptionFade.start();
        }
    }

    function beginTelegramInterruption() {
        if (!telegramPlaybackActive)
            return;
        if (interruptionPhase === "fadingIn") {
            startInterruptionFade(0, "fadingOut");
            return;
        }
        if (interruptionPhase !== "idle")
            return;

        const player = yandexPlayer;
        if (!player || player.playbackState !== MprisPlaybackState.Playing)
            return;
        interruptedPlayer = player;
        pausedForTelegram = false;
        volumeBeforeInterruption = clampVolume(audioService.yandexPlaybackVolume);
        interruptionVolume = volumeBeforeInterruption;
        if (audioService.yandexPlaybackStream)
            startInterruptionFade(0, "fadingOut");
        else {
            interruptionPhase = "fadingOut";
            finishInterruptionFade();
        }
    }

    function finishInterruptionFade() {
        const player = interruptedPlayer;
        if (interruptionPhase === "fadingOut") {
            if (!telegramPlaybackActive) {
                restoreAfterTelegram();
                return;
            }
            if (player?.playbackState === MprisPlaybackState.Playing && player.canPause) {
                pausedForTelegram = true;
                player.pause();
            }
            interruptionPhase = "ducked";
            return;
        }
        if (interruptionPhase === "fadingIn") {
            audioService.setYandexPlaybackVolume(volumeBeforeInterruption);
            interruptedPlayer = null;
            pausedForTelegram = false;
            interruptionPhase = "idle";
        }
    }

    function restoreAfterTelegram() {
        if (interruptionPhase === "idle")
            return;
        interruptionFade.stop();
        const player = interruptedPlayer;
        if (!player) {
            pausedForTelegram = false;
            interruptionPhase = "idle";
            return;
        }
        if (pausedForTelegram && player.canPlay)
            player.play();
        pausedForTelegram = false;
        if (audioService.yandexPlaybackStream)
            startInterruptionFade(volumeBeforeInterruption, "fadingIn");
        else {
            interruptedPlayer = null;
            interruptionPhase = "idle";
        }
    }

    onInterruptionVolumeChanged: {
        if (interruptedPlayer)
            audioService.setYandexPlaybackVolume(interruptionVolume);
    }

    onTelegramPlaybackActiveChanged: {
        if (telegramPlaybackActive)
            beginTelegramInterruption();
        else
            restoreAfterTelegram();
    }

    Component.onCompleted: if (telegramPlaybackActive)
        Qt.callLater(root.beginTelegramInterruption)

    Connections {
        target: root.yandexPlayer
        function onPlaybackStateChanged() {
            if (root.telegramPlaybackActive
                    && root.yandexPlayer?.playbackState === MprisPlaybackState.Playing)
                root.beginTelegramInterruption();
        }
    }

    NumberAnimation {
        id: interruptionFade
        target: root
        property: "interruptionVolume"
        duration: 500
        easing.type: Easing.InOutCubic
        onFinished: root.finishInterruptionFade()
    }

    function trackSignature(track) {
        if (!track)
            return "null";
        const queueIndex = track.queueIndex === undefined || track.queueIndex === null
            ? null : String(track.queueIndex);
        return JSON.stringify([
            String(track.id ?? ""),
            String(track.title ?? ""),
            String(track.artist ?? ""),
            String(track.album ?? ""),
            String(track.artUrl ?? ""),
            Number(track.duration || 0),
            track.liked === true,
            track.disliked === true,
            queueIndex
        ]);
    }

    function trackListSignature(tracks) {
        const signatures = [];
        for (let i = 0; i < tracks.length; ++i)
            signatures.push(trackSignature(tracks[i]));
        return JSON.stringify(signatures);
    }

    function settingsSignature(settings) {
        return JSON.stringify([
            String(settings.moodEnergy ?? "all"),
            String(settings.diversity ?? "default"),
            String(settings.language ?? "any")
        ]);
    }

    function trackKey(track) {
        if (!track)
            return "";
        return String(track.id || "") + ":" + String(track.title || "")
            + ":" + String(track.artist || "");
    }

    function announceUpcoming() {
        const track = upcoming[0];
        if (!track)
            return;
        const title = String(track.title || "Неизвестный трек");
        const artist = String(track.artist || "");
        notificationService.showSilentToast(
            "Следующий трек",
            artist === "" ? title : title + " — " + artist,
            String(track.artUrl || "")
        );
    }

    function open() {
        mode = "yandex";
        isOpen = true;
    }

    function openGeneric() {
        mode = "generic";
        isOpen = true;
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    function setQuery(value) {
        query = value;
        selectedIndex = 0;
        searchTimer.restart();
    }

    function moveSelection(offset) {
        const items = query.trim() === "" ? upcoming : results;
        if (items.length > 0)
            selectedIndex = (selectedIndex + offset + items.length) % items.length;
    }

    function activateSelected() {
        const isQueue = query.trim() === "";
        const track = (isQueue ? upcoming : results)[selectedIndex];
        if (track) {
            if (isQueue)
                runAction(["play_queue_index", track.queueIndex]);
            else
                runAction(["play_track", track.id]);
        }
    }

    function runAction(arguments) {
        if (!arguments || arguments.length === 0)
            return;
        const method = String(arguments[0]);
        const params = {};
        if (method === "play_track") params.id = String(arguments[1]);
        else if (method === "play_queue_index") params.index = Number(arguments[1]);
        else if (method === "seek") params.position = Number(arguments[1]);
        sendRequest(controlSocket, method, params);
    }

    function setWaveSettings(moodEnergy, diversity, language) {
        sendRequest(controlSocket, "set_wave_settings", {
            moodEnergy: moodEnergy,
            diversity: diversity,
            language: language
        });
    }

    function loadMore() {
        if (loadingMore || queueKind !== "wave") return;
        loadingMore = true;
        sendRequest(controlSocket, "load_more", {});
    }

    function sendRequest(socket, method, params) {
        if (!socket.connected) {
            error = "Backend Яндекс Музыки недоступен";
            if (method === "search")
                searching = false;
            return;
        }
        const id = ++requestId;
        pendingRequests[id] = { method: method, query: method === "search" ? String(params.query || "").trim() : "" };
        if (method === "play_wave" || method === "set_wave_settings") waveRequestPending = true;
        socket.write(JSON.stringify({ id: id, method: method, params: params || {} }) + "\n");
        socket.flush();
    }

    function refresh() {
        sendRequest(controlSocket, "status", {});
    }

    function handleResponse(line, source) {
        try {
            const response = JSON.parse(line);
            if (response.event === "status") {
                if (source !== "control")
                    return;
                if (response.ok)
                    applyStatus(response.result || {});
                else
                    error = response.error || "Не удалось обновить состояние";
                return;
            }
            const pending = pendingRequests[response.id] || { method: "", query: "" };
            const method = pending.method;
            delete pendingRequests[response.id];
            if (method === "play_wave" || method === "set_wave_settings") waveRequestPending = false;
            if (method === "load_more") loadingMore = false;
            if (!response.ok) {
                error = response.error || "Команда не выполнена";
                if (method === "search") {
                    results = [];
                    searching = false;
                }
                return;
            }
            if (method === "search") {
                if (pending.query !== query.trim()) return;
                results = response.result || [];
                searching = false;
                error = "";
            } else {
                applyStatus(response.result || {});
            }
        } catch (parseError) {
            error = "Некорректный ответ backend";
        }
    }

    function applyStatus(data) {
        const nextCurrent = data.current || null;
        const nextUpcoming = data.upcoming || [];
        const nextWaveSettings = data.waveSettings || waveSettings;
        const nextCurrentSignature = trackSignature(nextCurrent);
        const nextUpcomingSignature = trackListSignature(nextUpcoming);
        const nextWaveSettingsSignature = settingsSignature(nextWaveSettings);
        const nextPlayback = data.playback || "stopped";
        const nextTrackKey = trackKey(nextCurrent);
        authenticated = data.authenticated === true;
        authError = data.authError || "";
        error = data.error || "";
        if (nextCurrentSignature !== currentSignature) {
            current = nextCurrent;
            currentSignature = nextCurrentSignature;
        }
        playback = nextPlayback;
        position = Number(data.position || 0);
        duration = Number(data.duration || 0);
        queueLength = Number(data.queueLength || 0);
        if (nextUpcomingSignature !== upcomingSignature) {
            upcoming = nextUpcoming;
            upcomingSignature = nextUpcomingSignature;
        }
        queueKind = data.queueKind || "";
        waveRefreshing = data.waveRefreshing === true;
        if (nextWaveSettingsSignature !== waveSettingsSignature) {
            waveSettings = nextWaveSettings;
            waveSettingsSignature = nextWaveSettingsSignature;
        }
        if (statusInitialized && playback === "playing" && nextTrackKey !== ""
                && nextTrackKey !== lastPlayingTrackKey)
            announceUpcoming();
        if (playback === "playing" && nextTrackKey !== "")
            lastPlayingTrackKey = nextTrackKey;
        else if (playback === "stopped")
            lastPlayingTrackKey = "";
        statusInitialized = true;
        if (selectedIndex >= (query.trim() === "" ? upcoming.length : results.length))
            selectedIndex = 0;
    }

    Timer {
        interval: 250
        running: root.playback === "playing"
        repeat: true
        onTriggered: root.position = Math.min(root.duration, root.position + interval / 1000)
    }

    Timer {
        id: searchTimer
        interval: 220
        onTriggered: {
            if (root.query.trim() === "") {
                root.results = [];
                root.searching = false;
                return;
            }
            root.searching = true;
            root.sendRequest(searchSocket, "search", { query: root.query });
        }
    }

    Socket {
        id: controlSocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qanda-ymusic.sock"
        connected: true
        parser: SplitParser { onRead: data => root.handleResponse(data, "control") }
        onConnectedChanged: if (connected) root.refresh()
        onError: error => {
            connected = false;
            root.loadingMore = false;
            root.waveRequestPending = false;
            controlReconnect.restart();
        }
    }

    Socket {
        id: searchSocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qanda-ymusic.sock"
        connected: true
        parser: SplitParser { onRead: data => root.handleResponse(data, "search") }
        onConnectedChanged: {
            if (connected && root.query.trim() !== "")
                searchTimer.restart();
        }
        onError: error => {
            connected = false;
            root.searching = false;
            searchReconnect.restart();
        }
    }

    Timer {
        id: controlReconnect
        interval: 1500
        onTriggered: controlSocket.connected = true
    }

    Timer {
        id: searchReconnect
        interval: 1500
        onTriggered: searchSocket.connected = true
    }

    IpcHandler {
        target: "media"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function openGeneric(): void { root.openGeneric(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
    }
}
