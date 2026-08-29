import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

Item {
    id: root

    property real contentLeftMargin: 58
    property bool concealed: false
    readonly property real workspaceContentWidth: workspaceRow.implicitWidth

    width: 790
    opacity: concealed ? 0 : 1
    enabled: !concealed

    Behavior on opacity {
        NumberAnimation { duration: Config.Theme.motionFast; easing.type: Easing.OutQuad }
    }

    RowLayout {
        id: clusterRow
        anchors.left: parent.left
        anchors.leftMargin: root.contentLeftMargin
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 6

        Row {
            id: workspaceRow
            Layout.preferredHeight: 38
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Repeater {
                model: Hyprland.workspaces?.values ?? []

                delegate: Item {
                    required property var modelData

                    width: modelData.id > 0 && modelData.id <= 10
                        ? (modelData.focused ? 34 : 16) : 0
                    height: parent.height
                    visible: width > 0

                    Behavior on width {
                        NumberAnimation {
                            duration: Config.Theme.motionNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: modelData.focused ? 26 : 7
                        height: 7
                        radius: height / 2
                        color: modelData.urgent
                            ? Config.Theme.danger
                            : (modelData.focused ? Config.Theme.accent : Config.Theme.textMuted)
                        opacity: modelData.focused || modelData.urgent ? 1 : 0.72

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.Theme.motionNormal
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Config.Theme.motionFast }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: Config.Theme.motionFast }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([
                            "hyprctl", "dispatch",
                            "hl.dsp.focus({ workspace = " + modelData.id + " })"
                        ])
                    }
                }
            }
        }

    }
}
