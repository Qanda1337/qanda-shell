//@ pragma UseQApplication

import QtQuick
import Quickshell
import "components"
import "services"

ShellRoot {
    id: shellRoot

    readonly property var systemData: systemService
    readonly property var notifications: notificationService
    readonly property var launcher: launcherService
    readonly property var clipboard: clipboardService
    readonly property var bindings: bindingsService
    readonly property var docker: dockerService
    readonly property var timer: timerService
    readonly property var calendar: calendarService
    readonly property var media: mediaService
    readonly property var weather: weatherService
    readonly property var audio: audioService
    readonly property var power: powerService
    readonly property var performance: performanceService
    readonly property var wallet: walletService
    readonly property var wallpaper: wallpaperService
    readonly property var settings: settingsService
    readonly property var quickSettings: quickSettingsService
    readonly property var immersive: immersiveService

    SystemService {
        id: systemService
    }

    NotificationService {
        id: notificationService
    }

    LauncherService {
        id: launcherService
    }

    ClipboardService {
        id: clipboardService
    }

    BindingsService {
        id: bindingsService
    }

    DockerService {
        id: dockerService
    }

    TimerService {
        id: timerService
    }

    CalendarService {
        id: calendarService
    }

    MediaService {
        id: mediaService
        notificationService: notificationService
        audioService: audioService
    }

    WeatherService {
        id: weatherService
    }

    AudioService {
        id: audioService
    }

    PowerService {
        id: powerService
    }

    PerformanceService {
        id: performanceService
        systemService: systemService
    }

    WalletService {
        id: walletService
    }

    WallpaperService {
        id: wallpaperService
    }

    SettingsService {
        id: settingsService
        notificationService: notificationService
        systemService: systemService
        audioService: audioService
    }

    QuickSettingsService {
        id: quickSettingsService
        settingsService: settingsService
    }

    ImmersiveService {
        id: immersiveService
    }

    Connections {
        target: launcherService
        function onIsOpenChanged() {
            if (launcherService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: calendarService
        function onIsOpenChanged() {
            if (calendarService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: mediaService
        function onIsOpenChanged() {
            if (mediaService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: weatherService
        function onIsOpenChanged() {
            if (weatherService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: audioService
        function onIsOpenChanged() {
            if (audioService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: powerService
        function onIsOpenChanged() {
            if (powerService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: performanceService
        function onIsOpenChanged() {
            if (performanceService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: walletService
        function onIsOpenChanged() {
            if (walletService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                wallpaperService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: wallpaperService
        function onIsOpenChanged() {
            if (wallpaperService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                clipboardService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: clipboardService
        function onIsOpenChanged() {
            if (clipboardService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                bindingsService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: bindingsService
        function onIsOpenChanged() {
            if (bindingsService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                clipboardService.close();
                dockerService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: dockerService
        function onIsOpenChanged() {
            if (dockerService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close();
                clipboardService.close();
                bindingsService.close();
                calendarService.close();
                mediaService.close();
                weatherService.close();
                audioService.close();
                powerService.close();
                performanceService.close();
                walletService.close();
                wallpaperService.close();
                notificationService.close();
                timerService.close();
            }
        }
    }

    Connections {
        target: notificationService
        function onIsOpenChanged() {
            if (notificationService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close(); clipboardService.close(); bindingsService.close(); dockerService.close();
                timerService.close(); calendarService.close(); mediaService.close(); weatherService.close();
                audioService.close(); powerService.close(); performanceService.close(); walletService.close(); wallpaperService.close();
            }
        }
    }

    Connections {
        target: timerService
        function onIsOpenChanged() {
            if (timerService.isOpen) {
                quickSettingsService.close();
                settingsService.close();
                launcherService.close(); clipboardService.close(); bindingsService.close(); dockerService.close();
                notificationService.close(); calendarService.close(); mediaService.close(); weatherService.close();
                audioService.close(); powerService.close(); performanceService.close(); walletService.close(); wallpaperService.close();
            }
        }
    }

    Connections {
        target: settingsService
        function onIsOpenChanged() {
            if (settingsService.isOpen) {
                quickSettingsService.close();
                launcherService.close(); clipboardService.close(); bindingsService.close(); dockerService.close();
                notificationService.close(); timerService.close(); calendarService.close(); mediaService.close();
                weatherService.close(); audioService.close(); powerService.close(); performanceService.close();
                walletService.close(); wallpaperService.close();
            }
        }
    }

    Connections {
        target: quickSettingsService
        function onIsOpenChanged() {
            if (quickSettingsService.isOpen) {
                settingsService.close();
                launcherService.close(); clipboardService.close(); bindingsService.close(); dockerService.close();
                notificationService.close(); timerService.close(); calendarService.close(); mediaService.close();
                weatherService.close(); audioService.close(); powerService.close(); performanceService.close();
                walletService.close(); wallpaperService.close();
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: TopBar {
            required property ShellScreen modelData

            screen: modelData
            systemService: shellRoot.systemData
            notificationService: shellRoot.notifications
            launcherService: shellRoot.launcher
            clipboardService: shellRoot.clipboard
            bindingsService: shellRoot.bindings
            dockerService: shellRoot.docker
            timerService: shellRoot.timer
            calendarService: shellRoot.calendar
            mediaService: shellRoot.media
            weatherService: shellRoot.weather
            audioService: shellRoot.audio
            powerService: shellRoot.power
            performanceService: shellRoot.performance
            walletService: shellRoot.wallet
            wallpaperService: shellRoot.wallpaper
            settingsService: shellRoot.settings
            quickSettingsService: shellRoot.quickSettings
            immersiveService: shellRoot.immersive
            immersivePresentation: false
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: TopBar {
            required property ShellScreen modelData

            screen: modelData
            systemService: shellRoot.systemData
            notificationService: shellRoot.notifications
            launcherService: shellRoot.launcher
            clipboardService: shellRoot.clipboard
            bindingsService: shellRoot.bindings
            dockerService: shellRoot.docker
            timerService: shellRoot.timer
            calendarService: shellRoot.calendar
            mediaService: shellRoot.media
            weatherService: shellRoot.weather
            audioService: shellRoot.audio
            powerService: shellRoot.power
            performanceService: shellRoot.performance
            walletService: shellRoot.wallet
            wallpaperService: shellRoot.wallpaper
            settingsService: shellRoot.settings
            quickSettingsService: shellRoot.quickSettings
            immersiveService: shellRoot.immersive
            immersivePresentation: true
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: BarExclusionZone {
            required property ShellScreen modelData
            screen: modelData
            immersiveService: shellRoot.immersive
        }
    }
}
