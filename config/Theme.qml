pragma Singleton

import QtQuick

QtObject {
    readonly property var presetPalettes: ({
        "catppuccin-mocha": {
            island: "#11111b", raised: "#1e1e2e", hover: "#313244", active: "#45475a",
            edge: "#334c4f69", track: "#313244", text: "#cdd6f4", muted: "#a6adc8",
            accent: "#cba6f7", success: "#a6e3a1", warning: "#fab387", danger: "#f38ba8"
        },
        "gruvbox-dark": {
            island: "#1d2021", raised: "#282828", hover: "#3c3836", active: "#504945",
            edge: "#337c6f64", track: "#3c3836", text: "#ebdbb2", muted: "#a89984",
            accent: "#fabd2f", success: "#b8bb26", warning: "#fe8019", danger: "#fb4934"
        },
        "kanagawa-wave": {
            island: "#16161d", raised: "#1f1f28", hover: "#2a2a37", active: "#363646",
            edge: "#33545c7e", track: "#2a2a37", text: "#dcd7ba", muted: "#727169",
            accent: "#7e9cd8", success: "#98bb6c", warning: "#e6c384", danger: "#e46876"
        },
        "tokyo-night": {
            island: "#16161e", raised: "#1a1b26", hover: "#24283b", active: "#292e42",
            edge: "#33414868", track: "#24283b", text: "#c0caf5", muted: "#565f89",
            accent: "#7aa2f7", success: "#9ece6a", warning: "#e0af68", danger: "#f7768e"
        },
        "nord": {
            island: "#242933", raised: "#2e3440", hover: "#3b4252", active: "#434c5e",
            edge: "#334c566a", track: "#3b4252", text: "#eceff4", muted: "#aeb8c5",
            accent: "#88c0d0", success: "#a3be8c", warning: "#ebcb8b", danger: "#bf616a"
        },
        "rose-pine": {
            island: "#191724", raised: "#1f1d2e", hover: "#26233a", active: "#403d52",
            edge: "#3352466f", track: "#26233a", text: "#e0def4", muted: "#908caa",
            accent: "#c4a7e7", success: "#9ccfd8", warning: "#f6c177", danger: "#eb6f92"
        },
        "everforest": {
            island: "#1e2326", raised: "#272e33", hover: "#2e383c", active: "#374145",
            edge: "#335d6b66", track: "#2e383c", text: "#d3c6aa", muted: "#859289",
            accent: "#a7c080", success: "#83c092", warning: "#dbbc7f", danger: "#e67e80"
        },
        "dracula": {
            island: "#191a21", raised: "#282a36", hover: "#343746", active: "#44475a",
            edge: "#336272a4", track: "#343746", text: "#f8f8f2", muted: "#9aa0c4",
            accent: "#bd93f9", success: "#50fa7b", warning: "#f1fa8c", danger: "#ff5555"
        }
    })
    readonly property bool presetActive: Preferences.themeSource === "preset"
    readonly property var activePreset: preset(Preferences.themePreset)
    property color matugenAccent: "#ffcbc6bf"

    function preset(name) {
        return presetPalettes[name] || presetPalettes["catppuccin-mocha"];
    }

    readonly property color island: presetActive ? activePreset.island : "#ff0b0b0d"
    readonly property color islandRaised: presetActive ? activePreset.raised : "#ff18181b"
    readonly property color surfaceHover: presetActive ? activePreset.hover : "#ff202024"
    readonly property color surfaceActive: presetActive ? activePreset.active : "#ff29292e"
    readonly property color surfaceEdge: presetActive ? activePreset.edge : "#14ffffff"
    readonly property color track: presetActive ? activePreset.track : "#ff303034"
    readonly property color text: presetActive ? activePreset.text : "#fff5f5f7"
    readonly property color textMuted: presetActive ? activePreset.muted : "#ffaaaab2"
    readonly property color accent: presetActive ? activePreset.accent : matugenAccent
    readonly property color success: presetActive ? activePreset.success : "#ff76946a"
    readonly property color warning: presetActive ? activePreset.warning : "#ffffa066"
    readonly property color danger: presetActive ? activePreset.danger : "#ffc34043"
    readonly property color wallpaperOutline: "#b3000000"
    readonly property color barMaterial: Qt.rgba(island.r, island.g, island.b, 0.44)
    readonly property color barMaterialSoft: Qt.rgba(island.r, island.g, island.b, 0.16)

    readonly property string uiFont: "Adwaita Sans"
    readonly property string monoFont: "AdwaitaMono Nerd Font"

    readonly property int barHeight: 42
    readonly property int islandWidth: 380
    readonly property int islandBottomRadius: 22
    readonly property int motionFast: Preferences.animationsEnabled
        ? Math.round(140 / Preferences.animationSpeed) : 0
    readonly property int motionNormal: Preferences.animationsEnabled
        ? Math.round(220 / Preferences.animationSpeed) : 0
}
