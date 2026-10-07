import QtQuick

// NEW: notification module. Left-click opens the notification center,
// right-click toggles Do Not Disturb. Same bordered style as the other modules.
BarModule {
    id: root

    tooltip: Notifs.dnd ? "Do Not Disturb" : "Notifications"

    onClicked: m => {
        if (m.button === Qt.RightButton)
            Notifs.dnd = !Notifs.dnd;
        else if (m.button === Qt.LeftButton)
            Notifs.toggleCenter();
    }

    BarText {
        text: Notifs.dnd ? "󰂛" : (Notifs.count > 0 ? "󰂚" : "󰂜")
        color: Theme.rosewater
    }
    BarText {
        text: " " + Notifs.count
    }
}
