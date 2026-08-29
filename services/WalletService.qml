import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    property bool isOpen: false
    property real usdtBalance: 0
    property real trxBalance: 0
    property real accountValue: 0
    property real withdrawable: 0
    property real unrealizedPnl: 0
    property var positions: []
    property date lastUpdated
    property string error: ""

    readonly property string tronAddress: Config.Preferences.tronAddress
    readonly property string hyperliquidAddress: Config.Preferences.hyperliquidAddress
    readonly property bool tronConfigured: /^T[1-9A-HJ-NP-Za-km-z]{33}$/.test(tronAddress)
    readonly property bool hyperliquidConfigured: /^0x[0-9a-fA-F]{40}$/.test(hyperliquidAddress)
    readonly property bool loading: statsProcess.running

    function refresh() {
        if (!statsProcess.running && (tronConfigured || hyperliquidConfigured))
            statsProcess.running = true;
    }

    function configurationChanged() {
        if (!tronConfigured) {
            usdtBalance = 0;
            trxBalance = 0;
        }
        if (!hyperliquidConfigured) {
            accountValue = 0;
            withdrawable = 0;
            unrealizedPnl = 0;
            positions = [];
        }
        configRefreshTimer.restart();
    }

    function open() {
        isOpen = true;
        refresh();
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    Process {
        id: statsProcess
        command: [Quickshell.shellDir + "/scripts/wallet-stats", root.tronAddress, root.hyperliquidAddress]
        stdout: StdioCollector {}

        onExited: {
            try {
                const data = JSON.parse(stdout.text);
                const tron = data.tron || {};
                const hyperliquid = data.hyperliquid || {};

                if (tron.ok) {
                    root.usdtBalance = Number(tron.usdt || 0);
                    root.trxBalance = Number(tron.trx || 0);
                }

                if (hyperliquid.ok) {
                    root.accountValue = Number(hyperliquid.accountValue || 0);
                    root.withdrawable = Number(hyperliquid.withdrawable || 0);
                    root.unrealizedPnl = Number(hyperliquid.unrealizedPnl || 0);
                    root.positions = hyperliquid.positions || [];
                }

                root.error = root.tronConfigured && !tron.ok
                    ? "TronGrid недоступен"
                    : (root.hyperliquidConfigured && !hyperliquid.ok ? "Hyperliquid недоступен" : "");
                root.lastUpdated = new Date();
            } catch (error) {
                root.error = "Не удалось обновить данные";
                console.warn("Wallet metrics could not be parsed:", error);
            }
        }
    }

    Connections {
        target: Config.Preferences
        function onTronAddressChanged() { root.configurationChanged(); }
        function onHyperliquidAddressChanged() { root.configurationChanged(); }
    }

    Timer {
        id: configRefreshTimer
        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: root.isOpen
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "wallet"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function refresh(): void { root.refresh(); }
        function status(): bool { return root.isOpen; }
    }
}
