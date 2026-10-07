import QtQuick
import QtQuick.Layouts

// group/media-player [custom/media, custom/media-prev, custom/media-next] + custom/media-time
RowLayout {
    id: root
    spacing: 1

    readonly property bool controls: Player.status === "Playing" || Player.status === "Paused"
    readonly property var icon: ({
        "Playing": { glyph: " 󰏦 ", color: Theme.green },
        "Paused": { glyph: " 󰐍 ", color: Theme.yellow },
        "Stopped": { glyph: " 󰝛 ", color: Theme.red }
    })

    function truncate(t, n) {
        return t.length > n ? t.slice(0, n - 1) + "…" : t;
    }

    RowLayout {
        spacing: 0

        // custom/media: ' {icon} {text} '  (max-length 25)
        BarModule {
            bordered: false
            hPadding: 0
            vPadding: 0
            hMargin: 0
            vMargin: 0
            tooltip: Player.hasMedia ? Player.active.identity + " : " + Player.title : "No media"
            onClicked: if (Player.active) Player.active.togglePlaying()
            onScrolled: delta => {
                if (!Player.active)
                    return;
                if (delta > 0)
                    Player.active.next();
                else
                    Player.active.previous();
            }

            BarText { text: " " }
            BarText {
                text: root.icon[Player.status].glyph
                color: root.icon[Player.status].color
                font.pixelSize: Math.round(Theme.fontSize * 1.2) // pango "large"
            }
            BarText {
                text: " " + root.truncate(Player.hasMedia ? Player.title : "Nothing playing", 25) + " "
            }
        }

        // custom/media-prev
        BarModule {
            visible: root.controls
            bordered: false
            hPadding: 0
            vPadding: 0
            hMargin: 0
            vMargin: 0
            onClicked: Player.active.previous()

            BarText { text: " 󰼥 "; color: Theme.rosewater }
        }

        // custom/media-next
        BarModule {
            visible: root.controls
            bordered: false
            hPadding: 0
            vPadding: 0
            hMargin: 0
            vMargin: 0
            onClicked: Player.active.next()

            BarText { text: " 󰼦 "; color: Theme.rosewater }
        }
    }

    // custom/media-time: '  {} '  (hidden when empty, like waybar)
    BarText {
        visible: Player.timeText !== ""
        text: "  " + Player.timeText + " "
    }
}
