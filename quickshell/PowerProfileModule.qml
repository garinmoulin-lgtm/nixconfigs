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
