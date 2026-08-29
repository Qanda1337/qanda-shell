import QtQuick
import "../config" as Config

FocusScope {
    id: root

    required property var performanceService
    property int currentTab: 0
    readonly property int preferredHeight: currentTab === 0 ? 286 : 480

    Keys.onLeftPressed: currentTab = Math.max(0, currentTab - 1)
    Keys.onRightPressed: currentTab = Math.min(1, currentTab + 1)
    Keys.onEscapePressed: performanceService.close()
    onVisibleChanged: if (visible) forceActiveFocus()

    function formatBytes(bytes) {
        if (!bytes || bytes < 0)
            return "0 ГБ";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }

    function formatRate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " МБ/с";
        return (bytes / 1024).toFixed(0) + " КБ/с";
    }

    function temperatureColor(value) {
        if (value >= 85)
            return Config.Theme.danger;
        if (value >= 70)
            return Config.Theme.warning;
        return Config.Theme.textMuted;
    }

    component MetricBlock: Item {
        id: metric

        property string label: ""
        property string icon: ""
        property int value: 0
        property string detail: ""
        property color fillColor: Config.Theme.accent
        property string temperature: ""
        property color temperatureColor: Config.Theme.textMuted

        Text {
            id: metricIcon
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 2
            width: 24
            text: metric.icon
            color: metric.fillColor
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: metricLabel
            anchors.left: metricIcon.right
            anchors.leftMargin: 7
            anchors.top: parent.top
            text: metric.label
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            id: metricValue
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -2
            text: metric.value + "%"
            color: Config.Theme.text
            font.family: Config.Theme.monoFont
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.right: metricValue.left
            anchors.rightMargin: 9
            anchors.verticalCenter: metricValue.verticalCenter
            width: temperatureText.implicitWidth + 12
            height: 21
            radius: 8
            color: Qt.rgba(metric.temperatureColor.r, metric.temperatureColor.g, metric.temperatureColor.b, 0.11)
            visible: metric.temperature !== ""

            Text {
                id: temperatureText
                anchors.centerIn: parent
                text: metric.temperature
                color: metric.temperatureColor
                font.family: Config.Theme.monoFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: metricTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 31
            height: 6
            radius: 3
            color: Config.Theme.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, metric.value / 100))
                height: parent.height
                radius: parent.radius
                color: metric.fillColor

                Behavior on width {
                    NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: metricTrack.bottom
            anchors.topMargin: 6
            text: metric.detail
            color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.7)
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 9

        Text {
            text: "\uf201"
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 14
        }

        Column {
            spacing: 1

            Text {
                text: "Производительность"
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                text: "Обновление каждые 1,5 секунды"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 58
        height: 1
        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.18)
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 64
        spacing: 6
        Repeater {
            model: ["Обзор", "Система"]
            delegate: Rectangle {
                required property string modelData
                required property int index
                width: 94
                height: 30
                radius: 10
                color: root.currentTab === index
                    ? Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.14)
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: root.currentTab === index ? Config.Theme.accent : Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
            }
        }
    }

    Grid {
        id: overviewGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.topMargin: 104
        anchors.bottomMargin: 16
        columns: 2
        columnSpacing: 28
        rowSpacing: 20
        visible: root.currentTab === 0

        MetricBlock {
            width: (parent.width - parent.columnSpacing) / 2
            height: (parent.height - parent.rowSpacing) / 2
            label: "ЦП"
            icon: "\uf2db"
            value: performanceService.cpuUsage
            detail: "Intel Core i5-11400F"
            fillColor: Config.Theme.accent
            temperature: performanceService.cpuTemperature + "°C"
            temperatureColor: root.temperatureColor(performanceService.cpuTemperature)
        }

        MetricBlock {
            width: (parent.width - parent.columnSpacing) / 2
            height: (parent.height - parent.rowSpacing) / 2
            label: "Видеокарта"
            icon: "\uf26c"
            value: performanceService.gpuUsage
            detail: performanceService.gpuMemoryTotal > 0
                ? "VRAM " + (performanceService.gpuMemoryUsed / 1024).toFixed(1) + " / " + (performanceService.gpuMemoryTotal / 1024).toFixed(1) + " ГБ"
                : "Данные VRAM недоступны"
            fillColor: Config.Theme.success
            temperature: performanceService.gpuTemperature + "°C"
            temperatureColor: root.temperatureColor(performanceService.gpuTemperature)
        }

        MetricBlock {
            width: (parent.width - parent.columnSpacing) / 2
            height: (parent.height - parent.rowSpacing) / 2
            label: "Оперативная память"
            icon: "\uf538"
            value: performanceService.memoryUsage
            detail: root.formatBytes(performanceService.memoryUsed) + " / " + root.formatBytes(performanceService.memoryTotal)
            fillColor: Config.Theme.warning
        }

        MetricBlock {
            width: (parent.width - parent.columnSpacing) / 2
            height: (parent.height - parent.rowSpacing) / 2
            label: "SWAP"
            icon: "\uf0a0"
            value: performanceService.swapUsage
            detail: root.formatBytes(performanceService.swapUsed) + " / " + root.formatBytes(performanceService.swapTotal)
            fillColor: Config.Theme.textMuted
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.topMargin: 104
        anchors.bottomMargin: 16
        visible: root.currentTab === 1

        Row {
            id: summaries
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 92
            spacing: 16

            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 15
                color: Config.Theme.islandRaised
                Column {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 6
                    Text { text: "Диск /"; color: Config.Theme.textMuted; font.family: Config.Theme.uiFont; font.pixelSize: 13 }
                    Text { text: Number(performanceService.disk.usedPercent || 0).toFixed(1) + "%"; color: Config.Theme.text; font.family: Config.Theme.monoFont; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text { text: root.formatBytes(performanceService.disk.usedBytes || 0) + " / " + root.formatBytes(performanceService.disk.totalBytes || 0); color: Config.Theme.textMuted; font.family: Config.Theme.uiFont; font.pixelSize: 13 }
                }
            }
            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 15
                color: Config.Theme.islandRaised
                Column {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 6
                    Text { text: "Сеть · " + (performanceService.network.interface || "—"); color: Config.Theme.textMuted; font.family: Config.Theme.uiFont; font.pixelSize: 13 }
                    Text { text: "↓ " + root.formatRate(performanceService.network.rxBytesPerSecond || 0); color: Config.Theme.success; font.family: Config.Theme.monoFont; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: "↑ " + root.formatRate(performanceService.network.txBytesPerSecond || 0); color: Config.Theme.warning; font.family: Config.Theme.monoFont; font.pixelSize: 13 }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.top: summaries.bottom
            anchors.topMargin: 18
            text: "Активные процессы"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: summaries.bottom
            anchors.topMargin: 46
            spacing: 3
            Repeater {
                model: performanceService.processes
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 42
                    radius: 11
                    color: index % 2 === 0 ? Config.Theme.islandRaised : "transparent"
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 250; text: modelData.name + "  ·  " + modelData.pid; color: Config.Theme.text; font.family: Config.Theme.monoFont; font.pixelSize: 13; elide: Text.ElideRight }
                    Text { anchors.right: memoryText.left; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: Number(modelData.cpuPercent || 0).toFixed(1) + "% CPU"; color: Config.Theme.accent; font.family: Config.Theme.monoFont; font.pixelSize: 13 }
                    Text { id: memoryText; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 92; text: Number(modelData.memoryPercent || 0).toFixed(1) + "% RAM"; color: Config.Theme.textMuted; font.family: Config.Theme.monoFont; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }
}
