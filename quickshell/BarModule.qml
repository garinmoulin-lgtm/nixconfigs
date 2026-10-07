import QtQuick
import QtQuick.Layouts

// One waybar module. Defaults match your CSS for bordered modules:
//   padding: 2px 10px; margin: 2px 4px; border: 2px solid @rosewater;
// Set bordered: false (and zero paddings) for the plain custom/* style modules.
Item {
    id: root

    default property alias content: row.data
    property int hPadding: 10
    property int vPadding: 2
    property int hMargin: 4
    property int vMargin: 2
    property bool bordered: true
    property bool fillHeight: false
    property string tooltip: ""
    readonly property alias hovered: mouse.containsMouse
    readonly property alias box: box

    signal clicked(var mouse)
    signal scrolled(int delta) // > 0 = scroll up

    Layout.fillHeight: fillHeight
    implicitWidth: box.implicitWidth + hMargin * 2
    implicitHeight: box.implicitHeight + vMargin * 2

    // under the content, so child MouseAreas (tray icons) still get their own clicks
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }

    Rectangle {
        id: box
        readonly property int bw: root.bordered ? Theme.border : 0
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + root.hPadding * 2 + bw * 2
        implicitHeight: row.implicitHeight + root.vPadding * 2 + bw * 2
        radius: 8
        width: implicitWidth
        height: root.fillHeight ? root.height - root.vMargin * 2 : implicitHeight
        color: "transparent"
        border.width: bw
        border.color: Theme.rosewater

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 0
        }
    }

    Tooltip {
        target: box
        text: root.tooltip
        show: mouse.containsMouse
    }
}
