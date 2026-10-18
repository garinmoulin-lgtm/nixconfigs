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
  normalUsers = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);
  greeterUsers = builtins.toJSON (
    map (u: {
      name = u.name;
      real = u.description;
    }) normalUsers
  );
  mainUser = (lib.head normalUsers).name; # owns the shared wallpaper folder
  # The color themes, from home.nix (its themes block, handed out as my.themes).
  # The login screen uses the one you picked in your session: the theme command writes
  # its name, cursor and a copy of its wallpaper to /var/lib/greeter-theme (see `theme`
  # in home.nix).
  themes = config.home-manager.users.${mainUser}.my.themes;
  greeterThemeDir = "/var/lib/greeter-theme";
  # what the login screen's Theme.qml gets: { id: { bg, inner, pill, text, accent, yellow, red } }
  greeterThemes = builtins.toJSON (
    lib.mapAttrs (
      _: t:
      lib.mapAttrs (_: v: "#" + t.colors.${v}) {
        bg = "bg";
        inner = "surface";
        pill = "overlay";
        text = "fg";
        accent = "accent";
        yellow = "yellow";
        red = "red";
      }
    ) themes.themes
  );
  # Every theme's cursor, so the login screen can show whichever one is picked.
  greeterCursors = pkgs.symlinkJoin {
    name = "greeter-cursors";
    paths = lib.unique (map (t: t.cursor.package) (lib.attrValues themes.themes));
  };
  defaultCursor = themes.themes.${themes.default}.cursor.name;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # A quiet console, so no text shows up between the login screen and Hyprland:
    #  - vt.global_cursor_default=0: no blinking text cursor
    #  - consoleLogLevel 3 / quiet: only real errors from the kernel get printed on screen
    #    (driver warnings were the text that popped up now and then)
    #  - systemd/udev status lines off
    # (In its own little block because boot.kernelParams is also set in the GPU section.)
    # Kernel settings: they take effect after a reboot. Everything still goes to the
    # journal (journalctl -b), it just isn't printed on the screen.
    {
      boot.kernelParams = [
        "vt.global_cursor_default=0"
        "quiet"
        "udev.log_level=3"
        "systemd.show_status=false"
      ];
      boot.consoleLogLevel = 3;
      boot.initrd.verbose = false;
    }
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
  # greetd normally waits until every other boot job has been handed out before it starts
  # (systemd "Type=idle", up to 5 s), so a text login doesn't get boot messages printed
  # over it. A graphical login screen doesn't need that, so start right away.
  systemd.services.greetd.serviceConfig = {
    Type = lib.mkForce "simple";
    # Wipe the text console (tty1, where greetd runs) when greetd starts and stops, so
    # old boot messages can't show through between the login screen and your session.
    TTYPath = "/dev/tty1";
    TTYReset = true;
    TTYVTDisallocate = true;
  };
  # The greeter needs a home: Hyprland and Quickshell keep caches there, and the login
  # screen remembers your last user + session in /var/lib/greeter/last.
  users.users.greeter = {
    home = "/var/lib/greeter";
    createHome = true;
  };
  # Your ~/Pictures/Wallpapers gets copied here by your session (home.nix), because the
  # login screen runs as the "greeter" user and can't see inside your home folder.
  # You own it; everyone can read it.
  # /var/lib/greeter-theme: the theme you picked (name, cursor, wallpaper copy), written
  # by the theme command in your session for the same reason. Also yours.
  systemd.tmpfiles.rules = [
    "d /var/lib/greeter-wallpapers 0755 ${mainUser} users -"
    "d ${greeterThemeDir} 0755 ${mainUser} users -"
  ];

  environment.etc."greetd/hyprland.lua".text = ''
    -- Hyprland for the login screen only. Your own config isn't used here.

    -- your cursor: the current theme's (the theme command writes its name here), at the
    -- same size as in your session
    local cursorFile = io.open("${greeterThemeDir}/cursor", "r")
    local cursor = cursorFile and cursorFile:read("*l") or ""
    if cursorFile then cursorFile:close() end
    if cursor == "" then cursor = "${defaultCursor}" end
    hl.env("XCURSOR_THEME", cursor)
    hl.env("XCURSOR_SIZE", "24")
    hl.env("XCURSOR_PATH", "${greeterCursors}/share/icons")
    hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto" })

    hl.config({
        misc = {
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            disable_xdg_env_checks = true,
            disable_hyprland_guiutils_check = true,
            disable_watchdog_warning = true, -- started by greetd, not start-hyprland
            force_default_wallpaper = 0,
            background_color = "rgb(000000)", -- black, so the login screen fades in from (and out to) black
        },
        cursor = {
            no_hardware_cursors = true, -- [GPU] NVIDIA needs this; fine to delete on AMD/Intel
            inactive_timeout = 5,
        },
        input = {
            kb_layout = "us",
            -- same as your Hyprland: no mouse acceleration, 1:1 movement
            accel_profile = "flat",
            sensitivity = 0.0,
        },
        -- the login screen animates itself; skipping Hyprland's own open animation
        -- gets it on screen (and typeable) a little sooner
        animations = {
            enabled = false,
        },
    })

    -- Rescue hatch: a plain text login in a terminal.
    hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd([[${pkgs.kitty}/bin/kitty ${pkgs.greetd}/bin/agreety --cmd "uwsm start hyprland-uwsm.desktop" && ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.exit()']]))

    -- Start the login screen. When it's done (you logged in), close this Hyprland so
    -- greetd can start your session.
    hl.on("hyprland.start", function()
        -- no mouse pointer on the black screen before the login screen fades in
        -- (the login screen shows it again; the timer is a safety net)
        hl.config({ cursor = { invisible = true } })
        hl.timer(function() hl.config({ cursor = { invisible = false } }) end, { timeout = 3000, type = "oneshot" })
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
      import Quickshell.Io

      // The theme you picked in your session (same colors as the bar), from
      // ${greeterThemeDir}/state.json. Until there is one: the default theme.
      Singleton {
          id: theme

          readonly property var themes: (${greeterThemes})
          readonly property string defaultTheme: "${themes.default}"

          // { theme, wallpaper, stamp }, written by the theme command in your session
          property var saved: ({})
          FileView {
              path: "${greeterThemeDir}/state.json"
              blockLoading: true
              printErrors: false
              onLoaded: {
                  try {
                      theme.saved = JSON.parse(text());
                  } catch (e) {
                      theme.saved = {};
                  }
              }
          }
          // the theme's wallpaper (a copy in ${greeterThemeDir}), and a stamp that
          // changes whenever you switch themes (see restoreWallpaper in shell.qml)
          readonly property string wallpaper: saved.wallpaper || ""
          readonly property string stamp: saved.stamp || ""

          readonly property var c: themes[saved.theme] || themes[defaultTheme]
          readonly property color bg: c.bg
          readonly property color inner: c.inner
          readonly property color pill: c.pill
          readonly property color text: c.text
          readonly property color accent: c.accent
          readonly property color yellow: c.yellow
          readonly property color red: c.red
          readonly property string font: "SFMono Nerd Font"
          readonly property string iconFont: "Material Symbols Rounded"
      }
  '';
  environment.etc."greetd/greeter/CenterFade.qml".text = ''
      import QtQuick
      import QtQuick.Shapes

      // A full-screen fade that moves outward from the middle of the screen.
      //   mode "cover":  progress 0 = nothing, 1 = all black. Black spreads out from the center.
      //   mode "reveal": progress 0 = all black, 1 = nothing. The picture underneath opens up
      //                  from the center outward.
      // It's a radial gradient with a soft edge that travels from the center to past the corners.
      Item {
          id: fade

          property string mode: "cover"
          property real progress: 0

          readonly property real soft: 0.3     // how wide the soft edge is (part of the radius)
          readonly property real edge: -soft + progress * (1 + soft)
          readonly property color inner: mode === "cover" ? "black" : "transparent"
          readonly property color outer: mode === "cover" ? "transparent" : "black"

          function clamp(v) {
              return Math.max(0, Math.min(1, v));
          }

          // fully black / fully clear: a plain rectangle, or nothing
          Rectangle {
              anchors.fill: parent
              color: "black"
              visible: fade.mode === "cover" ? fade.progress >= 1 : fade.progress <= 0
          }

          Shape {
              anchors.fill: parent
              visible: fade.progress > 0 && fade.progress < 1

          ShapePath {
              strokeWidth: -1
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                  centerX: fade.width / 2
                  centerY: fade.height / 2
                  focalX: fade.width / 2
                  focalY: fade.height / 2
                  // reaches the corners
                  centerRadius: Math.sqrt(fade.width * fade.width + fade.height * fade.height) / 2

                  GradientStop {
                      position: 0
                      color: fade.inner
                  }
                  GradientStop {
                      position: fade.clamp(fade.edge)
                      color: fade.inner
                  }
                  GradientStop {
                      position: fade.clamp(fade.edge + fade.soft)
                      color: fade.outer
                  }
                  GradientStop {
                      position: 1
                      color: fade.outer
                  }
              }

              startX: 0
              startY: 0
              PathLine { x: fade.width; y: 0 }
              PathLine { x: fade.width; y: fade.height }
              PathLine { x: 0; y: fade.height }
              PathLine { x: 0; y: 0 }
          }
          }
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
                  color: chip.active ? Theme.accent : chip.iconColor
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
                          color: row.index === list.current ? Theme.accent : Theme.text
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
                          color: Theme.accent
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
  environment.etc."greetd/greeter/WallPicker.qml".text = ''
      import QtQuick
      import Quickshell.Widgets

      // Wallpaper picker that slides down from under the top bar: thumbnails of
      // everything in /var/lib/greeter-wallpapers, the current one outlined.
      Rectangle {
          id: picker
          property Item anchor
          property var model: []        // full paths
          property string current: ""
          property bool open: false
          signal picked(string path)
          // Thumbnails load the first time the picker opens, not at startup, so they
          // don't slow the login screen down.
          property bool everOpened: false
          onOpenChanged: if (open)
              everOpened = true

          readonly property int columns: Math.min(3, Math.max(1, model.length))
          readonly property real fullHeight: grid.implicitHeight + 16
          x: anchor ? anchor.x + anchor.width / 2 - width / 2 : 0
          y: anchor ? anchor.y + anchor.height + 6 : 0
          width: columns * 136 + (columns - 1) * 8 + 16
          height: open ? Math.min(fullHeight, 420) : 0
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

          Flickable {
              anchors.fill: parent
              anchors.margins: 8
              contentHeight: grid.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              opacity: picker.open ? 1 : 0
              Behavior on opacity {
                  NumberAnimation {
                      duration: 200
                  }
              }

              Grid {
                  id: grid
                  columns: picker.columns
                  spacing: 8

                  Repeater {
                      model: picker.everOpened ? picker.model : []

                      ClippingRectangle {
                          id: thumb
                          required property string modelData
                          readonly property bool isCurrent: modelData === picker.current
                          width: 136
                          height: 76
                          radius: 10
                          color: Theme.pill
                          scale: thumbMouse.pressed ? 0.94 : thumbMouse.containsMouse ? 1.03 : 1
                          Behavior on scale {
                              NumberAnimation {
                                  duration: 120
                                  easing.type: Easing.OutCubic
                              }
                          }

                          Image {
                              anchors.fill: parent
                              source: "file://" + thumb.modelData
                              sourceSize: Qt.size(272, 152)
                              fillMode: Image.PreserveAspectCrop
                              asynchronous: true
                          }
                          // green outline on the one in use (drawn over the picture)
                          Rectangle {
                              anchors.fill: parent
                              radius: 10
                              color: "transparent"
                              border.width: thumb.isCurrent ? 3 : 0
                              border.color: Theme.accent
                          }
                          MouseArea {
                              id: thumbMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: picker.picked(thumb.modelData)
                          }
                      }
                  }
              }
          }
      }
  '';
  # Lists the pictures your session copied for the login screen (see home.nix).
  environment.etc."greetd/greeter/wallpapers.sh".text = ''
    for f in /var/lib/greeter-wallpapers/*; do
      case "$f" in
        *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP) [ -f "$f" ] && echo "$f" ;;
      esac
    done
  '';
  environment.etc."greetd/greeter/shell.qml".text = ''
      // Login screen: Quickshell running inside its own little Hyprland, started by
      // greetd. Looks like your hyprlock (blurred wallpaper, big clock, green pill
      // password box). The bar at the top picks the session (desktop) and the
      // wallpaper, and has suspend / reboot / power off.
      //
      // Flow: type password, Enter -> greetd checks it -> the screen fades -> greetd
      // starts the session you picked -> this Hyprland exits.
      //
      // Keys: Enter = log in, Esc = clear / close the menus.
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
          readonly property string fallbackWallpaper: "${greeterWallpaper}"   // the hk.png from your repo
          readonly property var users: ${greeterUsers}                         // [{ name, real }]
          readonly property string stateFile: "/var/lib/greeter/last"  // remembers user, session, wallpaper
          readonly property string hyprctl: "${config.programs.hyprland.package}/bin/hyprctl"
          // Show / hide the mouse pointer, so it isn't left floating on the black screen
          // while fading in and out.
          function pointer(visible) {
              Quickshell.execDetached([hyprctl, "eval", "hl.config({ cursor = { invisible = " + !visible + " } })"]);
          }

          // ── state ──
          property var sessions: []       // [{ name, exec, desktops, id }], from the .desktop files
          property int sessionIndex: 0
          property int userIndex: 0
          readonly property var session: sessions.length > 0 ? sessions[Math.min(sessionIndex, sessions.length - 1)] : null
          readonly property var user: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : ({ "name": "", "real": "" })

          // Your ~/Pictures/Wallpapers, copied to /var/lib/greeter-wallpapers by home.nix
          // (the login screen runs as its own user and can't look inside your home).
          property var wallpapers: []     // full paths
          property string wallpaper: fallbackWallpaper

          // ── showing up only when it's ready ──
          // The screen stays black until all of these are true, then opens up from the
          // middle:
          //   1. the wallpaper is loaded (wallReady)
          //   2. Hyprland has found your keyboard (kbDevice). The login screen starts
          //      early in boot, sometimes before the keyboard has been set up; keys
          //      pressed before that never reach Hyprland at all, so nothing could
          //      catch them. Checked every 100 ms with `hyprctl devices`.
          //   3. Hyprland has given this window the keyboard (kbReady)
          //   4. a run of frames has been drawn on time (smoothFrames), so the first
          //      frames' set-up work (like the blur's shaders) is out of the way
          // So the moment you can see it, it's taking keys. Keys pressed while it's
          // still black count too, once 2 and 3 are true. If something never gets
          // ready, it shows up after 5 s anyway.
          // How long each step took is written to /var/lib/greeter/startup.log.
          property bool ready: false
          property bool wallReady: false
          property bool kbDevice: false
          property bool kbReady: false
          property int smoothFrames: 0
          property var kbNames: []          // the keyboards Hyprland reported
          readonly property double t0: Date.now()
          property var times: ({})          // step -> ms after start
          function mark(step) {
              if (times[step] !== undefined)
                  return;
              const t = times;
              t[step] = Date.now() - t0;
              times = t;
          }
          onWallReadyChanged: mark("wallpaper")
          onKbDeviceChanged: mark("keyboardFound")
          onKbReadyChanged: mark("windowGotKeyboard")

          // 2. ask Hyprland for its keyboards until a real one shows up. Things like the
          //    power button and media-key devices are listed as keyboards too, so
          //    they're skipped.
          Process {
              id: devPoll
              running: true
              command: [root.hyprctl, "devices", "-j"]
              stdout: StdioCollector {
                  onStreamFinished: {
                      let names = [];
                      try {
                          names = (JSON.parse(text).keyboards || []).map(k => k.name).filter(n => !/power-button|sleep-button|video-bus|lid-switch|pc-speaker|virtual|wmi|hotkey|consumer-control|system-control/i.test(n));
                      } catch (e) {}
                      root.kbNames = names;
                      if (names.length > 0)
                          root.kbDevice = true;
                      else
                          devRetry.start();
                  }
              }
          }
          Timer {
              id: devRetry
              interval: 100
              onTriggered: devPoll.running = true
          }
          FileView {
              id: startLog
              path: "/var/lib/greeter/startup.log"
              printErrors: false
          }
          property real introP: 0      // 0 = black, 1 = login screen fully visible
          property real outP: 0        // 0 = visible, 1 = black again (logging in)
          function markReady(why) {
              if (ready)
                  return;
              ready = true;
              mark(why === "fallback" ? "shown (gave up waiting, 5 s)" : "shown");
              startLog.setText(JSON.stringify({ "msAfterStart": times, "keyboards": kbNames }, null, 2) + "\n");
              pointer(true);           // hidden until now (see /etc/greetd/hyprland.lua)
              introAnim.start();
          }
          Timer {
              id: readyFallback
              interval: 5000
              running: true
              onTriggered: root.markReady("fallback")
          }
          NumberAnimation {
              id: introAnim
              target: root
              property: "introP"
              from: 0
              to: 1
              duration: 650
              easing.type: Easing.OutCubic
          }
          NumberAnimation {
              id: outAnim
              target: root
              property: "outP"
              from: 0
              to: 1
              duration: 700
              easing.type: Easing.InOutCubic
          }

          // "idle", "checking" (greetd is looking at the password), "failed", "launching"
          property string phase: "idle"
          property string message: ""     // shown under the box (errors, PAM messages)
          property string password: ""

          // ── awake / resting, like hyprlock ──
          // Typing or moving the mouse wakes the screen: the wallpaper blurs and darkens
          // more and the password box comes up to full strength. After a few quiet
          // seconds with nothing typed it relaxes again.
          property bool awake: true
          function wake() {
              awake = true;
              restTimer.restart();
          }
          Timer {
              id: restTimer
              interval: 6000
              running: true
              onTriggered: if (root.password === "" && root.phase === "idle")
                  root.awake = false
          }

          // One entry per typed character; the dots in the box are drawn from this,
          // so each one can fade in and out on its own.
          ListModel {
              id: dots
          }
          onPasswordChanged: {
              while (dots.count < password.length)
                  dots.append({ "n": dots.count });
              while (dots.count > password.length)
                  dots.remove(dots.count - 1);
          }

          // ── what you picked last time ──
          FileView {
              id: lastFile
              path: root.stateFile
              blockLoading: true
              printErrors: false
          }
          function saved(i) {
              return ((lastFile.text() || "").trim().split("\t"))[i] || "";
          }
          function saveLast() {
              const wall = root.wallpaper.startsWith("/var/lib/greeter-wallpapers/") ? root.wallpaper.split("/").pop() : "";
              // 4th: which theme switch this screen has already seen (Theme.stamp)
              lastFile.setText([root.user.name, root.session ? root.session.id : "", wall, Theme.stamp].join("\t") + "\n");
          }
          function restoreSession() {
              const u = root.users.findIndex(x => x.name === saved(0));
              if (u >= 0)
                  root.userIndex = u;
              let s = root.sessions.findIndex(x => x.id === saved(1));
              // nothing saved yet: prefer Hyprland under UWSM
              if (s < 0)
                  s = root.sessions.findIndex(x => x.id === "hyprland-uwsm");
              root.sessionIndex = Math.max(0, s);
          }
          function restoreWallpaper() {
              const byName = n => root.wallpapers.find(p => p.split("/").pop() === n);
              // Just switched themes in your session (a stamp this screen hasn't seen):
              // the theme's wallpaper. Otherwise the one you picked here last time, else
              // the theme's, else hk.png, else the first one, else the repo copy.
              const themeIsNew = Theme.wallpaper !== "" && Theme.stamp !== saved(3);
              root.wallpaper = (themeIsNew ? Theme.wallpaper : "") || byName(saved(2)) || Theme.wallpaper || byName("hk.png") || root.wallpapers[0] || root.fallbackWallpaper;
          }

          // ── list the installed Wayland sessions ──
          Process {
              running: true
              command: ["/bin/sh", "/etc/greetd/greeter/sessions.sh"]
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
                      root.restoreSession();
                  }
              }
          }
          // ── list the wallpapers ──
          Process {
              running: true
              command: ["/bin/sh", "/etc/greetd/greeter/wallpapers.sh"]
              stdout: StdioCollector {
                  onStreamFinished: {
                      root.wallpapers = text.split("\n").filter(p => p !== "");
                      root.restoreWallpaper();
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
                  root.pointer(false);
                  outAnim.start();
                  root.saveLast();
                  // greetd wants the greeter gone quickly once it launches, so the fade
                  // happens first and launch() comes after it.
                  launchTimer.restart();
              }
          }
          Timer {
              id: launchTimer
              interval: 750   // just after the 700 ms fade to black (outAnim)
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
                  // One string, not ["sh", "-c", ...]: greetd glues the list together
                  // with spaces and runs it through a shell itself ("exec <command>").
                  Greetd.launch([exec], env);
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
                  color: "black"   // what shows while fading in and out

                  Item {
                      id: scene
                      anchors.fill: parent

                      // moving the mouse wakes the screen (hover only, clicks pass through)
                      MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          acceptedButtons: Qt.NoButton
                          onPositionChanged: root.wake()
                      }

                      // ── wallpaper ──
                      // Two pictures stacked: a new wallpaper loads into the hidden one,
                      // then they cross-fade.
                      Item {
                          id: wallLayer
                          anchors.fill: parent
                          visible: false      // drawn through the blur below
                          property string shown: ""
                          property bool useB: false

                          function show(path) {
                              if (path === shown)
                                  return;
                              shown = path;
                              const target = useB ? wallA : wallB;
                              target.source = path !== "" ? "file://" + path : "";
                              loaded(target);
                          }
                          function loaded(img) {
                              if (img.status === Image.Ready && img.source.toString() === "file://" + shown) {
                                  useB = img === wallB;
                                  if (win.main)
                                      root.wallReady = true;
                              }
                          }
                          Component.onCompleted: show(root.wallpaper)
                          Connections {
                              target: root
                              function onWallpaperChanged() {
                                  wallLayer.show(root.wallpaper);
                              }
                          }

                          Image {
                              id: wallA
                              anchors.fill: parent
                              fillMode: Image.PreserveAspectCrop
                              // load it at screen size, not the photo's full size (less to blur)
                              sourceSize.width: width
                              sourceSize.height: height
                              asynchronous: true
                              opacity: wallLayer.useB ? 0 : 1
                              Behavior on opacity {
                                  NumberAnimation {
                                      duration: 500
                                      easing.type: Easing.InOutQuad
                                  }
                              }
                              onStatusChanged: wallLayer.loaded(wallA)
                          }
                          Image {
                              id: wallB
                              anchors.fill: parent
                              fillMode: Image.PreserveAspectCrop
                              sourceSize.width: width
                              sourceSize.height: height
                              asynchronous: true
                              opacity: wallLayer.useB ? 1 : 0
                              Behavior on opacity {
                                  NumberAnimation {
                                      duration: 500
                                      easing.type: Easing.InOutQuad
                                  }
                              }
                              onStatusChanged: wallLayer.loaded(wallB)
                          }
                      }
                      // just blurred (no darkening); a little more blur while you're typing
                      MultiEffect {
                          anchors.fill: parent
                          source: wallLayer
                          blurEnabled: true
                          blurMax: 48
                          blur: root.awake ? 1.0 : 0.45
                          Behavior on blur {
                              NumberAnimation {
                                  duration: 250
                                  easing.type: Easing.OutCubic
                              }
                          }
                          // start slightly zoomed and settle in
                          scale: root.ready ? 1.0 : 1.06
                          Behavior on scale {
                              NumberAnimation {
                                  duration: 900
                                  easing.type: Easing.OutCubic
                              }
                          }
                      }
                      Component.onCompleted: if (win.main) {
                          field.forceActiveFocus();   // takes keys from the very first frame
                          if (hasKeyboard)
                              root.kbReady = true;
                      }

                      // 3. keyboard focus: the window becomes "active" when Hyprland gives
                      //    it the keyboard
                      readonly property bool hasKeyboard: Window.active
                      onHasKeyboardChanged: if (win.main && hasKeyboard)
                          root.kbReady = true
                      // 4. smooth frames: once 1-3 are done, count frames drawn in under
                      //    25 ms in a row; 8 of them and it opens up
                      FrameAnimation {
                          running: win.main && !root.ready && root.wallReady && root.kbDevice && root.kbReady
                          onTriggered: {
                              root.smoothFrames = frameTime > 0 && frameTime < 0.025 ? root.smoothFrames + 1 : 0;
                              if (root.smoothFrames >= 8)
                                  root.markReady();
                          }
                      }

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
                          // soft shadow, so it stays readable on a bright wallpaper
                          layer.enabled: true
                          layer.effect: MultiEffect {
                              shadowEnabled: true
                              shadowBlur: 0.6
                              shadowOpacity: 0.55
                              shadowVerticalOffset: 2
                          }
                      }
                      Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.bottom: clockText.top
                          text: Qt.formatDate(clock.date, "dddd, MMMM d")
                          color: Theme.text
                          opacity: 0.85
                          font.family: Theme.font
                          font.pixelSize: 15
                          // soft shadow, so it stays readable on a bright wallpaper
                          layer.enabled: true
                          layer.effect: MultiEffect {
                              shadowEnabled: true
                              shadowBlur: 0.6
                              shadowOpacity: 0.55
                              shadowVerticalOffset: 2
                          }
                      }

                      // ── password box: 200 x 50 pill, 20 px below the middle ──
                      Item {
                          id: loginBox
                          visible: win.main
                          // grows when the dots don't fit, like hyprlock
                          width: Math.max(200, dots.count * 18 + 56)
                          height: 50
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.verticalCenterOffset: 20
                          // dimmer while resting with nothing typed
                          opacity: root.awake || root.password !== "" ? 1 : 0.55
                          Behavior on opacity {
                              NumberAnimation {
                                  duration: 180
                                  easing.type: Easing.OutCubic
                              }
                          }
                          Behavior on width {
                              NumberAnimation {
                                  duration: 180
                                  easing.type: Easing.OutCubic
                              }
                          }

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
                              border.color: root.phase === "checking" ? Theme.yellow : root.phase === "failed" ? Theme.red : Theme.accent
                              Behavior on border.color {
                                  ColorAnimation {
                                      duration: 200
                                  }
                              }
                          }

                          // The hint inside the box (hyprlock's italic placeholder); fades
                          // out as you start typing and back in when the box is empty.
                          Text {
                              anchors.centerIn: parent
                              opacity: dots.count > 0 ? 0 : root.phase === "failed" ? 1 : 0.5
                              text: root.phase === "failed" ? root.message : "Input Password..."
                              color: root.phase === "failed" ? Theme.red : Theme.text
                              font.family: Theme.font
                              font.pixelSize: 14
                              font.italic: true
                              elide: Text.ElideRight
                              width: Math.min(implicitWidth, parent.width - 32)
                              Behavior on opacity {
                                  NumberAnimation {
                                      duration: 150
                                  }
                              }
                          }

                          // The dots. Each one pops in when you type and fades out when
                          // you delete it; the row slides to stay centred.
                          ListView {
                              id: dotsView
                              y: (parent.height - height) / 2
                              x: (parent.width - width) / 2
                              width: Math.max(1, dots.count * 18 - 8)
                              height: 10
                              orientation: ListView.Horizontal
                              interactive: false
                              spacing: 8
                              model: dots
                              Behavior on x {
                                  NumberAnimation {
                                      duration: 160
                                      easing.type: Easing.OutCubic
                                  }
                              }
                              delegate: Rectangle {
                                  width: 10
                                  height: 10
                                  radius: 5
                                  color: root.phase === "checking" ? Theme.yellow : Theme.text
                                  Behavior on color {
                                      ColorAnimation {
                                          duration: 200
                                      }
                                  }
                              }
                              add: Transition {
                                  NumberAnimation {
                                      property: "opacity"
                                      from: 0
                                      to: 1
                                      duration: 160
                                  }
                                  NumberAnimation {
                                      property: "scale"
                                      from: 0.2
                                      to: 1
                                      duration: 220
                                      easing.type: Easing.OutBack
                                  }
                              }
                              remove: Transition {
                                  NumberAnimation {
                                      property: "opacity"
                                      to: 0
                                      duration: 140
                                  }
                                  NumberAnimation {
                                      property: "scale"
                                      to: 0.2
                                      duration: 140
                                  }
                              }
                          }

                          // The real (invisible) text box that takes the keys.
                          TextField {
                              id: field
                              anchors.fill: parent
                              anchors.leftMargin: 16
                              anchors.rightMargin: 16
                              background: null
                              focus: win.main
                              enabled: root.phase !== "launching"
                              echoMode: TextInput.Password
                              color: "transparent"
                              selectByMouse: false
                              cursorDelegate: Item {}   // no text cursor, like hyprlock
                              text: root.password
                              onTextEdited: {
                                  root.password = text;
                                  if (root.phase !== "checking")
                                      root.message = "";   // typing again clears the old error
                              }
                              onAccepted: root.login()
                              Keys.onPressed: event => {
                                  root.wake();
                                  event.accepted = false;   // let the box handle the key too
                              }
                              Keys.onEscapePressed: {
                                  if (sessionMenu.open || userMenu.open || wallMenu.open) {
                                      sessionMenu.open = false;
                                      userMenu.open = false;
                                      wallMenu.open = false;
                                  } else {
                                      root.password = "";
                                  }
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
                          opacity: loginBox.opacity * 0.9
                          font.family: Theme.font
                          font.pixelSize: 14
                          // soft shadow, so it stays readable on a bright wallpaper
                          layer.enabled: true
                          layer.effect: MultiEffect {
                              shadowEnabled: true
                              shadowBlur: 0.6
                              shadowOpacity: 0.55
                              shadowVerticalOffset: 2
                          }
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

                          function only(menu) {
                              for (const m of [sessionMenu, userMenu, wallMenu])
                                  m.open = m === menu ? !m.open : false;
                              root.wake();
                          }

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
                                  onClicked: topBar.only(sessionMenu)
                              }
                              // user picker, only when there's more than one account
                              BarChip {
                                  visible: root.users.length > 1
                                  icon: "person"
                                  label: root.user.name
                                  trailing: userMenu.open ? "expand_less" : "expand_more"
                                  active: userMenu.open
                                  onClicked: topBar.only(userMenu)
                              }
                              // wallpaper picker, once your wallpapers have been copied over
                              BarChip {
                                  visible: root.wallpapers.length > 0
                                  icon: "wallpaper"
                                  active: wallMenu.open
                                  onClicked: topBar.only(wallMenu)
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
                                  onClicked: {
                                      root.pointer(false);
                                      Quickshell.execDetached(["systemctl", "reboot"]);
                                  }
                              }
                              BarChip {
                                  icon: "power_settings_new"
                                  iconColor: Theme.red
                                  onClicked: {
                                      root.pointer(false);
                                      Quickshell.execDetached(["systemctl", "poweroff"]);
                                  }
                              }
                          }
                      }

                      // ── drop-downs under the bar ──
                      DropList {
                          id: sessionMenu
                          anchor: topBar
                          model: root.sessions
                          current: root.sessionIndex
                          labelOf: s => s.name
                          onPicked: i => {
                              root.sessionIndex = i;
                              open = false;
                              root.saveLast();
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
                              root.saveLast();
                              field.forceActiveFocus();
                          }
                      }
                      WallPicker {
                          id: wallMenu
                          anchor: topBar
                          model: root.wallpapers
                          current: root.wallpaper
                          onPicked: path => {
                              root.wallpaper = path;
                              root.saveLast();
                              field.forceActiveFocus();
                          }
                      }
                  }

                  // Opening up from the middle when it appears, and closing to black from
                  // the middle when you log in (CenterFade.qml). Your desktop then opens
                  // up from the middle too (home.nix).
                  CenterFade {
                      anchors.fill: parent
                      mode: root.phase === "launching" ? "cover" : "reveal"
                      progress: root.phase === "launching" ? root.outP : root.introP
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

  # Firmware for the Wi-Fi/Bluetooth chip (and other devices). The generated
  # hardware-configuration.nix usually turns this on already; set here so it's certain.
  hardware.enableRedistributableFirmware = true;

  # ── Bluetooth firmware for the board's MediaTek MT7927 (ROG Strix X870E-E) ──
  # The kernel driver is there (Linux 7.1+), but its firmware file,
  # mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin, isn't in linux-firmware (only the
  # Wi-Fi files are), so without this the chip just resets over and over. It's pulled out
  # of ASUS's own Wi-Fi/Bluetooth driver ZIP, the way the mediatek-mt7927-dkms package
  # does it (the `mt7927-dkms` input in flake.nix).
  #
  # Updates: which ASUS driver release to use (file name + SHA-256) and the extractor
  # script both come from that repo, so `nix flake update` moves to whatever release it
  # uses next. Nix still only accepts a ZIP that matches the hash the repo lists.
  # Once linux-firmware ships this file, delete this block (and the flake input).
  hardware.firmware =
    let
      dkms = inputs.mt7927-dkms;
      # "_driver_filename='...'" and "_driver_sha256='...'" from the repo's PKGBUILD
      pkgbuildLines = builtins.filter builtins.isString (builtins.split "\n" (builtins.readFile "${dkms}/PKGBUILD"));
      pkgbuildValue =
        key:
        let
          found = builtins.filter (m: m != null) (map (l: builtins.match "${key}='([^']+)'" l) pkgbuildLines);
        in
        if found == [ ] then
          throw "mt7927 firmware: ${key} not found in mediatek-mt7927-dkms's PKGBUILD (format changed?)"
        else
          builtins.head (builtins.head found);
      driverZipName = pkgbuildValue "_driver_filename";

      # Download the ZIP. ASUS serves it at a plain address; if that ever stops working,
      # it falls back to ASUS's signed-link service (what the repo's download-driver.sh
      # does). This is a fixed-output build: it may use the network because its result
      # must match the hash, like fetchurl.
      asusDriverZip =
        pkgs.runCommand driverZipName
          {
            nativeBuildInputs = [
              pkgs.curl
              pkgs.jq
            ];
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            outputHashMode = "flat";
            outputHashAlgo = "sha256";
            outputHash = pkgbuildValue "_driver_sha256";
          }
          ''
            file=${driverZipName}
            path="https://dlcdnets.asus.com/pub/ASUS/mb/08WIRELESS/$file"
            if ! curl -sSfL -o "$out" "$path"; then
              echo "plain download failed, asking ASUS for a signed link" >&2
              json=$(curl -sSf -X POST -H 'Origin: https://rog.asus.com' \
                "https://cdnta.asus.com/api/v1/TokenHQ?filePath=https:%2F%2Fdlcdnta.asus.com%2Fpub%2FASUS%2Fmb%2F08WIRELESS%2F$file%3Fmodel%3DROG%2520CROSSHAIR%2520X870E%2520HERO&systemCode=rog")
              field() { echo "$json" | jq -r "[.. | .$1? // empty] | first"; }
              curl -sSfL -o "$out" \
                "https://dlcdnta.asus.com/pub/ASUS/mb/08WIRELESS/$file?model=ROG%20CROSSHAIR%20X870E%20HERO&Signature=$(field signature)&Expires=$(field expires)&Key-Pair-Id=$(field keyPairId)"
            fi
          '';
    in
    [
      (pkgs.stdenvNoCC.mkDerivation {
        pname = "mt7927-bt-firmware";
        version = builtins.substring 0 8 (dkms.rev or "unknown");
        src = asusDriverZip;
        nativeBuildInputs = [ pkgs.python3 ];
        dontUnpack = true;
        installPhase = ''
          python3 ${dkms}/extract_firmware.py $src fw --bluetooth-only
          install -Dm644 fw/BT_RAM_CODE_MT6639_2_1_hdr.bin \
            $out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin
        '';
      })
    ];

  # ── Bluetooth ──
  # BlueZ, which the bar's Bluetooth widget talks to (Quickshell.Bluetooth uses BlueZ over D-Bus).
  # If it doesn't show up: BIOS → Advanced → Onboard Devices Configuration → Bluetooth
  # Controller = Enabled, then check `rfkill list` and `bluetoothctl show`.
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
