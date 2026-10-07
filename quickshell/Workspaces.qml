import QtQuick
import Quickshell
import Quickshell.Hyprland

// hyprland/workspaces: format "{id}", on-click "activate".
// Buttons: 2px rosewater border, padding 2px 7px, margin 0 3px, min-width 22px,
// active/urgent = rosewater fill with crust label, hover = 25% rosewater.
Row {
    id: root

    property var screen: null
    property int rowHeight: 30
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null

    leftPadding: 6
    rightPadding: 6
    height: rowHeight

    Repeater {
        model: Theme.toArray(Hyprland.workspaces.values).filter(w => w.id > 0 && (root.monitor === null || w.monitor === root.monitor))

        delegate: Item {
            id: ws
            required property var modelData
            readonly property bool lit: modelData.active || modelData.urgent

            width: btn.width + 6
            height: root.rowHeight

            Rectangle {
                id: btn
                anchors.centerIn: parent
                width: Math.max(22, label.implicitWidth) + 14 + Theme.border * 2
                radius: 8
                height: parent.height
                color: ws.lit ? Theme.rosewater : (area.containsMouse ? Theme.alpha(Theme.rosewater, 0.25) : "transparent")
                border.width: Theme.border
                border.color: Theme.rosewater

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: ws.modelData.id
                    color: ws.lit ? Theme.crust : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ws.modelData.activate()
                }
            }
        }
    }
}
