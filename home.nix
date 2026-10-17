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
    import Quickshell.Services.UPower
    import Quickshell.Networking
    import Quickshell.Services.Notifications
    import Quickshell.Io
    import Quickshell.Widgets
    import Quickshell.Bluetooth

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
            // Move a queue entry so it ends up at position `to`. mpv's playlist-move puts the
            // entry *in front of* its second index, so moving down needs one more.
            function move(from, to) {
                if (from === to)
                    return;
                send(["playlist-move", from, to > from ? to + 1 : to]);
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
                /*
                Poll {
                    id: bluetooth
                    cmd: "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"
                }
                */
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
                                    // pointing hand over the whole slider, grab hand while dragging.
                                    // HoverHandler only watches the mouse, so dragging still works.
                                    HoverHandler {
                                        cursorShape: control.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    }
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
                                    // ScriptModel compares the new queue with the old one and only
                                    // updates the rows that changed. A plain array (model: music.queue)
                                    // makes the ListView throw every row away and rebuild the list on
                                    // each mpv update, which is what jumped it back to the top after a drop.
                                    model: ScriptModel {
                                        values: music.queue
                                    }
                                    boundsBehavior: Flickable.StopAtBounds
                                    // no flicking the list while a row is being dragged
                                    // (it scrolls by itself near the edges instead, see edgeScroll)
                                    interactive: dragFrom < 0
                                    // The ListView deletes rows that are far off screen. While dragging,
                                    // keep them all, so the row in your hand isn't deleted when the list
                                    // scrolls a long way.
                                    cacheBuffer: dragFrom >= 0 ? Math.max(400, contentHeight) : 400

                                    // ── drag to reorder ──
                                    // Kept here, not in the rows, so every row can see the drag.
                                    property int dragFrom: -1      // row being dragged, -1 = none
                                    property int dragTo: -1        // where it would land if dropped now
                                    property real dragOffset: 0    // how far it has moved from its spot
                                    property bool settling: false  // just dropped: skip the slide-back animation
                                    readonly property real rowStep: 46 + spacing   // row height + gap
                                    property real grabY: 0         // where you grabbed it, in list-content coordinates
                                    property real dragMouseY: 0    // the mouse, measured from the list's top edge
                                    property real grabInRow: 0     // where in the row you grabbed it
                                    property var dragSong: null    // the song being dragged (mpv entry)
                                    property var dragInfo: null    // ...and its library info, for the floating copy
                                    property bool dropping: false  // let go, waiting for mpv to send the new order
                                    property real dropViewY: 0     // where the dropped row lands, from the list's top edge

                                    // Let go: the floating copy glides into the gap and everything stays
                                    // as it looks until mpv sends the new order (a few ms). Then the real
                                    // rows take over, scrolled so nothing on screen moves.
                                    function drop() {
                                        const from = dragFrom, to = dragTo;
                                        if (from < 0 || from === to) {
                                            endDrag();
                                            return;
                                        }
                                        // the gap = where the row now at `to` sits normally
                                        const slot = itemAtIndex(to);
                                        dropViewY = (slot ? slot.y : originY + to * rowStep) - contentY;
                                        dropping = true;
                                        dropTimeout.restart();
                                        music.move(from, to);
                                    }
                                    function finishDrop() {
                                        if (!dropping)
                                            return;
                                        const to = dragTo, viewY = dropViewY;
                                        endDrag();
                                        forceLayout();
                                        const row = itemAtIndex(to);
                                        if (row) {
                                            const top = originY;
                                            const bottom = originY + Math.max(0, contentHeight - height);
                                            contentY = Math.max(top, Math.min(bottom, row.y - viewY));
                                        }
                                    }
                                    function endDrag() {
                                        dropTimeout.stop();
                                        settling = true;      // rows jump to their new places, no slide
                                        dropping = false;
                                        dragFrom = -1;
                                        dragTo = -1;
                                        dragOffset = 0;
                                    }
                                    Connections {
                                        target: music
                                        // after the list has caught up with the new order
                                        function onQueueChanged() {
                                            if (queueList.dropping)
                                                Qt.callLater(queueList.finishDrop);
                                        }
                                    }
                                    // mpv didn't answer: put things back
                                    Timer {
                                        id: dropTimeout
                                        interval: 800
                                        onTriggered: queueList.endDrag()
                                    }

                                    // Content coordinates count from the top of the whole queue, not the
                                    // visible part, so the offset stays right while the list scrolls.
                                    function updateDrag() {
                                        dragOffset = dragMouseY + contentY - grabY;
                                        // the slot under the middle of the dragged row
                                        const slot = Math.round(dragFrom + dragOffset / rowStep);
                                        dragTo = Math.max(0, Math.min(count - 1, slot));
                                    }

                                    // While dragging, hold the row near the top or bottom edge (or past
                                    // it) and the list scrolls that way; the closer to the edge, the faster.
                                    Timer {
                                        id: edgeScroll
                                        interval: 16          // about once a frame
                                        repeat: true
                                        running: queueList.dragFrom >= 0 && !queueList.dropping
                                        onTriggered: {
                                            const zone = 48;      // px from each edge where it starts scrolling
                                            const maxSpeed = 12;  // px per tick at the very edge
                                            const y = queueList.dragMouseY;
                                            let push = 0;
                                            if (y < zone)
                                                push = -(zone - y) / zone;
                                            else if (y > queueList.height - zone)
                                                push = (y - (queueList.height - zone)) / zone;
                                            if (push === 0)
                                                return;
                                            push = Math.max(-1, Math.min(1, push));
                                            const top = queueList.originY;
                                            const bottom = queueList.originY + Math.max(0, queueList.contentHeight - queueList.height);
                                            const next = Math.max(top, Math.min(bottom, queueList.contentY + push * maxSpeed));
                                            if (next === queueList.contentY)
                                                return;
                                            queueList.contentY = next;
                                            queueList.updateDrag();
                                        }
                                    }

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

                                        // Where this row should sit while something is dragged:
                                        // the dragged row follows the mouse, the rows it passes
                                        // step aside by one row to make room for it.
                                        readonly property bool dragged: queueList.dragFrom === index
                                        readonly property real shift: {
                                            const f = queueList.dragFrom, t = queueList.dragTo;
                                            if (f < 0 || dragged)
                                                return 0;
                                            if (f < t && index > f && index <= t)
                                                return -queueList.rowStep;   // dragged one is moving down past me
                                            if (f > t && index >= t && index < f)
                                                return queueList.rowStep;    // dragged one is moving up past me
                                            return 0;
                                        }

                                        width: ListView.view.width - 8
                                        height: 46
                                        radius: Theme.radius
                                        color: entryMouse.containsMouse || dragged ? Theme.pill : "transparent"
                                        border.width: 1
                                        border.color: entry.modelData.current ? Theme.accent : "transparent"
                                        scale: entryMouse.pressed && !dragged ? 0.95 : 1
                                        // The row you're dragging stays in its slot, invisible; a floating
                                        // copy (dragGhost, below the delegate) follows the mouse instead.
                                        // The list stops drawing rows that scroll out of view, so a row
                                        // that moved itself would vanish once its slot scrolled away.
                                        opacity: dragged ? 0 : 1

                                        transform: Translate {
                                            y: entry.dragged ? 0 : entry.shift
                                            Behavior on y {
                                                enabled: !entry.dragged && !queueList.settling
                                                NumberAnimation {
                                                    duration: 150
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }

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

                                            // grab here and drag up or down to move the song
                                            Text {
                                                id: dragHandle
                                                x: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "drag_indicator"
                                                color: Theme.text
                                                opacity: entryMouse.containsMouse || entry.dragged ? 0.8 : 0.3
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                font.variableAxes: Theme.iconAxes

                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -6               // a bit easier to grab
                                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    preventStealing: true             // keep the list from scrolling instead

                                                    onPressed: mouse => {
                                                        if (queueList.dropping)
                                                            return;
                                                        queueList.dragMouseY = mapToItem(queueList, 0, mouse.y).y;
                                                        queueList.grabInRow = mapToItem(entry, 0, mouse.y).y;
                                                        queueList.dragSong = entry.modelData;
                                                        queueList.dragInfo = entry.info;
                                                        queueList.grabY = queueList.dragMouseY + queueList.contentY;
                                                        queueList.settling = false;
                                                        queueList.dragOffset = 0;
                                                        queueList.dragTo = entry.index;
                                                        queueList.dragFrom = entry.index;
                                                    }
                                                    onPositionChanged: mouse => {
                                                        if (queueList.dragFrom < 0 || queueList.dropping)
                                                            return;
                                                        queueList.dragMouseY = mapToItem(queueList, 0, mouse.y).y;
                                                        queueList.updateDrag();
                                                    }
                                                    onReleased: queueList.drop()
                                                    onCanceled: queueList.endDrag()
                                                }
                                            }

                                            ClippingRectangle {
                                                id: entryCover
                                                x: 28
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

                                    // the floating copy of the row being dragged
                                    Rectangle {
                                        id: dragGhost
                                        parent: queueList          // the list itself, not its scrolling content
                                        visible: queueList.dragFrom >= 0
                                        z: 10
                                        x: 0
                                        y: queueList.dropping ? queueList.dropViewY : queueList.dragMouseY - queueList.grabInRow
                                        width: queueList.width - 8
                                        height: 46
                                        radius: Theme.radius
                                        color: Theme.pill
                                        border.width: 1
                                        border.color: queueList.dragSong && queueList.dragSong.current ? Theme.accent : "transparent"
                                        scale: queueList.dropping ? 1 : 1.03

                                        // only animates the glide into the gap, not following the mouse
                                        Behavior on y {
                                            enabled: queueList.dropping
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            x: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "drag_indicator"
                                            color: Theme.text
                                            opacity: 0.8
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize
                                            font.variableAxes: Theme.iconAxes
                                        }
                                        ClippingRectangle {
                                            id: ghostCover
                                            x: 28
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 36
                                            height: 36
                                            radius: 6
                                            color: Theme.bg

                                            Image {
                                                anchors.fill: parent
                                                source: queueList.dragInfo ? queueList.dragInfo.cover : ""
                                                sourceSize: Qt.size(72, 72)
                                                fillMode: Image.PreserveAspectCrop
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                visible: !queueList.dragInfo || queueList.dragInfo.cover === ""
                                                text: "music_note"
                                                color: Theme.pillIcon
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                            }
                                        }
                                        Column {
                                            anchors.left: ghostCover.right
                                            anchors.leftMargin: 10
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                width: parent.width
                                                text: queueList.dragInfo ? queueList.dragInfo.title : queueList.dragSong ? queueList.dragSong.filename.split("/").pop() : ""
                                                elide: Text.ElideRight
                                                color: queueList.dragSong && queueList.dragSong.current ? Theme.accent : Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize
                                                font.weight: 700
                                                font.letterSpacing: Theme.letterSpacing
                                            }
                                            Text {
                                                width: parent.width
                                                visible: text !== ""
                                                text: queueList.dragInfo ? queueList.dragInfo.artist : ""
                                                elide: Text.ElideRight
                                                color: Theme.text
                                                opacity: 0.6
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.85
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

                    // ── Display: brightness, night light, color filters ──
                    // Icon only, like Bluetooth. The icon shows what's on: a filter, night
                    // light, or plain brightness.
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: {
                            if (disp.filter === "invert")
                                return "invert_colors";
                            if (disp.filter === "grayscale")
                                return "filter_b_and_w";
                            if (disp.filter === "sepia")
                                return "filter_vintage";
                            if (disp.filter === "contrast")
                                return "contrast";
                            return disp.nightOn ? "nightlight" : "brightness_6";
                        }

                        Column {
                            id: disp
                            spacing: 8
                            width: 280

                            // ── state ──
                            // "backlight": a laptop screen, set for real with brightnessctl.
                            // "gamma": no backlight (desktop monitor), so dim it in software with
                            //          hyprsunset instead. Looks the same, but the panel stays at
                            //          full power.
                            property string mode: "backlight"
                            property int brightness: 100     // percent
                            property bool nightOn: false
                            property int kelvin: 4000        // night light warmth: lower = warmer
                            property string filter: "none"   // none / invert / grayscale / sepia / contrast
                            readonly property string shaderDir: Quickshell.env("HOME") + "/.config/hypr/shaders/"

                            // Read the real values each time the popup opens, so keys or other
                            // tools changing them are picked up.
                            readonly property bool shown: !!QsWindow.window && QsWindow.window.visible
                            onShownChanged: if (shown)
                                reader.running = true

                            Process {
                                id: reader
                                running: true
                                // prints e.g. "backlight 45" (or "gamma 100.000000"), then "night false 4000"
                                command: ["sh", "-c", "if out=$(brightnessctl -m -c backlight 2>/dev/null); then echo \"backlight $(echo \"$out\" | head -n1 | cut -d, -f4 | tr -d %)\"; else echo \"gamma $(hyprctl hyprsunset gamma 2>/dev/null)\"; fi; echo \"night $(hyprctl hyprsunset identity get 2>/dev/null) $(hyprctl hyprsunset temperature 2>/dev/null)\""]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        for (const line of text.trim().split("\n")) {
                                            const f = line.trim().split(/\s+/);
                                            if (f[0] === "backlight" || f[0] === "gamma") {
                                                disp.mode = f[0];
                                                const v = parseFloat(f[1]);
                                                if (!isNaN(v) && !brightSlider.pressed)
                                                    disp.brightness = Math.round(v);
                                            } else if (f[0] === "night" && (f[1] === "true" || f[1] === "false")) {
                                                // identity = "no color change", so night light is off
                                                disp.nightOn = f[1] === "false";
                                                const k = parseInt(f[2]);
                                                if (disp.nightOn && !isNaN(k) && !warmSlider.pressed)
                                                    disp.kelvin = k;
                                            }
                                        }
                                    }
                                }
                            }

                            // Sliders fire many times a second while dragging. Each setter runs
                            // one command at a time: if you move again while it's still running,
                            // it sends the newest value as soon as it's done. That keeps it
                            // smooth without piling up hundreds of processes.
                            property bool brightDirty: false
                            function pushBrightness() {
                                if (brightSetter.running) {
                                    brightDirty = true;
                                    return;
                                }
                                brightSetter.command = mode === "backlight" ? ["brightnessctl", "-q", "-c", "backlight", "set", brightness + "%"] : ["hyprctl", "hyprsunset", "gamma", String(brightness)];
                                brightSetter.running = true;
                            }
                            Process {
                                id: brightSetter
                                onExited: if (disp.brightDirty) {
                                    disp.brightDirty = false;
                                    disp.pushBrightness();
                                }
                            }

                            property bool sunDirty: false
                            function pushNight() {
                                if (sunSetter.running) {
                                    sunDirty = true;
                                    return;
                                }
                                // "identity" = no tint at all; "temperature N" turns the tint on
                                sunSetter.command = nightOn ? ["hyprctl", "hyprsunset", "temperature", String(kelvin)] : ["hyprctl", "hyprsunset", "identity"];
                                sunSetter.running = true;
                            }
                            Process {
                                id: sunSetter
                                onExited: if (disp.sunDirty) {
                                    disp.sunDirty = false;
                                    disp.pushNight();
                                }
                            }

                            // Color filters are Hyprland screen shaders (the .frag files in
                            // ~/.config/hypr/shaders). Setting decoration.screen_shader to ""
                            // turns the filter off. Picking the active one again also turns it off.
                            function setFilter(name) {
                                filter = filter === name ? "none" : name;
                                const path = filter === "none" ? "" : shaderDir + filter + ".frag";
                                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { screen_shader = \"" + path + "\" } })"]);
                            }

                            // ── header: title, and Reset on the right ──
                            Item {
                                width: parent.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Display"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 1.2
                                    font.weight: 700
                                    font.letterSpacing: Theme.letterSpacing
                                }
                                Chip {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: "Reset"
                                    // full brightness, no tint, no filter
                                    onClicked: {
                                        disp.brightness = 100;
                                        disp.pushBrightness();
                                        disp.nightOn = false;
                                        disp.pushNight();
                                        if (disp.filter !== "none")
                                            disp.setFilter(disp.filter);
                                    }
                                }
                            }

                            // ── brightness ──
                            Item {
                                width: parent.width
                                height: brightLabel.implicitHeight

                                Text {
                                    id: brightLabel
                                    text: disp.mode === "backlight" ? "Brightness" : "Brightness (software)"
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: disp.brightness + "%"
                                    color: Theme.yellow
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 700
                                }
                            }
                            Row {
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "brightness_low"
                                    color: Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                                HSlider {
                                    id: brightSlider
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: disp.width - 2 * (Theme.iconSize + 6)
                                    // never all the way to 0: a black screen is hard to fix by mouse
                                    from: disp.mode === "backlight" ? 1 : 20
                                    to: 100
                                    stepSize: 1
                                    tint: Theme.yellow
                                    value: disp.brightness
                                    onMoved: {
                                        disp.brightness = Math.round(value);
                                        disp.pushBrightness();
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "brightness_high"
                                    color: Theme.yellow
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                            }

                            // ── night light ──
                            Item {
                                width: parent.width
                                height: 24

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Night light" + (disp.nightOn ? "  ·  " + disp.kelvin + " K" : "")
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                                Chip {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: disp.nightOn ? "On" : "Off"
                                    selected: disp.nightOn
                                    tint: Theme.orange
                                    onClicked: {
                                        disp.nightOn = !disp.nightOn;
                                        disp.pushNight();
                                    }
                                }
                            }
                            Row {
                                spacing: 6
                                // dimmed while off; dragging it turns night light on
                                opacity: disp.nightOn ? 1 : 0.5

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "local_fire_department"
                                    color: Theme.orange
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                                HSlider {
                                    id: warmSlider
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: disp.width - 2 * (Theme.iconSize + 6)
                                    // left = warm (2500 K), right = barely tinted (6000 K)
                                    from: 2500
                                    to: 6000
                                    stepSize: 100
                                    tint: Theme.orange
                                    value: disp.kelvin
                                    onMoved: {
                                        disp.kelvin = Math.round(value);
                                        disp.nightOn = true;
                                        disp.pushNight();
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "ac_unit"
                                    color: Theme.blue
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                            }

                            // ── color filters: one at a time ──
                            Text {
                                text: "Color filter"
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                                font.weight: 600
                            }
                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 6

                                Repeater {
                                    model: [
                                        {
                                            "id": "invert",
                                            "label": "Invert"
                                        },
                                        {
                                            "id": "grayscale",
                                            "label": "Grayscale"
                                        },
                                        {
                                            "id": "sepia",
                                            "label": "Sepia"
                                        },
                                        {
                                            "id": "contrast",
                                            "label": "Contrast"
                                        }
                                    ]

                                    Chip {
                                        required property var modelData
                                        width: (disp.width - 6) / 2   // two per row, same size
                                        label: modelData.label
                                        selected: disp.filter === modelData.id
                                        tint: Theme.magenta
                                        onClicked: disp.setFilter(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // ── Bluetooth ──
                    // In the bar: just the icon, no pill. Click it for the device list.
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        // bluetooth_searching (the one with waves) while something is still connecting
                        icon: !btList.powered ? "bluetooth_disabled" : btList.anyConnected ? "bluetooth_connected" : btList.anyConnecting ? "bluetooth_searching" : "bluetooth"

                        Column {
                            id: btList
                            spacing: 4

                            readonly property var adapter: Bluetooth.defaultAdapter
                            readonly property bool powered: !!adapter && adapter.enabled
                            // "Connected" here means actually usable (see ready() below), not just
                            // "BlueZ has a radio link".
                            readonly property bool anyConnected: Bluetooth.devices.values.some(d => ready(d))
                            readonly property bool anyConnecting: Bluetooth.devices.values.some(d => d.state === BluetoothDeviceState.Connecting || (d.connected && !ready(d)))

                            // ── When is a device really connected? ──
                            // BlueZ (and so Quickshell) flips a device to "Connected" as soon as the
                            // Bluetooth link is up. For headphones and speakers the audio part (A2DP)
                            // takes a few more seconds; that's the gap you saw with the AirPods.
                            // WirePlumber only creates the device's audio node once audio is ready,
                            // and names it after the MAC address with _ for : (from WirePlumber's
                            // monitor-utils.lua: "bluez_output.C0_1E_7C_D0_1C_84.1", or
                            // "bluez_input..." for a mic). So an audio device counts as connected
                            // once a node with its address exists.
                            // Mice, keyboards, phones etc. have no node; for them BlueZ's
                            // "Connected" is used as-is.
                            readonly property var btNodeNames: Pipewire.nodes.values.filter(n => n.name.startsWith("bluez_")).map(n => n.name)
                            function isAudio(device) {
                                return device.icon.startsWith("audio");
                            }
                            function hasNode(device) {
                                const key = device.address.replace(/:/g, "_");
                                return btNodeNames.some(n => n.includes(key));
                            }
                            // Safety net: if an audio device is linked but never gets a node (say
                            // it only connected for something other than audio), call it connected
                            // after 15 s anyway instead of saying "Connecting..." forever.
                            property var linkedSince: ({})  // address -> time BlueZ said Connected
                            property double now: Date.now()
                            function ready(device) {
                                if (device.state !== BluetoothDeviceState.Connected)
                                    return false;
                                if (!isAudio(device) || hasNode(device))
                                    return true;
                                const t = linkedSince[device.address];
                                return t !== undefined && now - t >= 15000;
                            }
                            Timer {
                                // only ticks while an audio device is linked but has no node yet
                                running: Bluetooth.devices.values.some(d => d.connected && btList.isAudio(d) && !btList.hasNode(d))
                                interval: 1000
                                repeat: true
                                triggeredOnStart: true
                                onTriggered: {
                                    btList.now = Date.now();
                                    const next = {};
                                    for (const d of Bluetooth.devices.values)
                                        if (d.connected)
                                            next[d.address] = btList.linkedSince[d.address] ?? btList.now;
                                    btList.linkedSince = next; // reassign so bindings notice
                                }
                            }

                            // Devices that have a name (or that you've paired): connected first, then
                            // paired, then A to Z. Nameless ones are usually random nearby gadgets.
                            readonly property var devices: Bluetooth.devices.values.filter(d => d.paired || d.deviceName !== "").sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

                            // Like the network list, the open drop-down is remembered here, not in the
                            // rows: the list re-sorts when a device connects, and rows can be rebuilt.
                            property var active: null       // the device whose drop-down is open
                            property var pairingDevice: null // a new device we're pairing, to connect once paired
                            property var failedDevice: null  // shows "Pairing failed" for a few seconds

                            function toggle(device) {
                                active = active === device ? null : device;
                            }
                            // Status shown next to each device.
                            function stateText(device) {
                                if (device.state === BluetoothDeviceState.Connected)
                                    return ready(device) ? "Connected" : "Connecting...";
                                if (device.state === BluetoothDeviceState.Connecting)
                                    return "Connecting...";
                                if (device.state === BluetoothDeviceState.Disconnecting)
                                    return "Disconnecting...";
                                if (device.pairing)
                                    return "Pairing...";
                                if (device === failedDevice)
                                    return "Pairing failed";
                                return device.paired ? "Not connected" : "New";
                            }
                            function busy(device) {
                                return device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
                            }
                            function connectOrDisconnect(device) {
                                if (busy(device))
                                    return;
                                if (device.connected) {
                                    device.disconnect();
                                } else if (!device.paired) {
                                    // never paired: pair first; the Connections below connects afterwards
                                    device.trusted = true;      // lets it reconnect by itself next time
                                    failedDevice = null;
                                    pairingDevice = device;
                                    device.pair();
                                } else {
                                    device.connect();
                                }
                            }
                            // Material Symbols icon for the kind of device (BlueZ gives freedesktop icon names).
                            function glyph(device) {
                                const i = device.icon;
                                if (i.startsWith("audio-head"))
                                    return "headphones";
                                if (i.startsWith("audio"))
                                    return "speaker";
                                if (i === "input-mouse")
                                    return "mouse";
                                if (i === "input-keyboard")
                                    return "keyboard";
                                if (i === "input-gaming")
                                    return "sports_esports";
                                if (i === "phone")
                                    return "smartphone";
                                if (i === "computer")
                                    return "computer";
                                return "bluetooth";
                            }

                            Connections {
                                target: btList.pairingDevice
                                function onPairedChanged() {
                                    const device = btList.pairingDevice;
                                    btList.pairingDevice = null;
                                    pairCheck.stop();
                                    if (device.paired && !device.connected)
                                        device.connect();
                                }
                                // The pairing attempt ended. If it isn't paired a moment later
                                // (BlueZ can report "paired" just after), it failed.
                                function onPairingChanged() {
                                    if (!btList.pairingDevice.pairing && !btList.pairingDevice.paired)
                                        pairCheck.restart();
                                }
                            }
                            Timer {
                                id: pairCheck
                                interval: 1500
                                onTriggered: {
                                    const device = btList.pairingDevice;
                                    if (!device || device.paired)
                                        return;
                                    btList.pairingDevice = null;
                                    btList.failedDevice = device;
                                    failedReset.restart();
                                }
                            }
                            // "Pairing failed" goes back to "New" after 4 s
                            Timer {
                                id: failedReset
                                interval: 4000
                                onTriggered: btList.failedDevice = null
                            }

                            // Look for nearby devices only while this popup is open (and Bluetooth is on).
                            Binding {
                                when: btList.powered
                                target: btList.adapter
                                property: "discovering"
                                value: !!QsWindow.window && QsWindow.window.visible
                            }

                            // header: title on the left, on/off switch on the right
                            Item {
                                width: 280
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Bluetooth"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 1.2
                                    font.weight: 700
                                    font.letterSpacing: Theme.letterSpacing
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !!btList.adapter
                                    width: btPowerLabel.implicitWidth + 24
                                    height: 24
                                    radius: height / 2
                                    color: btList.powered ? Theme.accent : btPowerMouse.containsMouse ? Theme.pill : "transparent"
                                    border.width: 1
                                    border.color: btList.powered ? Theme.accent : Theme.pill
                                    scale: btPowerMouse.pressed ? 0.85 : 1

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
                                        id: btPowerLabel
                                        anchors.centerIn: parent
                                        text: btList.powered ? "On" : "Off"
                                        color: btList.powered ? Theme.bg : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.9
                                        font.weight: 700
                                    }
                                    MouseArea {
                                        id: btPowerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: btList.adapter.enabled = !btList.adapter.enabled
                                    }
                                }
                            }

                            // what to show when there's no list
                            Text {
                                width: 280
                                wrapMode: Text.Wrap
                                visible: text !== ""
                                text: {
                                    if (!btList.adapter)
                                        return "No Bluetooth adapter found.";
                                    if (!btList.powered)
                                        return "Bluetooth is off.";
                                    if (btList.devices.length === 0)
                                        return btList.adapter.discovering ? "Searching for devices..." : "No devices found.";
                                    return "";
                                }
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                            }

                            // "Devices", with "Searching..." on the right while it scans
                            Item {
                                width: 280
                                height: devicesLabel.implicitHeight
                                visible: btList.powered && btList.devices.length > 0

                                Text {
                                    id: devicesLabel
                                    text: "Devices"
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                    font.weight: 600
                                }
                                Text {
                                    anchors.right: parent.right
                                    visible: !!btList.adapter && btList.adapter.discovering
                                    text: "Searching..."
                                    color: Theme.accent
                                    opacity: 0.8
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                }
                            }

                            Repeater {
                                // ScriptModel only builds rows for new devices instead of rebuilding them all.
                                model: ScriptModel {
                                    values: btList.powered ? btList.devices : []
                                }

                                Rectangle {
                                    id: btRow
                                    required property var modelData
                                    readonly property var device: modelData
                                    readonly property bool expanded: btList.active === device
                                    readonly property bool ready: btList.ready(device)  // really connected

                                    width: 280
                                    height: btHeader.height + btDrop.height
                                    radius: Theme.radius
                                    color: btHeaderMouse.containsMouse || expanded ? Theme.pill : "transparent"
                                    clip: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    // ── the row itself: icon, name, status ──
                                    Item {
                                        id: btHeader
                                        width: parent.width
                                        height: 30
                                        scale: btHeaderMouse.pressed ? 0.85 : 1

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            id: btGlyph
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: btList.glyph(btRow.device)
                                            color: btRow.ready ? Theme.accent : Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize
                                            font.variableAxes: Theme.iconAxes
                                        }
                                        Text {
                                            anchors {
                                                left: btGlyph.right
                                                right: btStatus.left
                                                leftMargin: 8
                                                rightMargin: 8
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: btRow.device.name
                                            elide: Text.ElideRight
                                            color: btRow.ready ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: btRow.ready ? 700 : 500
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                        // per-device status (and battery, when the device reports it)
                                        Text {
                                            id: btStatus
                                            anchors {
                                                right: parent.right
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: btList.stateText(btRow.device) + (btRow.device.batteryAvailable ? "  ·  " + Math.round(btRow.device.battery * 100) + "%" : "")
                                            color: btRow.ready ? Theme.green : btRow.device === btList.failedDevice ? Theme.red : btRow.device.connected ? Theme.yellow : Theme.text
                                            opacity: btRow.device.connected || btRow.device === btList.failedDevice ? 1 : 0.6
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.85
                                        }
                                        MouseArea {
                                            id: btHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: btList.toggle(btRow.device)
                                        }
                                    }

                                    // ── the drop-down: Connect / Disconnect, glides open over 500 ms ──
                                    Item {
                                        id: btDrop
                                        y: btHeader.height
                                        width: parent.width
                                        height: btRow.expanded ? btDropContent.implicitHeight + 10 : 0
                                        clip: true

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 500
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Column {
                                            id: btDropContent
                                            x: 10
                                            width: parent.width - 20
                                            spacing: 6

                                            Rectangle {
                                                id: btAction
                                                // red "Disconnect" when connected, green "Connect" otherwise
                                                readonly property bool disconnecting: btRow.device.connected
                                                readonly property color tint: disconnecting ? Theme.red : Theme.green
                                                readonly property bool busy: btList.busy(btRow.device)

                                                width: parent.width
                                                height: 26
                                                radius: height / 2
                                                color: btActionMouse.containsMouse && !busy ? tint : Theme.bg
                                                opacity: busy ? 0.5 : 1
                                                scale: btActionMouse.pressed && !busy ? 0.85 : 1

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
                                                    // while it's working, show what it's doing instead
                                                    text: btAction.busy ? btList.stateText(btRow.device) : btAction.disconnecting ? "Disconnect" : "Connect"
                                                    color: btActionMouse.containsMouse && !btAction.busy ? Theme.bg : btAction.tint
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize
                                                    font.weight: 600
                                                }
                                                MouseArea {
                                                    id: btActionMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: btAction.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                    onClicked: btList.connectOrDisconnect(btRow.device)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

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
                            // Volume and mute straight from PipeWire. These are bindings, so the
                            // pill redraws the moment PipeWire reports a change (keyboard keys,
                            // the slider, pavucontrol...) instead of waiting for a timer.
                            readonly property var sink: Pipewire.defaultAudioSink
                            readonly property bool ready: !!sink && !!sink.audio
                            readonly property bool muted: ready && sink.audio.muted

                            icon: muted ? "volume_off" : "volume_up"
                            iconColor: muted ? Theme.red : Theme.cyan
                            text: ready ? Math.round(sink.audio.volume * 100) + "%" : "--"

                            // PipeWire only sends live volume updates for nodes something is
                            // tracking; this keeps the current output device tracked.
                            PwObjectTracker {
                                objects: [Pipewire.defaultAudioSink].filter(n => n)
                            }
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
                                    // pointing hand over the whole slider, grab hand while dragging.
                                    // HoverHandler only watches the mouse, so dragging still works.
                                    HoverHandler {
                                        cursorShape: volSlider.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    }
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
                    // ── Battery ──
                    Widget {
                        id: battery
                        anchors.verticalCenter: parent.verticalCenter
                        // hidden on machines without a laptop battery (this desktop)
                        visible: battery.present

                        // UPower's combined battery. percentage is 0..1 (Quickshell converts UPower's 0-100).
                        readonly property var device: UPower.displayDevice
                        readonly property bool present: !!device && device.ready && device.isLaptopBattery
                        readonly property int percent: present ? Math.round(device.percentage * 100) : 0
                        readonly property bool pluggedIn: !UPower.onBattery
                        // Plugged in: a lightning bolt, whatever the level.
                        // On battery: Material Symbols' battery_0_bar ... battery_6_bar, then battery_full.
                        readonly property string glyph: {
                            if (!present)
                                return "battery_unknown";
                            if (pluggedIn)
                                return "bolt";
                            if (percent >= 95)
                                return "battery_full";
                            return "battery_" + Math.min(6, Math.floor(percent / 100 * 7)) + "_bar";
                        }

                        button: Pill {
                            icon: battery.glyph
                            // green bolt while charging, red when low, yellow otherwise
                            iconColor: battery.pluggedIn ? Theme.green : battery.present && battery.percent <= 15 ? Theme.red : Theme.yellow
                            text: battery.present ? battery.percent + "%" : "--"
                        }

                        Column {
                            spacing: 4

                            // percentage
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: battery.present ? battery.percent + "%" : "No battery"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 2.4
                                font.weight: 700
                                font.letterSpacing: Theme.letterSpacing
                            }
                            // plugged in / on battery
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: battery.pluggedIn ? "Plugged in" : "Running off battery"
                                color: battery.pluggedIn ? Theme.green : Theme.yellow
                                opacity: 0.8
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 600
                                font.letterSpacing: Theme.letterSpacing
                            }
                            // the battery ligature, big
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 6
                                text: battery.glyph
                                color: battery.pluggedIn ? Theme.green : battery.present && battery.percent <= 15 ? Theme.red : Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize * 3
                                font.variableAxes: Theme.iconAxes
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
                    // ── System monitor ──
                    // Bar: the CPU package temperature. Popup: a graph of the last minute, every
                    // component's usage in text, and a list: click a component to graph just that
                    // one, click it again (or "All") to go back. Numbers come from SysMon.qml.
                    Widget {
                        id: sysmon
                        anchors.verticalCenter: parent.verticalCenter

                        // what the graph shows: "all", or one component's key
                        property string selected: "all"
                        readonly property var selectedPart: parts.find(p => p.key === selected) ?? null

                        // The components, in list order. Only looks; the numbers are looked up from SysMon by key.
                        readonly property var parts: [
                            {
                                key: "cpu",
                                name: "CPU",
                                icon: "memory",
                                color: Theme.green
                            },
                            {
                                key: "gpu",
                                name: "GPU",
                                icon: "developer_board",
                                color: Theme.blue
                            },
                            {
                                key: "mem",
                                name: "Memory",
                                icon: "memory_alt",
                                color: Theme.yellow
                            },
                            {
                                key: "vram",
                                name: "VRAM",
                                icon: "view_in_ar_new",
                                color: Theme.magenta
                            },
                            {
                                key: "swap",
                                name: "Swap",
                                icon: "swap_horiz",
                                color: Theme.orange
                            },
                            {
                                key: "disk",
                                name: "Disk",
                                icon: "hard_drive",
                                color: Theme.cyan
                            }
                        ]

                        button: Pill {
                            icon: "device_thermostat"
                            iconColor: SysMon.cpuTemp >= 85 ? Theme.red : Theme.orange
                            text: SysMon.cpuTemp < 0 ? "--°C" : Math.round(SysMon.cpuTemp) + "°C"
                        }

                        Column {
                            width: 360
                            spacing: 10

                            // ── header: title on the left, "All" on the right while one component is picked ──
                            Item {
                                width: parent.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "System"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 1.2
                                    font.weight: 700
                                    font.letterSpacing: Theme.letterSpacing
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: allLabel.implicitWidth + 20
                                    height: 24
                                    radius: height / 2
                                    color: allMouse.containsMouse ? Theme.pill : "transparent"
                                    border.width: 1
                                    border.color: Theme.pill
                                    opacity: sysmon.selected === "all" ? 0 : 1
                                    visible: opacity > 0
                                    scale: allMouse.pressed ? 0.85 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Text {
                                        id: allLabel
                                        anchors.centerIn: parent
                                        text: "All"
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.9
                                        font.weight: 600
                                    }
                                    MouseArea {
                                        id: allMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sysmon.selected = "all"
                                    }
                                }
                            }

                            // ── the graph ──
                            Rectangle {
                                width: parent.width
                                height: 170
                                radius: Theme.radius
                                color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.45)

                                // what's being graphed, and (for one component) its numbers right now
                                Item {
                                    id: graphHeader
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    height: 22

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: sysmon.selectedPart ? sysmon.selectedPart.icon : "monitoring"
                                            color: sysmon.selectedPart ? sysmon.selectedPart.color : Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize
                                            font.variableAxes: Theme.iconAxes
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: sysmon.selectedPart ? sysmon.selectedPart.name : "All components"
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: 700
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        visible: !!sysmon.selectedPart

                                        // the temperature (the dashed red line in the graph), for CPU and GPU
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!sysmon.selectedPart && SysMon.temp(sysmon.selected) >= 0
                                            spacing: 2
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "device_thermostat"
                                                color: Theme.red
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize * 0.9
                                                font.variableAxes: Theme.iconAxes
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Math.round(SysMon.temp(sysmon.selected)) + "°C"
                                                color: Theme.red
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                                font.weight: 600
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(SysMon.percent(sysmon.selected)) + "%"
                                            color: sysmon.selectedPart ? sysmon.selectedPart.color : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 1.4
                                            font.weight: 700
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                    }
                                }

                                Canvas {
                                    id: graph
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: graphHeader.bottom
                                    anchors.bottom: timeLabels.top
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 4

                                    // Repaint on every new sample (only while the popup is open: nobody
                                    // sees it otherwise), when it opens, and when the selection changes.
                                    Connections {
                                        target: SysMon
                                        function onSampled() {
                                            if (sysmon.open)
                                                graph.requestPaint();
                                        }
                                    }
                                    Connections {
                                        target: sysmon
                                        function onOpenChanged() {
                                            graph.requestPaint();
                                        }
                                        function onSelectedChanged() {
                                            graph.requestPaint();
                                        }
                                    }

                                    // "rgba(r, g, b, a)": the canvas wants CSS-style color strings
                                    function rgba(c, a) {
                                        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                                    }
                                    // x of the i-th sample: the newest sits on the right edge, so the
                                    // line scrolls in from the right while history is still filling up
                                    function xAt(i, count) {
                                        return width - (count - 1 - i) * width / (SysMon.historyLength - 1);
                                    }
                                    // y of a value: 0 at the bottom, 100 (% or °C) at the top
                                    function yAt(v) {
                                        return height - Math.max(0, Math.min(100, v)) / 100 * height;
                                    }
                                    // Draws the path of one list of values; nulls leave a gap.
                                    function trace(ctx, values) {
                                        ctx.beginPath();
                                        let drawing = false;
                                        for (let i = 0; i < values.length; i++) {
                                            if (values[i] === null) {
                                                drawing = false;
                                                continue;
                                            }
                                            const x = xAt(i, values.length), y = yAt(values[i]);
                                            if (drawing)
                                                ctx.lineTo(x, y);
                                            else
                                                ctx.moveTo(x, y);
                                            drawing = true;
                                        }
                                    }

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.lineJoin = "round";
                                        ctx.lineCap = "round";

                                        // grid lines at 25 / 50 / 75 %
                                        ctx.strokeStyle = rgba(Theme.text, 0.08);
                                        ctx.lineWidth = 1;
                                        for (const v of [25, 50, 75]) {
                                            ctx.beginPath();
                                            ctx.moveTo(0, Math.round(yAt(v)) + 0.5);
                                            ctx.lineTo(width, Math.round(yAt(v)) + 0.5);
                                            ctx.stroke();
                                        }

                                        if (!sysmon.selectedPart) {
                                            // everything at once: one thin line per component
                                            ctx.lineWidth = 1.5;
                                            for (const part of sysmon.parts) {
                                                if (!SysMon.has(part.key))
                                                    continue;
                                                ctx.strokeStyle = rgba(part.color, 1);
                                                trace(ctx, SysMon.history[part.key]);
                                                ctx.stroke();
                                            }
                                            return;
                                        }

                                        // one component: its line with a fade underneath...
                                        const part = sysmon.selectedPart;
                                        const values = SysMon.history[part.key];
                                        const first = values.findIndex(v => v !== null);
                                        if (first >= 0) {
                                            const fade = ctx.createLinearGradient(0, 0, 0, height);
                                            fade.addColorStop(0, rgba(part.color, 0.35));
                                            fade.addColorStop(1, rgba(part.color, 0));
                                            trace(ctx, values);
                                            ctx.lineTo(xAt(values.length - 1, values.length), height);
                                            ctx.lineTo(xAt(first, values.length), height);
                                            ctx.closePath();
                                            ctx.fillStyle = fade;
                                            ctx.fill();

                                            ctx.strokeStyle = rgba(part.color, 1);
                                            ctx.lineWidth = 2;
                                            trace(ctx, values);
                                            ctx.stroke();
                                        }

                                        // ...plus its temperature as a dashed line, if it has one
                                        const temps = SysMon.history[part.key + "Temp"];
                                        if (temps) {
                                            ctx.strokeStyle = rgba(Theme.red, 0.9);
                                            ctx.lineWidth = 1.5;
                                            ctx.setLineDash([3, 3]);
                                            trace(ctx, temps);
                                            ctx.stroke();
                                        }
                                    }
                                }

                                // time axis: the left edge is a minute ago, the right edge is now
                                Item {
                                    id: timeLabels
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                    anchors.bottomMargin: 6
                                    height: 14

                                    Text {
                                        anchors.left: parent.left
                                        text: SysMon.historyLength + "s ago"
                                        color: Theme.text
                                        opacity: 0.4
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: "now"
                                        color: Theme.text
                                        opacity: 0.4
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.8
                                    }
                                }
                            }

                            // ── every component, in text; click one to graph it alone ──
                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: sysmon.parts

                                    Rectangle {
                                        id: partRow
                                        required property var modelData     // { key, name, icon, color }

                                        readonly property bool picked: sysmon.selected === modelData.key
                                        readonly property real percent: SysMon.percent(modelData.key)

                                        visible: SysMon.has(modelData.key)
                                        width: parent.width
                                        height: 32
                                        radius: Theme.radius
                                        color: picked ? Theme.pill : partMouse.containsMouse ? Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.5) : "transparent"
                                        scale: partMouse.pressed ? 0.97 : 1

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

                                        // icon + name on the left
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 10
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: partRow.modelData.icon
                                                color: partRow.modelData.color
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                font.variableAxes: Theme.iconAxes
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: partRow.modelData.name
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize
                                                font.weight: partRow.picked ? 700 : 500
                                                font.letterSpacing: Theme.letterSpacing
                                            }
                                        }

                                        // detail, a little meter, and the percentage on the right
                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 10

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: SysMon.detail(partRow.modelData.key)
                                                color: Theme.text
                                                opacity: 0.55
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.9
                                                font.weight: 500
                                                font.letterSpacing: Theme.letterSpacing
                                            }
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 56
                                                height: 5
                                                radius: height / 2
                                                // the empty part of the meter: whichever of the two colors the row isn't
                                                color: partRow.picked ? Theme.bg : Theme.pill
                                                Rectangle {
                                                    width: Math.max(parent.height, parent.width * partRow.percent / 100)
                                                    height: parent.height
                                                    radius: height / 2
                                                    color: partRow.modelData.color
                                                    Behavior on width {
                                                        NumberAnimation {
                                                            duration: 400
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 38
                                                horizontalAlignment: Text.AlignRight
                                                text: Math.round(partRow.percent) + "%"
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize
                                                font.weight: 700
                                                font.letterSpacing: Theme.letterSpacing
                                            }
                                        }

                                        MouseArea {
                                            id: partMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            // click the picked one again to go back to all
                                            onClicked: sysmon.selected = partRow.picked ? "all" : partRow.modelData.key
                                        }
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
                                        icon: "lock",
                                        name: "Lock",
                                        cmd: ["hyprlock"]
                                    },
                                    {
                                        icon: "logout",
                                        name: "Log out",
                                        cmd: ["uwsm", "stop"]
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

    // Everforest dark (medium), from sainnhe/everforest
    Singleton {
        property color bg: "#2d353b"        // bg0
        property color pill: "#3d484d"      // bg2
        property color pillIcon: "#56635f"  // bg5
        // Theme colors
        property color text: "#d3c6aa"      // fg
        property color red: "#e67e80"
        property color green: "#a7c080"
        property color blue: "#7fbbb3"
        property color yellow: "#dbbc7f"
        property color magenta: "#d699b6"   // everforest calls it purple
        property color cyan: "#83c092"      // everforest calls it aqua
        property color orange: "#e69875"
        property color accent: green

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
    // part of the bar, slides down when it opens, and slides back up into the
    // bar when it closes.
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
    import Quickshell.Hyprland

    Item {
        id: root

        property Component button: iconButton   // what shows in the bar
        property string icon: "widgets"         // used only by the default button

        property int popupWidth: 0     // 0 = fit the content's width
        property int popupHeight: 0    // 0 = fit the content's height
        property int padding: 12       // space between the popup's edge and your content
        property int curve: 14         // size of the two curves where the popup melts into the bar
        property int cornerRadius: 14  // roundness of the popup's two bottom corners
        property int duration: 350       // slide-down (open) time in ms
        property int closeDuration: 260  // slide-up (close) time in ms; closing a bit faster feels snappier

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
            grab.active = true
            // Opening: starts fast and settles (OutCubic), sliding down out of the bar.
            slide.duration = root.duration
            slide.easing.type = Easing.OutCubic
            slide.to = 1
            slide.restart()
        }

        function closePopup() {
            if (!root.open)
                return
            root.open = false
            grab.active = false
            // Closing: the same slide played backwards. The mirror of "starts fast and
            // settles" is "starts gently and speeds up", so it gets pulled back into
            // the bar. InQuad instead of InCubic so it reacts right away on click.
            slide.duration = root.closeDuration
            slide.easing.type = Easing.InQuad
            slide.to = 0
            slide.restart()      // the window is hidden once this finishes (see onFinished)
        }

        NumberAnimation {
            id: slide
            target: root
            property: "openness"
            onFinished: if (root.openness === 0) popup.visible = false
        }

        // Click-outside-to-close. The popup used to take the pointer itself
        // (grabFocus), but then Hyprland closes it instantly when you click away and
        // there's no time to animate. Hyprland's focus grab only *tells* us about the
        // outside click (onCleared) and leaves the window up, so we can slide it back
        // into the bar first. Keyboard input still goes to the popup while it's active.
        HyprlandFocusGrab {
            id: grab
            windows: [popup]
            onCleared: {
                root.clearedAt = Date.now()
                root.closePopup()
            }
        }
        // When the outside click that closed it was on this same button, don't let
        // that click reopen it straight away.
        property double clearedAt: 0

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
            onClicked: {
                if (root.open)
                    root.closePopup()
                else if (Date.now() - root.clearedAt > 300)
                    root.openPopup()
            }
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

            // If the compositor ever hides the popup by itself, skip the animation
            // and reset so the next click opens it again.
            onClosed: {
                slide.stop()
                grab.active = false
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

        // Which number the mouse is over: -1 = none.
        property int hoveredIndex: -1
        property real hoverShrink: 0.85   // size of the hovered number (same as the other bar buttons)
        property int hoverTime: 150

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
                    id: wsNumber
                    required property var modelData
                    required property int index        // 0, 1, 2... this number's place in the row

                    width: root.cellWidth
                    height: parent.height
                    text: modelData.name
                    color: modelData.active ? Theme.accent : Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    font.family: Theme.font
                    font.pixelSize: Theme.textSize
                    font.weight: 600

                    // only the hovered number shrinks; the rest stay as they are
                    scale: root.hoveredIndex === wsNumber.index ? root.hoverShrink : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: root.slideTime
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.hoverTime
                            easing.type: Easing.OutCubic
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true             // needed for onEntered/onExited without clicking
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredIndex = wsNumber.index
                        // only clear it if it's still ours: moving to the next number can
                        // run that one's onEntered before this onExited
                        onExited: if (root.hoveredIndex === wsNumber.index)
                            root.hoveredIndex = -1
                        onClicked: wsNumber.modelData.activate()
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

  # A small rounded toggle/button with a label, used by the Display widget.
  #   Chip { label: "On"; selected: true; tint: Theme.orange; onClicked: ... }
  xdg.configFile."quickshell/Chip.qml".text = ''
    import QtQuick

    Rectangle {
        id: chip

        property string label: ""
        property bool selected: false      // filled with `tint` when true
        property color tint: Theme.accent

        signal clicked

        implicitWidth: chipLabel.implicitWidth + 24
        implicitHeight: 24
        radius: height / 2
        color: selected ? tint : chipMouse.containsMouse ? Theme.pill : "transparent"
        border.width: 1
        border.color: selected ? tint : Theme.pill
        scale: chipMouse.pressed ? 0.85 : 1

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
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? Theme.bg : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.textSize * 0.9
            font.weight: 700
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
  '';

  # A horizontal slider in the same style as the media seek bar, with a color.
  xdg.configFile."quickshell/HSlider.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic

    Slider {
        id: control

        property color tint: Theme.accent

        padding: 6
        HoverHandler {
            cursorShape: control.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        }

        background: Rectangle {        // the track
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 4
            width: control.availableWidth
            height: implicitHeight
            radius: 2
            color: Theme.pill

            Rectangle {                // the filled part
                width: control.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: control.tint
            }
        }

        handle: Rectangle {            // the knob
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: control.pressed ? control.tint : Theme.text
        }
    }
  '';

  # ── Color filters for the Display widget ──
  # Hyprland runs one of these over the whole screen (decoration.screen_shader).
  # Same format as Hyprland's own shaders: the screen comes in as `tex`.
  xdg.configFile."hypr/shaders/invert.frag".text = ''
    #version 300 es
    precision highp float;
    in vec2 v_texcoord;
    uniform sampler2D tex;
    layout(location = 0) out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);
        fragColor = vec4(1.0 - c.rgb, c.a);
    }
  '';
  xdg.configFile."hypr/shaders/grayscale.frag".text = ''
    #version 300 es
    precision highp float;
    in vec2 v_texcoord;
    uniform sampler2D tex;
    layout(location = 0) out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);
        // how bright each color looks to the eye (Rec. 709 weights)
        float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        fragColor = vec4(vec3(y), c.a);
    }
  '';
  xdg.configFile."hypr/shaders/sepia.frag".text = ''
    #version 300 es
    precision highp float;
    in vec2 v_texcoord;
    uniform sampler2D tex;
    layout(location = 0) out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);
        // the classic sepia-tone matrix
        vec3 s = vec3(
            dot(c.rgb, vec3(0.393, 0.769, 0.189)),
            dot(c.rgb, vec3(0.349, 0.686, 0.168)),
            dot(c.rgb, vec3(0.272, 0.534, 0.131)));
        fragColor = vec4(min(s, vec3(1.0)), c.a);
    }
  '';
  xdg.configFile."hypr/shaders/contrast.frag".text = ''
    #version 300 es
    precision highp float;
    in vec2 v_texcoord;
    uniform sampler2D tex;
    layout(location = 0) out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);
        // push colors away from mid-gray: darks darker, lights lighter
        vec3 h = (c.rgb - 0.5) * 1.35 + 0.5;
        fragColor = vec4(clamp(h, 0.0, 1.0), c.a);
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
  # The system monitor's sampler (a singleton: one for every bar). See the widget in shell.qml.
  xdg.configFile."quickshell/SysMon.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io

    // Samples the system once a second for the bar's system monitor widget.
    // A singleton, so there's one sampler however many monitors (bars) there are.
    //
    // Components, by key:  cpu  gpu  mem  vram  swap  disk
    //   SysMon.percent("cpu")  → 0..100
    //   SysMon.detail("mem")   → "12.3 / 30.5 GiB"
    //   SysMon.has("gpu")      → false when there's nothing to show (no GPU found, no swap...)
    //   SysMon.history.cpu     → the last `historyLength` percentages, oldest first
    Singleton {
        id: root

        readonly property int historyLength: 60     // seconds the graph spans

        // ── latest values ──
        property real cpu: 0          // % busy, all cores together
        property real cpuTemp: -1     // °C, package; -1 = no sensor found
        property real memUsed: 0      // KiB
        property real memTotal: 0
        property real swapUsed: 0     // KiB (your zram)
        property real swapTotal: 0
        property real gpu: -1         // % busy; -1 = no GPU found
        property string gpuKind: ""   // "nvidia", "amd", "intel" or "" (found automatically)
        property real gpuTemp: -1     // °C
        property real vramUsed: 0     // MiB
        property real vramTotal: 0
        property real disk: 0         // % of the last second the busiest disk spent working
        property string diskName: ""  // which disk that was

        readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0
        readonly property real swapPercent: swapTotal > 0 ? swapUsed / swapTotal * 100 : 0
        readonly property real vramPercent: vramTotal > 0 ? vramUsed / vramTotal * 100 : 0

        // ── graph data ──
        // Plain JS arrays, changed in place, so QML can't see them change by itself:
        // `sampled` is emitted after every update instead, for the graph to repaint on.
        // A null in a list means "no reading" (a gap in the line).
        readonly property var history: ({
                cpu: [],
                cpuTemp: [],
                gpu: [],
                gpuTemp: [],
                mem: [],
                vram: [],
                swap: [],
                disk: []
            })
        signal sampled

        function percent(key) {
            switch (key) {
            case "cpu":
                return cpu;
            case "gpu":
                return Math.max(0, gpu);
            case "mem":
                return memPercent;
            case "vram":
                return vramPercent;
            case "swap":
                return swapPercent;
            case "disk":
                return disk;
            }
            return 0;
        }

        function has(key) {
            switch (key) {
            case "gpu":
                return gpu >= 0;
            case "vram":
                return gpu >= 0 && vramTotal > 0;   // Intel graphics have no VRAM of their own
            case "swap":
                return swapTotal > 0;
            case "disk":
                return diskName !== "";
            }
            return true;
        }

        // the temperature that goes with a component, -1 if it has none
        function temp(key) {
            return key === "cpu" ? cpuTemp : key === "gpu" ? gpuTemp : -1;
        }

        function detail(key) {
            const gib = kib => (kib / 1048576).toFixed(1);
            switch (key) {
            case "cpu":
            case "gpu":
                if (temp(key) >= 0)
                    return Math.round(temp(key)) + "°C";
                return key === "gpu" && gpuKind === "intel" ? "estimated" : "";
            case "mem":
                return gib(memUsed) + " / " + gib(memTotal) + " GiB";
            case "vram":
                return gib(vramUsed * 1024) + " / " + gib(vramTotal * 1024) + " GiB";
            case "swap":
                return gib(swapUsed) + " / " + gib(swapTotal) + " GiB";
            case "disk":
                return diskName;
            }
            return "";
        }

        function push(key, value) {
            const list = history[key];
            list.push(value);
            if (list.length > historyLength)
                list.shift();
        }

        // ── turning sysmon.sh's running totals into percentages ──
        property var last: null     // the previous line, to compare against
        property real lastTime: 0

        function update(now) {
            const before = last;
            const ms = Date.now() - lastTime;
            last = now;
            lastTime = Date.now();
            if (!before)
                return;       // the first line has nothing to compare with

            // CPU: of the jiffies that passed, how many weren't idle
            const total = now.cpu[1] - before.cpu[1];
            cpu = total > 0 ? (now.cpu[0] - before.cpu[0]) / total * 100 : 0;
            cpuTemp = now.temp === null ? -1 : now.temp;

            memTotal = now.mem[0];
            memUsed = now.mem[0] - now.mem[1];
            swapTotal = now.swap[0];
            swapUsed = now.swap[0] - now.swap[1];

            // Disks: ms spent busy since last time, out of the ms that passed. Show the busiest.
            let busiest = -1;
            for (const name in now.disks) {
                if (!(name in before.disks))
                    continue;
                const busy = Math.min(100, (now.disks[name] - before.disks[name]) / ms * 100);
                if (busy > busiest) {
                    busiest = busy;
                    diskName = name;
                }
            }
            disk = Math.max(0, busiest);

            // GPU from sysmon.sh (AMD / Intel). NVIDIA is filled in by nvidia-smi below instead.
            if (gpuKind !== "nvidia" && now.gpu) {
                if ("busy" in now.gpu) {
                    gpuKind = "amd";
                    gpu = Math.max(0, now.gpu.busy);
                    gpuTemp = now.gpu.temp === null ? -1 : now.gpu.temp;
                    vramUsed = now.gpu.vram[0];
                    vramTotal = now.gpu.vram[1];
                } else if ("idle" in now.gpu && before.gpu && now.gpu.idle >= 0) {
                    // Intel: busy = the part of the last second it wasn't idle
                    gpuKind = "intel";
                    const idle = (now.gpu.idle - before.gpu.idle) / ms * 100;
                    gpu = Math.max(0, Math.min(100, 100 - idle));
                    gpuTemp = -1;
                    vramTotal = 0;
                }
            }

            push("cpu", cpu);
            push("cpuTemp", cpuTemp >= 0 ? cpuTemp : null);
            push("mem", memPercent);
            push("swap", swapPercent);
            push("disk", disk);
            push("gpu", gpu >= 0 ? gpu : null);
            push("gpuTemp", gpuTemp >= 0 ? gpuTemp : null);
            push("vram", has("vram") ? vramPercent : null);
            sampled();
        }

        Process {
            command: ["sh", Quickshell.shellDir + "/sysmon.sh"]
            running: true
            stdout: SplitParser {
                onRead: line => root.update(JSON.parse(line))
            }
        }

        // NVIDIA: nvidia-smi can repeat its own query (-l 1 = every second), so it's
        // started once and left running. One line per GPU:  "23, 48, 2100, 12282"
        // (busy %, °C, MiB used, MiB total). Only run when nvidia-smi is installed, so
        // machines without it (AMD / Intel, read by sysmon.sh) get no warning.
        Process {
            command: ["sh", "-c", "command -v nvidia-smi >/dev/null && exec nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits -l 1"]
            running: true
            stdout: SplitParser {
                onRead: line => {
                    const f = line.split(",").map(Number);
                    if (f.length < 4 || f.some(isNaN))
                        return;     // "[N/A]" or an error message
                    root.gpuKind = "nvidia";
                    root.gpu = f[0];
                    root.gpuTemp = f[1];
                    root.vramUsed = f[2];
                    root.vramTotal = f[3];
                }
            }
        }
    }
  '';

  # Read once a second by SysMon.qml. Inside '' '' strings, the shell's ${...} is written ''${...}.
  xdg.configFile."quickshell/sysmon.sh".text = ''
    #!/bin/sh
    # Prints one JSON line per second for the bar's system monitor (SysMon.qml reads it):
    #
    #   {"cpu":[busy,total],"mem":[total,available],"swap":[total,free],"temp":54.1,"disks":{"nvme0n1":1234},"gpu":...}
    #
    # cpu and disks are running totals since boot (jiffies / ms spent busy); SysMon.qml
    # turns them into percentages by comparing each line with the one before.
    # mem and swap are in KiB. temp is °C, or null if no sensor was found.
    # gpu is one of:
    #   {"busy":37,"temp":51.0,"vram":[used,total]}   AMD: busy %, °C, VRAM in MiB
    #   {"idle":123456}                               Intel: ms spent idle since boot (a running total)
    #   null                                          no GPU found here (or NVIDIA, which SysMon.qml
    #                                                 reads with nvidia-smi instead)

    # ── Find the CPU package temperature sensor, once ──
    # AMD (k10temp): Tctl is always temp1; use Tdie instead if the chip reports one.
    # Intel (coretemp): the input labelled "Package id 0".
    sensor=""
    for h in /sys/class/hwmon/hwmon*; do
        [ -r "$h/name" ] || continue
        case $(cat "$h/name") in
            k10temp | zenpower)
                sensor=$h/temp1_input
                for l in "$h"/temp*_label; do
                    [ "$(cat "$l" 2>/dev/null)" = Tdie ] && sensor=''${l%_label}_input
                done
                ;;
            coretemp)
                for l in "$h"/temp*_label; do
                    [ "$(cat "$l" 2>/dev/null)" = "Package id 0" ] && sensor=''${l%_label}_input
                done
                ;;
        esac
        [ -n "$sensor" ] && break
    done

    # ── Find a GPU that can be read from /sys, once ──
    # AMD (amdgpu driver): busy %, VRAM and temperature are plain files.
    # Intel (i915 or xe driver): there's no busy % readable without root, but the time
    #   the GPU spends idle is, so busy = whatever isn't idle. Intel graphics share system
    #   RAM, so there's no VRAM to show, and no separate temperature sensor.
    # Skipped when nvidia-smi exists: SysMon.qml asks that instead.
    gpu_kind=""
    gpu_dir=""
    gpu_idle=""
    gpu_temp=""
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        for c in /sys/class/drm/card[0-9]*; do
            case $(basename "$c") in *-*) continue ;; esac   # skip outputs like card0-eDP-1
            drv=$(basename "$(readlink -f "$c/device/driver")")
            case $drv in
                amdgpu)
                    gpu_kind=amd
                    gpu_dir=$c/device
                    for t in "$c"/device/hwmon/hwmon*/temp1_input; do
                        [ -r "$t" ] && gpu_temp=$t
                    done
                    break                           # an AMD card wins over Intel graphics
                    ;;
                i915)
                    for f in "$c/gt/gt0/rc6_residency_ms" "$c/power/rc6_residency_ms"; do
                        if [ -z "$gpu_kind" ] && [ -r "$f" ]; then
                            gpu_kind=intel
                            gpu_idle=$f
                        fi
                    done
                    ;;
                xe)
                    f=$c/device/tile0/gt0/gtidle/idle_residency_ms
                    if [ -z "$gpu_kind" ] && [ -r "$f" ]; then
                        gpu_kind=intel
                        gpu_idle=$f
                    fi
                    ;;
            esac
        done
    fi

    # ── Once a second: read the counters, print them as one line ──
    while :; do
        awk -v sensor="$sensor" -v gk="$gpu_kind" -v gdir="$gpu_dir" -v gidle="$gpu_idle" -v gtemp="$gpu_temp" '
            # first line of /proc/stat: all cores together
            # cpu  user nice system idle iowait irq softirq steal
            FILENAME == "/proc/stat" && $1 == "cpu" {
                for (i = 2; i <= 9; i++) total += $i
                busy = total - $5 - $6          # everything but idle and iowait
            }
            FILENAME == "/proc/meminfo" { mem[$1] = $2 }
            # whole disks only (nvme0n1, sda...), not partitions; column 13 = ms spent doing I/O
            FILENAME == "/proc/diskstats" && $3 ~ /^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$/ {
                disks = disks sep "\"" $3 "\":" sprintf("%.0f", $13)
                sep = ","
            }
            # reads the first line of a file as a number; -1 if that fails
            function num(f,   v) {
                if (f != "" && (getline v < f) > 0) {
                    close(f)
                    return v + 0
                }
                return -1
            }
            END {
                temp = "null"
                if (sensor != "" && (getline t < sensor) > 0) temp = sprintf("%.1f", t / 1000)
                gpu = "null"
                if (gk == "amd") {
                    gt = num(gtemp)
                    gpu = sprintf("{\"busy\":%.0f,\"temp\":%s,\"vram\":[%.0f,%.0f]}",
                        num(gdir "/gpu_busy_percent"), gt < 0 ? "null" : sprintf("%.1f", gt / 1000),
                        num(gdir "/mem_info_vram_used") / 1048576, num(gdir "/mem_info_vram_total") / 1048576)
                } else if (gk == "intel") {
                    gpu = sprintf("{\"idle\":%.0f}", num(gidle))
                }
                printf "{\"cpu\":[%.0f,%.0f],\"mem\":[%.0f,%.0f],\"swap\":[%.0f,%.0f],\"temp\":%s,\"disks\":{%s},\"gpu\":%s}\n",
                    busy, total, mem["MemTotal:"], mem["MemAvailable:"], mem["SwapTotal:"], mem["SwapFree:"], temp, disks, gpu
            }' /proc/stat /proc/meminfo /proc/diskstats
        sleep 1
    done
  '';
  services.hyprpolkitagent.enable = true;

  # ── UWSM session environment ──
  # uwsm reads ~/.config/uwsm/env before starting Hyprland and exports it to the whole
  # session (systemd services included). Pointing it at home-manager's session variables
  # file, as the Hyprland wiki suggests, means everything in home.sessionVariables
  # (these, plus the cursor and Qt ones other modules add) reaches every app.
  home.sessionVariables = {
    # [GPU] Same swap as the GPU section of configuration.nix: keep one block active.
    # ── NVIDIA (active) ───────────────────────────── start of block ──
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct"; # nvidia-vaapi-driver
    GBM_BACKEND = "nvidia-drm";
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    WLR_NO_HARDWARE_CURSORS = "1";
    # ── NVIDIA ────────────────────────────────────────── end of block ──
    # ── AMD ───────────────────────────────────────── start of block ──
    # LIBVA_DRIVER_NAME = "radeonsi";
    # ── AMD ───────────────────────────────────────────── end of block ──
    # ── Intel ─────────────────────────────────────── start of block ──
    # LIBVA_DRIVER_NAME = "iHD"; # "i965" on pre-2014 Intel
    # ── Intel ─────────────────────────────────────────── end of block ──
    # Qt apps on Wayland (QT_QPA_PLATFORMTHEME comes from the qt module below)
    QT_QPA_PLATFORM = "wayland";
    # Where the time zone database is. NixOS has no /usr/share/zoneinfo, which is where Qt
    # looks when this isn't set; without it Qt can't load your zone (time.timeZone in
    # configuration.nix) and warns "Unable to determine system time zone".
    TZDIR = "/etc/zoneinfo";
  };
  # The bar is a systemd service, so give it TZDIR directly too.
  systemd.user.services.quickshell.Service.Environment = [ "TZDIR=/etc/zoneinfo" ];
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  # ── Autostart, as services (were hl.exec_cmd lines in the Hyprland config) ──
  # Wallpaper: home-manager's awww module runs awww-daemon with the session.
  services.awww.enable = true;
  systemd.user.services.awww = {
    # The module only starts the daemon if WAYLAND_DISPLAY is already in the session's
    # environment, and a skipped start is never retried. Hyprland exports that variable
    # while the session is starting, so the daemon could miss it and you'd get no
    # wallpaper. An empty value clears that check; Restart= retries it instead.
    Unit.ConditionEnvironment = lib.mkForce "";
    Service.RestartSec = lib.mkForce 2;
    # Set the picture every time the daemon (re)starts. awww answers a moment after it
    # starts, so keep trying for up to ~10 s.
    Service.ExecStartPost = toString (
      pkgs.writeShellScript "awww-wallpaper" ''
        for _ in $(${pkgs.coreutils}/bin/seq 50); do
          ${pkgs.awww}/bin/awww img ${config.home.homeDirectory}/Pictures/Wallpapers/hk.png && exit 0
          ${pkgs.coreutils}/bin/sleep 0.2
        done
        exit 1
      ''
    );
  };

  # Your session services (awww, quickshell, playerctld, polkit, blueman, music-player)
  # all start with graphical-session.target.
  #  - "Hyprland (UWSM)" in ly: uwsm starts that target itself.
  #  - plain "Hyprland": Hyprland starts hyprland-session.target, which pulls the target
  #    in. Hyprland ships that unit, but NixOS doesn't install it as a user unit (only
  #    packages in systemd.packages get that), so here it is, same as Hyprland's own file.
  #    Under UWSM, Hyprland doesn't start it, so it can't get in the way.
  systemd.user.targets.hyprland-session.Unit = {
    Description = "Hyprland session";
    BindsTo = [ "graphical-session.target" ];
    Wants = [ "graphical-session-pre.target" ];
    After = [ "graphical-session-pre.target" ];
    PropagatesStopTo = [ "graphical-session.target" ];
  };

  # Keeps track of the most recently active media player for playerctl.
  services.playerctld.enable = true;
  # Bluetooth pairing agent (with services.blueman in configuration.nix): when a device
  # wants a code confirmed, blueman shows the dialog. The bar's widget does the rest.
  services.blueman-applet.enable = true;

  # Night light (and software dimming on screens without a backlight) for the
  # bar's Display widget. --identity: start with no tint; the widget turns it on.
  services.hyprsunset = {
    enable = true;
    extraArgs = [ "--identity" ];
  };
  # Same start-up race as awww: don't skip it if WAYLAND_DISPLAY isn't set yet,
  # just retry quickly.
  systemd.user.services.hyprsunset = {
    Unit.ConditionEnvironment = lib.mkForce "";
    Service.RestartSec = lib.mkForce 2;
  };
  programs.hyprtoolkit.settings = {
    background = "0xFF2D353B"; # your Theme.bg (everforest bg0)
    base = "0xFF3D484D"; # your Theme.pill (bg2)
    accent = "0xFFA7C080"; # your Theme.accent (green)
    font_family = "SFProText Nerd Font";
    font_family_monospace = "SFMono Nerd Font";
  };

  # ── Qt theming (polkit agent, pavucontrol-qt, any Qt app) ──
  # hyprpolkitagent in nixpkgs is the Qt/QML version, so it takes its colors from
  # Qt's palette, not hyprtoolkit. qt6ct supplies that palette. This module also
  # exports QT_QPA_PLATFORMTHEME to systemd user services, so the polkit agent sees it.
  qt = {
    enable = true;
    platformTheme.name = "qtct"; # installs qt5ct + qt6ct
    qt5ctSettings = {
      Appearance = {
        style = "Fusion";
        custom_palette = true;
        color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/everforest.conf";
      };
      Fonts = {
        general = ''"SFProText Nerd Font,11"'';
        fixed = ''"SFMono Nerd Font,11"'';
      };
    };
    qt6ctSettings = {
      Appearance = {
        style = "Fusion";
        custom_palette = true;
        color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/everforest.conf";
      };
      Fonts = {
        general = ''"SFProText Nerd Font,11"'';
        fixed = ''"SFMono Nerd Font,11"'';
      };
    };
  };
  xdg.configFile."qt5ct/qt5ct.conf".force = true;
  xdg.configFile."qt6ct/qt6ct.conf".force = true;

  # Everforest dark (medium) as a qt6ct color scheme. One color per Qt palette role, in order:
  # WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window,
  # Shadow, Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole,
  # ToolTipBase, ToolTipText, PlaceholderText
  xdg.configFile."qt6ct/colors/everforest.conf".text = ''
    [ColorScheme]
    active_colors=#ffd3c6aa, #ff3d484d, #ff4f585e, #ff475258, #ff232a2e, #ff343f44, #ffd3c6aa, #ffe6e2cc, #ffd3c6aa, #ff343f44, #ff2d353b, #ff232a2e, #ffa7c080, #ff2d353b, #ff7fbbb3, #ffd699b6, #ff3d484d, #ff000000, #ff2d353b, #ffd3c6aa, #ff859289
    inactive_colors=#ffd3c6aa, #ff3d484d, #ff4f585e, #ff475258, #ff232a2e, #ff343f44, #ffd3c6aa, #ffe6e2cc, #ffd3c6aa, #ff343f44, #ff2d353b, #ff232a2e, #ffa7c080, #ff2d353b, #ff7fbbb3, #ffd699b6, #ff3d484d, #ff000000, #ff2d353b, #ffd3c6aa, #ff859289
    disabled_colors=#ff7a8478, #ff3d484d, #ff4f585e, #ff475258, #ff232a2e, #ff343f44, #ff7a8478, #ffe6e2cc, #ff7a8478, #ff343f44, #ff2d353b, #ff232a2e, #ffa7c080, #ff2d353b, #ff7fbbb3, #ffd699b6, #ff3d484d, #ff000000, #ff2d353b, #ffd3c6aa, #ff859289
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use programs.hyprland from configuration.nix
    portalPackage = null; # portal already set in configuration.nix
    configType = "lua";
    settings = lib.mkForce { };
    # Off for UWSM: uwsm starts graphical-session.target and exports the environment
    # itself. The Hyprland wiki says this home-manager integration conflicts with it.
    systemd.enable = false;
    extraConfig = ''
      -- Generated by hyprconf2lua v1.3.2
      -- https://github.com/Prateek-squadron/hyprconf2lua
      -- Manual review may be needed for complex directives
      -- Fixed: env vars now actually applied via hl.env(); blur config consolidated into one block

      ---@module 'hl'

      hl.monitor({
          output   = "", -- for laptops generally eDP-0 or eDP-1, and desktops usually DP-1.
          mode     = "highrr",
          position = "auto",
          scale    = "auto",
      })

      -- Environment variables live in home.nix (home.sessionVariables), which uwsm
      -- loads from ~/.config/uwsm/env before Hyprland starts. uwsm sets the XDG_* ones itself.
      --hyprmod settings
      hl.unbind("SUPER + SHIFT + Left")
      hl.bind("SUPER + SHIFT + Left", hl.dsp.focus({ workspace = -1 }))
      hl.unbind("SUPER + SHIFT + Right")
      hl.bind("SUPER + SHIFT + Right", hl.dsp.focus({ workspace = "+1" }))
      hl.bind("Print", hl.dsp.exec_cmd("uwsm app -- hyprshot -m region --output-folder ~/Pictures/Screenshots"))
      -- Laptop brightness keys: hold to keep going, and they work on the lock screen too.
      -- --min-value=1 stops it at 1 instead of going fully black.
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q -c backlight set 5%+"), { repeating = true, locked = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q -c backlight --min-value=1 set 5%-"), { repeating = true, locked = true })
      hl.bind("SUPER + CTRL + Right", hl.dsp.window.move({ workspace = "+1" }))
      hl.bind("SUPER + CTRL + Left", hl.dsp.window.move({ workspace = -1 }))

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
              ["col.active_border"]   = "rgba(a7c080ee)", -- everforest green
              ["col.inactive_border"] = "rgba(56635f99)", -- everforest bg5
              resize_on_border = true,
              extend_border_grab_area = 20,  -- pixels of grab area beyond the visible border
              hover_icon_on_border = true,
          },
      })
      hl.config({
          cursor = {
              inactive_timeout = 0,
              -- [GPU] NVIDIA needs software cursors; on AMD / Intel this can be false
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

      hl.bind("SUPER + Return", hl.dsp.exec_cmd("uwsm app -- kitty"))

      hl.bind("SUPER + Q", hl.dsp.window.close())

      hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("uwsm stop"))


      -- Captures the entire screen and copies it directly to your clipboard
      -- Pressing Print captures the entire screen straight to your clipboard


      -- True fullscreen (Hides waybar and gaps)

      hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind("SUPER + V", hl.dsp.window.float())

      -- Forces every window on the workspace into floating mode

      hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("hyprctl clients -j| jq -r '.[]| select(.workspace.id=='$(hyprctl activeworkspace -j| jq '.id')')| . address'| xargs -I { } hyprctl dispatch togglefloating address:{ }"))

      -- Toggle Rofi App Launcher using Super and Tab

      hl.bind("SUPER + TAB", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -run-command 'uwsm app -- {cmd}' -theme-str 'window { close-on-click:true; } '"))

      -- Delete or replace the bottom section with ONLY this line:

      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })

      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- TODO: manual review: blurls = "waybar"

      -- Autostart: nothing here anymore. Everything that used to start here is a
      -- systemd user service in home.nix (awww, playerctld,
      -- hyprpolkitagent, quickshell, music-player), started by uwsm's graphical-session.target.

      -- HyprMod managed settings
      --require("hyprland-gui")
      -- hyprbars settings go inside hl.config under plugin
      --[[hl.config({
          plugin = {
              hyprbars = {
                  bar_height = 20,
                  bar_color = "rgb(2d353b)",
                  ["col.text"] = "rgb(d3c6aa)",
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
          bg_color = "rgb(e67e80)",
          fg_color = "rgb(2d353b)",
          size = 15,
          icon = "󱎘",
          action = "hyprctl dispatch 'hl.dsp.window.close()'",
      })
      hl.plugin.hyprbars.add_button({
          bg_color = "rgb(a7c080)",
          fg_color = "rgb(2d353b)",
          size = 15,
          icon = "",
          action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
      })
      hl.plugin.hyprbars.add_button({
          bg_color = "rgb(d699b6)",
          fg_color = "rgb(2d353b)",
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
        # Everforest dark (medium)
        "*" = {
          background = mkLiteral "#2d353b";
          background-alt = mkLiteral "#3d484d";
          foreground = mkLiteral "#d3c6aa";
          selected = mkLiteral "#a7c080";
          active = mkLiteral "#83c092";
          urgent = mkLiteral "#e67e80";
          font = "SFMono Nerd Font 11";
          border-radius = mkLiteral "8px";
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
      # Everforest dark (medium), same values as kitty-themes' everforest_dark_medium
      foreground = "#d3c6aa";
      background = "#2d353b";
      selection_foreground = "#9da9a0";
      selection_background = "#505a60";
      cursor = "#d3c6aa";
      cursor_text_color = "#343f44";
      url_color = "#7fbbb3";
      active_border_color = "#a7c080";
      inactive_border_color = "#56635f";
      bell_border_color = "#e69875";
      wayland_titlebar_color = "system";
      active_tab_foreground = "#d3c6aa";
      active_tab_background = "#2d353b";
      inactive_tab_foreground = "#9da9a0";
      inactive_tab_background = "#3d484d";
      tab_bar_background = "#343f44";
      mark1_foreground = "#2d353b";
      mark1_background = "#7fbbb3";
      mark2_foreground = "#2d353b";
      mark2_background = "#d3c6aa";
      mark3_foreground = "#2d353b";
      mark3_background = "#d699b6";
      color0 = "#343f44";
      color8 = "#868d80";
      color1 = "#e67e80";
      color9 = "#e67e80";
      color2 = "#a7c080";
      color10 = "#a7c080";
      color3 = "#dbbc7f";
      color11 = "#dbbc7f";
      color4 = "#7fbbb3";
      color12 = "#7fbbb3";
      color5 = "#d699b6";
      color13 = "#d699b6";
      color6 = "#83c092";
      color14 = "#83c092";
      color7 = "#859289";
      color15 = "#9da9a0";
    };
  };
  # kitty rewrites kitty.conf itself (e.g. the font/theme kittens), turning HM's
  # symlink into a regular file; force lets HM replace it
  xdg.configFile."kitty/kitty.conf".force = true;

  gtk = {
    enable = true;
    theme = {
      # the package builds every accent; Green matches Theme.qml's accent
      name = "Everforest-Green-Dark";
      package = pkgs.everforest-gtk-theme;
    };
    iconTheme = {
      name = "Everforest-Dark"; # icons ship in the same package
      package = pkgs.everforest-gtk-theme;
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
    name = "everforest-cursors";
    package = pkgs.everforest-cursors;
  };

  gtk.cursorTheme = {
    name = "everforest-cursors";
    package = pkgs.everforest-cursors;
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
    # Everforest colors, written as rgb(hex)
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
          color = "rgb(d3c6aa)"; # fg
          font_size = 64;
          font_family = "SFMono Nerd Font";
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
          outer_color = "rgb(a7c080)"; # green
          inner_color = "rgb(343f44)"; # bg1
          font_color = "rgb(d3c6aa)"; # fg
          font_family = "SFMono Nerd Font";
          placeholder_text = "<i>Input Password...</i>";
          fade_on_empty = false;
          dots_center = true;
          check_color = "rgb(dbbc7f)"; # yellow
          fail_color = "rgb(e67e80)"; # red
          dots_size = 0.33; # 0.2–0.8, fraction of the field height
          dots_spacing = 0.15; # 0.0–1.0, gap between dots, relative to dot size
        }
      ];
    };
  };
  # replaces any hand-written ~/.config/hypr/hyprlock.conf instead of failing activation
  xdg.configFile."hypr/hyprlock.conf".force = true;
}
