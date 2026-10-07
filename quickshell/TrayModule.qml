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
