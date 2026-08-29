pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string settingsScript: Quickshell.env("HOME")
        + "/.config/quickshell/qanda-shell/scripts/settings"
    readonly property string settingsPath: Quickshell.env("HOME")
        + "/.local/state/qanda-shell/settings.json"

    readonly property list<string> profiles: ["normal", "work", "game", "focus"]
    readonly property list<string> themeSources: ["matugen", "preset"]
    readonly property var themePresets: [
        { id: "catppuccin-mocha", label: "Catppuccin" },
        { id: "gruvbox-dark", label: "Gruvbox" },
        { id: "kanagawa-wave", label: "Kanagawa" },
        { id: "tokyo-night", label: "Tokyo Night" },
        { id: "nord", label: "Nord" },
        { id: "rose-pine", label: "Rosé Pine" },
        { id: "everforest", label: "Everforest" },
        { id: "dracula", label: "Dracula" }
    ]
    readonly property list<string> themePresetIds: [
        "catppuccin-mocha", "gruvbox-dark", "kanagawa-wave", "tokyo-night",
        "nord", "rose-pine", "everforest", "dracula"
    ]
    readonly property list<string> matugenSources: ["wallpaper", "color"]
    readonly property list<string> matugenSchemes: [
        "scheme-content", "scheme-expressive", "scheme-fidelity",
        "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
        "scheme-rainbow", "scheme-tonal-spot", "scheme-vibrant"
    ]
    readonly property list<string> matugenPreferences: [
        "darkness", "lightness", "saturation", "less-saturation", "value"
    ]

    property string activeProfile: "normal"
    property bool animationsEnabled: true
    property real animationSpeed: 1
    property bool effectsEnabled: true
    property int notificationDuration: 4000
    property bool showLeftCluster: true
    property bool showRightCluster: true
    property string themeSource: "matugen"
    property string themePreset: "catppuccin-mocha"
    property string matugenSource: "wallpaper"
    property string matugenColor: "#cbc6bf"
    property string matugenScheme: "scheme-content"
    property real matugenContrast: 0
    property string matugenPrefer: "saturation"
    property string weatherCity: ""
    property string weatherLatitude: ""
    property string weatherLongitude: ""
    property string weatherTimezone: "auto"
    property string tronAddress: ""
    property string hyperliquidAddress: ""
    property bool loaded: false
    property string error: ""

    function validChoice(value, choices) {
        return typeof value === "string" && choices.indexOf(value) !== -1;
    }

    function validColor(value) {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value);
    }

    function validContrast(value) {
        return typeof value === "number" && Number.isFinite(value)
            && value >= -1 && value <= 1;
    }

    function validAnimationSpeed(value) {
        return typeof value === "number" && Number.isFinite(value)
            && value >= 0.5 && value <= 2;
    }

    function validNotificationDuration(value) {
        return Number.isInteger(value) && value >= 1000 && value <= 15000;
    }

    function validCoordinate(value, minimum, maximum) {
        const text = String(value || "").trim();
        if (text === "")
            return true;
        if (!/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(text))
            return false;
        const number = Number(text);
        return Number.isFinite(number) && number >= minimum && number <= maximum;
    }

    function validWeatherCity(value) {
        const text = String(value || "").trim();
        return text.length <= 80 && !/[:\x00-\x1f\x7f]/.test(text);
    }

    function validWeatherTimezone(value) {
        return /^(?:auto|[A-Za-z_+-]+(?:\/[A-Za-z0-9_+.-]+)*)$/.test(String(value || ""));
    }

    function validTronAddress(value) {
        return value === "" || /^T[1-9A-HJ-NP-Za-km-z]{33}$/.test(String(value));
    }

    function validHyperliquidAddress(value) {
        return value === "" || /^0x[0-9a-fA-F]{40}$/.test(String(value));
    }

    function updateActiveProfile(value) {
        if (!validChoice(value, profiles))
            return false;
        activeProfile = value;
        scheduleSave();
        return true;
    }

    function updateAnimationsEnabled(value) {
        animationsEnabled = Boolean(value);
        scheduleSave();
    }

    function updateAnimationSpeed(value) {
        const speed = Math.round(Number(value) * 4) / 4;
        if (!validAnimationSpeed(speed))
            return false;
        animationSpeed = speed;
        scheduleSave();
        return true;
    }

    function updateEffectsEnabled(value) {
        effectsEnabled = Boolean(value);
        scheduleSave();
    }

    function updateNotificationDuration(value) {
        const duration = Math.round(Number(value) / 500) * 500;
        if (!validNotificationDuration(duration))
            return false;
        notificationDuration = duration;
        scheduleSave();
        return true;
    }

    function updateShowLeftCluster(value) {
        showLeftCluster = Boolean(value);
        scheduleSave();
    }

    function updateShowRightCluster(value) {
        showRightCluster = Boolean(value);
        scheduleSave();
    }

    function updateWeatherCity(value) {
        const text = String(value || "").trim();
        if (!validWeatherCity(text))
            return false;
        weatherCity = text;
        scheduleSave();
        return true;
    }

    function updateWeatherLatitude(value) {
        const text = String(value || "").trim();
        if (!validCoordinate(text, -90, 90))
            return false;
        weatherLatitude = text;
        scheduleSave();
        return true;
    }

    function updateWeatherLongitude(value) {
        const text = String(value || "").trim();
        if (!validCoordinate(text, -180, 180))
            return false;
        weatherLongitude = text;
        scheduleSave();
        return true;
    }

    function updateWeatherTimezone(value) {
        const text = String(value || "").trim();
        if (!validWeatherTimezone(text))
            return false;
        weatherTimezone = text;
        scheduleSave();
        return true;
    }

    function updateTronAddress(value) {
        const text = String(value || "").trim();
        if (!validTronAddress(text))
            return false;
        tronAddress = text;
        scheduleSave();
        return true;
    }

    function updateHyperliquidAddress(value) {
        const text = String(value || "").trim();
        if (!validHyperliquidAddress(text))
            return false;
        hyperliquidAddress = text;
        scheduleSave();
        return true;
    }

    function updateThemeSource(value) {
        if (!validChoice(value, themeSources))
            return false;
        themeSource = value;
        scheduleSave();
        return true;
    }

    function updateThemePreset(value) {
        if (!validChoice(value, themePresetIds))
            return false;
        themePreset = value;
        themeSource = "preset";
        scheduleSave();
        return true;
    }

    function scheduleSave() {
        if (loaded)
            saveTimer.restart();
    }

    function updateMatugenSource(value) {
        if (!validChoice(value, matugenSources))
            return false;
        matugenSource = value;
        scheduleSave();
        return true;
    }

    function updateMatugenColor(value) {
        if (!validColor(value))
            return false;
        matugenColor = value.toLowerCase();
        scheduleSave();
        return true;
    }

    function updateMatugenScheme(value) {
        if (!validChoice(value, matugenSchemes))
            return false;
        matugenScheme = value;
        scheduleSave();
        return true;
    }

    function updateMatugenContrast(value) {
        if (!validContrast(value))
            return false;
        matugenContrast = value;
        scheduleSave();
        return true;
    }

    function updateMatugenPrefer(value) {
        if (!validChoice(value, matugenPreferences))
            return false;
        matugenPrefer = value;
        scheduleSave();
        return true;
    }

    property Process loadProcess: Process {
        command: [root.settingsScript, "read"]
        running: true
        stdout: StdioCollector { id: loadOutput }
        stderr: StdioCollector { id: loadErrors }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.error = loadErrors.text.trim() || "Не удалось загрузить настройки";
                root.loaded = true;
                return;
            }

            try {
                const data = JSON.parse(loadOutput.text);
                if (root.validChoice(data.activeProfile, root.profiles))
                    root.activeProfile = data.activeProfile;
                if (typeof data.animationsEnabled === "boolean")
                    root.animationsEnabled = data.animationsEnabled;
                if (root.validAnimationSpeed(data.animationSpeed))
                    root.animationSpeed = data.animationSpeed;
                if (typeof data.effectsEnabled === "boolean")
                    root.effectsEnabled = data.effectsEnabled;
                if (root.validNotificationDuration(data.notificationDuration))
                    root.notificationDuration = data.notificationDuration;
                if (typeof data.showLeftCluster === "boolean")
                    root.showLeftCluster = data.showLeftCluster;
                if (typeof data.showRightCluster === "boolean")
                    root.showRightCluster = data.showRightCluster;
                if (root.validChoice(data.themeSource, root.themeSources))
                    root.themeSource = data.themeSource;
                if (root.validChoice(data.themePreset, root.themePresetIds))
                    root.themePreset = data.themePreset;
                if (root.validChoice(data.matugenSource, root.matugenSources))
                    root.matugenSource = data.matugenSource;
                if (root.validColor(data.matugenColor))
                    root.matugenColor = data.matugenColor.toLowerCase();
                if (root.validChoice(data.matugenScheme, root.matugenSchemes))
                    root.matugenScheme = data.matugenScheme;
                if (root.validContrast(data.matugenContrast))
                    root.matugenContrast = data.matugenContrast;
                if (root.validChoice(data.matugenPrefer, root.matugenPreferences))
                    root.matugenPrefer = data.matugenPrefer;
                if (root.validWeatherCity(data.weatherCity))
                    root.weatherCity = String(data.weatherCity || "").trim();
                if (root.validCoordinate(data.weatherLatitude, -90, 90))
                    root.weatherLatitude = String(data.weatherLatitude || "").trim();
                if (root.validCoordinate(data.weatherLongitude, -180, 180))
                    root.weatherLongitude = String(data.weatherLongitude || "").trim();
                if (root.validWeatherTimezone(data.weatherTimezone))
                    root.weatherTimezone = data.weatherTimezone;
                if (root.validTronAddress(data.tronAddress))
                    root.tronAddress = data.tronAddress;
                if (root.validHyperliquidAddress(data.hyperliquidAddress))
                    root.hyperliquidAddress = data.hyperliquidAddress;
                root.error = "";
            } catch (exception) {
                root.error = "Некорректный файл настроек";
            }
            root.loaded = true;
        }
    }

    property Timer saveTimer: Timer {
        interval: 150
        onTriggered: {
            if (saveProcess.running) {
                restart();
                return;
            }
            saveProcess.command = [root.settingsScript, "write", JSON.stringify({
                activeProfile: root.activeProfile,
                animationsEnabled: root.animationsEnabled,
                animationSpeed: root.animationSpeed,
                effectsEnabled: root.effectsEnabled,
                notificationDuration: root.notificationDuration,
                showLeftCluster: root.showLeftCluster,
                showRightCluster: root.showRightCluster,
                themeSource: root.themeSource,
                themePreset: root.themePreset,
                matugenSource: root.matugenSource,
                matugenColor: root.matugenColor,
                matugenScheme: root.matugenScheme,
                matugenContrast: root.matugenContrast,
                matugenPrefer: root.matugenPrefer,
                weatherCity: root.weatherCity,
                weatherLatitude: root.weatherLatitude,
                weatherLongitude: root.weatherLongitude,
                weatherTimezone: root.weatherTimezone,
                tronAddress: root.tronAddress,
                hyperliquidAddress: root.hyperliquidAddress
            })];
            saveProcess.running = true;
        }
    }

    property Process saveProcess: Process {
        command: []
        stderr: StdioCollector { id: saveErrors }
        onExited: exitCode => root.error = exitCode === 0
            ? ""
            : (saveErrors.text.trim() || "Не удалось сохранить настройки")
    }
}
