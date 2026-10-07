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
