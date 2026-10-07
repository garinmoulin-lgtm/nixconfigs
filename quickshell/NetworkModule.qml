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
