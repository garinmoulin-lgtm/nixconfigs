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
