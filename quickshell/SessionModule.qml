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
        glyph: " 󰌾 "
        tooltip: "Lock screen"
        command: ["env", "TZ=America/Chicago", "hyprlock"]
    }
    SessionButton {
        glyph: " 󰜉 "
        tooltip: "Reboot"
        command: ["systemctl", "reboot"]
    }
    SessionButton {
        glyph: " 󰤄 "
        tooltip: "Sleep"
        command: ["systemctl", "suspend"]
    }
    SessionButton {
        glyph: " 󰐥 "
        tooltip: "Power Off"
        command: ["systemctl", "poweroff"]
    }
    SessionButton {
        glyph: " 󰈆 "
        tooltip: "Log Out"
        command: ["pkill", "Hyprland"]
    }
}
