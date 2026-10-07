import QtQuick
import Quickshell

// The clock tooltip: "<big>{:%Y %B}</big>" + month grid, weeks on the right ("W{}"),
// everything Rosewater, today bold + underlined.
PopupWindow {
    id: root

    required property Item target
    property bool show: false
    property bool armed: false
    property date date: new Date()
    property int offset: 0

    readonly property date shown: new Date(date.getFullYear(), date.getMonth() + offset, 1)
    readonly property var weeks: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - first.getDay()); // weeks start on Sunday
        const rows = [];
        for (let w = 0; w < 6; w++) {
            const days = [];
            for (let d = 0; d < 7; d++) {
                const day = new Date(start);
                day.setDate(start.getDate() + w * 7 + d);
                days.push(day);
            }
            if (w > 3 && days[0].getMonth() !== shown.getMonth())
                break;
            rows.push(days);
        }
        return rows;
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dayNum = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: armed && show
    color: "transparent"
    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 20

    onShowChanged: if (!show) armed = false

    Timer {
        interval: 400
        running: root.show && !root.armed
        onTriggered: root.armed = true
    }

    component Cell: Text {
        property bool bold: false
        width: 30
        horizontalAlignment: Text.AlignRight
        color: Theme.rosewater
        font.family: Theme.font
        font.pixelSize: 12 // <small>
        font.bold: bold
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        border.width: Theme.border
        border.color: Theme.rosewater

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: Qt.formatDateTime(root.shown, "yyyy MMMM")
                color: Theme.rosewater
                font.family: Theme.font
                font.pixelSize: 17 // <big>
                font.bold: true
            }

            Row {
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Cell {
                        required property var modelData
                        text: modelData
                        bold: true
                    }
                }
                Cell { width: 44; text: "" }
            }

            Repeater {
                model: root.weeks

                Row {
                    id: week
                    required property var modelData

                    Repeater {
                        model: week.modelData

                        Cell {
                            required property var modelData
                            readonly property bool inMonth: modelData.getMonth() === root.shown.getMonth()
                            readonly property bool today: modelData.toDateString() === root.date.toDateString()
                            text: inMonth ? modelData.getDate() : ""
                            bold: today
                            font.underline: today
                        }
                    }

                    Cell {
                        width: 44
                        text: "W" + root.isoWeek(week.modelData[1])
                        bold: true
                    }
                }
            }
        }
    }
}
