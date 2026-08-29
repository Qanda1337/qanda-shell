import QtQuick
import Quickshell
import Quickshell.Widgets
import "../config" as Config

PopupWindow {
    id: root

    required property Item anchorItem
    required property var menu
    property string title: ""
    property string icon: ""
    property bool menuVisible: false
    property int selectedIndex: -1

    visible: menuVisible
    implicitWidth: 190
    implicitHeight: Math.max(52, menuContent.implicitHeight + 16)
    color: "transparent"

    anchor.item: anchorItem
    anchor.rect.x: anchorItem.width - implicitWidth
    anchor.rect.y: anchorItem.height + 5

    function open() {
        closeTimer.stop();
        menuVisible = true;
        selectedIndex = firstEnabledIndex();
        Qt.callLater(() => menuFocus.forceActiveFocus());
    }

    function close() {
        menuVisible = false;
    }

    function scheduleClose() {
        closeTimer.restart();
    }

    function cancelClose() {
        closeTimer.stop();
    }

    function firstEnabledIndex() {
        for (let index = 0; index < menuOpener.children.length; ++index) {
            const entry = menuOpener.children[index];
            if (!entry.isSeparator && entry.enabled)
                return index;
        }
        return -1;
    }

    function moveSelection(offset) {
        const entries = menuOpener.children;
        if (entries.length === 0)
            return;
        let index = selectedIndex;
        for (let count = 0; count < entries.length; ++count) {
            index = (index + offset + entries.length) % entries.length;
            if (!entries[index].isSeparator && entries[index].enabled) {
                selectedIndex = index;
                return;
            }
        }
    }

    function activateSelected() {
        const entry = menuOpener.children[selectedIndex];
        if (!entry || entry.isSeparator || !entry.enabled)
            return;
        if (entry.hasChildren)
            entry.display(root, root.width, 8 + selectedIndex * 34);
        else {
            entry.triggered();
            close();
        }
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: root.close()
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.menu
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: Config.Theme.island
        border.width: 1
        border.color: Config.Theme.surfaceEdge

        FocusScope {
            id: menuFocus
            anchors.fill: parent
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onReturnPressed: root.activateSelected()
            Keys.onEnterPressed: root.activateSelected()
            Keys.onEscapePressed: root.close()
        }

        Column {
            id: menuContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 1

            Item {
                width: parent.width
                height: 34
                visible: root.title.length > 0

                IconImage {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17
                    height: 17
                    source: root.icon
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 27
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: Config.Theme.textMuted
                    font.family: Config.Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Config.Theme.surfaceEdge
                }
            }

            Repeater {
                model: menuOpener.children

                delegate: Item {
                    id: menuEntry

                    required property var modelData
                    required property int index

                    width: menuContent.width
                    height: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        visible: menuEntry.modelData.isSeparator
                        color: Qt.rgba(Config.Theme.textMuted.r, Config.Theme.textMuted.g, Config.Theme.textMuted.b, 0.18)
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !menuEntry.modelData.isSeparator
                        radius: 9
                        color: (entryMouse.containsMouse || root.selectedIndex === menuEntry.index) && menuEntry.modelData.enabled
                            ? (root.selectedIndex === menuEntry.index ? Config.Theme.surfaceActive : Config.Theme.surfaceHover)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Config.Theme.motionFast }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        visible: !menuEntry.modelData.isSeparator
                        text: menuEntry.modelData.checkState === Qt.Checked ? "✓" : ""
                        color: Config.Theme.accent
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    IconImage {
                        anchors.left: parent.left
                        anchors.leftMargin: 25
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: 15
                        visible: !menuEntry.modelData.isSeparator && source.toString().length > 0
                        source: menuEntry.modelData.icon
                        opacity: menuEntry.modelData.enabled ? 1 : 0.4
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: menuEntry.modelData.icon ? 48 : 27
                        anchors.right: submenuArrow.left
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !menuEntry.modelData.isSeparator
                        text: menuEntry.modelData.text
                        color: menuEntry.modelData.enabled ? Config.Theme.text : Config.Theme.textMuted
                        opacity: menuEntry.modelData.enabled ? 1 : 0.45
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        id: submenuArrow
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        visible: !menuEntry.modelData.isSeparator && menuEntry.modelData.hasChildren
                        text: "›"
                        color: Config.Theme.textMuted
                        font.family: Config.Theme.uiFont
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        enabled: !menuEntry.modelData.isSeparator && menuEntry.modelData.enabled
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.selectedIndex = menuEntry.index;
                            if (menuEntry.modelData.hasChildren) {
                                menuEntry.modelData.display(root, menuEntry.x + menuEntry.width, menuEntry.y);
                            } else {
                                menuEntry.modelData.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: hovered ? root.cancelClose() : root.scheduleClose()
    }
}
