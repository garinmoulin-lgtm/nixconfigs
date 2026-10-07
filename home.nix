{ config, pkgs, lib, ... }:

{
  home.username = "garinh";
  home.homeDirectory = "/home/garinh";


  programs.home-manager.enable = true;

  # ── Quickshell: bar + notifications (replaces waybar and swaync) ─────────────
  # Started from the Hyprland autostart with hl.exec_cmd("qs").
  # Notification center from a keybind/script:  qs ipc call notifs toggle
  programs.quickshell.enable = true;

  xdg.configFile."quickshell/shell.qml".text = ''
    import QtQuick
    import Quickshell

    // Entry point: one bar per monitor, plus notification popups and the notification center.
    ShellRoot {
        Variants {
            model: Quickshell.screens

            Bar {}
        }

        NotificationPopups {}
        NotificationCenter {}
    }
  '';

  xdg.configFile."quickshell/Bar.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Wayland

    // The bar (was waybar). margin-top 8, margin-left/right 10, layer top.
    // Outer box: background @base, 2px @subtext0 border, padding 2px 6px, square corners.
    PanelWindow {
        id: bar

        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: 8
            left: 10
            right: 10
        }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-bar"
        color: "transparent"
        implicitHeight: frame.implicitHeight

        // modules-left / -center / -right sit 1px apart (waybar "spacing = 1")
        readonly property int rowHeight: memory.implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: Math.max(left.implicitHeight, center.implicitHeight, right.implicitHeight) + (2 + Theme.border) * 2
            color: Theme.base
            border.width: Theme.border
            border.color: Theme.subtext0

            // modules-left: group/hardware, hyprland/workspaces, hyprland/window
            RowLayout {
                id: left
                anchors.left: parent.left
                anchors.leftMargin: Theme.border + 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                RowLayout {
                    spacing: 0
                    PowerProfileModule {}
                    MemoryModule { id: memory }
                    CpuModule {}
                    DiskModule {}
                }

                Workspaces {
                    screen: bar.screen
                    rowHeight: bar.rowHeight
                }

                WindowTitle {}
            }

            // modules-center: group/media-player, custom/media-time, tray
            RowLayout {
                id: center
                anchors.centerIn: parent
                height: bar.rowHeight
                spacing: 1

                MediaModule {}
                TrayModule {}
            }

            // modules-right: notifications (new), clock, wireplumber#sink, network, group/session
            RowLayout {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: Theme.border + 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                NotifModule {}
                ClockModule {}
                VolumeModule {}
                NetworkModule {}
                SessionModule {}
            }
        }
    }
  '';

  xdg.configFile."quickshell/BarModule.qml".text = ''
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
  '';

  xdg.configFile."quickshell/BarText.qml".text = ''
    import QtQuick

    // Plain text in the bar font. Plain (not rich) text so the spacing inside
    // your waybar format strings is preserved exactly.
    Text {
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
    }
  '';

  xdg.configFile."quickshell/CalendarPopup.qml".text = ''
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
  '';

  xdg.configFile."quickshell/ClockModule.qml".text = ''
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
  '';

  xdg.configFile."quickshell/CpuModule.qml".text = ''
    import QtQuick
    import Quickshell

    // cpu: "󰘚 {usage}%", interval 1, click opens btop
    BarModule {
        onClicked: m => {
            if (m.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "-e", "btop"]);
        }

        BarText { text: "󰘚"; color: Theme.rosewater }
        BarText { text: " " + SysInfo.cpuUsage + "%" }
    }
  '';

  xdg.configFile."quickshell/DiskModule.qml".text = ''
    import QtQuick

    // disk: "󰋊 {percentage_used}%", path "/", interval 30
    BarModule {
        BarText { text: "󰋊"; color: Theme.rosewater }
        BarText { text: " " + SysInfo.diskUsed + "%" }
    }
  '';

  xdg.configFile."quickshell/MediaModule.qml".text = ''
    import QtQuick
    import QtQuick.Layouts

    // group/media-player [custom/media, custom/media-prev, custom/media-next] + custom/media-time
    RowLayout {
        id: root
        spacing: 1

        readonly property bool controls: Player.status === "Playing" || Player.status === "Paused"
        readonly property var icon: ({
            "Playing": { glyph: " 󰏦 ", color: Theme.green },
            "Paused": { glyph: " 󰐍 ", color: Theme.yellow },
            "Stopped": { glyph: " 󰝛 ", color: Theme.red }
        })

        function truncate(t, n) {
            return t.length > n ? t.slice(0, n - 1) + "…" : t;
        }

        RowLayout {
            spacing: 0

            // custom/media: ' {icon} {text} '  (max-length 25)
            BarModule {
                bordered: false
                hPadding: 0
                vPadding: 0
                hMargin: 0
                vMargin: 0
                tooltip: Player.hasMedia ? Player.active.identity + " : " + Player.title : "No media"
                onClicked: if (Player.active) Player.active.togglePlaying()
                onScrolled: delta => {
                    if (!Player.active)
                        return;
                    if (delta > 0)
                        Player.active.next();
                    else
                        Player.active.previous();
                }

                BarText { text: " " }
                BarText {
                    text: root.icon[Player.status].glyph
                    color: root.icon[Player.status].color
                    font.pixelSize: Math.round(Theme.fontSize * 1.2) // pango "large"
                }
                BarText {
                    text: " " + root.truncate(Player.hasMedia ? Player.title : "Nothing playing", 25) + " "
                }
            }

            // custom/media-prev
            BarModule {
                visible: root.controls
                bordered: false
                hPadding: 0
                vPadding: 0
                hMargin: 0
                vMargin: 0
                onClicked: Player.active.previous()

                BarText { text: "  󰼥  "; color: Theme.rosewater }
            }

            // custom/media-next
            BarModule {
                visible: root.controls
                bordered: false
                hPadding: 0
                vPadding: 0
                hMargin: 0
                vMargin: 0
                onClicked: Player.active.next()

                BarText { text: "  󰼦  "; color: Theme.rosewater }
            }
        }

        // custom/media-time: '  {} '  (hidden when empty, like waybar)
        BarText {
            visible: Player.timeText !== ""
            text: "  " + Player.timeText + " "
        }
    }
  '';

  xdg.configFile."quickshell/MemoryModule.qml".text = ''
    import QtQuick
    import Quickshell

    // memory: "󰍛 {used:0.1f}GiB", interval 1, click opens btop
    BarModule {
        onClicked: m => {
            if (m.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "-e", "btop"]);
        }

        BarText { text: "󰍛"; color: Theme.rosewater }
        BarText { text: " " + SysInfo.memUsedGiB.toFixed(1) + "GiB" }
    }
  '';

  xdg.configFile."quickshell/NetInfo.qml".text = ''
    pragma Singleton
    import QtQuick
    import Quickshell
    import Quickshell.Io

    // NetworkManager state via nmcli. `nmcli monitor` pushes changes, so this only
    // re-queries when something actually changes (plus a slow refresh for wifi signal).
    Singleton {
        id: root

        property string type: ""      // "ethernet", "wifi" or "" (disconnected)
        property string ifname: ""
        property bool linked: false   // link up but no IP yet
        property string ssid: ""
        property int signal: 0
        property string ip: ""        // "192.168.1.5/24"
        readonly property string ipOnly: ip.split("/")[0]

        // nmcli -t escapes ':' inside fields as '\:'
        function splitTerse(line) {
            const out = [];
            let cur = "";
            for (let i = 0; i < line.length; i++) {
                const c = line[i];
                if (c === "\\" && i + 1 < line.length) {
                    cur += line[i + 1];
                    i++;
                } else if (c === ":") {
                    out.push(cur);
                    cur = "";
                } else {
                    cur += c;
                }
            }
            out.push(cur);
            return out;
        }

        function refresh() {
            devices.running = true;
        }

        Process {
            id: devices
            command: ["nmcli", "-t", "-f", "TYPE,STATE,DEVICE", "device"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const rows = this.text.trim().split("\n").map(l => root.splitTerse(l));
                    const up = s => s.indexOf("connected") === 0 && s.indexOf("disconnected") !== 0;
                    const pick = rows.find(r => r[0] === "ethernet" && (up(r[1]) || r[1].indexOf("connecting") === 0))
                              || rows.find(r => r[0] === "wifi" && (up(r[1]) || r[1].indexOf("connecting") === 0));
                    if (!pick) {
                        root.type = "";
                        root.ifname = "";
                        root.ip = "";
                        return;
                    }
                    root.type = pick[0];
                    root.ifname = pick[2];
                    root.linked = pick[1].indexOf("connecting") === 0;
                    address.running = true;
                    if (root.type === "wifi")
                        wifi.running = true;
                }
            }
        }

        Process {
            id: wifi
            command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const row = this.text.trim().split("\n").map(l => root.splitTerse(l)).find(r => r[0] === "yes");
                    root.signal = row ? Number(row[1]) : 0;
                    root.ssid = row ? row[2] : "";
                }
            }
        }

        Process {
            id: address
            command: ["ip", "-4", "-o", "addr", "show", "dev", root.ifname]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = this.text.match(/inet (\S+)/);
                    root.ip = m ? m[1] : "";
                }
            }
        }

        Process {
            running: true
            command: ["nmcli", "monitor"]
            stdout: SplitParser {
                onRead: _ => debounce.restart()
            }
        }

        Timer {
            id: debounce
            interval: 300
            onTriggered: root.refresh()
        }

        Timer {
            interval: 30000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: root.refresh()
        }
    }
  '';

  xdg.configFile."quickshell/NetworkModule.qml".text = ''
    import QtQuick
    import Quickshell

    // network: ethernet "󰈀 {ifname}", wifi "󰖩 {essid} ({signalStrength}%) ",
    // linked "(No IP)", disconnected red "󰖪 Disconnected".
    // click toggles format-alt "{ifname}: {ipaddr}/{cidr}", right-click opens nmtui.
    BarModule {
        id: root

        property bool alt: false

        tooltip: NetInfo.type === "" ? "" : NetInfo.ifname + ": " + NetInfo.ipOnly

        onClicked: m => {
            if (m.button === Qt.RightButton)
                Quickshell.execDetached(["kitty", "-e", "nmtui"]);
            else if (m.button === Qt.LeftButton)
                root.alt = !root.alt;
        }

        // format-alt has no color spans, so it renders in the module color (Rosewater)
        BarText {
            visible: root.alt && NetInfo.type !== ""
            text: NetInfo.ifname + ": " + NetInfo.ip
            color: Theme.rosewater
        }

        BarText {
            visible: !root.alt || NetInfo.type === ""
            text: NetInfo.type === "wifi" ? "󰖩" : (NetInfo.type === "ethernet" ? "󰈀" : "󰖪")
            color: NetInfo.type === "" ? Theme.red : Theme.rosewater
        }
        BarText {
            visible: !root.alt || NetInfo.type === ""
            text: {
                if (NetInfo.type === "")
                    return " Disconnected";
                if (NetInfo.type === "wifi")
                    return " " + NetInfo.ssid + " (" + NetInfo.signal + "%) ";
                return " " + NetInfo.ifname + (NetInfo.linked ? " (No IP)" : "");
            }
        }
    }
  '';

  xdg.configFile."quickshell/NotifModule.qml".text = ''
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
  '';

  xdg.configFile."quickshell/NotificationCard.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Services.Notifications

    // One notification, styled from your swaync CSS:
    //   background rgba(base, 0.8); border 1px rgba(rosewater, 0.15); hover @surface0
    //   summary 16px bold, body 15px, text Rosewater; image 64px; 24px close button (@surface1)
    Rectangle {
        id: card

        required property var notif
        readonly property bool hovered: hover.hovered
        readonly property var actions: Theme.toArray(notif.actions)
        readonly property var defaultAction: actions.find(a => a.identifier === "default") || null
        readonly property var extraActions: actions.filter(a => a.identifier !== "default")
        readonly property string iconSource: {
            const img = notif.image;
            if (img !== "")
                return img;
            const ic = notif.appIcon;
            if (ic === "")
                return "";
            if (ic.startsWith("/"))
                return "file://" + ic;
            if (ic.startsWith("file://") || ic.startsWith("image://"))
                return ic;
            return Quickshell.iconPath(ic, true);
        }

        implicitHeight: layout.implicitHeight
        color: Theme.alpha(Theme.base, 0.8)
        border.width: 1
        border.color: Theme.alpha(Theme.rosewater, 0.15)

        HoverHandler {
            id: hover
        }

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            spacing: 0

            // the default action: summary + body (whole area clickable)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 8
                color: bodyArea.containsMouse ? Theme.surface0 : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    id: bodyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (card.defaultAction)
                            card.defaultAction.invoke();
                        else
                            card.notif.dismiss();
                    }
                }

                RowLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    spacing: 4

                    Image {
                        visible: card.iconSource !== "" && status !== Image.Error
                        source: card.iconSource
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        Layout.margins: 4
                        Layout.alignment: Qt.AlignTop
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 4
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: card.notif.summary
                                elide: Text.ElideRight
                                color: Theme.rosewater
                                font.family: Theme.uiFont
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                Layout.rightMargin: 30 // leaves room for the close button
                                text: Notifs.ago(card.notif)
                                color: Theme.rosewater
                                font.family: Theme.uiFont
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.notif.body
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            color: Theme.rosewater
                            font.family: Theme.uiFont
                            font.pixelSize: 15
                        }
                    }
                }
            }

            // alternative actions
            Flow {
                Layout.fillWidth: true
                Layout.margins: 4
                visible: card.extraActions.length > 0
                spacing: 8

                Repeater {
                    model: card.extraActions

                    Rectangle {
                        id: action
                        required property var modelData
                        width: actionLabel.implicitWidth + 24
                        height: actionLabel.implicitHeight + 12
                        color: actionArea.containsMouse ? Theme.surface1 : Theme.surface0

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: action.modelData.text
                            color: Theme.rosewater
                            font.family: Theme.uiFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: action.modelData.invoke()
                        }
                    }
                }
            }
        }

        // close button
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            width: 24
            height: 24
            color: closeArea.containsMouse ? Theme.surface2 : Theme.surface1

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: Theme.rosewater
                font.family: Theme.font
                font.pixelSize: 14
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: card.notif.dismiss()
            }
        }
    }
  '';

  xdg.configFile."quickshell/NotificationCenter.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Wayland

    // Notification center (was swaync's control center): 500x600 at the top-right,
    // background rgba(base, 0.7), widgets: title + Clear All, Do Not Disturb, the list.
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
            color: Theme.alpha(Theme.base, 0.7)
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
  '';

  xdg.configFile."quickshell/NotificationPopups.qml".text = ''
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
  '';

  xdg.configFile."quickshell/Notifs.qml".text = ''
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
  '';

  xdg.configFile."quickshell/Player.qml".text = ''
    pragma Singleton
    import QtQuick
    import Quickshell
    import Quickshell.Services.Mpris

    // The media player the bar follows. You run playerctld, so prefer its proxy:
    // that's the same player `playerctl` (your old waybar scripts) talked to.
    Singleton {
        id: root

        readonly property var players: Theme.toArray(Mpris.players.values)
        readonly property var active: {
            const ps = root.players;
            const ctl = ps.find(p => p.dbusName.indexOf("playerctld") !== -1);
            if (ctl && ctl.trackTitle !== "")
                return ctl;
            const playing = ps.find(p => p.isPlaying);
            if (playing)
                return playing;
            const named = ps.find(p => p.trackTitle !== "");
            return named ? named : null;
        }
        readonly property bool hasMedia: active !== null && active.trackTitle !== ""
        readonly property string status: {
            if (!hasMedia)
                return "Stopped";
            if (active.playbackState === MprisPlaybackState.Playing)
                return "Playing";
            if (active.playbackState === MprisPlaybackState.Paused)
                return "Paused";
            return "Stopped";
        }
        readonly property string title: hasMedia ? active.trackTitle : ""

        // position isn't reactive on its own; refresh it once a second while playing
        Timer {
            interval: 1000
            repeat: true
            running: root.status === "Playing"
            onTriggered: root.active.positionChanged()
        }

        function fmt(s) {
            const t = Math.floor(s);
            const sec = t % 60;
            return Math.floor(t / 60) + ":" + (sec < 10 ? "0" : "") + sec;
        }

        // was media-time.sh: "m:ss / m:ss", empty when there's no length
        readonly property string timeText: {
            if (!hasMedia || !active.lengthSupported || active.length <= 0)
                return "";
            return fmt(active.position) + " / " + fmt(active.length);
        }
    }
  '';

  xdg.configFile."quickshell/PowerProfileModule.qml".text = ''
    import QtQuick
    import Quickshell.Services.UPower

    // power-profiles-daemon: icon only, click cycles to the next profile (waybar's default).
    BarModule {
        id: root

        readonly property var names: ["power-saver", "balanced", "performance"]
        readonly property var icons: ["󰌪", "󰗑", "󱐋"]
        readonly property int current: PowerProfiles.profile

        tooltip: "Power profile: " + (names[current] !== undefined ? names[current] : "unknown")

        onClicked: m => {
            if (m.button !== Qt.LeftButton)
                return;
            const order = PowerProfiles.hasPerformanceProfile
                ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                : [PowerProfile.PowerSaver, PowerProfile.Balanced];
            const i = order.indexOf(PowerProfiles.profile);
            PowerProfiles.profile = order[(i + 1) % order.length];
        }

        BarText {
            text: root.icons[root.current] !== undefined ? root.icons[root.current] : "󰾞"
            color: Theme.rosewater
        }
    }
  '';

  xdg.configFile."quickshell/SessionModule.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell

    // group/session: lock, reboot, sleep, power, logout (plain icons, no border)
    RowLayout {
        spacing: 0

        component SessionButton: BarModule {
            id: btn
            property string glyph
            property var command
            bordered: false
            hPadding: 0
            vPadding: 0
            hMargin: 0
            vMargin: 0
            onClicked: m => {
                if (m.button === Qt.LeftButton)
                    Quickshell.execDetached(btn.command);
            }

            BarText {
                text: btn.glyph
                color: Theme.rosewater
            }
        }

        SessionButton {
            glyph: " 󰌾  "
            tooltip: "Lock screen"
            command: ["env", "TZ=America/Chicago", "hyprlock"]
        }
        SessionButton {
            glyph: "  󰜉  "
            tooltip: "Reboot"
            command: ["systemctl", "reboot"]
        }
        SessionButton {
            glyph: "  󰤄  "
            tooltip: "Sleep"
            command: ["systemctl", "suspend"]
        }
        SessionButton {
            glyph: "  󰐥  "
            tooltip: "Power Off"
            command: ["systemctl", "poweroff"]
        }
        SessionButton {
            glyph: "  󰈆 "
            tooltip: "Log Out"
            command: ["pkill", "Hyprland"]
        }
    }
  '';

  xdg.configFile."quickshell/SysInfo.qml".text = ''
    pragma Singleton
    import QtQuick
    import Quickshell
    import Quickshell.Io

    // CPU / memory / disk, shared by every bar (replaces waybar's cpu, memory and disk modules).
    Singleton {
        id: root

        property int cpuUsage: 0
        property real memUsedGiB: 0
        property int diskUsed: 0
        property var lastCpu: null

        // cpu + memory: interval = 1 (like your waybar config); reads /proc directly, no processes
        FileView {
            id: stat
            path: "/proc/stat"
            onLoaded: {
                const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + (f[4] || 0);
                const total = f.reduce((a, b) => a + b, 0);
                if (root.lastCpu !== null) {
                    const dt = total - root.lastCpu.total;
                    const di = idle - root.lastCpu.idle;
                    if (dt > 0)
                        root.cpuUsage = Math.round((1 - di / dt) * 100);
                }
                root.lastCpu = { total: total, idle: idle };
            }
        }

        FileView {
            id: meminfo
            path: "/proc/meminfo"
            onLoaded: {
                const t = meminfo.text();
                const total = t.match(/MemTotal:\s+(\d+)/);
                const avail = t.match(/MemAvailable:\s+(\d+)/);
                if (total && avail)
                    root.memUsedGiB = (Number(total[1]) - Number(avail[1])) / 1048576;
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                stat.reload();
                meminfo.reload();
            }
        }

        // disk: interval = 30, path = "/"  (same math as waybar: 100 - available/total)
        Process {
            id: df
            command: ["stat", "-f", "-c", "%b %a", "/"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = this.text.trim().split(" ").map(Number);
                    if (p[0] > 0)
                        root.diskUsed = Math.round(100 - p[1] / p[0] * 100);
                }
            }
        }

        Timer {
            interval: 30000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: df.running = true
        }
    }
  '';

  xdg.configFile."quickshell/Theme.qml".text = ''
    pragma Singleton
    import QtQuick
    import Quickshell

    // Catppuccin Mocha palette + shared sizing. Every other file reads colors from here.
    Singleton {
        readonly property color rosewater: "#f5e0dc"
        readonly property color flamingo: "#f2cdcd"
        readonly property color pink: "#f5c2e7"
        readonly property color mauve: "#cba6f7"
        readonly property color red: "#f38ba8"
        readonly property color maroon: "#eba0ac"
        readonly property color peach: "#fab387"
        readonly property color yellow: "#f9e2af"
        readonly property color green: "#a6e3a1"
        readonly property color teal: "#94e2d5"
        readonly property color sky: "#89dceb"
        readonly property color sapphire: "#74c7ec"
        readonly property color blue: "#89b4fa"
        readonly property color lavender: "#b4befe"
        readonly property color text: "#cdd6f4"
        readonly property color subtext1: "#bac2de"
        readonly property color subtext0: "#a6adc8"
        readonly property color overlay2: "#9399b2"
        readonly property color overlay1: "#7f849c"
        readonly property color overlay0: "#6c7086"
        readonly property color surface2: "#585b70"
        readonly property color surface1: "#45475a"
        readonly property color surface0: "#313244"
        readonly property color base: "#1e1e2e"
        readonly property color mantle: "#181825"
        readonly property color crust: "#11111b"

        // Bar (was waybar's "* { font-family; font-size; font-weight }")
        readonly property string font: "JetBrainsMono Nerd Font"
        readonly property int fontSize: 14
        readonly property int fontWeight: Font.Medium   // 500
        readonly property int border: 2

        // Notifications (swaync used your GTK font: Noto Sans 11pt)
        readonly property string uiFont: "Noto Sans"

        function alpha(c, a) {
            return Qt.rgba(c.r, c.g, c.b, a);
        }

        // copy a Quickshell object list (e.g. ObjectModel.values) into a plain JS array
        function toArray(l) {
            const out = [];
            if (!l)
                return out;
            for (let i = 0; i < l.length; i++)
                out.push(l[i]);
            return out;
        }
    }
  '';

  xdg.configFile."quickshell/Tooltip.qml".text = ''
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
  '';

  xdg.configFile."quickshell/TrayMenu.qml".text = ''
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
  '';

  xdg.configFile."quickshell/TrayModule.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Services.SystemTray

    // tray: icon-size 16, spacing 5; #tray { padding: 0 10px; margin: 0 2px } + the 2px border
    BarModule {
        id: root

        visible: SystemTray.items.values.length > 0
        hPadding: 10
        vPadding: 0
        hMargin: 2
        vMargin: 0
        fillHeight: true

        Row {
            spacing: 5

            Repeater {
                model: SystemTray.items.values

                delegate: Item {
                    id: entry
                    required property var modelData
                    width: 16
                    height: 16

                    Image {
                        anchors.fill: parent
                        source: entry.modelData.icon
                        sourceSize.width: 16
                        sourceSize.height: 16
                        smooth: true
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton)
                                entry.modelData.secondaryActivate();
                            else if (m.button === Qt.RightButton || entry.modelData.onlyMenu)
                                menu.visible = entry.modelData.hasMenu;
                            else
                                entry.modelData.activate();
                        }
                        onWheel: w => entry.modelData.scroll(w.angleDelta.y, false)
                    }

                    Tooltip {
                        target: entry
                        text: entry.modelData.tooltipTitle !== "" ? entry.modelData.tooltipTitle : entry.modelData.title
                        show: area.containsMouse && !menu.visible
                    }

                    TrayMenu {
                        id: menu
                        target: entry
                        handle: entry.modelData.menu
                    }
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/VolumeModule.qml".text = ''
    import QtQuick
    import Quickshell.Services.Pipewire

    // wireplumber#sink: "{icon} {volume}%" (󰕿 󰖀 󰕾), muted: "󰝟",
    // click toggles mute, scroll ±1% (capped at 100%).
    BarModule {
        id: root

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property bool ready: sink !== null && sink.audio !== null
        readonly property bool muted: ready && sink.audio.muted
        readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0
        readonly property string icon: percent < 34 ? "󰕿" : (percent < 67 ? "󰖀" : "󰕾")

        onClicked: m => {
            if (m.button === Qt.LeftButton && ready)
                sink.audio.muted = !sink.audio.muted;
        }
        onScrolled: delta => {
            if (!ready)
                return;
            const v = sink.audio.volume + (delta > 0 ? 0.01 : -0.01);
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }

        PwObjectTracker {
            objects: [Pipewire.defaultAudioSink]
        }

        BarText {
            text: root.muted ? "󰝟" : root.icon
            color: Theme.rosewater
        }
        BarText {
            visible: !root.muted
            text: " " + root.percent + "%"
        }
    }
  '';

  xdg.configFile."quickshell/WindowTitle.qml".text = ''
    import QtQuick
    import Quickshell.Hyprland

    // hyprland/window: "  {title}  " in Text color, max-length 35, with your two rewrites.
    BarText {
        id: root

        readonly property string raw: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

        function rewrite(t) {
            let m = t.match(/^(.*) - Mozilla Firefox$/);
            if (m)
                return "🌎 " + m[1];
            m = t.match(/^(.*) - zsh$/);
            if (m)
                return "> [" + m[1] + "]";
            return t;
        }

        function truncate(t, n) {
            return t.length > n ? t.slice(0, n - 1) + "…" : t;
        }

        visible: raw !== ""
        text: "  " + truncate(rewrite(raw), 35) + "  "
        color: Theme.text
        leftPadding: 10
        rightPadding: 10
        topPadding: 2
        bottomPadding: 2
    }
  '';

  xdg.configFile."quickshell/Workspaces.qml".text = ''
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
  '';


  wayland.windowManager.hyprland = {
    enable = true;
    package = null;        # use programs.hyprland from configuration.nix
    portalPackage = null;  # portal already set in configuration.nix
    configType = "lua";
    settings = lib.mkForce { };
    systemd.enable = true; # your Lua already runs dbus-update-activation-environment
    extraConfig = ''
-- Generated by hyprconf2lua v1.3.2
-- https://github.com/Prateek-squadron/hyprconf2lua
-- Manual review may be needed for complex directives
-- Fixed: env vars now actually applied via hl.env(); blur config consolidated into one block

---@module 'hl'

-- Catppuccin palette (written to ~/.config/hypr/themes/catppuccin.lua by catppuccin/nix)
local colors = require('themes.catppuccin')

hl.monitor({
    output   = "DP-1", -- for laptops generally eDP-0 or eDP-1, and desktops usually DP-1.
    mode     = "1920x1080@240",
    position = "0x0",
    scale    = 1,
})

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
--hyprmod settings
hl.unbind("SUPER + SHIFT + Left")
hl.bind("SUPER + SHIFT + Left", hl.dsp.focus({ workspace = -1 }))
hl.unbind("SUPER + SHIFT + Right")
hl.bind("SUPER + SHIFT + Right", hl.dsp.focus({ workspace = "+1" }))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --output-folder ~/Pictures/Screenshots"))
hl.bind("SUPER + CTRL + Right", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER + CTRL + Left", hl.dsp.window.move({ workspace = -1 }))
-- Env vars (Variance by graphics drivers)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
-- Force Qt apps to use qt5ct/qt6ct for styling layouts
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- Ensure Qt apps pick up Wayland instead of fallback X11 layouts
hl.env("QT_QPA_PLATFORM", "wayland")

hl.config({
    layerrule = {
        "blur, quickshell-bar",
        "ignorealpha 0.4, quickshell-bar", -- lets blur render through semi-transparent areas; tune threshold to your CSS alpha
    }
})


-- Consolidated decoration/blur block (previously split across 3 hl.config calls
-- that overwrote each other; only the last one was ever actually in effect)
hl.config({
    decoration = {
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            xray = true,
        },
        shadow = {
            enabled = false,
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        accel_profile = "flat",
        sensitivity = 0.0,
    },
})
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 0,
        ["col.active_border"]   = "rgba(" .. colors.overlay1Alpha .. "ee)",    
        ["col.inactive_border"] = "rgba(" .. colors.surface1Alpha .. "99)",  
        resize_on_border = true,
        extend_border_grab_area = 20,  -- pixels of grab area beyond the visible border
        hover_icon_on_border = true,
    },
})
hl.config({
    cursor = {
        inactive_timeout = 0,
        no_hardware_cursors = true,
    },
})
-- anims here
-- Define curves first
hl.curve("sharp", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })

-- Then reference them by leaf
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "snappy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "sharp", style = "popin 90%" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "sharp" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.6, bezier = "sharp" })
hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.1 && ~/.config/hypr/scripts/capslock.sh"))

-- Try using the shorthand variant if the full word is being ignored

hl.bind("SUPER + J", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + K", hl.dsp.focus({ workspace = "+1" }))

hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))


-- Trigger the rofi power menu

hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))

hl.bind("SUPER + Q", hl.dsp.window.close())

hl.bind("SUPER + SHIFT + E", hl.dsp.exit())


-- Captures the entire screen and copies it directly to your clipboard
-- Pressing Print captures the entire screen straight to your clipboard


-- True fullscreen (Hides waybar and gaps)

hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + V", hl.dsp.window.float())

-- Forces every window on the workspace into floating mode

hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("hyprctl clients -j| jq -r '.[]| select(.workspace.id=='$(hyprctl activeworkspace -j| jq '.id')')| . address'| xargs -I { } hyprctl dispatch togglefloating address:{ }"))

-- Toggle Rofi App Launcher using Super and Tab

hl.bind("SUPER + TAB", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -theme-str 'window { close-on-click:true; } '"))

-- Delete or replace the bottom section with ONLY this line:

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })

hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- TODO: manual review: blurls = "waybar"

-- Autostart
hl.on("hyprland.start", function()
   hl.exec_cmd("qs")
   hl.exec_cmd("awww-daemon")
   hl.exec_cmd("awww img ~/Pictures/Wallpapers/hk.png")
   hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
   hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
   hl.exec_cmd("eww daemon")
   hl.exec_cmd("playerctld daemon")
end)

-- HyprMod managed settings
--require("hyprland-gui")
-- hyprbars settings go inside hl.config under plugin
--[[hl.config({
    plugin = {
        hyprbars = {
            bar_height = 20,
            bar_color = colors.base,
            ["col.text"] = colors.text,
            bar_text_size = 14,
            bar_text_font = "SF Pro Text",
            bar_button_padding = 10,
            bar_padding = 10,
            bar_precedence_over_border = true,
            bar_part_of_window = true,
        }
    }
})

-- buttons are added separately
hl.plugin.hyprbars.add_button({
    bg_color = colors.red,
    fg_color = colors.base,
    size = 15,
    icon = "󱎘",
    action = "hyprctl dispatch 'hl.dsp.window.close()'",
})
hl.plugin.hyprbars.add_button({
    bg_color = colors.green,
    fg_color = colors.base,
    size = 15,
    icon = "",
    action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
})
hl.plugin.hyprbars.add_button({
    bg_color = colors.mauve,
    fg_color = colors.base,
    size = 15,
    icon = "",
    action = "hyprctl dispatch 'hl.dsp.window.float({action=\"toggle\"})'",
})
]]
    '';
  };

  programs.rofi = {
    enable = true;
    settings = {
      modi = "drun,run,filebrowser";
      show-icons = true;
      display-drun = "";
      display-run = "";
      display-filebrowser = "";
      drun-display-format = "{name}";
    };
    theme = lib.mkForce (
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        # Mocha palette file written to ~/.local/share/rofi/themes by catppuccin/nix
        "@import" = "catppuccin-mocha";
        "*" = {
          background = mkLiteral "@base";
          background-alt = mkLiteral "@surface0";
          foreground = mkLiteral "@text";
          selected = mkLiteral "@lavender";
          active = mkLiteral "@green";
          urgent = mkLiteral "@red";
          font = "JetBrainsMono Nerd Font 11";
        };
        "window" = {
          transparency = "real";
          location = mkLiteral "west";
          anchor = mkLiteral "west";
          fullscreen = false;
          width = mkLiteral "500px";
          height = mkLiteral "96%";
          x-offset = mkLiteral "20px";
          y-offset = mkLiteral "0px";
          enabled = true;
          margin = mkLiteral "0px";
          padding = mkLiteral "0px";
          border = mkLiteral "4px solid";
          border-color = mkLiteral "@background-alt";
          cursor = "default";
          background-color = mkLiteral "@background";
        };
        "mainbox" = {
          enabled = true;
          spacing = mkLiteral "20px";
          margin = mkLiteral "0px";
          padding = mkLiteral "20px";
          background-color = mkLiteral "transparent";
          children = [ "inputbar" "message" "listview" "mode-switcher" ];
        };
        "inputbar" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
          children = [ "textbox-prompt-colon" "entry" ];
        };
        "prompt" = {
          enabled = true;
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
        };
        "textbox-prompt-colon" = {
          enabled = true;
          padding = mkLiteral "0px";
          expand = false;
          str = " ";
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
        };
        "entry" = {
          enabled = true;
          padding = mkLiteral "0px";
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
          cursor = mkLiteral "text";
          placeholder = "Search...";
          placeholder-color = mkLiteral "inherit";
        };
        "listview" = {
          enabled = true;
          columns = 1;
          lines = 12;
          cycle = true;
          dynamic = true;
          scrollbar = true;
          layout = mkLiteral "vertical";
          reverse = false;
          fixed-height = true;
          fixed-columns = true;
          spacing = mkLiteral "5px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = "default";
        };
        "scrollbar" = {
          handle-width = mkLiteral "5px";
          handle-color = mkLiteral "@selected";
          background-color = mkLiteral "@background-alt";
        };
        "element" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "6px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = mkLiteral "pointer";
        };
        "element normal.normal, element alternate.normal" = {
          background-color = mkLiteral "var(background)";
          text-color = mkLiteral "var(foreground)";
        };
        "element normal.urgent, element alternate.urgent, element selected.active" = {
          background-color = mkLiteral "var(urgent)";
          text-color = mkLiteral "var(background)";
        };
        "element normal.active, element alternate.active, element selected.urgent" = {
          background-color = mkLiteral "var(active)";
          text-color = mkLiteral "var(background)";
        };
        "element selected.normal" = {
          background-color = mkLiteral "var(selected)";
          text-color = mkLiteral "var(background)";
        };
        "element-icon" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
          size = mkLiteral "24px";
          cursor = mkLiteral "inherit";
        };
        "element-text" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
          highlight = mkLiteral "inherit";
          cursor = mkLiteral "inherit";
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.0";
        };
        "mode-switcher" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "0px 0px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
        };
        "button" = {
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "inherit";
          cursor = mkLiteral "pointer";
        };
        "button selected" = {
          background-color = mkLiteral "var(urgent)";
          text-color = mkLiteral "var(background)";
        };
        "message" = {
          enabled = true;
          margin = mkLiteral "0px";
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
        };
        "textbox" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.0";
          highlight = mkLiteral "none";
          placeholder-color = mkLiteral "@foreground";
          blink = true;
          markup = true;
        };
        "error-message" = {
          padding = mkLiteral "20px";
          background-color = mkLiteral "@background";
          text-color = mkLiteral "@foreground";
        };
      });
  };



  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      logo = {
        padding = {
          top = 1;
          right = 3;
        };
      };
      display = {
        separator = " │ ";
      };
      modules = [
        {
          type = "custom";
          format = "╭───────────╮";
        }
        {
          type = "user";
          key = "│ user    ";
          keyColor = "red";
        }
        {
          type = "host";
          key = "│󰋜 hname   ";
          keyColor = "green";
        }
        {
          type = "command";
          key = "│󰋔 os age  ";
          keyColor = "yellow";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
        }
        {
          type = "uptime";
          key = "│󱎫 uptime  ";
          keyColor = "blue";
        }
        {
          type = "os";
          key = "│ distro  ";
          keyColor = "cyan";
        }
        {
          type = "kernel";
          key = "│󰒋 kernel  ";
          keyColor = "magenta";
        }
        {
          type = "wm";
          key = "│󱂬 wm      ";
          keyColor = "green";
        }
        {
          type = "lm";
          key = "│󰧨 desktop ";
          keyColor = "cyan";
        }
        {
          type = "terminal";
          key = "│ term    ";
          keyColor = "red";
        }
        {
          type = "shell";
          key = "│󰞷 shell   ";
          keyColor = "green";
        }
        {
          type = "cpu";
          key = "│󰻠 cpu     ";
          keyColor = "yellow";
        }
        {
          type = "gpu";
          key = "│󰢮 gpu     ";
          keyColor = "yellow";
        }
        {
          type = "disk";
          key = "│󰋊 disk    ";
          keyColor = "blue";
        }
        {
          type = "memory";
          key = "│󰍛 memory  ";
          keyColor = "cyan";
        }
        {
          type = "localip";
          key = "│ local ip";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "│ packages";
          keyColor = "green";
        }
        {
          type = "custom";
          format = "├───────────┤";
        }
        {
          type = "colors";
          key = "│🎨 colors ";
          symbol = "circle";
        }
        {
          type = "custom";
          format = "╰───────────╯";
        }
      ];
    };
  };

  programs.kitty = {
    enable = true;
    themeFile = lib.mkForce null;
    font.name = "JetBrainsMono Nerd Font Mono";
    shellIntegration = {
      mode = null; # set via settings below, so HM does not force "no-rc"
      enableBashIntegration = false;
      enableZshIntegration = false;
      enableFishIntegration = false;
    };
    settings = {
      remember_window_size = "no";
      scrollback_lines = 10000;
      background_opacity = "0.7";
      cursor_shape = "beam";
      shell_integration = "no-cursor";
      cursor_trail = 1;
      repaint_delay = 5;
      input_delay = 1;
      sync_to_monitor = "no";
      confirm_os_window_close = 0;
      cursor_trail_start_threshold = 0;
      foreground = "#CDD6F4";
      background = "#1E1E2E";
      selection_foreground = "#1E1E2E";
      selection_background = "#F5E0DC";
      cursor = "#F5E0DC";
      cursor_text_color = "#1E1E2E";
      url_color = "#F5E0DC";
      active_border_color = "#B4BEFE";
      inactive_border_color = "#6C7086";
      bell_border_color = "#F9E2AF";
      wayland_titlebar_color = "system";
      active_tab_foreground = "#11111B";
      active_tab_background = "#CBA6F7";
      inactive_tab_foreground = "#CDD6F4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111B";
      mark1_foreground = "#1E1E2E";
      mark1_background = "#B4BEFE";
      mark2_foreground = "#1E1E2E";
      mark2_background = "#CBA6F7";
      mark3_foreground = "#1E1E2E";
      mark3_background = "#74C7EC";
      color0 = "#45475A";
      color8 = "#585B70";
      color1 = "#F38BA8";
      color9 = "#F38BA8";
      color2 = "#A6E3A1";
      color10 = "#A6E3A1";
      color3 = "#F9E2AF";
      color11 = "#F9E2AF";
      color4 = "#89B4FA";
      color12 = "#89B4FA";
      color5 = "#F5C2E7";
      color13 = "#F5C2E7";
      color6 = "#94E2D5";
      color14 = "#94E2D5";
      color7 = "#BAC2DE";
      color15 = "#A6ADC8";
    };
  };
  # kitty rewrites kitty.conf itself (e.g. the font/theme kittens), turning HM's
  # symlink into a regular file; force lets HM replace it
  xdg.configFile."kitty/kitty.conf".force = true;

gtk = {
  enable = true;
  theme = {
    name = "catppuccin-mocha-blue-standard"; # whatever GTK theme you have installed
    package = pkgs.catppuccin-gtk.override {
      accents = [ "blue" ];
      size = "standard";
      variant = "mocha";
    };
  };
    gtk4.theme = config.gtk.theme;


  font = {
    name = "Noto Sans";
    size = 11;
  };

  gtk3.extraConfig = {
    gtk-application-prefer-dark-theme = true;
  };

  gtk4.extraConfig = {
    gtk-application-prefer-dark-theme = true;
  };
};


home.pointerCursor = {
  enable = true;
  gtk.enable = true;
  x11.enable = true;
  name = "catppuccin-mocha-mauve-cursors";
  package = pkgs.catppuccin-cursors.mochaMauve;
};

gtk.cursorTheme = {
  name = "catppuccin-mocha-mauve-cursors";
  package = pkgs.catppuccin-cursors.mochaMauve;
};

programs.bash = {
  enable = true;
  shellAliases = {
    ll = "lsd -la";
    ls = "lsd";
    gs = "git status";
    update = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos && cd && flatpak update -y";
    viconfig = "sudo fresh /etc/nixos/configuration.nix";
    clean = "nh clean all";
    reload = "source ~/.bashrc";
  };
  bashrcExtra = ''
    source -- "${pkgs.blesh}/share/blesh/ble.sh" --noattach
    eval "$(starship init bash)"
    export PATH=~/bin:$PATH
    export PATH="$HOME/.npm-global/bin:$PATH"
    fastfetch
    [[ ! ''${BLE_VERSION-} ]] || ble-attach
  '';
};

  # Lock screen (launched from the waybar lock button)
  # Measured from the reference screenshot and scaled to 1920x1080
  programs.hyprlock = {
    enable = true;
    package = null; # hyprlock is installed system-wide in configuration.nix (needed for PAM)
    # no mkForce: catppuccin sources its Mocha palette ($rosewater, $surface0, ...);
    # its default layout is turned off with useDefaultConfig = false below
    settings = {
      general = {
        hide_cursor = false; # cursor is visible in the reference
      };

      background = [
        {
          monitor = "";
          path = "${config.home.homeDirectory}/Pictures/Wallpapers/hk.png";
          blur_passes = 3;
        }
      ];

      # Clock: 07:44 — ink ~238x64px, centered 74px above screen center
      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "$rosewater";
          font_size = 64;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 74";
          halign = "center";
          valign = "center";
        }
      ];

      # Password pill: ~225x56px, centered 27px below screen center
      input-field = [
        {
          monitor = "";
          size = "200, 50";
          position = "0, -20";
          halign = "center";
          valign = "center";
          rounding = -1; # full pill
          outline_thickness = 3;
          outer_color = "$rosewater";
          inner_color = "$surface0";
          font_color = "$rosewater";
          font_family = "JetBrainsMono Nerd Font";
          placeholder_text = "<i>Input Password...</i>";
          fade_on_empty = false;
          dots_center = true;
          check_color = "$yellow";
          fail_color = "$red";
          dots_size = 0.33;    # 0.2–0.8, fraction of the field height
          dots_spacing = 0.15; # 0.0–1.0, gap between dots, relative to dot size
        }
      ];
    };
  };
  # keep catppuccin's palette for hyprlock, but not its corner clock / layout / mauve field
  catppuccin.hyprlock.useDefaultConfig = false;
  # replaces any hand-written ~/.config/hypr/hyprlock.conf instead of failing activation
  xdg.configFile."hypr/hyprlock.conf".force = true;
}
