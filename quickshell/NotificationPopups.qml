import QtQuick
import Quickshell
import Quickshell.Wayland

// Floating notifications, top-right below the bar (swaync: positionX right, positionY top,
// layer overlay, width 500, transition-time 200). Hovering a popup pauses its timeout.
PanelWindow {
    id: root

    visible: Notifs.popups.length > 0
    anchors {
        top: true
        right: true
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    color: "transparent"
    implicitWidth: 500
    implicitHeight: Math.max(1, list.contentHeight)

    ListView {
        id: list
        anchors.fill: parent
        interactive: false
        model: ScriptModel {
            values: Notifs.popups
        }

        delegate: Item {
            id: row
            required property var modelData
            width: 500
            height: card.implicitHeight + 12 // .notification-row padding: 6px 12px

            NotificationCard {
                id: card
                x: 12
                y: 6
                width: 476
                notif: row.modelData
            }

            Timer {
                interval: Notifs.timeoutFor(row.modelData)
                running: interval > 0 && !card.hovered
                onTriggered: Notifs.removePopup(row.modelData)
            }
        }

        add: Transition {
            NumberAnimation { property: "x"; from: 500; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
