import QtQuick
import Quickshell.Hyprland

// hyprland/window: "  {title}  " in Text color, max-length 35, with your two rewrites.
BarText {
    id: root

    readonly property string raw: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

    function rewrite(t) {
        let m = t.match(/^(.*) - Mozilla Firefox$/);
        if (m)
            return "🌎 " + m[1];
        m = t.match(/^(.*) - zsh$/);
        if (m)
            return "> [" + m[1] + "]";
        return t;
    }

    function truncate(t, n) {
        return t.length > n ? t.slice(0, n - 1) + "…" : t;
    }

    visible: raw !== ""
    text: " " + truncate(rewrite(raw), 25) + " "
    color: Theme.text
    leftPadding: 10
    rightPadding: 10
    topPadding: 2
    bottomPadding: 2
}
