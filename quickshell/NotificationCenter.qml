import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Notification center (was swaync's control center): 500x600 at the top-right,
// background rgba(base, 1), widgets: title + Clear All, Do Not Disturb, the list.
// Click outside or press Escape to close.
PanelWindow {
    id: root

    visible: Notifs.centerOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    // click-away
    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.centerOpen = false
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        width: 500
        height: Math.min(600, parent.height)
        color: Theme.alpha(Theme.base, 1)
        border.width: 2
        border.color: Theme.overlay1
        radius: 8
        focus: true
        Keys.onEscapePressed: Notifs.centerOpen = false

        // keep clicks inside the panel from closing it
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // widget-title: "Notifications" + Clear All
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16 // .widget { margin: 8px; padding: 8px }

                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.rosewater
                    font.family: Theme.uiFont
                    font.pixelSize: 22 // 1.5rem
                }

                Rectangle {
                    implicitWidth: clearLabel.implicitWidth + 24
                    implicitHeight: clearLabel.implicitHeight + 12
                    color: clearArea.containsMouse ? Theme.surface1 : Theme.surface0

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Theme.rosewater
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Notifs.clearAll()
                    }
                }
            }

            // widget-dnd: "Do Not Disturb" + switch
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 16

                Text {
                    Layout.fillWidth: true
                    text: "Do Not Disturb"
                    color: Theme.rosewater
                    font.family: Theme.uiFont
                    font.pixelSize: 16 // 1.1rem
                }

                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 24
                    radius: 12
                    color: Notifs.dnd ? Theme.rosewater : Theme.surface1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        y: 3
                        x: Notifs.dnd ? parent.width - width - 3 : 3
                        color: Notifs.dnd ? Theme.crust : Theme.text

                        Behavior on x {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
            }

            // the list (newest first)
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: ScriptModel {
                    values: Notifs.list.slice().reverse()
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    height: card.implicitHeight + 12

                    NotificationCard {
                        id: card
                        x: 12
                        y: 6
                        width: parent.width - 24
                        notif: row.modelData
                    }
                }

                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Notifs.count === 0
                    text: "No Notifications"
                    opacity: 0.5
                    color: Theme.rosewater
                    font.family: Theme.uiFont
                    font.pixelSize: 16
                }
            }
        }
    }
}
