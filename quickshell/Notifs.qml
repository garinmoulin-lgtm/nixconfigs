pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon (replaces swaync). Quickshell owns org.freedesktop.Notifications;
// the popups, the center and the bar module all read from here.
Singleton {
    id: root

    property bool dnd: false
    property bool centerOpen: false
    property var popups: []
    property var times: ({})
    property real now: Date.now()

    readonly property var list: Theme.toArray(server.trackedNotifications.values)
    readonly property int count: list.length

    // swaync: timeout = 10, timeout-low = 5, timeout-critical = 0 (never)
    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        return n.urgency === NotificationUrgency.Low ? 5000 : 10000;
    }

    // swaync: relative-timestamps = true
    function ago(n) {
        const t = root.times[n.id];
        if (t === undefined)
            return "";
        const mins = Math.floor((root.now - t) / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return mins + " min ago";
        const hours = Math.floor(mins / 60);
        return hours + (hours === 1 ? " hour ago" : " hours ago");
    }

    function removePopup(n) {
        root.popups = root.popups.filter(p => p !== n);
    }

    function clearAll() {
        const all = root.list.slice();
        for (const n of all)
            n.dismiss();
        root.popups = [];
    }

    function toggleCenter() {
        root.centerOpen = !root.centerOpen;
        if (root.centerOpen)
            root.popups = [];
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const t = Object.assign({}, root.times);
            t[n.id] = Date.now();
            root.times = t;
            n.closed.connect(function () {
                root.removePopup(n);
            });
            if (!root.dnd && !root.centerOpen)
                root.popups = root.popups.concat([n]);
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Keybinds / scripts:  qs ipc call notifs toggle | toggleDnd | clear
    IpcHandler {
        target: "notifs"

        function toggle(): void {
            root.toggleCenter();
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function clear(): void {
            root.clearAll();
        }
    }
}
