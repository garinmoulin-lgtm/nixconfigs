import QtQuick
import Quickshell.Services.Pipewire

// wireplumber#sink: "{icon} {volume}%" (󰕿 󰖀 󰕾), muted: "󰝟",
// click toggles mute, scroll ±1% (capped at 100%).
BarModule {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted
    readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0
    readonly property string icon: percent < 34 ? "󰕿" : (percent < 67 ? "󰖀" : "󰕾")

    onClicked: m => {
        if (m.button === Qt.LeftButton && ready)
            sink.audio.muted = !sink.audio.muted;
    }
    onScrolled: delta => {
        if (!ready)
            return;
        const v = sink.audio.volume + (delta > 0 ? 0.01 : -0.01);
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    BarText {
        text: root.muted ? "󰝟" : root.icon
        color: Theme.rosewater
    }
    BarText {
        visible: !root.muted
        text: " " + root.percent + "%"
    }
}
