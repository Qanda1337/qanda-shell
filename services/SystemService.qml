import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    property int cpuUsage: 0
    property int memoryUsage: 0
    property bool vpnConnected: false
    property string networkType: "disconnected"
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property string wifiName: ""
    property bool wifiUpdatePending: false
    property bool screenRecording: false
    property bool directCameraInUse: false
    property string powerProfile: "balanced"
    property bool powerProfilesAvailable: false
    property var availablePowerProfiles: []
    property bool vpnUpdatePending: false
    property bool powerProfileUpdatePending: false
    property bool themeModeUpdatePending: false
    property string keyboardLayout: "EN"
    property string weatherText: "--°"
    property string weatherDetails: "Погода загружается"
    property string weatherCondition: "Погода"
    property string weatherCity: "Не настроено"
    property string weatherIcon: "󰖐"
    property string weatherTemperature: "--°"
    property string weatherFeelsLike: "--°"
    property string weatherWind: "-- км/ч"
    property var weatherForecast: []
    property string themeMode: "dark"
    property bool backendConnected: false
    property bool backendProcessWanted: true
    property int nextBackendRequestId: 0
    property var performanceData: ({})

    readonly property string backendSocketPath: Quickshell.env("XDG_RUNTIME_DIR") !== ""
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/qanda-shell-system.sock"
        : "/tmp/qanda-shell-system-" + Quickshell.env("USER") + ".sock"

    signal backendCommandFinished(int requestId, bool succeeded, string error)

    function shortLayout(name) {
        const value = String(name || "").toLowerCase();
        if (value.includes("russian") || value === "ru")
            return "RU";
        if (value.includes("english") || value.includes("us"))
            return "EN";
        return value.length > 0 ? value.slice(0, 2).toUpperCase() : "EN";
    }

    function applyBackendSnapshot(message) {
        const data = message.system || {};
        cpuUsage = Math.round(Number(data.cpuUsage || 0));
        memoryUsage = Math.round(Number(data.memoryUsage || 0));
        if (!vpnUpdatePending)
            vpnConnected = Boolean(data.vpnConnected);
        networkType = String(data.networkType || "disconnected");
        wifiAvailable = Boolean(data.wifiAvailable);
        if (!wifiUpdatePending)
            wifiEnabled = Boolean(data.wifiEnabled);
        wifiName = String(data.wifiName || "");
        screenRecording = Boolean(data.screenRecording);
        directCameraInUse = Boolean(data.cameraInUse);
        powerProfilesAvailable = Boolean(data.powerProfilesAvailable);
        availablePowerProfiles = Array.isArray(data.availablePowerProfiles)
            ? data.availablePowerProfiles : [];
        if (!powerProfileUpdatePending)
            powerProfile = String(data.powerProfile || "balanced");
        if (!themeModeUpdatePending)
            themeMode = String(data.themeMode || "dark") === "light" ? "light" : "dark";
        const accent = String(data.accent || "");
        if (/^#[0-9a-fA-F]{6}$/.test(accent))
            Config.Theme.matugenAccent = accent;
        performanceData = message.performance || {};
    }

    function handleBackendMessage(line) {
        try {
            const message = JSON.parse(line);
            if (message.event === "snapshot") {
                applyBackendSnapshot(message);
                return;
            }
            if (message.id !== undefined)
                backendCommandFinished(Number(message.id), Boolean(message.ok), String(message.error || ""));
        } catch (error) {
            console.warn("System backend response could not be parsed:", error);
        }
    }

    function sendBackendCommand(method, params) {
        if (!backendSocket.connected)
            return -1;
        const requestId = ++nextBackendRequestId;
        backendSocket.write(JSON.stringify({
            id: requestId,
            method: method,
            params: params || {}
        }) + "\n");
        backendSocket.flush();
        return requestId;
    }

    function requestBackendRefresh() {
        return sendBackendCommand("refresh", {});
    }

    function refreshWeather() {
        if (!weatherProcess.running)
            weatherProcess.running = true;
    }

    Process {
        id: backendProcess
        command: [Quickshell.shellDir + "/scripts/system-backend"]
        running: root.backendProcessWanted

        onExited: {
            root.backendProcessWanted = false;
            if (!backendSocket.connected)
                backendRestartTimer.restart();
        }
    }

    Socket {
        id: backendSocket
        path: root.backendSocketPath
        connected: true
        parser: SplitParser {
            onRead: data => root.handleBackendMessage(data)
        }

        onConnectedChanged: {
            root.backendConnected = connected;
            if (connected)
                root.requestBackendRefresh();
            else
                backendReconnectTimer.restart();
        }
        onError: error => {
            connected = false;
            root.backendConnected = false;
            backendReconnectTimer.restart();
            if (!backendProcess.running)
                backendRestartTimer.restart();
        }
    }

    Timer {
        id: backendReconnectTimer
        interval: 1000
        onTriggered: backendSocket.connected = true
    }

    Timer {
        id: backendRestartTimer
        interval: 2000
        onTriggered: if (!backendSocket.connected) root.backendProcessWanted = true
    }

    Process {
        id: statsProcess
        command: [Quickshell.shellDir + "/scripts/system-stats"]
        stdout: StdioCollector {}
        onExited: {
            const values = stdout.text.trim().split(" ");
            if (values.length >= 2) {
                root.cpuUsage = Number(values[0]);
                root.memoryUsage = Number(values[1]);
            }
        }
    }

    Process {
        id: vpnProcess
        command: ["sh", "-c", "nmcli -t -f TYPE connection show --active | grep -Eq '^(vpn|wireguard)$'"]
        onExited: exitCode => {
            if (!root.vpnUpdatePending)
                root.vpnConnected = exitCode === 0;
        }
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "LC_ALL=C nmcli -t -f TYPE,STATE device status"]
        stdout: StdioCollector {}
        onExited: {
            let connectedType = "disconnected";
            const lines = stdout.text.trim().split("\n");
            for (let index = 0; index < lines.length; ++index) {
                const fields = lines[index].split(":");
                if (fields.length < 2 || !fields[1].startsWith("connected"))
                    continue;
                if (fields[0] === "wifi") {
                    connectedType = "wifi";
                    break;
                }
                if (fields[0] === "ethernet")
                    connectedType = "ethernet";
            }
            root.networkType = connectedType;
        }
    }

    Process {
        id: recordingProcess
        command: ["sh", "-c", "pgrep -u \"$UID\" -f '(^|/)gpu-screen-recorder( |$)' >/dev/null"]
        onExited: exitCode => root.screenRecording = exitCode === 0
    }

    Process {
        id: cameraProcess
        command: ["sh", "-c", "for device in /dev/video*; do [ -e \"$device\" ] || continue; fuser \"$device\" >/dev/null 2>&1 && exit 0; done; exit 1"]
        onExited: exitCode => root.directCameraInUse = exitCode === 0
    }

    Process {
        id: powerProfileProcess
        command: [Quickshell.shellDir + "/scripts/power-profile"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (root.powerProfileUpdatePending)
                return;
            const value = stdout.text.trim();
            root.powerProfilesAvailable = exitCode === 0;
            root.powerProfile = exitCode === 0 && value !== "" ? value : "balanced";
        }
    }

    Process {
        id: keyboardProcess
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {}
        onExited: {
            try {
                const data = JSON.parse(stdout.text);
                const keyboards = data.keyboards || [];
                const keyboard = keyboards.find(item => item.main) || keyboards[0];
                if (keyboard)
                    root.keyboardLayout = root.shortLayout(keyboard.active_keymap);
            } catch (error) {
                console.warn("Keyboard layout could not be parsed:", error);
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const values = event.parse(2);
            if (values.length > 1)
                root.keyboardLayout = root.shortLayout(values[1]);
        }
    }

    Process {
        id: weatherProcess
        command: [
            Quickshell.shellDir + "/scripts/weather",
            Config.Preferences.weatherCity,
            Config.Preferences.weatherLatitude,
            Config.Preferences.weatherLongitude,
            Config.Preferences.weatherTimezone
        ]
        stdout: StdioCollector {}
        onExited: {
            try {
                const data = JSON.parse(stdout.text);
                root.weatherText = String(data.text || "--°").replace(/<[^>]+>/g, "").trim();
                root.weatherDetails = data.tooltip || "";
                const lines = root.weatherDetails.split("\n");
                const firstLine = lines[0] || "";
                const conditionMatch = firstLine.match(/^[^:]+:\s*(.*?)\s*·/);
                root.weatherCondition = conditionMatch ? conditionMatch[1].replace("Переменная облачность", "Облачно") : "Погода";
                const currentMatch = firstLine.match(/^([^:]+):\s*(.*?)\s*·\s*(-?\d+)°C/);
                const detailMatch = (lines[1] || "").match(/Ощущается как\s*(-?\d+)°C\s*·\s*Ветер\s*(\d+)\s*км\/ч/);
                const textMatch = root.weatherText.match(/^(\S+)\s+(-?\d+°)$/);
                root.weatherCity = currentMatch ? currentMatch[1]
                    : (Config.Preferences.weatherCity || "Не настроено");
                root.weatherIcon = textMatch ? textMatch[1] : "󰖐";
                root.weatherTemperature = textMatch ? textMatch[2] : "--°";
                root.weatherFeelsLike = detailMatch ? detailMatch[1] + "°" : "--°";
                root.weatherWind = detailMatch ? detailMatch[2] + " км/ч" : "-- км/ч";

                const forecast = [];
                for (let i = 4; i < lines.length; ++i) {
                    const match = lines[i].trim().match(/^(\S+)\s+(\d{2}\.\d{2})\s+(\S+)\s+(-?\d+)…(-?\d+)°C\s+\S+\s+(\d+)%$/);
                    if (match) {
                        forecast.push({
                            day: match[1], date: match[2], icon: match[3],
                            minimum: match[4], maximum: match[5], precipitation: match[6]
                        });
                    }
                }
                root.weatherForecast = forecast;
            } catch (error) {
                root.weatherText = "--°";
                root.weatherCondition = "Погода";
                root.weatherForecast = [];
            }
        }
    }

    Connections {
        target: Config.Preferences
        function onWeatherCityChanged() { weatherConfigTimer.restart(); }
        function onWeatherLatitudeChanged() { weatherConfigTimer.restart(); }
        function onWeatherLongitudeChanged() { weatherConfigTimer.restart(); }
        function onWeatherTimezoneChanged() { weatherConfigTimer.restart(); }
    }

    Timer {
        id: weatherConfigTimer
        interval: 250
        onTriggered: root.refreshWeather()
    }

    Process {
        id: themeProcess
        command: ["sh", "-c", "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/theme/mode\" 2>/dev/null || printf dark"]
        stdout: StdioCollector {}
        onExited: {
            if (!root.themeModeUpdatePending)
                root.themeMode = stdout.text.trim() === "light" ? "light" : "dark";
        }
    }

    Process {
        id: accentProcess
        command: [Quickshell.shellDir + "/scripts/accent-color"]
        stdout: StdioCollector {}
        onExited: {
            const value = stdout.text.trim();
            if (/^#[0-9a-fA-F]{6}$/.test(value))
                Config.Theme.matugenAccent = value;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.backendConnected)
                return;
            if (!statsProcess.running)
                statsProcess.running = true;
            if (!vpnProcess.running && !root.vpnUpdatePending)
                vpnProcess.running = true;
            if (!networkProcess.running)
                networkProcess.running = true;
            if (!recordingProcess.running)
                recordingProcess.running = true;
            if (!cameraProcess.running)
                cameraProcess.running = true;
            if (!powerProfileProcess.running && !root.powerProfileUpdatePending)
                powerProfileProcess.running = true;
            if (!themeProcess.running && !root.themeModeUpdatePending)
                themeProcess.running = true;
            if (!accentProcess.running)
                accentProcess.running = true;
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }
}
