import QtQuick
import "../config" as Config

Item {
    id: root

    property real outputLevel: 0
    property real inputLevel: 0
    property bool outputMuted: false
    property bool inputMuted: false
    property string icon: "\uf028"

    implicitWidth: 42
    implicitHeight: 30

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        text: root.icon
        color: root.outputMuted ? Config.Theme.danger : Qt.rgba(Config.Theme.text.r, Config.Theme.text.g, Config.Theme.text.b, 0.84)
        font.family: Config.Theme.monoFont
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        style: Text.Raised
        styleColor: Config.Theme.wallpaperOutline
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: [
                {
                    level: root.outputMuted ? 0 : root.outputLevel,
                    color: root.outputMuted ? Config.Theme.danger : Config.Theme.accent
                },
                {
                    level: root.inputMuted ? 0 : root.inputLevel,
                    color: root.inputMuted ? Config.Theme.danger : Config.Theme.textMuted
                }
            ]

            delegate: Rectangle {
                required property var modelData

                width: 3
                height: 16
                radius: 1.5
                color: Qt.rgba(Config.Theme.text.r, Config.Theme.text.g, Config.Theme.text.b, 0.13)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * Math.max(0.08, Math.min(1, modelData.level))
                    radius: parent.radius
                    color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.76)

                    Behavior on height {
                        NumberAnimation {
                            duration: Config.Theme.motionNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
