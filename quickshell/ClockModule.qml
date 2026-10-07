import QtQuick
import Quickshell

// clock: "󰥔 {:%I:%M %p 󰃮 %B %d, %Y}", click toggles format-alt "󰥔 {:%I:%M %p}",
// hover shows the month calendar, scroll shifts it (shift_up / shift_down).
BarModule {
    id: root

    property bool alt: false
    property int monthOffset: 0

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.alt = !root.alt;
    }
    onScrolled: delta => root.monthOffset += delta > 0 ? 1 : -1
    onHoveredChanged: if (!hovered) monthOffset = 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarText { text: " 󰥔 "; color: Theme.rosewater }
    BarText {
        text: root.alt
            ? Qt.formatDateTime(clock.date, "hh:mm AP")
            : Qt.formatDateTime(clock.date, "hh:mm AP") + " 󰃮 " + Qt.formatDateTime(clock.date, "MMMM dd, yyyy")
    }

    CalendarPopup {
        target: root.box
        show: root.hovered
        date: clock.date
        offset: root.monthOffset
    }
}
