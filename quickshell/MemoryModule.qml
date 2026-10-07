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
