{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.username = "garinh";
  home.homeDirectory = "/home/garinh";

  programs.home-manager.enable = true;

  # ── Quickshell: bar + notifications (replaces waybar and swaync) ─────────────
  # Started by its systemd user service (systemd.enable below).
  # Restart after a rebuild:  systemctl --user restart quickshell
  programs.quickshell = {
    enable = true;
    package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
    systemd.enable = true;
  };
  # ── Music player for the Quickshell bar ──
  # mpv runs in the background as its own service; the bar's media widget is its screen.

  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.mpris ]; # makes it show up as an MPRIS player
  };

  systemd.user.services.music-player = {
    Unit = {
      Description = "Background mpv for the Quickshell music library";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${config.programs.mpv.finalPackage}/bin/mpv --idle=yes --no-video --no-terminal --input-ipc-server=%t/mpv-music.sock";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # The song list for the bar's music library (shell.qml runs it from ~/.config/quickshell).
  # Inside '' '' strings, Nix would read the shell's ${...} as its own, so those are
  # written ''${...} here; ${pkgs.ffmpeg} is Nix on purpose.
  xdg.configFile."quickshell/music-index.sh".text = ''
    #!/bin/sh
    # Lists every song in a music folder, one line per song, tab-separated:
    #
    #   path   mtime   title   artist   album   seconds   cover-image
    #
    # The bar's music library reads this. Results are cached in
    # ~/.cache/qs-music, so only new or changed files get read again;
    # the first run on a big library takes a while, later runs are quick.
    #
    # Usage:  sh music-index.sh [MUSIC_DIR]      (defaults to ~/Music)
    # ffmpeg/ffprobe come from the Nix store, so they always exist.

    cache=''${XDG_CACHE_HOME:-$HOME/.cache}/qs-music
    mkdir -p "$cache/covers"

    # ── One file: read its tags, length and cover art, print its line. ──
    # (The script calls itself with --probe, several files at once in parallel.)
    if [ "$1" = "--probe" ]; then
        f=$2
        mtime=$(stat -c %Y "$f")

        # Cover: the art embedded in the file, saved as a small thumbnail...
        hash=$(printf '%s' "$f" | md5sum | cut -c1-32)
        cover=$cache/covers/$hash.jpg
        ${pkgs.ffmpeg}/bin/ffmpeg -v quiet -y -i "$f" -an -frames:v 1 -update 1 \
            -vf scale=160:160:force_original_aspect_ratio=increase "$cover" </dev/null
        if [ ! -s "$cover" ]; then
            rm -f "$cover"
            # ...or else an image next to the song (cover.jpg, folder.png, ...)
            cover=$(find "$(dirname "$f")" -maxdepth 1 -type f \
                \( -iname 'cover.*' -o -iname 'folder.*' -o -iname 'front.*' -o -iname 'album.*' \) \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n 1)
        fi

        # Tags + length. Tag names come out as TAG:title or TAG:TITLE depending on
        # the format, so they're compared in lowercase.
        ${pkgs.ffmpeg}/bin/ffprobe -v quiet -show_entries format=duration:format_tags -of default=nw=1 "$f" |
            awk -F= -v path="$f" -v mtime="$mtime" -v cover="$cover" '
                { key = tolower($1); val = substr($0, length($1) + 2); gsub(/\t/, " ", val) }
                key == "duration"                   { dur = int(val) }
                key == "tag:title"  && title == ""  { title = val }
                key == "tag:artist" && artist == "" { artist = val }
                key == "tag:album"  && album == ""  { album = val }
                END {
                    # no title tag: use the file name without its extension
                    if (title == "") { title = path; sub(/.*\//, "", title); sub(/\.[^.]*$/, "", title) }
                    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", path, mtime, title, artist, album, dur, cover
                }'
        exit 0
    fi

    # ── The whole library ──
    dir=''${1:-$HOME/Music}
    index=$cache/index.tsv
    touch "$index"
    tmp=$(mktemp -d)

    # Every audio file with its modification time.
    find "$dir" -type f \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' \
        -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.wav' -o -iname '*.wv' -o -iname '*.ape' \) \
        -printf '%p\t%Ts\n' > "$tmp/found"

    # Unchanged files keep their cached line; new or changed ones go on the to-do list.
    awk -F'\t' -v todo="$tmp/todo" '
        FILENAME == ARGV[1] { cached[$1] = $0; when[$1] = $2; next }   # first file: the old index
        ($1 in cached) && when[$1] == $2 { print cached[$1]; next }
        { print $1 > todo }
    ' "$index" "$tmp/found" > "$tmp/index"

    # Read the to-do files, 4 at a time.
    if [ -s "$tmp/todo" ]; then
        xargs -d '\n' -n 1 -P 4 sh "$0" --probe < "$tmp/todo" >> "$tmp/index"
    fi

    # Sorted by artist, then album, then path (so track numbers in file names keep order).
    sort -t "$(printf '\t')" -k4,4f -k5,5f -k1,1 "$tmp/index" > "$index"
    cat "$index"
    rm -rf "$tmp"
  '';

  # Quickshell config files, written to ~/.config/quickshell/ on rebuild.
  # They're read-only links into the Nix store: edit them here, then rebuild.
  xdg.configFile."quickshell/shell.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Services.Mpris
    import QtQuick.Controls.Basic
    import Quickshell.Services.Pipewire
    import Quickshell.Networking
    import Quickshell.Services.Notifications
    import Quickshell.Io
    import Quickshell.Widgets

    ShellRoot {
        // ── Music player ──
        // The player is mpv, running in the background as its own service (see home.nix),
        // with the mpris plugin, so the media module picks it up like any other player.
        // This Scope talks to that mpv over its IPC socket (queue, shuffle, repeat...)
        // and gets the song list from music-index.sh. Outside the Variants, so every
        // monitor's bar shares the one connection.
        Scope {
            id: music

            readonly property string musicDir: Quickshell.env("HOME") + "/Music"
            // %t/mpv-music.sock in the service = $XDG_RUNTIME_DIR/mpv-music.sock
            readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/mpv-music.sock"

            // ── the library ──
            property var songs: []            // [{ path, title, artist, album, length, cover }]
            property var byPath: ({})         // path -> song, to look up queue entries
            readonly property bool scanning: indexer.running

            // ── what mpv tells us ──
            property var queue: []            // mpv's playlist: [{ filename, current, playing, id }]
            property string loopFile: "no"
            property string loopPlaylist: "no"
            property bool shuffled: false     // mpv doesn't report this, so we remember it
            readonly property bool connected: socket.connected
            readonly property int current: queue.findIndex(e => e.current)   // -1 = nothing
            readonly property string repeat: loopFile !== "no" ? "one" : loopPlaylist !== "no" ? "all" : "off"

            // One command to mpv: a JSON line like {"command": ["playlist-shuffle"]}
            function send(args) {
                socket.write(JSON.stringify({
                    command: args
                }) + "\n");
                socket.flush();
            }

            // Play it right now, in place of the current song. The rest of the queue
            // stays as it was; the song it replaces is taken out instead of piling up.
            function playNow(path) {
                if (current < 0) {
                    // nothing playing: put it on the end and start it
                    send(["loadfile", path, "append"]);
                    send(["playlist-play-index", queue.length]);
                    return;
                }
                const old = current;
                send(["loadfile", path, "insert-at", old + 1]);   // right after the current song
                send(["playlist-play-index", old + 1]);            // switch to it
                send(["playlist-remove", old]);                    // drop the one it replaced
            }
            // put it straight after the current song
            function playNext(path) {
                send(["loadfile", path, "insert-next-play"]);
            }
            // put it at the end of the queue
            function enqueue(path) {
                send(["loadfile", path, "append-play"]);
            }
            // replace the queue with a whole list of songs
            function playAll(list) {
                if (list.length === 0)
                    return;
                list = list.slice();                      // copy, so shuffling doesn't touch the library
                if (shuffled) {
                    for (let i = list.length - 1; i > 0; i--) {     // Fisher-Yates shuffle
                        const j = Math.floor(Math.random() * (i + 1));
                        [list[i], list[j]] = [list[j], list[i]];
                    }
                }
                send(["loadfile", list[0].path, "replace"]);
                for (let i = 1; i < list.length; i++)
                    send(["loadfile", list[i].path, "append"]);
            }
            function toggleShuffle() {
                send([shuffled ? "playlist-unshuffle" : "playlist-shuffle"]);
                shuffled = !shuffled;
            }
            // off -> all -> one -> off
            function cycleRepeat() {
                if (repeat === "off") {
                    send(["set_property", "loop-playlist", "inf"]);
                } else if (repeat === "all") {
                    send(["set_property", "loop-playlist", "no"]);
                    send(["set_property", "loop-file", "inf"]);
                } else {
                    send(["set_property", "loop-file", "no"]);
                }
            }
            function jumpTo(index) {
                send(["playlist-play-index", index]);
            }
            function remove(index) {
                send(["playlist-remove", index]);
            }
            // empties the queue except the song that's playing
            function clearQueue() {
                send(["playlist-clear"]);
            }
            function rescan() {
                indexer.running = true;
            }

            // Turns music-index.sh's lines into song objects.
            function load(text) {
                const list = [];
                const map = {};
                for (const line of text.split("\n")) {
                    if (line === "")
                        continue;
                    const f = line.split("\t");   // path, mtime, title, artist, album, seconds, cover
                    const song = {
                        path: f[0],
                        title: f[2],
                        artist: f[3],
                        album: f[4],
                        length: Number(f[5]),
                        // a file:// URL; each folder name is escaped so spaces and # work
                        cover: f[6] ? "file://" + f[6].split("/").map(encodeURIComponent).join("/") : ""
                    };
                    list.push(song);
                    map[song.path] = song;
                }
                songs = list;
                byPath = map;
            }

            // Scans ~/Music once at startup (and again from the refresh button).
            Process {
                id: indexer
                command: ["sh", Quickshell.shellDir + "/music-index.sh", music.musicDir]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: music.load(text)
                }
            }

            Socket {
                id: socket
                path: music.socketPath

                // Once connected, ask mpv to report these whenever they change.
                onConnectedChanged: {
                    if (connected) {
                        music.send(["observe_property", 1, "playlist"]);
                        music.send(["observe_property_string", 2, "loop-file"]);
                        music.send(["observe_property_string", 3, "loop-playlist"]);
                    } else {
                        music.queue = [];      // mpv went away; its queue went with it
                    }
                }

                // mpv answers with one JSON object per line.
                parser: SplitParser {
                    onRead: line => {
                        const msg = JSON.parse(line);
                        if (msg.event !== "property-change")
                            return;
                        if (msg.name === "playlist")
                            music.queue = msg.data ?? [];
                        else if (msg.name === "loop-file")
                            music.loopFile = msg.data ?? "no";
                        else if (msg.name === "loop-playlist")
                            music.loopPlaylist = msg.data ?? "no";
                    }
                }
            }

            // mpv may start after the bar, or restart: keep trying until connected.
            Timer {
                interval: 2000
                repeat: true
                triggeredOnStart: true
                running: !socket.connected
                onTriggered: socket.connected = true
            }
        }

        // ── Notifications ──
        // One server for the whole shell. It sits outside the Variants on purpose:
        // inside, every monitor would start its own server, and only one can run.
        NotificationServer {
            id: notifs

            // ids of notifications that haven't been marked read yet
            property var unread: []
            // when each one arrived, by id (notifications don't carry a timestamp)
            property var arrived: ({})
            // count only the unread ones that still exist (apps can close their own)
            readonly property int unreadCount: trackedNotifications.values.filter(n => unread.includes(n.id)).length

            onNotification: n => {
                n.tracked = true;              // without this the notification is discarded
                if (n.lastGeneration)          // re-sent after a config reload: not new
                    return;
                unread = unread.concat([n.id]);
                arrived = Object.assign({}, arrived, {
                    [n.id]: new Date()
                });
            }

            function markAllRead() {
                unread = [];
            }
        }

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: bar

                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: Theme.barHeight
                color: Theme.bg

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                Poll {
                    id: volume
                    cmd: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100+0.5) \"%\"}'"
                    every: 1000
                }
                /*
                Poll {
                    id: bluetooth
                    cmd: "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"
                }
                */
                // Battery would go here but I'm lazy
                Poll {
                    id: net
                    cmd: "nmcli -t -f TYPE,STATE,CONNECTION device | grep -E '^(ethernet|wifi):connected:' | head -n1"
                    every: 1000
                }
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing

                    Workspaces {
                        screen: bar.screen
                    }
                    Widget {
                        padding: 16
                        button: Item {
                            width: Theme.moduleHeight
                            height: width

                            // the cover of whatever's playing
                            Image {
                                id: barArt
                                anchors.fill: parent
                                source: media.player ? media.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                clip: true
                            }
                            // No player, no cover, or the cover didn't load: music_off instead.
                            // (status is Image.Ready only once a picture has actually loaded)
                            Text {
                                anchors.centerIn: parent
                                visible: barArt.status !== Image.Ready
                                text: "music_off"
                                color: Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                                font.variableAxes: Theme.iconAxes
                            }
                        }
                        Timer {
                            running: !!media.player && media.player.isPlaying && !control.pressed
                            interval: 1000
                            repeat: true
                            onTriggered: media.player.positionChanged()
                        }
                        Row {
                            spacing: 16

                            // ── Now playing ──
                            Column {
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: media.player ? media.player.trackArtUrl : ""
                                    width: 144
                                    height: 144
                                    fillMode: Image.PreserveAspectCrop
                                    clip: true
                                }
                                Text {
                                    padding: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 1
                                    font.letterSpacing: Theme.letterSpacing
                                    font.weight: 600
                                    color: Theme.text
                                    text: media.player ? media.player.trackTitle : " "
                                }
                                Text {
                                    padding: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.75
                                    font.letterSpacing: Theme.letterSpacing
                                    font.weight: 600
                                    color: Theme.text
                                    text: media.player ? media.player.trackArtist : " "
                                }
                                Slider {
                                    id: control
                                    padding: 8
                                    width: 400
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    from: 0
                                    to: media.player ? media.player.length : 1
                                    value: media.player ? media.player.position : 0
                                    onMoved: {
                                        if (media.player && media.player.canSeek && media.player.positionSupported)
                                            media.player.position = value;
                                    }
                                    background: Rectangle {        // the track
                                        x: control.leftPadding
                                        y: control.topPadding + control.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 4
                                        width: control.availableWidth
                                        height: implicitHeight
                                        radius: 2
                                        color: Theme.pill                          // unplayed part

                                        Rectangle {                                // the played part
                                            width: control.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
                                            color: Theme.accent
                                        }
                                    }

                                    handle: Rectangle {            // the knob
                                        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
                                        y: control.topPadding + control.availableHeight / 2 - height / 2
                                        implicitWidth: 12
                                        implicitHeight: 12
                                        radius: 6
                                        color: control.pressed ? Theme.accent : Theme.text
                                    }
                                }
                                Text {
                                    // seconds -> "m:ss"
                                    function fmt(s) {
                                        return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0");
                                    }

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.9
                                    font.letterSpacing: Theme.letterSpacing
                                    font.weight: 600
                                    text: media.player ? fmt(media.player.position) + "/" + fmt(media.player.length) : ""
                                }
                            }

                            // a thin line between now playing and the library
                            Rectangle {
                                width: 1
                                height: parent.height
                                color: Theme.pill
                            }

                            // ── Library and queue ──
                            Column {
                                id: lib
                                width: 360
                                spacing: 8

                                property string tab: "library"       // or "queue"
                                // the library, narrowed down by the search box
                                readonly property var results: {
                                    const q = search.text.toLowerCase();
                                    if (q === "")
                                        return music.songs;
                                    return music.songs.filter(s => (s.title + " " + s.artist + " " + s.album).toLowerCase().includes(q));
                                }

                                // seconds -> "m:ss"
                                function fmt(s) {
                                    return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0");
                                }

                                // ── tabs on the left, buttons on the right ──
                                Item {
                                    width: parent.width
                                    height: 28

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                {
                                                    id: "library",
                                                    name: "Library"
                                                },
                                                {
                                                    id: "queue",
                                                    name: "Queue"
                                                }
                                            ]
                                            Rectangle {
                                                id: tabButton
                                                required property var modelData
                                                readonly property bool selected: lib.tab === modelData.id

                                                width: tabLabel.implicitWidth + 20
                                                height: 26
                                                radius: height / 2
                                                color: selected ? Theme.accent : tabMouse.containsMouse ? Theme.pill : "transparent"
                                                scale: tabMouse.pressed ? 0.85 : 1

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }
                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 120
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }

                                                Text {
                                                    id: tabLabel
                                                    anchors.centerIn: parent
                                                    // the queue tab shows how many songs are in it
                                                    text: tabButton.modelData.name + (tabButton.modelData.id === "queue" && music.queue.length > 0 ? "  " + music.queue.length : "")
                                                    color: tabButton.selected ? Theme.bg : Theme.text
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize
                                                    font.weight: 700
                                                    font.letterSpacing: Theme.letterSpacing
                                                }
                                                MouseArea {
                                                    id: tabMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: lib.tab = tabButton.modelData.id
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter

                                        IconButton {        // play everything that's listed (search applies)
                                            icon: "playlist_play"
                                            onClicked: music.playAll(lib.results)
                                        }
                                        IconButton {
                                            icon: "shuffle"
                                            iconColor: music.shuffled ? Theme.accent : Theme.text
                                            onClicked: music.toggleShuffle()
                                        }
                                        IconButton {
                                            icon: music.repeat === "one" ? "repeat_one" : "repeat"
                                            iconColor: music.repeat === "off" ? Theme.text : Theme.accent
                                            onClicked: music.cycleRepeat()
                                        }
                                        IconButton {        // empty the queue (keeps the song that's playing)
                                            icon: "clear_all"
                                            onClicked: music.clearQueue()
                                        }
                                        IconButton {        // scan ~/Music again
                                            icon: "refresh"
                                            iconColor: music.scanning ? Theme.accent : Theme.text
                                            onClicked: music.rescan()
                                        }
                                    }
                                }

                                // ── search ──
                                TextField {
                                    id: search
                                    visible: lib.tab === "library"
                                    width: parent.width
                                    placeholderText: "Search songs, artists, albums"
                                    placeholderTextColor: Theme.pillIcon
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize
                                    leftPadding: 12
                                    rightPadding: 12
                                    background: Rectangle {
                                        radius: height / 2
                                        color: Theme.bg
                                        border.width: 1
                                        border.color: search.activeFocus ? Theme.accent : Theme.pillIcon
                                    }
                                }

                                // ── messages when there's nothing to list ──
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    visible: text !== ""
                                    text: {
                                        if (!music.connected)
                                            return "The player isn't running. Start it with:\nsystemctl --user start music-player";
                                        if (lib.tab === "queue")
                                            return music.queue.length === 0 ? "The queue is empty." : "";
                                        if (music.songs.length === 0)
                                            return music.scanning ? "Scanning ~/Music..." : "No songs found in ~/Music.";
                                        return lib.results.length === 0 ? "No matches." : "";
                                    }
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize
                                }

                                // ── the library list ──
                                // ListView only creates rows that are on screen, so thousands of songs are fine.
                                ListView {
                                    id: songList
                                    visible: lib.tab === "library" && lib.results.length > 0
                                    width: parent.width
                                    height: 320
                                    clip: true
                                    spacing: 2
                                    model: lib.results
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar {
                                        id: songBar
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: Theme.pillIcon
                                            // hidden when everything fits, faint until you scroll or hover
                                            opacity: songBar.size < 1 ? (songBar.active ? 1 : 0.4) : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 200
                                                }
                                            }
                                        }
                                    }

                                    delegate: Rectangle {
                                        id: song
                                        required property var modelData      // { path, title, artist, album, length, cover }
                                        // is this the song mpv is playing right now?
                                        readonly property bool playing: music.current >= 0 && music.queue[music.current].filename === modelData.path

                                        // Queueing takes two clicks: pick "next" or "end", then confirm.
                                        property string pending: ""    // "", "next" or "end": waiting for confirm
                                        property bool added: false     // shows "Added" for a moment afterwards

                                        function confirm() {
                                            if (pending === "next")
                                                music.playNext(modelData.path);
                                            else
                                                music.enqueue(modelData.path);
                                            pending = "";
                                            added = true;
                                            resetTimer.restart();
                                        }

                                        // an unconfirmed choice gives up after 3 s; "Added" fades after 1.5 s
                                        Timer {
                                            id: resetTimer
                                            interval: song.added ? 1500 : 3000
                                            onTriggered: {
                                                song.pending = "";
                                                song.added = false;
                                            }
                                        }

                                        width: ListView.view.width - 8           // room for the scrollbar
                                        height: 46
                                        radius: Theme.radius
                                        color: songMouse.containsMouse ? Theme.pill : "transparent"
                                        scale: songMouse.pressed ? 0.95 : 1

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // Click the row to play it now. Everything else sits inside this
                                        // MouseArea, so hovering the buttons still counts as hovering the row.
                                        MouseArea {
                                            id: songMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: music.playNow(song.modelData.path)

                                            // album cover with rounded corners
                                            ClippingRectangle {
                                                id: songCover
                                                x: 5
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 36
                                                height: 36
                                                radius: 6
                                                color: Theme.pill

                                                Image {
                                                    anchors.fill: parent
                                                    source: song.modelData.cover
                                                    sourceSize: Qt.size(72, 72)       // load a small copy, not the full image
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                                Text {                                 // when there's no cover
                                                    anchors.centerIn: parent
                                                    visible: song.modelData.cover === ""
                                                    text: "music_note"
                                                    color: Theme.pillIcon
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize
                                                }
                                            }

                                            Column {
                                                anchors.left: songCover.right
                                                anchors.leftMargin: 10
                                                anchors.right: songSide.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    width: parent.width
                                                    text: song.modelData.title
                                                    elide: Text.ElideRight
                                                    color: song.playing ? Theme.accent : Theme.text
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize
                                                    font.weight: 700
                                                    font.letterSpacing: Theme.letterSpacing
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: [song.modelData.artist, song.modelData.album].filter(s => s).join("  ·  ")
                                                    elide: Text.ElideRight
                                                    color: Theme.text
                                                    opacity: 0.6
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize * 0.85
                                                }
                                            }

                                            // Right side. Only one of these shows at a time:
                                            //   "Added"            just after confirming
                                            //   confirm / cancel   after picking a queue button
                                            //   queue buttons      while hovered
                                            //   the song's length  otherwise
                                            Item {
                                                id: songSide
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(songButtons.width, confirmRow.visible ? confirmRow.width : 0)
                                                height: 26

                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !songMouse.containsMouse && song.pending === "" && !song.added
                                                    text: song.modelData.length > 0 ? lib.fmt(song.modelData.length) : ""
                                                    color: Theme.text
                                                    opacity: 0.6
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize * 0.85
                                                }

                                                // step 1: pick where it goes
                                                Row {
                                                    id: songButtons
                                                    anchors.right: parent.right
                                                    visible: songMouse.containsMouse && song.pending === "" && !song.added
                                                    IconButton {
                                                        icon: "queue_play_next"         // play after the current song
                                                        onClicked: {
                                                            song.pending = "next";
                                                            resetTimer.restart();
                                                        }
                                                    }
                                                    IconButton {
                                                        icon: "playlist_add"            // add to the end of the queue
                                                        onClicked: {
                                                            song.pending = "end";
                                                            resetTimer.restart();
                                                        }
                                                    }
                                                }

                                                // step 2: confirm it (or cancel)
                                                Row {
                                                    id: confirmRow
                                                    anchors.right: parent.right
                                                    spacing: 2
                                                    visible: song.pending !== ""

                                                    Rectangle {
                                                        width: confirmLabel.implicitWidth + 30
                                                        height: 26
                                                        radius: height / 2
                                                        color: confirmMouse.containsMouse ? Theme.green : Theme.bg
                                                        border.width: 1
                                                        border.color: Theme.green
                                                        scale: confirmMouse.pressed ? 0.85 : 1

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: 120
                                                            }
                                                        }
                                                        Behavior on scale {
                                                            NumberAnimation {
                                                                duration: 120
                                                                easing.type: Easing.OutCubic
                                                            }
                                                        }

                                                        Row {
                                                            anchors.centerIn: parent
                                                            spacing: 4
                                                            Text {
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: "check"
                                                                color: confirmMouse.containsMouse ? Theme.bg : Theme.green
                                                                font.family: Theme.iconFont
                                                                font.pixelSize: Theme.iconSize * 0.9
                                                                font.variableAxes: Theme.iconAxes
                                                            }
                                                            Text {
                                                                id: confirmLabel
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: song.pending === "next" ? "Play next" : "Add to queue"
                                                                color: confirmMouse.containsMouse ? Theme.bg : Theme.green
                                                                font.family: Theme.font
                                                                font.pixelSize: Theme.textSize * 0.85
                                                                font.weight: 700
                                                            }
                                                        }
                                                        MouseArea {
                                                            id: confirmMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: song.confirm()
                                                        }
                                                    }
                                                    IconButton {
                                                        icon: "close"
                                                        iconColor: Theme.red
                                                        onClicked: song.pending = ""
                                                    }
                                                }

                                                // step 3: a short "Added"
                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: song.added
                                                    text: "Added"
                                                    color: Theme.green
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize * 0.85
                                                    font.weight: 700
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── the queue ──
                                ListView {
                                    id: queueList
                                    visible: lib.tab === "queue" && music.queue.length > 0
                                    width: parent.width
                                    height: 356
                                    clip: true
                                    spacing: 2
                                    model: music.queue
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar {
                                        id: queueBar
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: Theme.pillIcon
                                            // hidden when everything fits, faint until you scroll or hover
                                            opacity: queueBar.size < 1 ? (queueBar.active ? 1 : 0.4) : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 200
                                                }
                                            }
                                        }
                                    }

                                    delegate: Rectangle {
                                        id: entry
                                        required property var modelData      // { filename, current, ... } from mpv
                                        required property int index
                                        // the library's info for this file (title, cover...), if it's in the library
                                        readonly property var info: music.byPath[modelData.filename] ?? null

                                        width: ListView.view.width - 8
                                        height: 46
                                        radius: Theme.radius
                                        color: entryMouse.containsMouse ? Theme.pill : "transparent"
                                        border.width: 1
                                        border.color: entry.modelData.current ? Theme.accent : "transparent"
                                        scale: entryMouse.pressed ? 0.95 : 1

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // click a song in the queue to jump to it
                                        MouseArea {
                                            id: entryMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: music.jumpTo(entry.index)

                                            ClippingRectangle {
                                                id: entryCover
                                                x: 5
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 36
                                                height: 36
                                                radius: 6
                                                color: Theme.pill

                                                Image {
                                                    anchors.fill: parent
                                                    source: entry.info ? entry.info.cover : ""
                                                    sourceSize: Qt.size(72, 72)
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !entry.info || entry.info.cover === ""
                                                    text: "music_note"
                                                    color: Theme.pillIcon
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize
                                                }
                                            }

                                            Column {
                                                anchors.left: entryCover.right
                                                anchors.leftMargin: 10
                                                anchors.right: removeButton.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    width: parent.width
                                                    // not in the library: show the file name
                                                    text: entry.info ? entry.info.title : entry.modelData.filename.split("/").pop()
                                                    elide: Text.ElideRight
                                                    color: entry.modelData.current ? Theme.accent : Theme.text
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize
                                                    font.weight: 700
                                                    font.letterSpacing: Theme.letterSpacing
                                                }
                                                Text {
                                                    width: parent.width
                                                    visible: text !== ""
                                                    text: entry.info ? entry.info.artist : ""
                                                    elide: Text.ElideRight
                                                    color: Theme.text
                                                    opacity: 0.6
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize * 0.85
                                                }
                                            }

                                            IconButton {
                                                id: removeButton
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: entryMouse.containsMouse        // only while hovered
                                                icon: "close"
                                                iconColor: Theme.red
                                                onClicked: music.remove(entry.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: media
                        property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0]

                        width: mediaButtons.width + 12
                        height: Theme.moduleHeight
                        radius: Theme.radius
                        color: Theme.pill
                        visible: media.player != undefined

                        Row {
                            id: mediaButtons
                            anchors.centerIn: parent

                            IconButton {
                                icon: "skip_previous"
                                implicitWidth: 16
                                onClicked: if (media.player && media.player.canGoPrevious)
                                    media.player.previous()
                            }
                            IconButton {
                                icon: media.player && media.player.isPlaying ? "pause" : "play_arrow"
                                implicitWidth: 16
                                onClicked: if (media.player && media.player.canTogglePlaying)
                                    media.player.togglePlaying()
                            }
                            IconButton {
                                icon: "skip_next"
                                implicitWidth: 16
                                onClicked: if (media.player && media.player.canGoNext)
                                    media.player.next()
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            visible: media.player != undefined
                            text: media.player ? media.player.trackTitle : " "
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 600
                            font.letterSpacing: Theme.letterSpacing
                        }
                        Text {
                            visible: media.player != undefined
                            text: media.player ? media.player.trackArtist : " "
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.75
                            font.weight: 600
                            font.letterSpacing: Theme.letterSpacing
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing

                    // ── Notification center ──
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        button: Pill {
                            icon: notifs.unreadCount > 0 ? "notifications_unread" : "notifications"
                            iconColor: Theme.yellow
                            text: notifs.unreadCount
                        }

                        Column {
                            spacing: 10

                            // header: title on the left, "Mark all read" on the right
                            Item {
                                width: 340
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Notifications"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 1.2
                                    font.weight: 700
                                    font.letterSpacing: Theme.letterSpacing
                                }
                                Rectangle {
                                    id: markRead
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: markReadLabel.implicitWidth + 20
                                    height: 24
                                    radius: height / 2
                                    color: markReadMouse.containsMouse ? Theme.pill : "transparent"
                                    border.width: 1
                                    border.color: Theme.pill
                                    opacity: notifs.unreadCount > 0 ? 1 : 0.4     // dim when nothing is unread
                                    scale: markReadMouse.pressed ? 0.85 : 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        id: markReadLabel
                                        anchors.centerIn: parent
                                        text: "Mark all read"
                                        color: Theme.accent
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.9
                                        font.weight: 600
                                    }
                                    MouseArea {
                                        id: markReadMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifs.markAllRead()
                                    }
                                }
                            }

                            Text {
                                visible: notifs.trackedNotifications.values.length === 0
                                text: "No notifications"
                                color: Theme.text
                                opacity: 0.5
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                            }

                            // The list scrolls once it's taller than 400 px.
                            ListView {
                                width: 340
                                height: Math.min(contentHeight, 400)
                                visible: count > 0
                                clip: true
                                spacing: 6

                                // newest first; ScriptModel keeps existing cards when one is added
                                model: ScriptModel {
                                    values: [...notifs.trackedNotifications.values].reverse()
                                }

                                delegate: Rectangle {
                                    id: card
                                    required property var modelData
                                    readonly property bool isUnread: notifs.unread.includes(modelData.id)
                                    readonly property date arrivedAt: notifs.arrived[modelData.id] ?? new Date(NaN)

                                    width: ListView.view.width
                                    height: cardContent.implicitHeight + 20
                                    radius: Theme.radius
                                    color: Theme.pill
                                    border.width: 1
                                    border.color: isUnread ? Theme.accent : "transparent"

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 200
                                        }
                                    }

                                    Column {
                                        id: cardContent
                                        x: 12
                                        y: 10
                                        width: parent.width - 24
                                        spacing: 3

                                        // app name · time, with the dismiss × on the right
                                        Item {
                                            width: parent.width
                                            height: appLine.implicitHeight

                                            Text {
                                                id: appLine
                                                anchors.left: parent.left
                                                anchors.right: dismiss.left
                                                anchors.rightMargin: 8
                                                text: (card.modelData.appName || "Notification") + (isNaN(card.arrivedAt) ? "" : "  ·  " + Qt.formatDateTime(card.arrivedAt, "h:mm AP"))
                                                elide: Text.ElideRight
                                                color: card.isUnread ? Theme.accent : Theme.text
                                                opacity: card.isUnread ? 1 : 0.6
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.8
                                                font.weight: 600
                                            }
                                            Text {
                                                id: dismiss
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "close"                      // Material Symbols ×
                                                color: dismissMouse.containsMouse ? Theme.red : Theme.text
                                                opacity: dismissMouse.containsMouse ? 1 : 0.5
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize * 0.9
                                                MouseArea {
                                                    id: dismissMouse
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: card.modelData.dismiss()   // removes it for good
                                                }
                                            }
                                        }
                                        Text {
                                            width: parent.width
                                            text: card.modelData.summary
                                            textFormat: Text.PlainText
                                            wrapMode: Text.Wrap
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: 700
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: card.modelData.body
                                            textFormat: Text.PlainText   // apps may send markup; show it as plain text
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            opacity: 0.8
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.9
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        button: Pill {
                            icon: "volume_up"
                            iconColor: Theme.cyan
                            text: volume.text
                        }
                        Row {
                            spacing: 14

                            Column {
                                spacing: 4

                                // Binds the device nodes so their names and details are filled in.
                                PwObjectTracker {
                                    objects: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
                                }

                                Text {
                                    text: "Output"
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                                Repeater {
                                    // hardware devices that accept audio = speakers, headphones
                                    model: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink)

                                    Rectangle {
                                        id: row
                                        required property var modelData
                                        readonly property bool isDefault: modelData === Pipewire.defaultAudioSink

                                        width: 260
                                        height: 28
                                        radius: Theme.radius
                                        color: rowMouse.containsMouse ? Theme.pill : "transparent"   // highlight on hover
                                        scale: rowMouse.pressed ? 0.85 : 1                           // shrink while clicked

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: 10
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            // nickname and description can be empty; fall back to the raw name
                                            text: row.modelData.nickname || row.modelData.description || row.modelData.name
                                            elide: Text.ElideRight
                                            color: row.isDefault ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: row.isDefault ? 700 : 500
                                            font.letterSpacing: Theme.letterSpacing
                                        }

                                        MouseArea {
                                            id: rowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Pipewire.preferredDefaultAudioSink = row.modelData
                                        }
                                    }
                                }

                                Text {
                                    topPadding: 8
                                    text: "Input"
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                                Repeater {
                                    // hardware devices that produce audio = microphones
                                    model: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !n.isSink)

                                    Rectangle {
                                        id: row
                                        required property var modelData
                                        readonly property bool isDefault: modelData === Pipewire.defaultAudioSource

                                        width: 260
                                        height: 28
                                        radius: Theme.radius
                                        color: rowMouse.containsMouse ? Theme.pill : "transparent"   // highlight on hover
                                        scale: rowMouse.pressed ? 0.85 : 1                           // shrink while clicked

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: 10
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            // nickname and description can be empty; fall back to the raw name
                                            text: row.modelData.nickname || row.modelData.description || row.modelData.name
                                            elide: Text.ElideRight
                                            color: row.isDefault ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: row.isDefault ? 700 : 500
                                            font.letterSpacing: Theme.letterSpacing
                                        }

                                        MouseArea {
                                            id: rowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Pipewire.preferredDefaultAudioSource = row.modelData
                                        }
                                    }
                                }
                            }

                            // a thin line between the device lists and the slider
                            Rectangle {
                                width: 1
                                height: parent.height
                                color: Theme.pill
                            }

                            // ── Volume slider ──
                            Column {
                                id: vol
                                spacing: 6

                                // The current output device. The PwObjectTracker above already
                                // binds it, so its volume is filled in.
                                readonly property var sink: Pipewire.defaultAudioSink
                                readonly property bool ready: !!sink && !!sink.audio
                                readonly property bool muted: ready && sink.audio.muted

                                // percentage on top
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: vol.ready ? Math.round(vol.sink.audio.volume * 100) + "%" : "--"
                                    color: vol.muted ? Theme.pillIcon : Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize
                                    font.weight: 700
                                    font.letterSpacing: Theme.letterSpacing
                                }

                                Slider {
                                    id: volSlider
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    orientation: Qt.Vertical       // top = loud, bottom = silent
                                    width: 24
                                    height: 170
                                    from: 0
                                    to: 1                          // 1 = 100%
                                    value: vol.ready ? vol.sink.audio.volume : 0
                                    onMoved: if (vol.ready)
                                        vol.sink.audio.volume = value

                                    background: Rectangle {        // the track
                                        x: volSlider.leftPadding + volSlider.availableWidth / 2 - width / 2
                                        y: volSlider.topPadding
                                        implicitWidth: 6
                                        implicitHeight: 160
                                        width: implicitWidth
                                        height: volSlider.availableHeight
                                        radius: 3
                                        color: Theme.pill

                                        // The filled part grows up from the bottom. On a vertical
                                        // slider visualPosition is 0 at the top, so it's flipped.
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: (1 - volSlider.visualPosition) * parent.height
                                            radius: 3
                                            color: vol.muted ? Theme.pillIcon : Theme.cyan
                                        }
                                    }

                                    handle: Rectangle {            // the knob
                                        x: volSlider.leftPadding + volSlider.availableWidth / 2 - width / 2
                                        y: volSlider.topPadding + volSlider.visualPosition * (volSlider.availableHeight - height)
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: volSlider.pressed ? Theme.cyan : Theme.text
                                    }
                                }

                                // mute toggle under the slider
                                IconButton {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    icon: vol.muted ? "volume_off" : "volume_up"
                                    iconColor: vol.muted ? Theme.red : Theme.text
                                    onClicked: if (vol.ready)
                                        vol.sink.audio.muted = !vol.sink.audio.muted
                                }
                            }
                        }
                    }
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        button: Pill {
                            readonly property string kind: net.text.split(":")[0]

                            icon: kind === "ethernet" ? "lan" : kind === "wifi" ? "wifi" : "wifi_off"
                            iconColor: Theme.green
                            text: net.text.split(":").slice(2).join(":") || "offline"
                        }

                        Column {
                            id: netList
                            spacing: 4

                            // Every network from every device (Wi-Fi and wired): connected first,
                            // then strongest signal. Wired networks have no signalStrength, hence ?? 0.
                            readonly property var networks: [].concat(...Networking.devices.values.map(d => d.networks.values)).sort((a, b) => (b.connected - a.connected) || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)))

                            // ── The connect flow, for one network at a time ──
                            // It lives here and not in the rows: the list re-sorts whenever a network
                            // connects or its signal changes, and rows can be rebuilt when that happens.
                            property var active: null          // the network whose drop-down is open
                            property string phase: "idle"      // prompt, connecting, success, failed, connected
                            property bool usedPassword: false
                            property string password: ""

                            function isWifi(network) {
                                return !!network.device && network.device.type === DeviceType.Wifi;
                            }
                            // a saved Wi-Fi network already has its password; an open one needs none
                            function needsPassword(network) {
                                return isWifi(network) && !network.known && network.security !== WifiSecurityType.Open;
                            }
                            function toggle(network) {
                                if (active === network) {
                                    close();
                                    return;
                                }
                                active = network;
                                if (network.connected) {
                                    phase = "connected";
                                } else if (needsPassword(network)) {
                                    askPassword();
                                } else {
                                    // wired, open, or saved: try without a password first
                                    usedPassword = false;
                                    phase = "connecting";
                                    network.connect();
                                }
                            }
                            function askPassword() {
                                password = "";
                                phase = "prompt";
                            }
                            function submit() {
                                if (password === "")
                                    return;
                                usedPassword = true;
                                phase = "connecting";
                                active.connectWithPsk(password);
                            }
                            function disconnectActive() {
                                active.disconnect();
                                close();
                            }
                            function close() {
                                retryTimer.stop();
                                active = null;
                                phase = "idle";
                                password = "";
                            }

                            Connections {
                                target: netList.active
                                function onConnectedChanged() {
                                    if (netList.phase === "connecting" && netList.active.connected)
                                        netList.phase = "success";
                                }
                                function onConnectionFailed(reason) {
                                    if (netList.phase !== "connecting")
                                        return;
                                    // a saved network whose password no longer works: ask for it
                                    if (!netList.usedPassword && netList.isWifi(netList.active) && reason === ConnectionFailReason.NoSecrets) {
                                        netList.askPassword();
                                        return;
                                    }
                                    netList.phase = "failed";
                                    retryTimer.restart();
                                }
                            }

                            // "Incorrect Password." stays up alone for 2 s, then the prompt comes back.
                            Timer {
                                id: retryTimer
                                interval: 2000
                                onTriggered: netList.usedPassword ? netList.askPassword() : netList.close()
                            }

                            // Wi-Fi devices only list nearby networks while scanning,
                            // so scan while this popup is open and stop when it closes.
                            Repeater {
                                model: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
                                Item {
                                    required property var modelData
                                    Binding {
                                        target: modelData
                                        property: "scannerEnabled"
                                        value: !!QsWindow.window && QsWindow.window.visible
                                    }
                                }
                            }

                            Text {
                                text: "Networks"
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                                font.weight: 600
                            }

                            Repeater {
                                // ScriptModel only creates rows for networks that are new, instead of
                                // rebuilding every row each time the list changes.
                                model: ScriptModel {
                                    values: netList.networks
                                }

                                Rectangle {
                                    id: netRow
                                    required property var modelData
                                    readonly property var network: modelData
                                    readonly property bool isWifi: netList.isWifi(network)
                                    readonly property string phase: netList.active === network ? netList.phase : "idle"
                                    readonly property bool expanded: phase !== "idle"

                                    width: 280
                                    height: header.height + drop.height
                                    radius: Theme.radius
                                    color: headerMouse.containsMouse || expanded ? Theme.pill : "transparent"
                                    clip: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    // ── the row itself ──
                                    Item {
                                        id: header
                                        width: parent.width
                                        height: 28
                                        scale: headerMouse.pressed ? 0.85 : 1

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: strength.left
                                                leftMargin: 10
                                                rightMargin: 8
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: netRow.network.name
                                            elide: Text.ElideRight
                                            color: netRow.network.connected ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: netRow.network.connected ? 700 : 500
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                        Text {
                                            id: strength
                                            anchors {
                                                right: parent.right
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: netRow.isWifi ? Math.round(netRow.network.signalStrength * 100) + "%" : "wired"
                                            color: Theme.text
                                            opacity: 0.6
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.85
                                        }
                                        MouseArea {
                                            id: headerMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: netList.toggle(netRow.network)
                                        }
                                    }

                                    // ── the drop-down: glides open over 500 ms ──
                                    Item {
                                        id: drop
                                        y: header.height
                                        width: parent.width
                                        height: netRow.expanded ? dropContent.implicitHeight + 10 : 0
                                        clip: true

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 500
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Column {
                                            id: dropContent
                                            x: 10
                                            width: parent.width - 20
                                            spacing: 6

                                            Text {
                                                visible: netRow.phase === "prompt"
                                                text: "Enter password:"
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                            }
                                            TextField {
                                                id: passwordField
                                                visible: netRow.phase === "prompt"
                                                width: parent.width
                                                text: netList.password
                                                onTextEdited: netList.password = text
                                                onAccepted: netList.submit()       // Enter
                                                onVisibleChanged: if (visible)
                                                    forceActiveFocus()
                                                echoMode: TextInput.Password      // letters show as dots
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize
                                                leftPadding: 12
                                                rightPadding: 12
                                                background: Rectangle {
                                                    radius: height / 2                // fully rounded ends
                                                    color: Theme.bg
                                                    border.width: 1
                                                    border.color: passwordField.activeFocus ? Theme.accent : Theme.pillIcon
                                                }
                                            }
                                            Text {
                                                visible: netRow.phase === "connecting"
                                                text: "Attempting to connect..."
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                            }
                                            Text {
                                                visible: netRow.phase === "success"
                                                text: "Connected Successfully."
                                                color: Theme.green
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                            }
                                            Text {
                                                visible: netRow.phase === "failed"
                                                text: netList.usedPassword ? "Incorrect Password." : "Could not connect."
                                                color: Theme.red
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                            }

                                            // Disconnect, shown once connected
                                            Rectangle {
                                                visible: netRow.phase === "success" || netRow.phase === "connected"
                                                width: parent.width
                                                height: 26
                                                radius: height / 2
                                                color: disconnectMouse.containsMouse ? Theme.red : Theme.bg
                                                scale: disconnectMouse.pressed ? 0.85 : 1

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }
                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 120
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Disconnect"
                                                    color: disconnectMouse.containsMouse ? Theme.bg : Theme.red
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize
                                                    font.weight: 600
                                                }
                                                MouseArea {
                                                    id: disconnectMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: netList.disconnectActive()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter

                        button: Pill {
                            icon: "schedule"
                            iconColor: Theme.red
                            text: Qt.formatDateTime(clock.date, "hh:mm AP")
                        }

                        Column {
                            id: cal
                            spacing: 6

                            // the date being shown; updates by itself because clock.date does
                            readonly property date now: clock.date

                            // ── Time ──
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(cal.now, "hh:mm AP")
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 2.4
                                font.weight: 700
                                font.letterSpacing: Theme.letterSpacing
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bottomPadding: 6
                                text: Qt.formatDateTime(cal.now, "dddd, MMMM d")
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 600
                            }

                            // ── Month label ──
                            Text {
                                text: Qt.formatDateTime(cal.now, "MMMM yyyy")
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 1.1
                                font.weight: 700
                                font.letterSpacing: Theme.letterSpacing
                            }

                            // ── Weekday names: Sun Mon Tue ... ──
                            DayOfWeekRow {
                                width: grid.width
                                delegate: Text {
                                    required property string shortName
                                    text: shortName
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                            }

                            // ── The month ──
                            MonthGrid {
                                id: grid
                                width: 260
                                height: 200
                                month: cal.now.getMonth()        // 0 = January, same as MonthGrid
                                year: cal.now.getFullYear()

                                delegate: Item {
                                    required property var model
                                    // compared against the clock, so it moves to the new day at midnight
                                    readonly property bool isToday: model.day === cal.now.getDate() && model.month === cal.now.getMonth() && model.year === cal.now.getFullYear()

                                    implicitWidth: 30
                                    implicitHeight: 26

                                    // highlight behind today
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: Theme.accent
                                        visible: parent.isToday
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.model.day
                                        color: parent.isToday ? Theme.bg : Theme.text
                                        // days from the previous / next month are dimmed
                                        opacity: parent.model.month === grid.month ? 1 : 0.3
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                        font.weight: parent.isToday ? 700 : 500
                                    }
                                }
                            }
                        }
                    }
                    // ── Power menu ──
                    Widget {
                        icon: "power_settings_new"
                        anchors.verticalCenter: parent.verticalCenter

                        Column {
                            spacing: 2

                            Repeater {
                                model: [
                                    {
                                        icon: "bedtime",
                                        name: "Suspend",
                                        cmd: ["systemctl", "suspend"]
                                    },
                                    {
                                        icon: "restart_alt",
                                        name: "Restart",
                                        cmd: ["systemctl", "reboot"]
                                    },
                                    {
                                        icon: "power_settings_new",
                                        name: "Power off",
                                        cmd: ["systemctl", "poweroff"]
                                    },
                                    {
                                        icon: "logout",
                                        name: "Log out",
                                        cmd: ["pkill", "Hyprland"]
                                    }
                                ]

                                Rectangle {
                                    id: powerRow
                                    required property var modelData        // { icon, name, cmd }

                                    width: 170
                                    height: 30
                                    radius: Theme.radius
                                    color: powerMouse.containsMouse ? Theme.pill : "transparent"   // highlight on hover
                                    scale: powerMouse.pressed ? 0.85 : 1                           // shrink while clicked

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    // icon + label side by side: two Texts, because each uses a different font
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: powerRow.modelData.icon           // ligature name
                                            color: powerMouse.containsMouse ? Theme.accent : Theme.text
                                            font.family: Theme.iconFont             // turns the name into the glyph
                                            font.pixelSize: Theme.iconSize
                                            font.variableAxes: Theme.iconAxes
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: powerRow.modelData.name
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: 500
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                    }

                                    MouseArea {
                                        id: powerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(powerRow.modelData.cmd)
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 3
                    color: Theme.bg
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/Theme.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        property color bg: "#1e1e2e"
        property color pill: "#313244"
        property color pillIcon: "#585b70"
        // Theme colors
        property color text: "#cdd6f4"
        property color red: "#f38ba8"
        property color green: "#a6e3a1"
        property color blue: "#89b4fa"
        property color yellow: "#f9e2af"
        property color magenta: "#cba6f7"
        property color cyan: "#94e2d5"
        property color accent: blue

        property int barHeight: 38
        property int moduleHeight: 26
        property int spacing: 8
        property int radius: 8

        property string font: "SFMono Nerd Font"
        property real textSize: 12.5
        property real letterSpacing: -0.5

        property string iconFont: "Material Symbols Rounded"
        property int iconSize: 16
        property var iconAxes: ({
                "FILL": 0,
                "wght": 700,
                "opsz": 20,
                "GRAD": 0
            })
    }
  '';

  xdg.configFile."quickshell/Widget.qml".text = ''
    // A bar button that opens its own popup underneath it.
    // The popup hangs off the bottom of the bar and curves into it, like it's
    // part of the bar, and slides down when it opens.
    // Click to open, click again (or anywhere outside) to close.
    //
    //   Widget {
    //       button: Image { width: 18; height: 18; source: "file:///home/garinh/Pictures/x.png" }
    //       Text { text: "hello"; color: Theme.text }      // ← popup content
    //   }
    //
    // `button:` is what sits in the bar: any item (Image, Text, Row, Rectangle, ...).
    // Leave it out to get a plain icon from `icon:` instead.
    // Everything else you write inside Widget { } is the popup's content.
    //
    // Popup size: leave popupWidth / popupHeight at 0 to fit the content, or set pixels.
    import QtQuick
    import QtQuick.Shapes
    import Quickshell

    Item {
        id: root

        property Component button: iconButton   // what shows in the bar
        property string icon: "widgets"         // used only by the default button

        property int popupWidth: 0     // 0 = fit the content's width
        property int popupHeight: 0    // 0 = fit the content's height
        property int padding: 12       // space between the popup's edge and your content
        property int curve: 14         // size of the two curves where the popup melts into the bar
        property int cornerRadius: 14  // roundness of the popup's two bottom corners
        property int duration: 350     // slide-down time in ms

        // true while the popup is open (or opening)
        property bool open: false
        // How far open the popup is: 0 = closed, 1 = fully open. This is what gets
        // animated; the shape's height and the content's position follow it.
        property real openness: 0

        // Children written inside Widget { } go into `area`, inside the popup.
        default property alias content: area.data

        implicitWidth: Math.max(Theme.moduleHeight, buttonLoader.width)
        implicitHeight: Theme.moduleHeight

        function openPopup() {
            popup.visible = true
            root.open = true
            slide.to = 1
            slide.restart()
        }

        function closePopup() {
            root.open = false
            slide.to = 0
            slide.restart()      // the window is hidden once this finishes (see onFinished)
        }

        NumberAnimation {
            id: slide
            target: root
            property: "openness"
            duration: root.duration
            easing.type: Easing.OutCubic
            onFinished: if (root.openness === 0) popup.visible = false
        }

        // Creates whatever was passed as `button:` and shows it, centered.
        Loader {
            id: buttonLoader
            anchors.centerIn: parent
            sourceComponent: root.button

            scale: mouse.containsMouse ? 0.85 : 1
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open ? root.closePopup() : root.openPopup()
        }

        // The default button: a Material Symbols icon, like IconButton.
        Component {
            id: iconButton
            Text {
                text: root.icon
                color: Theme.text
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                font.variableAxes: Theme.iconAxes
            }
        }

        PopupWindow {
            id: popup

            anchor {
                // Attach to the whole bar window (not just the button), so the
                // popup can sit on the bar's bottom edge.
                window: root.QsWindow.window

                // Runs right before the popup is placed. Item positions aren't reactive,
                // so the position is worked out here instead of in a binding.
                onAnchoring: {
                    // Where this button sits inside the bar window.
                    const pos = root.QsWindow.itemPosition(root)
                    // Centered under the button...
                    popup.anchor.rect.x = pos.x + root.width / 2 - popup.implicitWidth / 2
                    // ...with its top exactly on the bar's bottom edge.
                    popup.anchor.rect.y = root.QsWindow.window.height
                }
            }

            // Content size (+ padding), plus room for a curve on each side.
            readonly property real bodyWidth: root.popupWidth > 0 ? root.popupWidth : Math.ceil(area.childrenRect.width + root.padding * 2)
            readonly property real bodyHeight: root.popupHeight > 0 ? root.popupHeight : Math.ceil(area.childrenRect.height + root.padding * 2)
            implicitWidth: bodyWidth + root.curve * 2
            implicitHeight: bodyHeight

            color: "transparent"    // the shape below is what you see
            visible: false          // starts closed
            grabFocus: true         // clicking outside closes it

            // Clicking outside makes the compositor close the popup instantly,
            // without our animation. Reset so the next click opens it again.
            onClosed: {
                slide.stop()
                root.openness = 0
                root.open = false
            }

            // The background: a box whose top corners flare outward into the bar.
            //
            //   bar  ────╮                    ╭────  bar
            //            │    (your content)  │
            //            ╰────────────────────╯
            Shape {
                id: shape
                width: popup.implicitWidth
                height: root.openness * popup.bodyHeight      // grows down as it opens
                visible: height > 0.5
                preferredRendererType: Shape.CurveRenderer    // smooth, anti-aliased curves

                // Curves can't be bigger than half the height, so they grow in while opening.
                readonly property real c: Math.min(root.curve, height / 2)
                readonly property real r: Math.min(root.cornerRadius, height / 2)
                readonly property real boxLeft: root.curve                // left side of the box
                readonly property real boxRight: width - root.curve      // right side of the box

                ShapePath {
                    fillColor: Theme.bg            // same color as the bar, so they read as one piece
                    strokeColor: "transparent"

                    // Start on the bar's edge, left of the box, and trace clockwise.
                    startX: shape.boxLeft - shape.c
                    startY: 0
                    // top-left flare: curve down into the box's left side
                    PathArc { x: shape.boxLeft; y: shape.c; radiusX: shape.c; radiusY: shape.c }
                    // left side
                    PathLine { x: shape.boxLeft; y: shape.height - shape.r }
                    // bottom-left corner
                    PathArc {
                        x: shape.boxLeft + shape.r; y: shape.height
                        radiusX: shape.r; radiusY: shape.r
                        direction: PathArc.Counterclockwise
                    }
                    // bottom
                    PathLine { x: shape.boxRight - shape.r; y: shape.height }
                    // bottom-right corner
                    PathArc {
                        x: shape.boxRight; y: shape.height - shape.r
                        radiusX: shape.r; radiusY: shape.r
                        direction: PathArc.Counterclockwise
                    }
                    // right side
                    PathLine { x: shape.boxRight; y: shape.c }
                    // top-right flare: curve back out onto the bar's edge
                    PathArc { x: shape.boxRight + shape.c; y: 0; radiusX: shape.c; radiusY: shape.c }
                }
            }

            // The content window: as tall as the shape is right now, so anything
            // below the shape's bottom edge is hidden (clip) while it slides.
            Item {
                x: root.curve
                width: popup.bodyWidth
                height: shape.height
                clip: true

                Item {
                    id: area
                    x: root.padding
                    // Rides on the bottom edge, so the content slides down out of the bar.
                    y: parent.height - popup.bodyHeight + root.padding
                    width: popup.bodyWidth - root.padding * 2
                    height: popup.bodyHeight - root.padding * 2
                    opacity: root.openness
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/Workspaces.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Hyprland

    Rectangle {
        id: root

        required property var screen

        property int cellWidth: 24
        property int padding: 3
        property int slideTime: 300

        property var monitor: Hyprland.monitorFor(root.screen)
        property var list: !root.monitor ? [] : Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)
        property int activeIndex: root.list.findIndex(w => w.active)

        implicitWidth: root.list.length * root.cellWidth + root.padding * 2
        implicitHeight: Theme.moduleHeight
        radius: Theme.radius
        color: Theme.pill
        visible: root.list.length > 0

        Rectangle {
            x: root.padding + root.activeIndex * root.cellWidth
            width: root.cellWidth
            height: parent.height - 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activeIndex >= 0
            radius: Theme.radius - 2
            color: Qt.darker(Theme.accent, 3)
            opacity: 0.75

            Behavior on x {
                NumberAnimation {
                    duration: root.slideTime
                    easing.type: Easing.OutCubic
                }
            }
        }
        Row {
            x: root.padding
            height: parent.height

            Repeater {
                model: root.list

                Text {
                    required property var modelData

                    width: root.cellWidth
                    height: parent.height
                    text: modelData.name
                    color: modelData.active ? Theme.accent : Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    font.family: Theme.font
                    font.pixelSize: Theme.textSize
                    font.weight: 600

                    Behavior on color {
                        ColorAnimation {
                            duration: root.slideTime
                            easing.type: Easing.OutCubic
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.activate()
                    }
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/Pill.qml".text = ''
    import QtQuick

    Rectangle {
        id: root

        property string icon: ""
        property color iconColor: Theme.text
        property string text: ""

        implicitWidth: row.width
        implicitHeight: Theme.moduleHeight
        radius: Theme.radius
        color: Theme.pill

        Row {
            id: row
            height: parent.height
            Rectangle {
                width: iconLabel.implicitWidth + 10
                height: parent.height
                color: Theme.pillIcon
                topLeftRadius: root.radius
                bottomLeftRadius: root.radius

                Text {
                    id: iconLabel
                    anchors.centerIn: parent
                    text: root.icon
                    color: root.iconColor
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize
                    font.variableAxes: Theme.iconAxes
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 6
                text: root.text
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                font.weight: 600
                font.letterSpacing: Theme.letterSpacing
            }
        }
    }
  '';

  xdg.configFile."quickshell/IconButton.qml".text = ''
    import QtQuick

    Rectangle {
        id: root

        property string icon: ""
        property color iconColor: Theme.text
        property int iconSize: Theme.iconSize

        signal clicked

        implicitWidth: Theme.moduleHeight
        implicitHeight: Theme.moduleHeight
        radius: Theme.radius
        color: "transparent"
        Text {
            scale: mouse.containsMouse ? 0.85 : 1
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            font.variableAxes: Theme.iconAxes
            Behavior on scale {                           // ← new: animate it
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            id: mouse
            hoverEnabled: true
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
  '';

  xdg.configFile."quickshell/Poll.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io

    Scope {
        id: root

        property string cmd: ""
        property int every: 5000
        property string text: ""

        Process {
            id: process

            command: ["sh", "-c", root.cmd]
            running: true

            stdout: StdioCollector {
                id: output
                onStreamFinished: root.text = output.text.trim()
            }
        }

        Timer {
            interval: root.every
            running: true
            repeat: true
            onTriggered: process.running = true
        }
    }
  '';
  services.hyprpolkitagent.enable = true;
  programs.hyprtoolkit.settings = {
    background = "0xFF1E1E2E"; # your Theme.bg
    base = "0xFF313244"; # your Theme.pill
    accent = "0xFF89B4FA"; # your Theme.accent (blue)
    font_family = "SFProText Nerd Font";
    font_family_monospace = "SFMono Nerd Font";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use programs.hyprland from configuration.nix
    portalPackage = null; # portal already set in configuration.nix
    configType = "lua";
    settings = lib.mkForce { };
    systemd.enable = true; # your Lua already runs dbus-update-activation-environment
    extraConfig = ''
      -- Generated by hyprconf2lua v1.3.2
      -- https://github.com/Prateek-squadron/hyprconf2lua
      -- Manual review may be needed for complex directives
      -- Fixed: env vars now actually applied via hl.env(); blur config consolidated into one block

      ---@module 'hl'

      -- Catppuccin palette (written to ~/.config/hypr/themes/catppuccin.lua by catppuccin/nix)
      local colors = require('themes.catppuccin')

      hl.monitor({
          output   = "DP-1", -- for laptops generally eDP-0 or eDP-1, and desktops usually DP-1.
          mode     = "1920x1080@240",
          position = "0x0",
          scale    = 1,
      })

      hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
      hl.env("XDG_SESSION_TYPE", "wayland")
      hl.env("XDG_SESSION_DESKTOP", "Hyprland")
      --hyprmod settings
      hl.unbind("SUPER + SHIFT + Left")
      hl.bind("SUPER + SHIFT + Left", hl.dsp.focus({ workspace = -1 }))
      hl.unbind("SUPER + SHIFT + Right")
      hl.bind("SUPER + SHIFT + Right", hl.dsp.focus({ workspace = "+1" }))
      hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --output-folder ~/Pictures/Screenshots"))
      hl.bind("SUPER + CTRL + Right", hl.dsp.window.move({ workspace = "+1" }))
      hl.bind("SUPER + CTRL + Left", hl.dsp.window.move({ workspace = -1 }))
      -- Env vars (Variance by graphics drivers)
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
      hl.env("NVD_BACKEND", "direct")
      hl.env("GBM_BACKEND", "nvidia-drm")
      hl.env("__GL_GSYNC_ALLOWED", "0")
      hl.env("__GL_VRR_ALLOWED", "0")
      hl.env("WLR_NO_HARDWARE_CURSORS", "1")
      -- Force Qt apps to use qt5ct/qt6ct for styling layouts
      hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

      -- Ensure Qt apps pick up Wayland instead of fallback X11 layouts
      hl.env("QT_QPA_PLATFORM", "wayland")

      hl.config({
          layerrule = {
              "blur, quickshell-bar",
              "ignorealpha 0.4, quickshell-bar", -- lets blur render through semi-transparent areas; tune threshold to your CSS alpha
          }
      })


      -- Consolidated decoration/blur block (previously split across 3 hl.config calls
      -- that overwrote each other; only the last one was ever actually in effect)
      hl.config({
          decoration = {
              rounding = 8,
              blur = {
                  enabled = true,
                  size = 8,
                  passes = 3,
                  new_optimizations = true,
                  xray = true,
              },
              shadow = {
                  enabled = false,
              },
          },
      })

      hl.config({
          animations = {
              enabled = true,
          },
      })

      hl.config({
          input = {
              kb_layout = "us",
              follow_mouse = 1,
              accel_profile = "flat",
              sensitivity = 0.0,
          },
      })
      hl.config({
          general = {
              gaps_in = 4,
              gaps_out = 8,
              border_size = 0,
              ["col.active_border"]   = "rgba(" .. colors.overlay1Alpha .. "ee)",    
              ["col.inactive_border"] = "rgba(" .. colors.surface1Alpha .. "99)",  
              resize_on_border = true,
              extend_border_grab_area = 20,  -- pixels of grab area beyond the visible border
              hover_icon_on_border = true,
          },
      })
      hl.config({
          cursor = {
              inactive_timeout = 0,
              no_hardware_cursors = true,
          },
      })
      -- anims here
      -- Define curves first
      hl.curve("sharp", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
      hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1} } })
      hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })

      -- Then reference them by leaf
      hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "snappy", style = "popin 90%" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "sharp", style = "popin 90%" })
      hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "linear" })
      hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "sharp" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "snappy", style = "slide" })
      hl.animation({ leaf = "layers", enabled = true, speed = 1.6, bezier = "sharp" })
      hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.1 && ~/.config/hypr/scripts/capslock.sh"))

      -- Try using the shorthand variant if the full word is being ignored

      hl.bind("SUPER + J", hl.dsp.focus({ workspace = "-1" }))
      hl.bind("SUPER + K", hl.dsp.focus({ workspace = "+1" }))

      hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
      hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
      hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
      hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))


      -- Trigger the rofi power menu

      hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))

      hl.bind("SUPER + Q", hl.dsp.window.close())

      hl.bind("SUPER + SHIFT + E", hl.dsp.exit())


      -- Captures the entire screen and copies it directly to your clipboard
      -- Pressing Print captures the entire screen straight to your clipboard


      -- True fullscreen (Hides waybar and gaps)

      hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind("SUPER + V", hl.dsp.window.float())

      -- Forces every window on the workspace into floating mode

      hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("hyprctl clients -j| jq -r '.[]| select(.workspace.id=='$(hyprctl activeworkspace -j| jq '.id')')| . address'| xargs -I { } hyprctl dispatch togglefloating address:{ }"))

      -- Toggle Rofi App Launcher using Super and Tab

      hl.bind("SUPER + TAB", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -theme-str 'window { close-on-click:true; } '"))

      -- Delete or replace the bottom section with ONLY this line:

      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })

      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- TODO: manual review: blurls = "waybar"

      -- Autostart
      hl.on("hyprland.start", function()
         hl.exec_cmd("awww-daemon")
         hl.exec_cmd("awww img ~/Pictures/Wallpapers/hk.png")
         hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
         hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
         hl.exec_cmd("eww daemon")
         hl.exec_cmd("playerctld daemon")
      end)

      -- HyprMod managed settings
      --require("hyprland-gui")
      -- hyprbars settings go inside hl.config under plugin
      --[[hl.config({
          plugin = {
              hyprbars = {
                  bar_height = 20,
                  bar_color = colors.base,
                  ["col.text"] = colors.text,
                  bar_text_size = 14,
                  bar_text_font = "SF Pro Text",
                  bar_button_padding = 10,
                  bar_padding = 10,
                  bar_precedence_over_border = true,
                  bar_part_of_window = true,
              }
          }
      })

      -- buttons are added separately
      hl.plugin.hyprbars.add_button({
          bg_color = colors.red,
          fg_color = colors.base,
          size = 15,
          icon = "󱎘",
          action = "hyprctl dispatch 'hl.dsp.window.close()'",
      })
      hl.plugin.hyprbars.add_button({
          bg_color = colors.green,
          fg_color = colors.base,
          size = 15,
          icon = "",
          action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
      })
      hl.plugin.hyprbars.add_button({
          bg_color = colors.mauve,
          fg_color = colors.base,
          size = 15,
          icon = "",
          action = "hyprctl dispatch 'hl.dsp.window.float({action=\"toggle\"})'",
      })
      ]]
    '';
  };

  programs.rofi = {
    enable = true;
    settings = {
      modi = "drun,run,filebrowser";
      show-icons = true;
      display-drun = "";
      display-run = "";
      display-filebrowser = "";
      drun-display-format = "{name}";
    };
    theme = lib.mkForce (
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        # Mocha palette file written to ~/.local/share/rofi/themes by catppuccin/nix
        "@import" = "catppuccin-mocha";
        "*" = {
          background = mkLiteral "@base";
          background-alt = mkLiteral "@surface0";
          foreground = mkLiteral "@text";
          selected = mkLiteral "@lavender";
          active = mkLiteral "@green";
          urgent = mkLiteral "@red";
          font = "SFMono Nerd Font 11";
        };
        "window" = {
          transparency = "real";
          location = mkLiteral "west";
          anchor = mkLiteral "west";
          fullscreen = false;
          width = mkLiteral "500px";
          height = mkLiteral "96%";
          x-offset = mkLiteral "20px";
          y-offset = mkLiteral "0px";
          enabled = true;
          margin = mkLiteral "0px";
          padding = mkLiteral "0px";
          border = mkLiteral "4px solid";
          border-color = mkLiteral "@background-alt";
          cursor = "default";
          background-color = mkLiteral "@background";
        };
        "mainbox" = {
          enabled = true;
          spacing = mkLiteral "20px";
          margin = mkLiteral "0px";
          padding = mkLiteral "20px";
          background-color = mkLiteral "transparent";
          children = [
            "inputbar"
            "message"
            "listview"
            "mode-switcher"
          ];
        };
        "inputbar" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
          children = [
            "textbox-prompt-colon"
            "entry"
          ];
        };
        "prompt" = {
          enabled = true;
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
        };
        "textbox-prompt-colon" = {
          enabled = true;
          padding = mkLiteral "0px";
          expand = false;
          str = " ";
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
        };
        "entry" = {
          enabled = true;
          padding = mkLiteral "0px";
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
          cursor = mkLiteral "text";
          placeholder = "Search...";
          placeholder-color = mkLiteral "inherit";
        };
        "listview" = {
          enabled = true;
          columns = 1;
          lines = 12;
          cycle = true;
          dynamic = true;
          scrollbar = true;
          layout = mkLiteral "vertical";
          reverse = false;
          fixed-height = true;
          fixed-columns = true;
          spacing = mkLiteral "5px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = "default";
        };
        "scrollbar" = {
          handle-width = mkLiteral "5px";
          handle-color = mkLiteral "@selected";
          background-color = mkLiteral "@background-alt";
        };
        "element" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "6px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = mkLiteral "pointer";
        };
        "element normal.normal, element alternate.normal" = {
          background-color = mkLiteral "var(background)";
          text-color = mkLiteral "var(foreground)";
        };
        "element normal.urgent, element alternate.urgent, element selected.active" = {
          background-color = mkLiteral "var(urgent)";
          text-color = mkLiteral "var(background)";
        };
        "element normal.active, element alternate.active, element selected.urgent" = {
          background-color = mkLiteral "var(active)";
          text-color = mkLiteral "var(background)";
        };
        "element selected.normal" = {
          background-color = mkLiteral "var(selected)";
          text-color = mkLiteral "var(background)";
        };
        "element-icon" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
          size = mkLiteral "24px";
          cursor = mkLiteral "inherit";
        };
        "element-text" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "inherit";
          highlight = mkLiteral "inherit";
          cursor = mkLiteral "inherit";
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.0";
        };
        "mode-switcher" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "0px 0px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
        };
        "button" = {
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "inherit";
          cursor = mkLiteral "pointer";
        };
        "button selected" = {
          background-color = mkLiteral "var(urgent)";
          text-color = mkLiteral "var(background)";
        };
        "message" = {
          enabled = true;
          margin = mkLiteral "0px";
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
        };
        "textbox" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          vertical-align = mkLiteral "0.5";
          horizontal-align = mkLiteral "0.0";
          highlight = mkLiteral "none";
          placeholder-color = mkLiteral "@foreground";
          blink = true;
          markup = true;
        };
        "error-message" = {
          padding = mkLiteral "20px";
          background-color = mkLiteral "@background";
          text-color = mkLiteral "@foreground";
        };
      }
    );
  };

  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      logo = {
        padding = {
          top = 1;
          right = 3;
        };
      };
      display = {
        separator = " │ ";
      };
      modules = [
        {
          type = "custom";
          format = "╭───────────╮";
        }
        {
          type = "user";
          key = "│ user    ";
          keyColor = "red";
        }
        {
          type = "host";
          key = "│󰋜 hname   ";
          keyColor = "green";
        }
        {
          type = "command";
          key = "│󰋔 os age  ";
          keyColor = "yellow";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
        }
        {
          type = "uptime";
          key = "│󱎫 uptime  ";
          keyColor = "blue";
        }
        {
          type = "os";
          key = "│ distro  ";
          keyColor = "cyan";
        }
        {
          type = "kernel";
          key = "│󰒋 kernel  ";
          keyColor = "magenta";
        }
        {
          type = "wm";
          key = "│󱂬 wm      ";
          keyColor = "green";
        }
        {
          type = "lm";
          key = "│󰧨 desktop ";
          keyColor = "cyan";
        }
        {
          type = "terminal";
          key = "│ term    ";
          keyColor = "red";
        }
        {
          type = "shell";
          key = "│󰞷 shell   ";
          keyColor = "green";
        }
        {
          type = "cpu";
          key = "│󰻠 cpu     ";
          keyColor = "yellow";
        }
        {
          type = "gpu";
          key = "│󰢮 gpu     ";
          keyColor = "yellow";
        }
        {
          type = "disk";
          key = "│󰋊 disk    ";
          keyColor = "blue";
        }
        {
          type = "memory";
          key = "│󰍛 memory  ";
          keyColor = "cyan";
        }
        {
          type = "localip";
          key = "│ local ip";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "│ packages";
          keyColor = "green";
        }
        {
          type = "custom";
          format = "├───────────┤";
        }
        {
          type = "colors";
          key = "│🎨 colors ";
          symbol = "circle";
        }
        {
          type = "custom";
          format = "╰───────────╯";
        }
      ];
    };
  };

  programs.kitty = {
    enable = true;
    themeFile = lib.mkForce null;
    font.name = "SFMono Nerd Font";
    shellIntegration = {
      mode = null; # set via settings below, so HM does not force "no-rc"
      enableBashIntegration = false;
      enableZshIntegration = false;
      enableFishIntegration = false;
    };
    settings = {
      remember_window_size = "no";
      scrollback_lines = 10000;
      background_opacity = "0.7";
      cursor_shape = "beam";
      shell_integration = "no-cursor";
      cursor_trail = 1;
      repaint_delay = 5;
      input_delay = 1;
      sync_to_monitor = "no";
      confirm_os_window_close = 0;
      cursor_trail_start_threshold = 0;
      foreground = "#CDD6F4";
      background = "#1E1E2E";
      selection_foreground = "#1E1E2E";
      selection_background = "#F5E0DC";
      cursor = "#F5E0DC";
      cursor_text_color = "#1E1E2E";
      url_color = "#F5E0DC";
      active_border_color = "#B4BEFE";
      inactive_border_color = "#6C7086";
      bell_border_color = "#F9E2AF";
      wayland_titlebar_color = "system";
      active_tab_foreground = "#11111B";
      active_tab_background = "#CBA6F7";
      inactive_tab_foreground = "#CDD6F4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111B";
      mark1_foreground = "#1E1E2E";
      mark1_background = "#B4BEFE";
      mark2_foreground = "#1E1E2E";
      mark2_background = "#CBA6F7";
      mark3_foreground = "#1E1E2E";
      mark3_background = "#74C7EC";
      color0 = "#45475A";
      color8 = "#585B70";
      color1 = "#F38BA8";
      color9 = "#F38BA8";
      color2 = "#A6E3A1";
      color10 = "#A6E3A1";
      color3 = "#F9E2AF";
      color11 = "#F9E2AF";
      color4 = "#89B4FA";
      color12 = "#89B4FA";
      color5 = "#F5C2E7";
      color13 = "#F5C2E7";
      color6 = "#94E2D5";
      color14 = "#94E2D5";
      color7 = "#BAC2DE";
      color15 = "#A6ADC8";
    };
  };
  # kitty rewrites kitty.conf itself (e.g. the font/theme kittens), turning HM's
  # symlink into a regular file; force lets HM replace it
  xdg.configFile."kitty/kitty.conf".force = true;

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard"; # whatever GTK theme you have installed
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        variant = "mocha";
      };
    };
    gtk4.theme = config.gtk.theme;

    font = {
      name = "SFProText Nerd Font";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "catppuccin-mocha-mauve-cursors";
    package = pkgs.catppuccin-cursors.mochaMauve;
  };

  gtk.cursorTheme = {
    name = "catppuccin-mocha-mauve-cursors";
    package = pkgs.catppuccin-cursors.mochaMauve;
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "lsd -la";
      ls = "lsd";
      gs = "git status";
      update = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos && cd && flatpak update -y";
      viconfig = "sudo fresh /etc/nixos/configuration.nix";
      clean = "nh clean all";
      reload = "source ~/.bashrc";
    };
    bashrcExtra = ''
      source -- "${pkgs.blesh}/share/blesh/ble.sh" --noattach
      eval "$(starship init bash)"
      export PATH=~/bin:$PATH
      export PATH="$HOME/.npm-global/bin:$PATH"
      fastfetch
      [[ ! ''${BLE_VERSION-} ]] || ble-attach
    '';
  };

  # Lock screen (launched from the waybar lock button)
  # Measured from the reference screenshot and scaled to 1920x1080
  programs.hyprlock = {
    enable = true;
    package = null; # hyprlock is installed system-wide in configuration.nix (needed for PAM)
    # no mkForce: catppuccin sources its Mocha palette ($rosewater, $surface0, ...);
    # its default layout is turned off with useDefaultConfig = false below
    settings = {
      general = {
        hide_cursor = false; # cursor is visible in the reference
      };

      background = [
        {
          monitor = "";
          path = "${config.home.homeDirectory}/Pictures/Wallpapers/hk.png";
          blur_passes = 3;
        }
      ];

      # Clock: 07:44 — ink ~238x64px, centered 74px above screen center
      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "$rosewater";
          font_size = 64;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 74";
          halign = "center";
          valign = "center";
        }
      ];

      # Password pill: ~225x56px, centered 27px below screen center
      input-field = [
        {
          monitor = "";
          size = "200, 50";
          position = "0, -20";
          halign = "center";
          valign = "center";
          rounding = -1; # full pill
          outline_thickness = 3;
          outer_color = "$rosewater";
          inner_color = "$surface0";
          font_color = "$rosewater";
          font_family = "JetBrainsMono Nerd Font";
          placeholder_text = "<i>Input Password...</i>";
          fade_on_empty = false;
          dots_center = true;
          check_color = "$yellow";
          fail_color = "$red";
          dots_size = 0.33; # 0.2–0.8, fraction of the field height
          dots_spacing = 0.15; # 0.0–1.0, gap between dots, relative to dot size
        }
      ];
    };
  };
  # keep catppuccin's palette for hyprlock, but not its corner clock / layout / mauve field
  catppuccin.hyprlock.useDefaultConfig = false;
  # replaces any hand-written ~/.config/hypr/hyprlock.conf instead of failing activation
  xdg.configFile."hypr/hyprlock.conf".force = true;
}
