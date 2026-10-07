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
        radius: 8
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
            anchors.verticalCenter: parent.verticalCenter
            // centered, but slides aside instead of overlapping (like waybar's center box)
            x: Math.max(left.x + left.width + 1,
                        Math.min((parent.width - width) / 2, right.x - width - 1))
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