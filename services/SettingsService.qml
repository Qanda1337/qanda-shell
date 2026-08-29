import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    required property var notificationService
    required property var systemService
    required property var audioService

    property bool isOpen: false
    property int currentSection: 0
    readonly property bool busy: applyProcess.running || actionProcess.running
        || backendActionId > 0
        || vpnActionProcess.running || themeModeProcess.running
    property string error: ""
    property bool wifiEnabled: false
    property bool wifiAvailable: false
    property string wifiName: ""
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    property string monitorName: ""
    property string monitorDescription: ""
    property real refreshRate: 0
    property real monitorScale: 1
    property bool brightnessAvailable: false
    property int brightness: 0
    property bool nightLightAvailable: false
    property bool nightLight: false
    property bool powerProfilesAvailable: false
    property var availablePowerProfiles: []
    property string powerProfile: "unavailable"
    property bool cameraAvailable: false
    property var dependencies: ({})
    property var actionRollback: null
    property var vpnRollback: null
    property var themeModeRollback: null
    property string applyThemeRollbackSource: ""
    property string applyThemeRollbackPreset: ""
    property string applyThemeRollbackMode: ""
    property bool applyingPreset: false
    property int stateRevision: 0
    property int statusRevision: 0
    property int backendActionId: 0
    readonly property string controlScript: Quickshell.shellDir + "/scripts/control-center"

    function open() {
        isOpen = true;
        openRefreshTimer.restart();
    }
    function close() {
        isOpen = false;
        openRefreshTimer.stop();
    }
    function toggle() { isOpen ? close() : open(); }

    function setSection(index) {
        currentSection = Math.max(0, Math.min(3, index));
    }

    function refresh() {
        if (!statusProcess.running && !actionProcess.running) {
            if (systemService.backendConnected)
                systemService.requestBackendRefresh();
            statusRevision = stateRevision;
            statusProcess.command = [controlScript,
                systemService.backendConnected ? "status-local" : "status"];
            statusProcess.running = true;
        }
    }

    function syncSystemBackend() {
        if (!systemService.backendConnected)
            return;
        if (!actionRollback || actionRollback.kind !== "wifi") {
            wifiAvailable = systemService.wifiAvailable;
            wifiEnabled = systemService.wifiEnabled;
            wifiName = systemService.wifiName;
        }
        if (!actionRollback || actionRollback.kind !== "power-profile") {
            powerProfilesAvailable = systemService.powerProfilesAvailable;
            availablePowerProfiles = systemService.availablePowerProfiles;
            powerProfile = systemService.powerProfile;
        }
    }

    function applyOptimisticAction(args) {
        const method = String(args[0] || "");
        if (method === "power-profile") {
            const target = String(args[1] || "balanced");
            const snapshot = {
                kind: method,
                powerProfile: powerProfile,
                systemPowerProfile: systemService.powerProfile
            };
            powerProfile = target;
            systemService.powerProfile = target;
            systemService.powerProfileUpdatePending = true;
            return snapshot;
        }
        if (method === "brightness") {
            const snapshot = { kind: method, brightness: brightness };
            const delta = parseFloat(String(args[1] || "0"));
            brightness = Math.max(0, Math.min(100, Math.round(brightness + delta)));
            return snapshot;
        }
        if (method === "night-light") {
            const snapshot = { kind: method, nightLight: nightLight };
            nightLight = !nightLight;
            return snapshot;
        }
        if (method === "wifi") {
            const snapshot = {
                kind: method,
                wifiEnabled: wifiEnabled,
                systemWifiEnabled: systemService.wifiEnabled
            };
            wifiEnabled = String(args[1]) === "on";
            systemService.wifiEnabled = wifiEnabled;
            systemService.wifiUpdatePending = true;
            return snapshot;
        }
        if (method === "bluetooth") {
            const snapshot = { kind: method, bluetoothEnabled: bluetoothEnabled };
            bluetoothEnabled = String(args[1]) === "on";
            return snapshot;
        }
        return null;
    }

    function finishOptimisticAction(succeeded) {
        const snapshot = actionRollback;
        if (!snapshot)
            return;
        if (!succeeded) {
            if (snapshot.kind === "power-profile") {
                powerProfile = snapshot.powerProfile;
                systemService.powerProfile = snapshot.systemPowerProfile;
            } else if (snapshot.kind === "brightness") {
                brightness = snapshot.brightness;
            } else if (snapshot.kind === "night-light") {
                nightLight = snapshot.nightLight;
            } else if (snapshot.kind === "wifi") {
                wifiEnabled = snapshot.wifiEnabled;
                systemService.wifiEnabled = snapshot.systemWifiEnabled;
            } else if (snapshot.kind === "bluetooth") {
                bluetoothEnabled = snapshot.bluetoothEnabled;
            }
        }
        if (snapshot.kind === "power-profile")
            systemService.powerProfileUpdatePending = false;
        if (snapshot.kind === "wifi")
            systemService.wifiUpdatePending = false;
        actionRollback = null;
    }

    function runAction(args) {
        if (actionProcess.running || backendActionId > 0)
            return false;
        error = "";
        stateRevision += 1;
        actionRollback = applyOptimisticAction(args);
        const method = String(args[0] || "");
        if (systemService.backendConnected
                && (method === "wifi" || method === "power-profile")) {
            const backendMethod = method === "wifi" ? "set_wifi" : "set_power_profile";
            const params = method === "wifi"
                ? { enabled: String(args[1]) === "on" }
                : { profile: String(args[1] || "balanced") };
            backendActionId = systemService.sendBackendCommand(backendMethod, params);
            if (backendActionId < 0) {
                backendActionId = 0;
                finishOptimisticAction(false);
                error = "Системный backend недоступен";
                return false;
            }
            backendActionTimeout.restart();
            return true;
        }
        actionProcess.command = [controlScript].concat(args);
        actionProcess.running = true;
        return true;
    }

    function applyTheme() {
        if (busy)
            return false;

        error = "";
        applyingPreset = false;
        applyThemeRollbackSource = Config.Preferences.themeSource;
        Config.Preferences.updateThemeSource("matugen");
        applyProcess.command = [
            "/bin/bash",
            Quickshell.env("HOME") + "/.config/theme/apply.sh",
            "--source", Config.Preferences.matugenSource,
            "--color", Config.Preferences.matugenColor,
            "--scheme", Config.Preferences.matugenScheme,
            "--contrast", String(Config.Preferences.matugenContrast),
            "--prefer", Config.Preferences.matugenPrefer
        ];
        applyProcess.running = true;
        return true;
    }

    function applyPresetTheme(name) {
        if (busy || Config.Preferences.themePresetIds.indexOf(name) === -1)
            return false;

        error = "";
        applyingPreset = true;
        applyThemeRollbackSource = Config.Preferences.themeSource;
        applyThemeRollbackPreset = Config.Preferences.themePreset;
        applyThemeRollbackMode = systemService.themeMode;
        Config.Preferences.updateThemePreset(name);
        systemService.themeMode = "dark";
        systemService.themeModeUpdatePending = true;
        applyProcess.command = [
            "/bin/bash",
            Quickshell.env("HOME") + "/.config/theme/apply.sh",
            "dark", "--preset", name
        ];
        applyProcess.running = true;
        return true;
    }

    function toggleDnd(service) {
        const target = service || notificationService;
        if (!target || typeof target.toggleDoNotDisturb !== "function")
            return false;
        target.toggleDoNotDisturb();
        return true;
    }

    function toggleMute() {
        audioService.toggleOutputMute();
        return audioService.defaultSink !== null;
    }

    function toggleVpn() {
        if (vpnActionProcess.running)
            return false;
        error = "";
        vpnRollback = systemService.vpnConnected;
        systemService.vpnConnected = !systemService.vpnConnected;
        systemService.vpnUpdatePending = true;
        vpnActionProcess.running = true;
        return true;
    }

    function toggleThemeMode() {
        if (themeModeProcess.running)
            return false;
        error = "";
        themeModeRollback = systemService.themeMode;
        systemService.themeMode = systemService.themeMode === "dark" ? "light" : "dark";
        systemService.themeModeUpdatePending = true;
        themeModeProcess.running = true;
        return true;
    }

    function setDnd(enabled) {
        if (notificationService.doNotDisturb !== enabled)
            notificationService.toggleDoNotDisturb();
    }

    function applyProfile(profile) {
        if (!Config.Preferences.updateActiveProfile(profile))
            return false;

        switch (profile) {
        case "work":
            setDnd(true);
            if (!systemService.vpnConnected)
                toggleVpn();
            if (powerProfilesAvailable)
                runAction(["power-profile", "balanced"]);
            break;
        case "game":
            setDnd(true);
            if (powerProfilesAvailable)
                runAction(["power-profile", "performance"]);
            break;
        case "focus":
            setDnd(true);
            if (powerProfilesAvailable)
                runAction(["power-profile", "balanced"]);
            break;
        default:
            setDnd(false);
            if (powerProfilesAvailable)
                runAction(["power-profile", "balanced"]);
            break;
        }
        return true;
    }

    function restartShell() {
        close();
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/restart"]);
    }

    function openLogs() {
        Quickshell.execDetached([
            "kitty", "--hold", "quickshell", "log",
            "-p", Quickshell.shellDir, "-n", "--tail", "200"
        ]);
    }

    Process {
        id: applyProcess

        command: []
        stderr: StdioCollector { id: applyErrors }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.error = applyErrors.text.trim() || "Theme apply failed with exit code " + exitCode;
                if (root.applyingPreset) {
                    Config.Preferences.updateThemePreset(root.applyThemeRollbackPreset || "catppuccin-mocha");
                    root.systemService.themeMode = root.applyThemeRollbackMode || "dark";
                }
                Config.Preferences.updateThemeSource(root.applyThemeRollbackSource || "matugen");
            }
            if (root.applyingPreset)
                root.systemService.themeModeUpdatePending = false;
            root.applyingPreset = false;
            root.applyThemeRollbackSource = "";
            root.applyThemeRollbackPreset = "";
            root.applyThemeRollbackMode = "";
        }
    }

    Process {
        id: vpnActionProcess
        command: [Quickshell.env("HOME") + "/.local/bin/vpn-toggle.sh"]
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemService.vpnConnected = Boolean(root.vpnRollback);
                root.error = stderr.text.trim() || "Не удалось переключить VPN";
            }
            root.systemService.vpnUpdatePending = false;
            root.vpnRollback = null;
        }
    }

    Process {
        id: themeModeProcess
        command: [Quickshell.env("HOME") + "/.config/theme/apply.sh", "toggle"]
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemService.themeMode = String(root.themeModeRollback || "dark");
                root.error = stderr.text.trim() || "Не удалось переключить цветовой режим";
            }
            root.systemService.themeModeUpdatePending = false;
            root.themeModeRollback = null;
        }
    }

    Process {
        id: statusProcess
        command: [root.controlScript, "status"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            if (actionProcess.running)
                return;
            if (statusRevision !== stateRevision)
                return;
            try {
                const data = JSON.parse(stdout.text);
                if (!root.systemService.backendConnected) {
                    root.wifiAvailable = Boolean(data.wifiAvailable);
                    root.wifiEnabled = Boolean(data.wifiEnabled);
                    root.wifiName = String(data.wifiName || "");
                }
                root.bluetoothAvailable = Boolean(data.bluetoothAvailable);
                root.bluetoothEnabled = Boolean(data.bluetoothEnabled);
                root.monitorName = String(data.monitorName || "");
                root.monitorDescription = String(data.monitorDescription || "");
                root.refreshRate = Number(data.refreshRate || 0);
                root.monitorScale = Number(data.scale || 1);
                root.brightnessAvailable = Boolean(data.brightnessAvailable);
                root.brightness = Number(data.brightness || 0);
                root.nightLightAvailable = Boolean(data.nightLightAvailable);
                root.nightLight = Boolean(data.nightLight);
                if (!root.systemService.backendConnected) {
                    root.powerProfilesAvailable = Boolean(data.powerProfilesAvailable);
                    root.availablePowerProfiles = Array.isArray(data.availablePowerProfiles)
                        ? data.availablePowerProfiles : [];
                    root.powerProfile = String(data.powerProfile || "unavailable");
                }
                root.cameraAvailable = Boolean(data.cameraAvailable);
                root.dependencies = data.dependencies || {};
                root.syncSystemBackend();
            } catch (exception) {
                root.error = "Не удалось разобрать состояние Control Center";
            }
        }
    }

    Connections {
        target: root.systemService

        function onBackendConnectedChanged() {
            if (!root.systemService.backendConnected && root.backendActionId > 0) {
                root.finishOptimisticAction(false);
                root.backendActionId = 0;
                backendActionTimeout.stop();
                root.error = "Соединение с системным backend потеряно";
            }
            root.syncSystemBackend();
        }
        function onWifiAvailableChanged() { root.syncSystemBackend(); }
        function onWifiEnabledChanged() { root.syncSystemBackend(); }
        function onWifiNameChanged() { root.syncSystemBackend(); }
        function onPowerProfilesAvailableChanged() { root.syncSystemBackend(); }
        function onAvailablePowerProfilesChanged() { root.syncSystemBackend(); }
        function onPowerProfileChanged() { root.syncSystemBackend(); }
        function onBackendCommandFinished(requestId, succeeded, backendError) {
            if (requestId !== root.backendActionId)
                return;
            root.finishOptimisticAction(succeeded);
            root.backendActionId = 0;
            backendActionTimeout.stop();
            if (!succeeded)
                root.error = backendError || "Системное действие завершилось с ошибкой";
            root.syncSystemBackend();
            root.refresh();
        }
    }

    Timer {
        id: backendActionTimeout
        interval: 8000
        onTriggered: {
            if (root.backendActionId <= 0)
                return;
            root.finishOptimisticAction(false);
            root.backendActionId = 0;
            root.error = "Системный backend не ответил вовремя";
            root.refresh();
        }
    }

    Process {
        id: actionProcess
        command: []
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.finishOptimisticAction(exitCode === 0);
            if (exitCode === 3)
                root.error = "Для этого действия не установлен системный backend";
            else if (exitCode !== 0)
                root.error = stderr.text.trim() || "Системное действие завершилось с ошибкой";
            root.refresh();
        }
    }

    Timer {
        id: openRefreshTimer
        interval: Math.max(1, Config.Theme.motionNormal
            + Math.round(Config.Theme.motionFast * 0.55))
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: root.isOpen
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
        function section(index: int): void { root.setSection(index); }
        function profile(name: string): bool { return root.applyProfile(name); }
    }
}
