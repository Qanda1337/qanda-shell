import QtQuick
import "../config" as Config

Item {
    id: root

    property real ratio: 0
    property string icon: ""
    property color fillColor: Config.Theme.accent
    property real animatedRatio: ratio

    implicitWidth: 30
    implicitHeight: 30

    Behavior on animatedRatio {
        NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutCubic }
    }

    onAnimatedRatioChanged: gauge.requestPaint()
    onFillColorChanged: gauge.requestPaint()

    Canvas {
        id: gauge
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.FramebufferObject

        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const cx = width / 2;
            const cy = height / 2;
            const radius = 12;
            const start = Math.PI * 0.75;
            const span = Math.PI * 1.5;

            ctx.reset();
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.strokeStyle = Config.Theme.track;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, start, start + span);
            ctx.stroke();

            if (root.animatedRatio > 0.005) {
                ctx.strokeStyle = root.fillColor;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, start, start + span * Math.max(0, Math.min(1, root.animatedRatio)));
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.icon
        color: Config.Theme.text
        font.family: Config.Theme.monoFont
        font.pixelSize: 13
        style: Text.Outline
        styleColor: Config.Theme.wallpaperOutline
    }
}
