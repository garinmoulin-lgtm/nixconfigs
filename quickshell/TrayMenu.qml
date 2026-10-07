import QtQuick
import Quickshell

// Tray context menu, styled like your waybar CSS:
//   menu { background: @crust; border: 1px solid @rosewater; padding: 6px }
//   menuitem { color: @rosewater; padding: 4px 12px }  :hover { background: @rosewater; color: @crust }
PopupWindow {
    id: root

    required property Item target
    property var handle: null
    property var stack: []   // submenus entered so far

    visible: false
    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    color: "transparent"
    implicitWidth: Math.max(180, list.implicitWidth) + 14
    implicitHeight: list.implicitHeight + 14

    onVisibleChanged: if (!visible) stack = []

    QsMenuOpener {
        id: opener
        menu: root.stack.length > 0 ? root.stack[root.stack.length - 1] : root.handle
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.crust
        border.width: 1
        border.color: Theme.rosewater

        Column {
            id: list
            x: 7
            y: 7
            width: root.width - 14

            // back row while inside a submenu
            MenuRow {
                visible: root.stack.length > 0
                label: "󰅁  Back"
                onActivated: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children ? opener.children.values : []

                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    implicitWidth: entryRow.implicitWidth
                    height: modelData.isSeparator ? 9 : entryRow.height

                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.rosewater, 0.3)
                    }

                    MenuRow {
                        id: entryRow
                        visible: !row.modelData.isSeparator
                        width: parent.width
                        enabled: row.modelData.enabled
                        hasChildren: row.modelData.hasChildren
                        label: {
                            let prefix = "";
                            if (row.modelData.buttonType === QsMenuButtonType.CheckBox)
                                prefix = row.modelData.checkState === Qt.Checked ? "󰄲  " : "󰄱  ";
                            else if (row.modelData.buttonType === QsMenuButtonType.RadioButton)
                                prefix = row.modelData.checkState === Qt.Checked ? "󰐾  " : "󰄯  ";
                            return prefix + row.modelData.text.replace(/_([^_])/g, "$1");
                        }
                        onActivated: {
                            if (row.modelData.hasChildren) {
                                root.stack = root.stack.concat([row.modelData]);
                            } else {
                                row.modelData.triggered();
                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: mrow
        property string label: ""
        property bool hasChildren: false
        signal activated

        implicitWidth: lbl.implicitWidth + 24 + (hasChildren ? 20 : 0)
        height: lbl.implicitHeight + 8
        width: parent ? parent.width : implicitWidth
        color: area.containsMouse && enabled ? Theme.rosewater : "transparent"
        opacity: enabled ? 1 : 0.5

        Behavior on color {
            ColorAnimation { duration: 200 }
        }

        Text {
            id: lbl
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: mrow.label
            color: area.containsMouse && mrow.enabled ? Theme.crust : Theme.rosewater
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        Text {
            visible: mrow.hasChildren
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅂"
            color: lbl.color
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: mrow.enabled
            onClicked: mrow.activated()
        }
    }
}
