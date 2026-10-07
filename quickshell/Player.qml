pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The media player the bar follows. You run playerctld, so prefer its proxy:
// that's the same player `playerctl` (your old waybar scripts) talked to.
Singleton {
    id: root

    readonly property var players: Theme.toArray(Mpris.players.values)
    readonly property var active: {
        const ps = root.players;
        const ctl = ps.find(p => p.dbusName.indexOf("playerctld") !== -1);
        if (ctl && ctl.trackTitle !== "")
            return ctl;
        const playing = ps.find(p => p.isPlaying);
        if (playing)
            return playing;
        const named = ps.find(p => p.trackTitle !== "");
        return named ? named : null;
    }
    readonly property bool hasMedia: active !== null && active.trackTitle !== ""
    readonly property string status: {
        if (!hasMedia)
            return "Stopped";
        if (active.playbackState === MprisPlaybackState.Playing)
            return "Playing";
        if (active.playbackState === MprisPlaybackState.Paused)
            return "Paused";
        return "Stopped";
    }
    readonly property string title: hasMedia ? active.trackTitle : ""

    // position isn't reactive on its own; refresh it once a second while playing
    Timer {
        interval: 1000
        repeat: true
        running: root.status === "Playing"
        onTriggered: root.active.positionChanged()
    }

    function fmt(s) {
        const t = Math.floor(s);
        const sec = t % 60;
        return Math.floor(t / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // was media-time.sh: "m:ss / m:ss", empty when there's no length
    readonly property string timeText: {
        if (!hasMedia || !active.lengthSupported || active.length <= 0)
            return "";
        return fmt(active.position) + " / " + fmt(active.length);
    }
}
