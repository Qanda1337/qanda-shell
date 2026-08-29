import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../config" as Config

FocusScope {
    id: root

    required property var wallpaperService
    readonly property int preferredHeight: 274

    focus: visible
    Keys.onLeftPressed: wallpaperService.move(-1)
    Keys.onRightPressed: wallpaperService.move(1)
    Keys.onReturnPressed: wallpaperService.applySelected()
    Keys.onEnterPressed: wallpaperService.applySelected()
    Keys.onEscapePressed: wallpaperService.close()
    onVisibleChanged: if (visible) Qt.callLater(() => forceActiveFocus())

    function fileName(path) {
        if (!path)
            return "Обои не выбраны";
        const parts = path.split("/");
        return parts[parts.length - 1].replace(/\.[^.]+$/, "");
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.top: parent.top
        anchors.topMargin: 15
        spacing: 9

        Text {
            text: "\uf03e"
            color: Config.Theme.accent
            font.family: Config.Theme.monoFont
            font.pixelSize: 14
        }

        Column {
            spacing: 1

            Text {
                width: 420
                text: root.fileName(wallpaperService.selectedWallpaper)
                color: Config.Theme.text
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                text: wallpaperService.wallpapers.length > 0
                    ? (wallpaperService.selectedIndex + 1) + " из " + wallpaperService.wallpapers.length + "  ·  ← → выбрать  ·  Enter применить"
                    : "Загрузка коллекции…"
                color: Config.Theme.textMuted
                font.family: Config.Theme.uiFont
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        id: applyButton
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 92
        height: 30
        radius: 11
        color: applyMouse.containsMouse ? Config.Theme.accent : Config.Theme.islandRaised

        Behavior on color { ColorAnimation { duration: Config.Theme.motionFast } }

        Text {
            anchors.centerIn: parent
            text: "Применить"
            color: applyMouse.containsMouse ? Config.Theme.island : Config.Theme.text
            font.family: Config.Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: applyMouse
            anchors.fill: parent
            enabled: wallpaperService.wallpapers.length > 0 && !wallpaperService.applying
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: wallpaperService.applySelected()
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 54
        height: 1
        color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.18)
    }

    ListView {
        id: carousel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 65
        anchors.bottomMargin: 14
        orientation: ListView.Horizontal
        spacing: -24
        clip: true
        model: wallpaperService.wallpapers
        currentIndex: wallpaperService.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Config.Theme.motionNormal
        cacheBuffer: 420

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== wallpaperService.selectedIndex)
                wallpaperService.select(currentIndex);
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Center);
        }

        Connections {
            target: wallpaperService
            function onSelectedIndexChanged() {
                carousel.positionViewAtIndex(wallpaperService.selectedIndex, ListView.Center);
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                wallpaperService.move(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1);
                event.accepted = true;
            }
        }

        delegate: Item {
            id: frame

            required property string modelData
            required property int index
            readonly property bool selected: index === wallpaperService.selectedIndex

            width: selected ? 218 : 158
            height: carousel.height
            z: selected ? 10 : 1

            Behavior on width {
                NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
            }

            Item {
                id: picture
                anchors.horizontalCenter: parent.horizontalCenter
                y: frame.selected ? 0 : 14
                width: parent.width
                height: frame.selected ? parent.height : parent.height - 28

                Behavior on y {
                    NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
                }

                Behavior on height {
                    NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
                }

                Image {
                    id: sourceImage
                    anchors.fill: parent
                    source: frame.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: false
                }

                Shape {
                    id: imageMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillColor: "white"
                        startX: 24
                        startY: 0
                        PathLine { x: imageMask.width; y: 0 }
                        PathLine { x: imageMask.width - 24; y: imageMask.height }
                        PathLine { x: 0; y: imageMask.height }
                        PathLine { x: 24; y: 0 }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: sourceImage
                    maskEnabled: true
                    maskSource: imageMask
                    brightness: frame.selected ? 0.08 : -0.26
                    saturation: frame.selected ? 0.12 : -0.32

                    Behavior on brightness {
                        NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
                    }

                    Behavior on saturation {
                        NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutQuart }
                    }
                }

                Shape {
                    id: separatorShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.rgba(Config.Theme.island.r, Config.Theme.island.g, Config.Theme.island.b, 0.92)
                        fillColor: "transparent"
                        startX: separatorShape.width
                        startY: 0
                        PathLine { x: separatorShape.width - 24; y: separatorShape.height }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: currentMark.implicitWidth + 12
                    height: 21
                    radius: 8
                    color: Config.Theme.island
                    visible: frame.modelData === wallpaperService.currentWallpaper

                    Text {
                        id: currentMark
                        anchors.centerIn: parent
                        text: "Сейчас"
                        color: Config.Theme.text
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperService.select(frame.index)
                    onDoubleClicked: {
                        wallpaperService.select(frame.index);
                        wallpaperService.applySelected();
                    }
                }
            }
        }
    }
}
