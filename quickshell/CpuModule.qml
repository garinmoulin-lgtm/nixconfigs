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
