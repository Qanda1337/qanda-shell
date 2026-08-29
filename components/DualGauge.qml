import QtQuick
import "../config" as Config

Item {
    id: root

    property real outerRatio: 0
    property real innerRatio: 0
    property string icon: ""
    property color outerColor: Config.Theme.accent
    property color innerColor: Config.Theme.textMuted

    property real animatedOuter: outerRatio
    property real animatedInner: innerRatio

    implicitWidth: 34
    implicitHeight: 34

    Behavior on animatedOuter {
        NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutCubic }
    }

    Behavior on animatedInner {
        NumberAnimation { duration: Config.Theme.motionNormal; easing.type: Easing.OutCubic }
    }

    onAnimatedOuterChanged: gauge.requestPaint()
    onAnimatedInnerChanged: gauge.requestPaint()
    onOuterColorChanged: gauge.requestPaint()
    onInnerColorChanged: gauge.requestPaint()

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
            const start = Math.PI * 0.75;
            const span = Math.PI * 1.5;

            ctx.reset();
            ctx.lineCap = "round";

            function arc(radius, lineWidth, ratio, color) {
                ctx.lineWidth = lineWidth;
                ctx.strokeStyle = Config.Theme.track;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, start, start + span);
                ctx.stroke();

                if (ratio > 0.005) {
                    ctx.strokeStyle = color;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, start, start + span * Math.max(0, Math.min(1, ratio)));
                    ctx.stroke();
                }
            }

            arc(14, 2.4, root.animatedOuter, root.outerColor);
            arc(10, 1.5, root.animatedInner, root.innerColor);
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
