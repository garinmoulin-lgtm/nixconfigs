import QtQuick

// disk: "󰋊 {percentage_used}%", path "/", interval 30
BarModule {
    BarText { text: "󰋊"; color: Theme.rosewater }
    BarText { text: " " + SysInfo.diskUsed + "%" }
}
