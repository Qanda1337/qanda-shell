import QtQuick
import QtQuick.Shapes
import "../config" as Config

FocusScope {
    id: root

    required property var walletService
    readonly property int positionCount: walletService.positions.length
    readonly property int preferredHeight: positionCount > 0 ? Math.min(410, 220 + positionCount * 64) : 280

    Keys.onReturnPressed: walletService.refresh()
    Keys.onEnterPressed: walletService.refresh()
    Keys.onEscapePressed: walletService.close()
    onVisibleChanged: if (visible) Qt.callLater(() => forceActiveFocus())

    function money(value) {
        return Number(value || 0).toLocaleString(Qt.locale("en_US"), "f", 2);
    }

    function shortAddress(address) {
        if (!address || address.length < 12)
            return address;
        return address.slice(0, 6) + "..." + address.slice(-5);
    }

    function pnlText(value) {
        const number = Number(value || 0);
        return (number >= 0 ? "+$" : "-$") + money(Math.abs(number));
    }

    function pnlColor(value) {
        return Number(value || 0) >= 0 ? Config.Theme.success : Config.Theme.danger;
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 66

        Rectangle {
            id: brandMark
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 11
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.20)

            Shape {
                anchors.centerIn: parent
                width: 24
                height: 24
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Config.Theme.accent
                    PathSvg { path: "M12 1.5 L21 5 V11.2 C21 17 17.4 21.3 12 23.5 C6.6 21.3 3 17 3 11.2 V5 Z" }
                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Config.Theme.island
                    PathSvg { path: "M7 7.5 H17 V10 H7 Z M8.8 12 H15.2 V14.4 H8.8 Z" }
                }
            }
        }

        Column {
            anchors.left: brandMark.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Trust Wallet"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: walletService.error !== "" ? Config.Theme.danger : Config.Theme.success
                }

                Text {
                    text: walletService.error !== ""
                        ? walletService.error
                        : (walletService.loading ? "Обновляем данные" : "Read-only · обновление каждые 30 секунд")
                    color: walletService.error !== "" ? Config.Theme.danger : Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            id: refreshButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 10
            color: refreshMouse.containsMouse || root.activeFocus ? Config.Theme.track : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\uf2f1"
                color: refreshMouse.containsMouse ? Config.Theme.text : Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                rotation: walletService.loading ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart } }
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: walletService.refresh()
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.20)
        }
    }

    Item {
        id: balances
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        height: 112

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 250
            spacing: 5

            Text {
                text: "Баланс · USDT TRC20"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: "$" + root.money(walletService.usdtBalance)
                color: Config.Theme.text
                font.family: Config.Theme.monoFont
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }

            Text {
                text: walletService.tronConfigured
                    ? root.shortAddress(walletService.tronAddress) + "  ·  " + walletService.trxBalance.toFixed(2) + " TRX"
                    : "Нет адреса Tron"
                color: Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 72
            color: Config.Theme.track
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 254
            spacing: 5

            Text {
                text: "Hyperliquid · Нереализованный PnL"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                text: walletService.hyperliquidConfigured ? root.pnlText(walletService.unrealizedPnl) : "Нет адреса"
                color: walletService.hyperliquidConfigured ? root.pnlColor(walletService.unrealizedPnl) : Config.Theme.textMuted
                font.family: Config.Theme.monoFont
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 13

                Text {
                    text: "Equity  $" + root.money(walletService.accountValue)
                    color: Config.Theme.text
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                }

                Text {
                    text: "Доступно  $" + root.money(walletService.withdrawable)
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.monoFont
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            height: 1
            color: Config.Theme.track
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: balances.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 16
        spacing: 8
        visible: !walletService.hyperliquidConfigured

        Text {
            text: "Подключение Hyperliquid"
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: "Добавьте публичные адреса в разделе «Данные» Control Center. API-ключ не требуется."
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: balances.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 12
        anchors.bottomMargin: 14
        visible: walletService.hyperliquidConfigured

        Row {
            id: positionHeader
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22

            Text {
                width: parent.width * 0.46
                text: "Открытые позиции  " + root.positionCount
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                width: parent.width * 0.24
                text: "Объём"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
            }
            Text {
                width: parent.width * 0.30
                text: "PnL / ROE"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
            }
        }

        Text {
            anchors.centerIn: parent
            text: walletService.loading ? "Обновляем позиции..." : "Открытых позиций нет"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            visible: root.positionCount === 0
        }

        ListView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: positionHeader.bottom
            anchors.bottom: parent.bottom
            clip: true
            spacing: 4
            model: walletService.positions
            visible: root.positionCount > 0

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 58
                radius: 12
                color: Config.Theme.islandRaised
                border.width: 1
                border.color: Qt.rgba(Config.Theme.text.r, Config.Theme.text.g, Config.Theme.text.b, 0.06)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Column {
                        width: parent.width * 0.46
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Row {
                            spacing: 8

                            Text {
                                text: modelData.coin
                                color: Config.Theme.text
                                font.family: Config.Theme.monoFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: sideLabel.implicitWidth + 10
                                height: 18
                                radius: 6
                                color: Qt.rgba(root.pnlColor(modelData.side === "LONG" ? 1 : -1).r,
                                    root.pnlColor(modelData.side === "LONG" ? 1 : -1).g,
                                    root.pnlColor(modelData.side === "LONG" ? 1 : -1).b, 0.12)

                                Text {
                                    id: sideLabel
                                    anchors.centerIn: parent
                                    text: modelData.side
                                    color: modelData.side === "LONG" ? Config.Theme.success : Config.Theme.danger
                                    font.family: Config.Theme.monoFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Text {
                            text: "Вход $" + root.money(modelData.entryPrice)
                                + (Number(modelData.liquidationPrice) > 0 ? "  ·  Ликв. $" + root.money(modelData.liquidationPrice) : "")
                            color: Config.Theme.textMuted
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 13
                        }
                    }

                    Column {
                        width: parent.width * 0.24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            anchors.right: parent.right
                            text: "$" + root.money(modelData.value)
                            color: Config.Theme.text
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.right: parent.right
                            text: Number(modelData.size).toFixed(5) + " " + modelData.coin
                            color: Config.Theme.textMuted
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 13
                        }
                    }

                    Column {
                        width: parent.width * 0.30
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            anchors.right: parent.right
                            text: root.pnlText(modelData.pnl)
                            color: root.pnlColor(modelData.pnl)
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.right: parent.right
                            text: (Number(modelData.roe) >= 0 ? "+" : "") + Number(modelData.roe).toFixed(1) + "% ROE"
                            color: root.pnlColor(modelData.roe)
                            font.family: Config.Theme.monoFont
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
