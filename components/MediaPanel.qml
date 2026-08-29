import QtQuick
import Quickshell.Services.Mpris
import "../config" as Config

FocusScope {
    id: root

    required property var player
    required property var mediaService

    signal hoveredChanged(bool hovered)
    signal closeRequested()
    property int selectedIndex: 1

    function activateSelected() {
        if (selectedIndex === 0 && (player?.canGoPrevious ?? false))
            player.previous();
        else if (selectedIndex === 1 && (player?.canTogglePlaying ?? false))
            player.togglePlaying();
        else if (selectedIndex === 2 && (player?.canGoNext ?? false))
            player.next();
    }

    Keys.onLeftPressed: selectedIndex = (selectedIndex + 2) % 3
    Keys.onRightPressed: selectedIndex = (selectedIndex + 1) % 3
    Keys.onReturnPressed: activateSelected()
    Keys.onEnterPressed: activateSelected()
    Keys.onEscapePressed: mediaService.close()
    onVisibleChanged: if (visible && mediaService.isOpen) {
        selectedIndex = 1;
        Qt.callLater(() => forceActiveFocus());
    }

    function formatDuration(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const minutes = Math.floor(seconds / 60);
        const remainder = Math.floor(seconds % 60);
        return minutes + ":" + String(remainder).padStart(2, "0");
    }

    component ControlButton: Rectangle {
        id: button

        property string icon: ""
        property bool primary: false
        property bool available: true
        property bool selected: false
        signal triggered()

        width: primary ? 40 : 32
        height: width
        radius: width / 2
        color: primary
            ? Config.Theme.text
            : (selected ? Config.Theme.surfaceActive : (hoverArea.containsMouse ? Config.Theme.surfaceHover : "transparent"))
        scale: primary && selected ? 1.08 : 1
        opacity: available ? 1 : 0.28

        Behavior on color {
            ColorAnimation { duration: Config.Theme.motionFast }
        }
        Behavior on scale {
            NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: button.icon === "\uf04b" ? 1 : 0
            text: button.icon
            color: button.primary ? Config.Theme.island : Config.Theme.text
            font.family: Config.Theme.monoFont
            font.pixelSize: button.primary ? 14 : 13
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: button.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.triggered()
        }
    }

    Timer {
        interval: 1000
        running: root.visible && root.player?.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Rectangle {
        id: artworkFrame
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 17
        width: 122
        height: 122
        radius: 20
        color: Config.Theme.islandRaised
        border.width: 1
        border.color: Config.Theme.surfaceEdge
        clip: true

        Text {
            anchors.centerIn: parent
            text: "\uf001"
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 30
            visible: artwork.status !== Image.Ready
        }

        Image {
            id: artwork
            anchors.fill: parent
            source: root.player?.trackArtUrl || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }
    }

    Column {
        anchors.left: artworkFrame.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 18
        spacing: 3

        Text {
            width: parent.width
            text: root.player?.trackTitle || "Неизвестный трек"
            color: Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.player?.trackArtist || root.player?.identity || "Неизвестный исполнитель"
            color: Config.Theme.textMuted
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.player?.trackAlbum || root.player?.identity || "Медиаплеер"
            color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.68)
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    Item {
        anchors.left: artworkFrame.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 82
        height: 20

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 4
            radius: 2
            color: Config.Theme.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (root.player?.position || 0) / Math.max(1, root.player?.length || 1)))
                height: parent.height
                radius: parent.radius
                color: Config.Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                enabled: (root.player?.canSeek ?? false) && (root.player?.positionSupported ?? false)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.player.position = (mouse.x / width) * root.player.length
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: root.formatDuration(root.player?.position || 0)
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.formatDuration(root.player?.length || 0)
            color: Config.Theme.textMuted
            font.family: Config.Theme.monoFont
            font.pixelSize: 13
        }
    }

    Row {
        anchors.left: artworkFrame.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: artworkFrame.bottom
        height: 40
        spacing: 12

        Item { width: Math.max(0, (parent.width - 128) / 2); height: 1 }

        ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "\uf048"
            available: root.player?.canGoPrevious ?? false
            selected: root.selectedIndex === 0
            onTriggered: root.player.previous()
        }

        ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            primary: true
            icon: root.player?.playbackState === MprisPlaybackState.Playing ? "\uf04c" : "\uf04b"
            available: root.player?.canTogglePlaying ?? false
            selected: root.selectedIndex === 1
            onTriggered: root.player.togglePlaying()
        }

        ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "\uf051"
            available: root.player?.canGoNext ?? false
            selected: root.selectedIndex === 2
            onTriggered: root.player.next()
        }
    }

    HoverHandler {
        onHoveredChanged: root.hoveredChanged(hovered)
    }
}
