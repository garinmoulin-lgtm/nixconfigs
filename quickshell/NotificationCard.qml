import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// One notification, styled from your swaync CSS:
//   background rgba(base, 0.8); border 1px rgba(rosewater, 0.15); hover @surface0
//   summary 16px bold, body 15px, text Rosewater; image 64px; 24px close button (@surface1)
Rectangle {
    id: card

    required property var notif
    readonly property bool hovered: hover.hovered
    readonly property var actions: Theme.toArray(notif.actions)
    readonly property var defaultAction: actions.find(a => a.identifier === "default") || null
    readonly property var extraActions: actions.filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        const img = notif.image;
        if (img !== "")
            return img;
        const ic = notif.appIcon;
        if (ic === "")
            return "";
        if (ic.startsWith("/"))
            return "file://" + ic;
        if (ic.startsWith("file://") || ic.startsWith("image://"))
            return ic;
        return Quickshell.iconPath(ic, true);
    }
    
    implicitHeight: layout.implicitHeight
    color: Theme.alpha(Theme.base, 0.8)
    border.width: 2
    border.color: Theme.alpha(Theme.overlay1, 0.4)
    radius: 8

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        spacing: 0

        // the default action: summary + body (whole area clickable)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + 8
            color: bodyArea.containsMouse ? Theme.surface0 : "transparent"

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: bodyArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (card.defaultAction)
                        card.defaultAction.invoke();
                    else
                        card.notif.dismiss();
                }
            }

            RowLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 4

                Image {
                    visible: card.iconSource !== "" && status !== Image.Error
                    source: card.iconSource
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    Layout.margins: 4
                    Layout.alignment: Qt.AlignTop
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 4
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: card.notif.summary
                            elide: Text.ElideRight
                            color: Theme.rosewater
                            font.family: Theme.uiFont
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            Layout.rightMargin: 30 // leaves room for the close button
                            text: Notifs.ago(card.notif)
                            color: Theme.rosewater
                            font.family: Theme.uiFont
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: card.notif.body
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                        color: Theme.rosewater
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }
                }
            }
        }

        // alternative actions
        Flow {
            Layout.fillWidth: true
            Layout.margins: 4
            visible: card.extraActions.length > 0
            spacing: 8

            Repeater {
                model: card.extraActions

                Rectangle {
                    id: action
                    required property var modelData
                    width: actionLabel.implicitWidth + 24
                    height: actionLabel.implicitHeight + 12
                    color: actionArea.containsMouse ? Theme.surface1 : Theme.surface0

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: action.modelData.text
                        color: Theme.rosewater
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: action.modelData.invoke()
                    }
                }
            }
        }
    }

    // close button
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 24
        height: 24
        color: closeArea.containsMouse ? Theme.surface2 : Theme.surface1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: Theme.rosewater
            font.family: Theme.font
            font.pixelSize: 14
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.notif.dismiss()
        }
    }
}
