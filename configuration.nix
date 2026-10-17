# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # ── for the login screen (see services.greetd below) ──
  greeterQuickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # The wallpaper: hk.png next to this file (it's in your repo). Copied into the Nix
  # store so the greeter user can read it. Without the file, the screen is plain.
  greeterWallpaper = if builtins.pathExists ./hk.png then "${./hk.png}" else "";
  # Accounts you can pick at login: every normal user.
  greeterUsers = builtins.toJSON (
    map (u: {
      name = u.name;
      real = u.description;
    }) (lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users))
  );
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    #./kernel.nix
  ];

  boot.blacklistedKernelModules = [
    "acpi_pad"
    # (nouveau is blacklisted in the NVIDIA block of the GPU section below)
  ];
  # Bootloader.
  #boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    settings.default = "@saved";
  };

  boot.loader.efi.canTouchEfiVariables = true;
  # Use latest kernel. You can switch to cachy (using chaotic flake) by appending _cachyos rather than _latest.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  nix.settings.trusted-users = [
    "root"
    "garinh"
  ];
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # Bash line editor
  programs.bash.blesh.enable = true;
  #nix helper
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 5"; # Wipes old boot configs but keeps the last 5 generations
    };
  };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #  services.xserver.displayManager.gdm.enable = true;
  #  services.xserver.desktopManager.gnome.enable = true;
  # =========================================================================
  # 1. DISPLAY MANAGER & HYPRLAND COMPOSITOR CONFIGURATION
  # =========================================================================

  # Enable the Hyprland Compositor via its dedicated module
  # This configures polkit, xdg portals, and session files seamlessly

  programs.hyprland = {
    enable = true;
    # Start Hyprland through UWSM (Universal Wayland Session Manager). It runs the session
    # as systemd units: graphical-session.target, autostart services, clean shutdown.
    # Adds a "Hyprland (UWSM)" session; the login screen picks it by default.
    withUWSM = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # ── Login screen: greetd + a Quickshell greeter ──
  # (replaces ly; to go back, delete this block and set services.displayManager.ly.enable = true)
  #
  # greetd starts a tiny Hyprland as the "greeter" user, Hyprland runs Quickshell with the
  # login screen from /etc/greetd/greeter, and once you log in greetd starts the session
  # you picked in the top bar. Every installed Wayland session shows up there (Hyprland,
  # Hyprland (UWSM), and anything you add later, like GNOME or Plasma).
  #
  # If the screen ever comes up broken: Ctrl+Alt+T opens a plain text login, or switch to
  # a text console with Ctrl+Alt+F2 and log in there.
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
      command = "${config.programs.hyprland.package}/bin/Hyprland --config /etc/greetd/hyprland.lua";
    };
  };
  # The greeter needs a home: Hyprland and Quickshell keep caches there, and the login
  # screen remembers your last user + session in /var/lib/greeter/last.
  users.users.greeter = {
    home = "/var/lib/greeter";
    createHome = true;
  };

  environment.etc."greetd/hyprland.lua".text = ''
    -- Hyprland for the login screen only. Your own config isn't used here.
    hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto" })

    hl.config({
        misc = {
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            disable_xdg_env_checks = true,
            disable_hyprland_guiutils_check = true,
            disable_watchdog_warning = true, -- started by greetd, not start-hyprland
            force_default_wallpaper = 0,
            background_color = "rgb(2d353b)", -- shows for a moment before the login screen appears
        },
        cursor = {
            no_hardware_cursors = true, -- [GPU] NVIDIA needs this; fine to delete on AMD/Intel
            inactive_timeout = 5,
        },
        input = {
            kb_layout = "us",
        },
    })

    -- Rescue hatch: a plain text login in a terminal.
    hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd([[${pkgs.kitty}/bin/kitty ${pkgs.greetd}/bin/agreety --cmd "uwsm start hyprland-uwsm.desktop" && ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.exit()']]))

    -- Start the login screen. When it's done (you logged in), close this Hyprland so
    -- greetd can start your session.
    hl.on("hyprland.start", function()
        hl.exec_cmd([[${greeterQuickshell}/bin/quickshell -p /etc/greetd/greeter/shell.qml; ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.exit()']])
    end)
  '';

  # Lists the Wayland sessions as: name <tab> command <tab> desktop names <tab> id
  environment.etc."greetd/greeter/sessions.sh".text = ''
    for f in ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop; do
      [ -e "$f" ] || continue
      get() { ${pkgs.gnused}/bin/sed -n "s/^$1=//p" "$f" | ${pkgs.coreutils}/bin/head -n1; }
      [ "$(get NoDisplay)" = true ] && continue
      [ "$(get Hidden)" = true ] && continue
      printf '%s\t%s\t%s\t%s\n' "$(get Name)" "$(get Exec)" "$(get DesktopNames)" "$(${pkgs.coreutils}/bin/basename "$f" .desktop)"
    done
  '';

  environment.etc."greetd/greeter/Theme.qml".text = ''
      pragma Singleton

      import QtQuick
      import Quickshell

      // Everforest, the same colors as hyprlock and the bar.
      Singleton {
          readonly property color bg: "#2d353b"
          readonly property color inner: "#343f44"
          readonly property color pill: "#3d484d"
          readonly property color text: "#d3c6aa"
          readonly property color green: "#a7c080"
          readonly property color yellow: "#dbbc7f"
          readonly property color red: "#e67e80"
          readonly property string font: "SFMono Nerd Font"
          readonly property string iconFont: "Material Symbols Rounded"
      }
  '';
  environment.etc."greetd/greeter/BarChip.qml".text = ''
      import QtQuick

      // A button in the top bar: icon, optional label, optional arrow.
      Rectangle {
          id: chip
          property string icon: ""
          property string label: ""
          property string trailing: ""
          property bool active: false
          property color iconColor: Theme.text
          signal clicked

          implicitWidth: chipRow.implicitWidth + 20
          implicitHeight: 28
          radius: height / 2
          color: active || chipMouse.containsMouse ? Theme.pill : "transparent"
          scale: chipMouse.pressed ? 0.9 : 1
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
              id: chipRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: chip.icon
                  color: chip.active ? Theme.green : chip.iconColor
                  font.family: Theme.iconFont
                  font.pixelSize: 18
              }
              Text {
                  visible: chip.label !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  text: chip.label
                  color: Theme.text
                  font.family: Theme.font
                  font.pixelSize: 13
                  font.weight: 600
              }
              Text {
                  visible: chip.trailing !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  text: chip.trailing
                  color: Theme.text
                  opacity: 0.7
                  font.family: Theme.iconFont
                  font.pixelSize: 16
              }
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
  environment.etc."greetd/greeter/DropList.qml".text = ''
      import QtQuick

      // A list that slides down from under the bar; the current entry has a check.
      Rectangle {
          id: list
          property Item anchor
          property var model: []
          property int current: 0
          property var labelOf: x => String(x)
          property bool open: false
          signal picked(int index)

          readonly property real fullHeight: listCol.implicitHeight + 12
          x: anchor ? anchor.x + anchor.width / 2 - width / 2 : 0
          y: anchor ? anchor.y + anchor.height + 6 : 0
          width: Math.max(240, listCol.implicitWidth + 12)
          height: open ? fullHeight : 0
          visible: height > 0.5
          clip: true
          radius: 16
          color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
          Behavior on height {
              NumberAnimation {
                  duration: 300
                  easing.type: Easing.OutCubic
              }
          }

          Column {
              id: listCol
              x: 6
              y: 6
              width: list.width - 12
              opacity: list.open ? 1 : 0
              Behavior on opacity {
                  NumberAnimation {
                      duration: 200
                  }
              }

              Repeater {
                  model: list.model
                  Rectangle {
                      id: row
                      required property var modelData
                      required property int index
                      width: listCol.width
                      implicitWidth: rowText.implicitWidth + 60
                      height: 32
                      radius: 10
                      color: rowMouse.containsMouse ? Theme.pill : "transparent"
                      Behavior on color {
                          ColorAnimation {
                              duration: 120
                          }
                      }
                      Text {
                          id: rowText
                          anchors.left: parent.left
                          anchors.leftMargin: 12
                          anchors.verticalCenter: parent.verticalCenter
                          text: list.labelOf(row.modelData)
                          color: row.index === list.current ? Theme.green : Theme.text
                          font.family: Theme.font
                          font.pixelSize: 13
                          font.weight: row.index === list.current ? 700 : 500
                      }
                      Text {
                          anchors.right: parent.right
                          anchors.rightMargin: 12
                          anchors.verticalCenter: parent.verticalCenter
                          visible: row.index === list.current
                          text: "check"
                          color: Theme.green
                          font.family: Theme.iconFont
                          font.pixelSize: 16
                      }
                      MouseArea {
                          id: rowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: list.picked(row.index)
                      }
                  }
              }
          }
      }
  '';
  environment.etc."greetd/greeter/shell.qml".text = ''
      // Login screen: Quickshell running inside its own little Hyprland, started by
      // greetd. Looks like your hyprlock (blurred wallpaper, big clock, green pill
      // password box). The bar at the top picks the session (desktop) and has
      // suspend / reboot / power off.
      //
      // Flow: type password, Enter -> greetd checks it -> the screen fades -> greetd
      // starts the session you picked -> this Hyprland exits.
      //
      // Keys: Enter = log in, Esc = clear / close the menu.
      //       Ctrl+Alt+T = plain text login in a terminal, in case this ever breaks.
      import QtQuick
      import QtQuick.Controls.Basic
      import QtQuick.Effects
      import Quickshell
      import Quickshell.Io
      import Quickshell.Wayland
      import Quickshell.Services.Greetd

      ShellRoot {
          id: root

          // ── filled in by configuration.nix ──
          readonly property string wallpaper: "${greeterWallpaper}"           // "" = no picture
          readonly property var users: ${greeterUsers}                         // [{ name, real }]
          readonly property string sessionsScript: "/etc/greetd/greeter/sessions.sh"
          readonly property string stateFile: "/var/lib/greeter/last"  // remembers user + session

          // ── state ──
          property var sessions: []       // [{ name, exec, desktops, id }], from the .desktop files
          property int sessionIndex: 0
          property int userIndex: 0
          readonly property var session: sessions.length > 0 ? sessions[Math.min(sessionIndex, sessions.length - 1)] : null
          readonly property var user: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : ({ "name": "", "real": "" })

          // "idle", "checking" (greetd is looking at the password), "failed", "launching"
          property string phase: "idle"
          property string message: ""     // shown under the box (errors, PAM messages)
          property string password: ""

          // ── what you picked last time ──
          FileView {
              id: lastFile
              path: root.stateFile
              blockLoading: true
              printErrors: false
          }
          function restoreLast() {
              const parts = (lastFile.text() || "").trim().split("\t");
              const u = root.users.findIndex(x => x.name === parts[0]);
              if (u >= 0)
                  root.userIndex = u;
              let s = root.sessions.findIndex(x => x.id === parts[1]);
              // nothing saved yet: prefer Hyprland under UWSM
              if (s < 0)
                  s = root.sessions.findIndex(x => x.id === "hyprland-uwsm");
              root.sessionIndex = Math.max(0, s);
          }

          // ── list the installed Wayland sessions ──
          Process {
              running: true
              command: ["/bin/sh", root.sessionsScript]
              stdout: StdioCollector {
                  onStreamFinished: {
                      const list = [];
                      for (const line of text.split("\n")) {
                          const f = line.split("\t");
                          if (f.length >= 4 && f[1] !== "")
                              list.push({ "name": f[0] || f[3], "exec": f[1], "desktops": f[2], "id": f[3] });
                      }
                      list.sort((a, b) => a.name.localeCompare(b.name));
                      root.sessions = list;
                      root.restoreLast();
                  }
              }
          }

          // ── logging in ──
          function login() {
              if (phase === "checking" || phase === "launching" || !session || user.name === "")
                  return;
              if (password === "") {
                  message = "Type your password first";
                  return;
              }
              message = "";
              phase = "checking";
              if (Greetd.state !== GreetdState.Inactive)
                  Greetd.cancelSession();
              Greetd.createSession(user.name);
          }
          function fail(why) {
              phase = "failed";
              message = why;
              password = "";
              failReset.restart();
          }

          Connections {
              target: Greetd

              function onAuthMessage(message, error, responseRequired, echoResponse) {
                  if (responseRequired) {
                      // PAM asks for the password: answer with what you typed
                      Greetd.respond(root.password);
                  } else if (error) {
                      root.message = message;
                  } else if (message !== "") {
                      root.message = message;   // info, e.g. "Place your finger..."
                  }
              }
              function onAuthFailure(message) {
                  root.fail(message !== "" ? message : "Wrong password");
              }
              function onError(error) {
                  root.fail(error);
              }
              function onReadyToLaunch() {
                  root.phase = "launching";
                  lastFile.setText(root.user.name + "\t" + root.session.id + "\n");
                  // greetd wants the greeter gone quickly once it launches, so the fade
                  // happens first and launch() comes after it.
                  launchTimer.restart();
              }
          }
          Timer {
              id: launchTimer
              interval: 450   // matches the fade below
              onTriggered: {
                  const s = root.session;
                  // Remove the %f / %U placeholders some .desktop files have.
                  const exec = s.exec.replace(/%[a-zA-Z]/g, "").trim();
                  const env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + s.id];
                  // Only pass desktop names the .desktop file lists. The UWSM entry has
                  // none on purpose: uwsm works out "Hyprland" itself, and a value here
                  // would replace that.
                  if (s.desktops !== "")
                      env.push("XDG_CURRENT_DESKTOP=" + s.desktops.replace(/;$/, "").replace(/;/g, ":"));
                  Greetd.launch(["/bin/sh", "-c", "exec " + exec], env);
              }
          }
          Timer {
              id: failReset
              interval: 2500
              onTriggered: if (root.phase === "failed")
                  root.phase = "idle"
          }

          // ── one window per screen; the login box only on the first ──
          Variants {
              model: Quickshell.screens

              PanelWindow {
                  id: win
                  required property var modelData
                  readonly property bool main: modelData.name === Quickshell.screens[0].name  // first screen

                  screen: modelData
                  anchors {
                      top: true
                      bottom: true
                      left: true
                      right: true
                  }
                  exclusionMode: ExclusionMode.Ignore
                  WlrLayershell.layer: WlrLayer.Overlay
                  WlrLayershell.namespace: "greeter"
                  WlrLayershell.keyboardFocus: main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                  color: Theme.bg

                  Item {
                      id: scene
                      anchors.fill: parent
                      // fade in on start, fade out right before the session starts
                      opacity: root.phase === "launching" ? 0 : 1
                      Behavior on opacity {
                          NumberAnimation {
                              duration: 400
                              easing.type: Easing.InOutCubic
                          }
                      }

                      // ── wallpaper, blurred and a bit darker, like hyprlock ──
                      Image {
                          id: wall
                          anchors.fill: parent
                          source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                          fillMode: Image.PreserveAspectCrop
                          // load it at screen size, not the photo's full size (less to blur)
                          sourceSize.width: width
                          sourceSize.height: height
                          asynchronous: true
                          visible: false
                      }
                      MultiEffect {
                          anchors.fill: parent
                          source: wall
                          visible: wall.status === Image.Ready
                          blurEnabled: true
                          blur: 1.0
                          blurMax: 48
                          brightness: -0.12
                          saturation: 0.1
                          // start slightly zoomed and settle in
                          scale: scene.introDone ? 1.0 : 1.06
                          Behavior on scale {
                              NumberAnimation {
                                  duration: 900
                                  easing.type: Easing.OutCubic
                              }
                          }
                      }
                      property bool introDone: false
                      Component.onCompleted: introDone = true

                      // ── the clock: 64 px, 74 px above the middle (hyprlock's spot) ──
                      SystemClock {
                          id: clock
                          precision: SystemClock.Minutes
                      }
                      Text {
                          id: clockText
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.bottom: parent.verticalCenter
                          anchors.bottomMargin: 74 - height / 2
                          text: Qt.formatTime(clock.date, "HH:mm")
                          color: Theme.text
                          font.family: Theme.font
                          font.pixelSize: 64
                          font.weight: 700
                      }
                      Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.bottom: clockText.top
                          text: Qt.formatDate(clock.date, "dddd, MMMM d")
                          color: Theme.text
                          opacity: 0.7
                          font.family: Theme.font
                          font.pixelSize: 15
                      }

                      // ── password box: 200 x 50 pill, 20 px below the middle ──
                      Item {
                          id: loginBox
                          visible: win.main
                          width: 200
                          height: 50
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.verticalCenterOffset: 20

                          // shake on a wrong password
                          transform: Translate {
                              id: shakeMove
                          }
                          SequentialAnimation {
                              id: shake
                              running: root.phase === "failed"
                              NumberAnimation { target: shakeMove; property: "x"; to: -10; duration: 50 }
                              NumberAnimation { target: shakeMove; property: "x"; to: 10; duration: 70 }
                              NumberAnimation { target: shakeMove; property: "x"; to: -6; duration: 70 }
                              NumberAnimation { target: shakeMove; property: "x"; to: 6; duration: 70 }
                              NumberAnimation { target: shakeMove; property: "x"; to: 0; duration: 60 }
                          }

                          Rectangle {
                              anchors.fill: parent
                              radius: height / 2
                              color: Theme.inner
                              border.width: 3
                              // green normally, yellow while checking, red when it failed
                              border.color: root.phase === "checking" ? Theme.yellow : root.phase === "failed" ? Theme.red : Theme.green
                              Behavior on border.color {
                                  ColorAnimation {
                                      duration: 200
                                  }
                              }
                          }

                          // The hint inside the box (hyprlock's italic placeholder). Drawn by
                          // hand: the built-in one hides while the box is focused.
                          Text {
                              anchors.centerIn: parent
                              visible: field.text === ""
                              text: root.phase === "failed" ? root.message : "Input Password..."
                              color: root.phase === "failed" ? Theme.red : Theme.text
                              opacity: root.phase === "failed" ? 1 : 0.5
                              font.family: Theme.font
                              font.pixelSize: 14
                              font.italic: true
                              elide: Text.ElideRight
                              width: Math.min(implicitWidth, parent.width - 32)
                          }

                          TextField {
                              id: field
                              anchors.fill: parent
                              anchors.leftMargin: 16
                              anchors.rightMargin: 16
                              background: null
                              focus: win.main
                              enabled: root.phase !== "launching"
                              echoMode: TextInput.Password
                              passwordCharacter: "●"
                              horizontalAlignment: TextInput.AlignHCenter
                              verticalAlignment: TextInput.AlignVCenter
                              color: Theme.text
                              selectionColor: Theme.green
                              font.family: Theme.font
                              font.pixelSize: 16
                              font.letterSpacing: 2
                              cursorDelegate: Item {}   // no text cursor, like hyprlock
                              text: root.password
                              onTextEdited: {
                                  root.password = text;
                                  if (root.phase !== "checking")
                                      root.message = "";   // typing again clears the old error
                              }
                              onAccepted: root.login()
                              Keys.onEscapePressed: {
                                  if (sessionMenu.open)
                                      sessionMenu.open = false;
                                  else
                                      root.password = "";
                              }
                          }
                      }

                      // who's logging in, and messages, under the box
                      Text {
                          visible: win.main
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.top: loginBox.bottom
                          anchors.topMargin: 14
                          text: root.phase === "checking" ? "Checking..." : root.message !== "" && root.phase !== "failed" ? root.message : root.user.real !== "" ? root.user.real : root.user.name
                          color: root.phase === "checking" ? Theme.yellow : Theme.text
                          opacity: 0.8
                          font.family: Theme.font
                          font.pixelSize: 14
                      }

                      // ── the options bar at the top ──
                      Rectangle {
                          id: topBar
                          visible: win.main
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.top: parent.top
                          anchors.topMargin: 12
                          width: barRow.implicitWidth + 16
                          height: 38
                          radius: height / 2
                          color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85)

                          Row {
                              id: barRow
                              anchors.centerIn: parent
                              spacing: 6

                              // session picker: click to open the list
                              BarChip {
                                  icon: "desktop_windows"
                                  label: root.session ? root.session.name : "No sessions found"
                                  trailing: sessionMenu.open ? "expand_less" : "expand_more"
                                  active: sessionMenu.open
                                  onClicked: {
                                      userMenu.open = false;
                                      sessionMenu.open = !sessionMenu.open;
                                  }
                              }
                              // user picker, only when there's more than one account
                              BarChip {
                                  visible: root.users.length > 1
                                  icon: "person"
                                  label: root.user.name
                                  trailing: userMenu.open ? "expand_less" : "expand_more"
                                  active: userMenu.open
                                  onClicked: {
                                      sessionMenu.open = false;
                                      userMenu.open = !userMenu.open;
                                  }
                              }
                              Rectangle {
                                  width: 1
                                  height: 18
                                  anchors.verticalCenter: parent.verticalCenter
                                  color: Theme.pill
                              }
                              BarChip {
                                  icon: "bedtime"
                                  onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                              }
                              BarChip {
                                  icon: "restart_alt"
                                  onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                              }
                              BarChip {
                                  icon: "power_settings_new"
                                  iconColor: Theme.red
                                  onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                              }
                          }
                      }

                      // ── drop-down lists under the bar ──
                      DropList {
                          id: sessionMenu
                          anchor: topBar
                          model: root.sessions
                          current: root.sessionIndex
                          labelOf: s => s.name
                          onPicked: i => {
                              root.sessionIndex = i;
                              open = false;
                              field.forceActiveFocus();
                          }
                      }
                      DropList {
                          id: userMenu
                          anchor: topBar
                          model: root.users
                          current: root.userIndex
                          labelOf: u => u.real !== "" ? u.real + "  (" + u.name + ")" : u.name
                          onPicked: i => {
                              root.userIndex = i;
                              open = false;
                              field.forceActiveFocus();
                          }
                      }
                  }
              }
          }
      }
  '';

  environment.sessionVariables = {
    # Fixes standard electron/chromium apps on Wayland too (any GPU)
    NIXOS_OZONE_WL = "1";
    # (GPU-specific variables are in the GPU section below)
  };
  chaotic.nyx.cache.enable = true;
  # =========================================================================
  # 2. SYSTEM-WIDE FONTS SETTINGS (Nerd Fonts, Ioskeley Mono, Hanken Grotesk)
  # =========================================================================
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # Modern granular Nerd Font packages (instead of the huge legacy package)
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only # Acts as a universal fallback for system icons
      material-symbols

      # Ioskeley Mono - the exact Berkeley Mono mimic configuration built over Iosevka
      # Options include: .normal, .normal-NF (Nerd Font patched), .condensed, etc.
      # Clean, modern sans-serif typeface
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-mono-nerd
    ];

    # Inform your desktop environment how to prioritize these fonts
    fontconfig.defaultFonts = {
      monospace = [
        "Ioskeley Mono"
        "JetBrainsMono Nerd Font"
      ];
      sansSerif = [ "SF Pro Nerd" ];
    };
  };
  #zram and such (oh yes)
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 100; # 1x RAM as compressed swap
  };
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  # =========================================================================
  # [GPU] GRAPHICS DRIVER: everything GPU-specific, one block per vendor.
  # NVIDIA is active. To switch to another GPU:
  #   1. Comment out the whole NVIDIA block (put "# " in front of every line).
  #   2. Uncomment the AMD or Intel block (remove the "# " in front of every line).
  #   3. Do the same in home.nix: search it for [GPU] (home.sessionVariables).
  # Only one block may be active at a time, or rebuilding will complain that the
  # same option is set twice. Same setups as the amd/ and intel/ folders in the repo.
  # =========================================================================

  # ── NVIDIA (active) ─────────────────────────────────────── start of block ──
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = pkgs.nvidia_cachyos; # chaotic: prebuilt for linuxPackages_cachyos (was config.boot.kernelPackages.nvidiaPackages.latest)
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
  };
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
  boot.extraModprobeConfig = ''
    blacklist nouveau
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    options nvidia NVreg_TemporaryFilePath=/var/tmp
  '';
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1"; # Nvidia can't draw the cursor in hardware
  environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia"; # needed with libva 2.20+, which forces this driver
  environment.sessionVariables.MOZ_DISABLE_RDD_SANDBOX = "1"; # lets Firefox's decoder process reach the driver
  programs.firefox.preferences."widget.dmabuf.force-enabled" = true; # README: needed on 500+ series drivers
  # ── NVIDIA ──────────────────────────────────────────────────── end of block ──

  # ── AMD ─────────────────────────────────────────────────── start of block ──
  # services.xserver.videoDrivers = [ "amdgpu" ];
  # hardware.graphics = {
  #   enable = true;
  #   enable32Bit = true; # for Steam / 32-bit games
  # };
  # environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi"; # Mesa's VA-API driver
  # ── AMD ─────────────────────────────────────────────────────── end of block ──

  # ── Intel ───────────────────────────────────────────────── start of block ──
  # services.xserver.videoDrivers = [ "modesetting" ]; # the default anyway
  # hardware.graphics = {
  #   enable = true;
  #   enable32Bit = true;
  #   extraPackages = with pkgs; [
  #     intel-media-driver # VA-API for Broadwell (2014) and newer
  #     vpl-gpu-rt         # Quick Sync for newer (Xe) Intel
  #   ];
  # };
  # environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD"; # "i965" on pre-2014 Intel
  # ── Intel ───────────────────────────────────────────────────── end of block ──

  #LE STEAM
  programs.steam = {
    enable = true; # Master switch, already covered in installation
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    # Other general flags if available can be set here.
  };
  # Improves Performance With games (temporary and in game, dont worry)
  programs.gamemode.enable = true;
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  #screen recorder
  programs.gpu-screen-recorder.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  #helps bins work
  programs.nix-ld.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."garinh" = {
    isNormalUser = true;
    description = "garinh";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "libvirtd"
      "docker"
    ];
    packages = with pkgs; [
    ];
  };
  # avahi
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.new-lg4ff.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{idVendor}=="046d", MODE="0666", GROUP="input"
    KERNEL=="js*", SUBSYSTEM=="input", ATTRS{idVendor}=="046d", MODE="0666", GROUP="input"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", MODE="0666", GROUP="input"
  '';
  # make sure you're in the input group
  # 2. Tell NixOS to use the CachyOS kernel package
  # Options include: linuxPackages-cachyos-latest, linuxPackages-cachyos-lts, etc.
  # boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  services.flatpak.enable = true;
  # 3. (Optional) Enable Sched-ext (scx) framework support if you want to use its modern schedulers
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland"; # or scx_rusty, scx_lavd, etc — pick per workload
  };
  services.udisks2.enable = true;
  # Install firefox.
  programs.firefox = {
    enable = true;
    package = pkgs.firefox_nightly;
    preferences = {
      "media.ffmpeg.vaapi.enabled" = true; # required: turns on VA-API
      "media.rdd-ffmpeg.enabled" = true; # already the default; decode inside RDD
      # ("widget.dmabuf.force-enabled" is in the NVIDIA block of the GPU section)
    };
  };
  #power prof daemon
  services.power-profiles-daemon.enable = true;
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  programs.starship.enable = true;
  programs.git.enable = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    papirus-icon-theme
    # screen brightness for the bar's Display widget and the brightness keys
    brightnessctl
    # The Fresh Terminal Text Editor/IDE
    udisks2
    fresh-editor
    wget
    cmake
    protontricks
    winetricks
    wineWow64Packages.stable
    gpu-screen-recorder-gtk
    tty-clock
    lunar-client
    unzip
    yt-dlp_git # chaotic
    xdg-utils
    pkgs.kdePackages.qtmultimedia
    pkgs.qt6.qtmultimedia
    lavat
    sbctl
    ffmpeg
    micro
    vscodium
    nixfmt
    kdePackages.qtdeclarative
    hyprlock
    vlc
    fastfetch
    psmisc
    jq
    kitty
    rofi
    btop
    lsd
    pavucontrol
    flatpak
    mdadm
    efibootmgr
    util-linux
    awww
    quickshell
    hyprshot
    gnome-themes-extra
    bibata-cursors
    nwg-look
    adwaita-qt
    adwaita-qt6
    pipes
    libreoffice
    adwaita-icon-theme
    nautilus
    wl-clipboard
    playerctl
    telegram-desktop_git # chaotic
    nodejs
    gnome-boxes
  ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  services.upower.enable = true;

  # ── Bluetooth ──
  # BlueZ, which the bar's Bluetooth widget talks to (Quickshell.Bluetooth uses BlueZ over D-Bus).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # adapter on at boot, so devices can reconnect by themselves
    settings.General = {
      # BlueZ's experimental D-Bus features. Some battery reports (e.g. separate
      # earbud / case levels) are only published with this on. Safe to remove.
      Experimental = true;
    };
  };
  # Pairing needs an "agent": the program BlueZ asks to confirm a code or PIN. Without
  # one, devices that want confirmation (phones, PCs) fail with "Authentication Failed".
  # blueman provides one (the applet runs from home.nix) and pops up the confirm dialog.
  services.blueman.enable = true;

  # Virtualization
  # Use this. It does use a daemon.
  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm; # host arch only, far fewer binaries to probe
    onBoot = "ignore"; # don't restart VMs that were running at shutdown
    onShutdown = "shutdown"; # default is "suspend", which leads to resuming on next boot
  };
  virtualisation.docker.enable = true;
  # programs.virt-manager.enable = true;
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true; # Set to false if using SSH keys exclusively
      PermitRootLogin = "no"; # "yes", "no", or "prohibit-password"
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.nftables.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
