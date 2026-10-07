import QtQuick
import Quickshell

// waybar tooltip: background @base, 2px rosewater border, square corners.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool show: false
    property bool armed: false

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: armed && show && text !== ""
    color: "transparent"
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12

    onShowChanged: if (!show) armed = false

    Timer {
        interval: 400
        running: root.show && !root.armed
        onTriggered: root.armed = true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        border.width: Theme.border
        border.color: Theme.rosewater

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
