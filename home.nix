{
  config,
  pkgs,
  lib,
  inputs,
  # the NixOS config (configuration.nix), from home-manager's NixOS module
  osConfig ? null,
  ...
}:

let
  # Used by the wallpaper and bar services: wait (up to 2 s) until the login fade-in
  # (fade.qml) has covered the screen. %t is XDG_RUNTIME_DIR.
  waitForFade = "${pkgs.writeShellScript "wait-for-fade" ''
    for _ in $(${pkgs.coreutils}/bin/seq 40); do
      [ -e "$1/desktop-fade-up-$HYPRLAND_INSTANCE_SIGNATURE" ] && exit 0
      ${pkgs.coreutils}/bin/sleep 0.05
    done
    exit 0
  ''} %t";

  # ── The color themes ──
  # Every part of the desktop with colors in it reads them from here: the bar
  # (Quickshell), kitty, rofi, GTK and Qt apps, the mouse cursor, and the login and
  # lock screens (configuration.nix reads this as my.themes, see "Themes" near the
  # end of this file).
  #
  # All of them get built, and the theme button on the bar (or `theme <id>` in a
  # terminal) picks which one is showing. "Themes" near the end explains how.
  #
  # To add a theme: copy one of the blocks below, give it a new id, change what's in
  # it, and add the id to `order`.
  themes =
    let
      # Rosé Pine for GTK isn't in nixpkgs. It comes from the rose-pine-gtk flake input
      # (rose-pine/gtk on GitHub, updated with `nix flake update`).
      #  - GTK 3: the theme folder, with one fix. Its "dark" variant (gtk-dark.css) has
      #    the colors flipped to light (rose-pine/gtk's README warns about it), and GTK
      #    uses that variant whenever an app or the desktop asks for dark, which is
      #    always here. So the dark variant is made the same as the normal (dark) one,
      #    in both gtk-3.0 and gtk-3.20 (GTK 3.24 reads gtk-3.20).
      #  - GTK 4: the repo has one .css per variant, but it's only colors for libadwaita
      #    apps, not a whole theme. So it's kept outside the theme folder (in
      #    share/rose-pine-gtk4) and only loaded through your gtk.css (gtk4Css below).
      #    As the theme's gtk-4.0 it would strip plain GTK 4 apps of their styling.
      rosePineGtk = pkgs.runCommand "rose-pine-gtk-theme" { } ''
        mkdir -p $out/share/themes $out/share/rose-pine-gtk4
        cp -r ${inputs.rose-pine-gtk}/gtk3/rose-pine-gtk $out/share/themes/
        chmod -R u+w $out/share/themes/rose-pine-gtk
        for d in gtk-3.0 gtk-3.20; do
          cp $out/share/themes/rose-pine-gtk/$d/gtk.css $out/share/themes/rose-pine-gtk/$d/gtk-dark.css
        done
        cp ${inputs.rose-pine-gtk}/gtk4/rose-pine.css $out/share/rose-pine-gtk4/gtk.css
      '';
      # Everblush's GTK theme isn't in nixpkgs either. It comes from the everblush-gtk
      # flake input (Everblush/gtk on GitHub). The repo has the finished GTK 3 and
      # GTK 2 themes in it, so they're copied in as they are, with the pictures they
      # use (assets/, which gtk-3.0/gtk.css finds at ../assets). (Its own default.nix
      # builds from a gtk-3.0/gtk.scss that the repo doesn't have, so it isn't used.)
      # There's no GTK 4 version, so everblushGtk4 below gives libadwaita apps the
      # colors.
      everblushGtk = pkgs.runCommand "everblush-gtk-theme" { } ''
        mkdir -p $out/share/themes/Everblush
        cp -r ${inputs.everblush-gtk}/{gtk-2.0,gtk-3.0,assets,index.theme} $out/share/themes/Everblush/
      '';
      # libadwaita's named colors, in Everblush's colors (my own file, in the same
      # shape as Rosé Pine's GTK 4 one)
      everblushGtk4 = pkgs.writeText "everblush-gtk4.css" ''
        @define-color accent_bg_color #67b0e8;
        @define-color accent_fg_color #141b1e;
        @define-color accent_color #67b0e8;
        @define-color destructive_bg_color #e57474;
        @define-color destructive_fg_color #141b1e;
        @define-color destructive_color #e57474;
        @define-color success_bg_color #8ccf7e;
        @define-color success_fg_color #141b1e;
        @define-color success_color #8ccf7e;
        @define-color warning_bg_color #e5c76b;
        @define-color warning_fg_color #141b1e;
        @define-color warning_color #e5c76b;
        @define-color error_bg_color #e57474;
        @define-color error_fg_color #141b1e;
        @define-color error_color #e57474;
        @define-color window_bg_color #141b1e;
        @define-color window_fg_color #dadada;
        @define-color view_bg_color #161d1f;
        @define-color view_fg_color #dadada;
        @define-color headerbar_bg_color #141b1e;
        @define-color headerbar_fg_color #dadada;
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color headerbar_shade_color #141b1e;
        @define-color card_bg_color #232a2d;
        @define-color card_fg_color #dadada;
        @define-color card_shade_color #141b1e;
        @define-color popover_bg_color #232a2d;
        @define-color popover_fg_color #dadada;
        @define-color dialog_bg_color #232a2d;
        @define-color dialog_fg_color #dadada;
        @define-color sidebar_bg_color #161d1f;
        @define-color sidebar_fg_color #dadada;
        @define-color sidebar_backdrop_color #161d1f;
      '';
      # one build for Tokyo Night's GTK theme and its icons
      tokyonightGtk = pkgs.tokyonight-gtk-theme.override {
        colorVariants = [ "dark" ];
        iconVariants = [ "Dark" ];
      };
    in
    {
      # The theme you get until you pick one (and if the one you picked is ever removed).
      default = "everforest";

      # Order in the bar's theme list.
      order = [
        "catppuccin-mocha"
        "everforest"
        "rose-pine"
        "gruvbox"
        "tokyo-night"
        "everblush"
      ];

      # Each theme:
      #   name, variant   what the theme list shows
      #   colors          6-digit hex, no "#". By what they're used for:
      #     bg            the bar, popups, terminal and window backgrounds
      #     bgDim         darker than bg (shadows, Qt's "Dark")
      #     surface       text fields, the login screen's password box
      #     overlay       pills, hovered rows, buttons
      #     midlight, light   lighter steps above overlay (Qt bevels)
      #     dim           dimmed icons (muted volume, idle search box border)
      #     border        inactive window border
      #     fg, fgBright  text
      #     subtle, placeholder, disabled   quieter text, from brighter to dimmer
      #     red orange yellow green cyan blue magenta   the named colors
      #     accent        selected / active things: chips, open tabs, the active border
      #     link, linkVisited
      #   gtk, icons, cursor   { name, package } for GTK apps and the mouse pointer
      #   gtk4Css         (optional) the .css your GTK 4 gtk.css imports. Normally the
      #                   theme's own gtk-4.0/gtk.css; Rosé Pine keeps its elsewhere
      #   kitty           the terminal's colors, as published by the theme's authors
      themes = {
        # catppuccin.com, catppuccin/palette
        catppuccin-mocha = {
          name = "Catppuccin";
          variant = "Mocha";
          colors = {
            bg = "1e1e2e"; # base
            bgDim = "11111b"; # crust
            surface = "181825"; # mantle
            overlay = "313244"; # surface0
            midlight = "45475a"; # surface1
            light = "585b70"; # surface2
            dim = "585b70"; # surface2
            border = "45475a"; # surface1
            fg = "cdd6f4"; # text
            fgBright = "cdd6f4"; # text
            subtle = "a6adc8"; # subtext0
            placeholder = "7f849c"; # overlay1
            disabled = "6c7086"; # overlay0
            red = "f38ba8";
            orange = "fab387"; # peach
            yellow = "f9e2af";
            green = "a6e3a1";
            cyan = "94e2d5"; # teal
            blue = "89b4fa";
            magenta = "cba6f7"; # mauve
            accent = "cba6f7"; # mauve
            link = "89b4fa";
            linkVisited = "cba6f7";
          };
          gtk = {
            # nixpkgs patches the "+default" off the end of the name upstream builds
            name = "catppuccin-mocha-mauve-standard";
            package = pkgs.catppuccin-gtk.override {
              variant = "mocha";
              accents = [ "mauve" ];
            };
          };
          icons = {
            name = "Papirus-Dark"; # Papirus with Catppuccin-colored folders
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "mocha";
              accent = "mauve";
            };
          };
          cursor = {
            name = "catppuccin-mocha-dark-cursors";
            package = pkgs.catppuccin-cursors.mochaDark;
          };
          # catppuccin/kitty, themes/mocha.conf
          kitty = ''
            foreground #cdd6f4
            background #1e1e2e
            selection_foreground #1e1e2e
            selection_background #f5e0dc
            cursor #f5e0dc
            cursor_text_color #1e1e2e
            scrollbar_handle_color #9399b2
            scrollbar_track_color #45475a
            url_color #f5e0dc
            active_border_color #b4befe
            inactive_border_color #6c7086
            bell_border_color #f9e2af
            active_tab_foreground #11111b
            active_tab_background #cba6f7
            inactive_tab_foreground #cdd6f4
            inactive_tab_background #181825
            tab_bar_background #11111b
            mark1_foreground #1e1e2e
            mark1_background #b4befe
            mark2_foreground #1e1e2e
            mark2_background #cba6f7
            mark3_foreground #1e1e2e
            mark3_background #74c7ec
            color0 #45475a
            color8 #585b70
            color1 #f38ba8
            color9 #f38ba8
            color2 #a6e3a1
            color10 #a6e3a1
            color3 #f9e2af
            color11 #f9e2af
            color4 #89b4fa
            color12 #89b4fa
            color5 #f5c2e7
            color13 #f5c2e7
            color6 #94e2d5
            color14 #94e2d5
            color7 #bac2de
            color15 #a6adc8
          '';
        };

        # sainnhe/everforest, dark, "hard" contrast
        everforest = {
          name = "Everforest";
          variant = "Dark Hard";
          colors = {
            bg = "272e33"; # bg0
            bgDim = "1e2326"; # bg_dim
            surface = "2e383c"; # bg1
            overlay = "374145"; # bg2
            midlight = "414b50"; # bg3
            light = "495156"; # bg4
            dim = "4f5b58"; # bg5
            border = "4f5b58"; # bg5
            fg = "d3c6aa";
            fgBright = "e6e2cc";
            subtle = "9da9a0"; # grey2
            placeholder = "859289"; # grey1
            disabled = "7a8478"; # grey0
            red = "e67e80";
            orange = "e69875";
            yellow = "dbbc7f";
            green = "a7c080";
            cyan = "83c092"; # aqua
            blue = "7fbbb3";
            magenta = "d699b6"; # purple
            accent = "a7c080"; # green
            link = "7fbbb3";
            linkVisited = "d699b6";
          };
          gtk = {
            name = "Everforest-Green-Dark";
            package = pkgs.everforest-gtk-theme;
          };
          icons = {
            name = "Everforest-Dark";
            package = pkgs.everforest-gtk-theme;
          };
          cursor = {
            name = "everforest-cursors";
            package = pkgs.everforest-cursors;
          };
          # kovidgoyal/kitty-themes, everforest_dark_hard.conf
          kitty = ''
            foreground #d3c6aa
            background #272e33
            selection_foreground #9da9a0
            selection_background #464e53
            cursor #d3c6aa
            cursor_text_color #2e383c
            url_color #7fbbb3
            active_border_color #a7c080
            inactive_border_color #4f5b58
            bell_border_color #e69875
            visual_bell_color none
            active_tab_background #272e33
            active_tab_foreground #d3c6aa
            inactive_tab_background #374145
            inactive_tab_foreground #9da9a0
            tab_bar_background #2e383c
            tab_bar_margin_color none
            mark1_foreground #272e33
            mark1_background #7fbbb3
            mark2_foreground #272e33
            mark2_background #d3c6aa
            mark3_foreground #272e33
            mark3_background #d699b6
            color0 #343f44
            color8 #868d80
            color1 #e67e80
            color9 #e67e80
            color2 #a7c080
            color10 #a7c080
            color3 #dbbc7f
            color11 #dbbc7f
            color4 #7fbbb3
            color12 #7fbbb3
            color5 #d699b6
            color13 #d699b6
            color6 #83c092
            color14 #83c092
            color7 #859289
            color15 #9da9a0
          '';
        };

        # rosepinetheme.com, main variant
        rose-pine = {
          name = "Rosé Pine";
          variant = "Main";
          colors = {
            bg = "191724"; # base
            bgDim = "191724"; # base (Rosé Pine has nothing darker)
            surface = "1f1d2e"; # surface
            overlay = "26233a"; # overlay
            midlight = "403d52"; # highlight med
            light = "524f67"; # highlight high
            dim = "524f67"; # highlight high
            border = "403d52"; # highlight med
            fg = "e0def4"; # text
            fgBright = "e0def4";
            subtle = "908caa"; # subtle
            placeholder = "6e6a86"; # muted
            disabled = "6e6a86"; # muted
            red = "eb6f92"; # love
            orange = "ebbcba"; # rose
            yellow = "f6c177"; # gold
            # Rosé Pine has 6 colors for these 7 names. Pine (its "green") is a dark teal
            # that's hard to read as text on the bar, so green and cyan are both foam,
            # and pine is blue.
            green = "9ccfd8"; # foam
            cyan = "9ccfd8"; # foam
            blue = "31748f"; # pine
            magenta = "c4a7e7"; # iris
            accent = "c4a7e7"; # iris
            link = "9ccfd8"; # foam
            linkVisited = "c4a7e7"; # iris
          };
          gtk = {
            name = "rose-pine-gtk";
            package = rosePineGtk;
          };
          icons = {
            name = "rose-pine";
            package = pkgs.rose-pine-icon-theme;
          };
          cursor = {
            name = "BreezeX-RosePine-Linux";
            package = pkgs.rose-pine-cursor;
          };
          gtk4Css = "${rosePineGtk}/share/rose-pine-gtk4/gtk.css";
          # rose-pine/kitty, dist/rose-pine.conf
          kitty = ''
            foreground #e0def4
            background #191724
            selection_foreground #e0def4
            selection_background #403d52
            cursor #524f67
            cursor_text_color #e0def4
            url_color #c4a7e7
            active_tab_foreground #e0def4
            active_tab_background #26233a
            inactive_tab_foreground #6e6a86
            inactive_tab_background #191724
            active_border_color #31748f
            inactive_border_color #403d52
            color0 #26233a
            color8 #6e6a86
            color1 #eb6f92
            color9 #eb6f92
            color2 #31748f
            color10 #31748f
            color3 #f6c177
            color11 #f6c177
            color4 #9ccfd8
            color12 #9ccfd8
            color5 #c4a7e7
            color13 #c4a7e7
            color6 #ebbcba
            color14 #ebbcba
            color7 #e0def4
            color15 #e0def4
          '';
        };

        # morhetz/gruvbox, dark, "hard" contrast
        gruvbox = {
          name = "Gruvbox";
          variant = "Dark Hard";
          colors = {
            bg = "1d2021"; # dark0_hard
            bgDim = "1d2021";
            surface = "282828"; # dark0
            overlay = "3c3836"; # dark1
            midlight = "504945"; # dark2
            light = "665c54"; # dark3
            dim = "665c54"; # dark3
            border = "504945"; # dark2
            fg = "ebdbb2"; # light1
            fgBright = "fbf1c7"; # light0
            subtle = "a89984"; # light4
            placeholder = "928374"; # gray
            disabled = "7c6f64"; # dark4
            red = "fb4934"; # bright_red
            orange = "fe8019"; # bright_orange
            yellow = "fabd2f"; # bright_yellow
            green = "b8bb26"; # bright_green
            cyan = "8ec07c"; # bright_aqua
            blue = "83a598"; # bright_blue
            magenta = "d3869b"; # bright_purple
            accent = "fe8019"; # bright_orange
            link = "83a598";
            linkVisited = "d3869b";
          };
          gtk = {
            name = "Gruvbox-Dark";
            package = pkgs.gruvbox-gtk-theme.override { colorVariants = [ "dark" ]; };
          };
          icons = {
            name = "Gruvbox-Plus-Dark";
            package = pkgs.gruvbox-plus-icons;
          };
          cursor = {
            name = "Capitaine Cursors (Gruvbox)";
            package = pkgs.capitaine-cursors-themed;
          };
          # kovidgoyal/kitty-themes, gruvbox-dark-hard.conf
          kitty = ''
            selection_foreground #ebdbb2
            selection_background #d65d0e
            background #1d2021
            foreground #ebdbb2
            color0 #3c3836
            color1 #cc241d
            color2 #98971a
            color3 #d79921
            color4 #458588
            color5 #b16286
            color6 #689d6a
            color7 #a89984
            color8 #928374
            color9 #fb4934
            color10 #b8bb26
            color11 #fabd2f
            color12 #83a598
            color13 #d3869b
            color14 #8ec07c
            color15 #fbf1c7
            cursor #bdae93
            cursor_text_color #665c54
            url_color #458588
            active_tab_foreground #eeeeee
            active_tab_background #d65d0e
            inactive_tab_foreground #ebdbb2
            inactive_tab_background #171a1a
          '';
        };

        # folke/tokyonight.nvim, "night" style
        tokyo-night = {
          name = "Tokyo Night";
          variant = "Night";
          colors = {
            bg = "1a1b26"; # bg
            bgDim = "16161e"; # bg_dark
            surface = "16161e"; # bg_dark
            overlay = "292e42"; # bg_highlight
            midlight = "3b4261"; # fg_gutter
            light = "414868"; # terminal_black
            dim = "545c7e"; # dark3
            border = "3b4261"; # fg_gutter
            fg = "c0caf5";
            fgBright = "c0caf5";
            subtle = "a9b1d6"; # fg_dark
            placeholder = "565f89"; # comment
            disabled = "545c7e"; # dark3
            red = "f7768e";
            orange = "ff9e64";
            yellow = "e0af68";
            green = "9ece6a";
            cyan = "7dcfff";
            blue = "7aa2f7";
            magenta = "bb9af7";
            accent = "7aa2f7"; # blue
            link = "7aa2f7";
            linkVisited = "bb9af7";
          };
          gtk = {
            name = "Tokyonight-Dark";
            package = tokyonightGtk;
          };
          icons = {
            name = "Tokyonight-Dark";
            package = tokyonightGtk;
          };
          cursor = {
            # no Tokyo Night cursor exists; Palenight is the closest of the Capitaine set
            name = "Capitaine Cursors (Palenight)";
            package = pkgs.capitaine-cursors-themed;
          };
          # folke/tokyonight.nvim, extras/kitty/tokyonight_night.conf
          kitty = ''
            background #1a1b26
            foreground #c0caf5
            selection_background #283457
            selection_foreground #c0caf5
            url_color #73daca
            cursor #c0caf5
            cursor_text_color #1a1b26
            active_tab_background #7aa2f7
            active_tab_foreground #16161e
            inactive_tab_background #292e42
            inactive_tab_foreground #545c7e
            active_border_color #7aa2f7
            inactive_border_color #292e42
            color0 #15161e
            color1 #f7768e
            color2 #9ece6a
            color3 #e0af68
            color4 #7aa2f7
            color5 #bb9af7
            color6 #7dcfff
            color7 #a9b1d6
            color8 #414868
            color9 #ff899d
            color10 #9fe044
            color11 #faba4a
            color12 #8db0ff
            color13 #c7a9ff
            color14 #a4daff
            color15 #c0caf5
            color16 #ff9e64
            color17 #db4b4b
          '';
        };

        # Everblush/everblush (the palette), Everblush/everblush.nvim (palette.lua)
        everblush = {
          name = "Everblush";
          variant = "Dark";
          colors = {
            bg = "141b1e"; # background
            bgDim = "141b1e"; # (nothing darker in the palette)
            surface = "161d1f"; # contrast
            overlay = "232a2d"; # lighter background (color0)
            midlight = "2d3437"; # color8
            light = "404749"; # comment
            dim = "404749"; # comment
            border = "2d3437"; # color8
            fg = "dadada"; # foreground
            fgBright = "dadada";
            subtle = "b3b9b8"; # light gray (color7)
            # Everblush has no steps between light gray and comment, or an orange,
            # so these three are blends of its colors (not from the palette):
            placeholder = "7a8080"; # halfway from light gray to comment
            disabled = "5d6365"; # three quarters of the way
            orange = "e59d6f"; # halfway from red to yellow
            red = "e57474";
            yellow = "e5c76b";
            green = "8ccf7e";
            cyan = "6cbfbf";
            blue = "67b0e8";
            magenta = "c47fd5";
            accent = "67b0e8"; # blue
            link = "67b0e8";
            linkVisited = "c47fd5";
          };
          gtk = {
            name = "Everblush";
            package = everblushGtk;
          };
          gtk4Css = "${everblushGtk4}";
          icons = {
            # No Everblush icons exist. Tela's standard dark one: blue folders (#5294e2),
            # close to the accent. (Not Papirus: every theme's icons are installed side
            # by side, and Catppuccin's are already a Papirus with the same folder
            # names, so two can't both be there.)
            name = "Tela-dark";
            package = pkgs.tela-icon-theme;
          };
          cursor = {
            # no Everblush cursor exists either; Nord's cool grey-blue is the closest
            # of the Capitaine set
            name = "Capitaine Cursors (Nord)";
            package = pkgs.capitaine-cursors-themed;
          };
          # The 16 colors from Gogh's Everblush (by Everblush's author, Mangeshrex);
          # the cursor, selection and tab colors are my picks from the palette.
          kitty = ''
            background #141b1e
            foreground #dadada
            cursor #dadada
            cursor_text_color #141b1e
            selection_foreground #dadada
            selection_background #2d3437
            url_color #67b0e8
            active_border_color #67b0e8
            inactive_border_color #232a2d
            active_tab_foreground #141b1e
            active_tab_background #67b0e8
            inactive_tab_foreground #b3b9b8
            inactive_tab_background #232a2d
            tab_bar_background #141b1e
            color0 #232a2d
            color1 #e57474
            color2 #8ccf7e
            color3 #e5c76b
            color4 #67b0e8
            color5 #c47fd5
            color6 #6cbfbf
            color7 #b3b9b8
            color8 #2d3437
            color9 #ef7e7e
            color10 #96d988
            color11 #f4d67a
            color12 #71baf2
            color13 #ce89df
            color14 #67cbe7
            color15 #bdc3c2
          '';
        };
      };
    };

  # ── Themes ──
  # The themes themselves (colors, GTK/icon/cursor packages, kitty colors) are
  # above. Here every theme gets one folder in the Nix store with its file for
  # each app, and ~/.local/state/theme/current points at the folder of the theme
  # you picked. The apps read their colors through that link, so switching themes
  # is just pointing it somewhere else. See "Themes" near the end of this file.
  themeState = "${config.home.homeDirectory}/.local/state/theme";
  themeCmd = "${themeSwitch}/bin/theme";

  # `lock`: the lock screen. It lives with the login screen in /etc/greetd/greeter
  # (lock.qml in configuration.nix) and looks the same, because it's built from the
  # same pieces. -n: if it's already locked, don't start a second one.
  lockCmd = pkgs.writeShellScriptBin "lock" ''
    exec ${config.programs.quickshell.package}/bin/quickshell -n -p /etc/greetd/greeter/lock.qml "$@"
  '';

  # ── UI sounds ──
  # KDE's Ocean sound theme (Plasma 6's default), as one flat folder of .oga files.
  # Sounds.qml plays them by name. Ocean has no sounds under a few of the names the
  # shell uses, so those play one of its others (oceanStandIns). The build stops here
  # if a sound the shell uses ever goes missing from the theme.
  #   the shell's name = Ocean's file it plays
  oceanStandIns = {
    "system-ready" = "desktop-login";              # logging in
    "system-shutdown" = "desktop-logout";          # log out / restart / power off
    "software-update-urgent" = "message-attention"; # a critical notification
    "power-unplug-battery-low" = "battery-low";    # unplugged while it's low
  };
  uiSounds = pkgs.runCommand "ui-sounds" { } ''
    mkdir -p $out
    for f in ${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo/*.oga; do
      ln -s "$f" "$out/$(basename "$f")"
    done
    stand_in() {
      test -e "$out/$1.oga" && return 0    # Ocean has its own after all: keep it
      test -e "$out/$2.oga" || { echo "ui-sounds: $2 is missing from the Ocean sound theme" >&2; exit 1; }
      ln -s "$(readlink "$out/$2.oga")" "$out/$1.oga"
    }
    ${lib.concatStrings (lib.mapAttrsToList (name: file: "stand_in ${name} ${file}\n") oceanStandIns)}
    for s in message-new-instant software-update-urgent device-added device-removed \
             system-ready system-shutdown alarm-clock-elapsed bell \
             battery-low battery-caution battery-full power-plug power-unplug power-unplug-battery-low; do
      test -e "$out/$s.oga" || { echo "ui-sounds: $s is missing from the Ocean sound theme" >&2; exit 1; }
    done
  '';

  # After waking from suspend: screens on, then give the keyboard back to the lock
  # screen. Hyprland hands the keyboard to the lock screen when the mouse moves
  # (InputManager.cpp), so this "moves" the cursor to where it already is, which
  # counts as a move. Done again a second later in case the monitor came back late
  # (NVIDIA can take a moment) and the lock screen made a new window for it.
  wakeCmd = pkgs.writeShellApplication {
    name = "after-wake";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null || true
      nudge() {
        local pos x y
        pos=$(hyprctl cursorpos 2>/dev/null) || return 0   # "960, 540"
        x=''${pos%%,*}
        y=''${pos##*, }
        hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })" >/dev/null || true
      }
      nudge
      sleep 1
      nudge
    '';
  };

  # ── Wallpaper animation ──
  # How awww changes the wallpaper: when you switch themes, and at login. The theme
  # command and the awww service both use these, and they're in your session's
  # environment too, so `awww img <picture>` in a terminal animates the same way.
  # AWWW_TRANSITION can be: simple fade left right top bottom wipe wave grow center
  # any outer random none (`man awww-img` has what each one does)
  awwwTransition = {
    AWWW_TRANSITION = "grow"; # a circle that grows...
    AWWW_TRANSITION_POS = "center"; # ...out from the middle of the screen
    AWWW_TRANSITION_DURATION = "1.5"; # seconds
    AWWW_TRANSITION_FPS = "240"; # frames per second; your monitor's refresh rate
  };

  # The Hyprland colors from a theme: the window borders and the title bars (hyprbars).
  # Read from "hyprland.lua" in each theme's folder (mkThemeDir), and the default theme's
  # are written into the Hyprland config for when that file is missing.
  # The title bar is the bar's see-through glass (Theme.glassOpacity, 0.8 = cc), blurred.
  hyprlandThemeColors = c: ''
    active_border = "rgba(${c.accent}ee)",
    inactive_border = "rgba(${c.border}99)",
    -- title bars (hyprbars)
    bar_color = "rgba(${c.bg}cc)",
    bar_text = "rgb(${c.fg})",
    bar_icon = "rgb(${c.bg})",               -- the symbols on the buttons
    bar_button_inactive = "rgb(${c.light})", -- all three, on windows that aren't focused
    bar_close = "rgb(${c.red})",
    bar_float = "rgb(${c.yellow})",           -- the minimize button (named before it was)
    bar_fullscreen = "rgb(${c.green})",
  '';

  # hyprbars (the title bars), with a small addition: a setting, on_drag, for a
  # command to run when you start and stop dragging a window by its bar. hyprbars
  # handles those clicks itself, before Hyprland's binds see them, so without this
  # nothing else knows about the drag. The Hyprland config sets it to tell Quickshell,
  # so a window dragged by its title bar can be dropped on a workspace in the
  # workspaces dock, like Super + drag (WindowDrag.qml). It runs
  #   <command> start <name>                                when the drag starts
  #   <command> finish <name> <address> <floating> at=<x>,<y>   when you let go
  # (where the window was when you picked it up). It also makes letting go end the
  # drag wherever the mouse is: hyprbars ignored a release over a panel (like the
  # workspaces dock), so the drop never happened. And the mouse pointer turns into a
  # pointing hand over the bar's buttons, like the buttons in Quickshell. The change
  # is the patch below; if
  # a hyprbars update stops it applying, the rebuild fails here and the patch needs
  # redoing.
  # Hyprland loads it from ~/.local/share/hypr/plugins (the link below), a path that
  # doesn't change between rebuilds: see the comment where the Hyprland config loads it.
  hyprbarsPatched = pkgs.hyprlandPlugins.hyprbars.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.writeText "hyprbars-on-drag.patch" ''
      --- a/barDeco.cpp
      +++ b/barDeco.cpp
      @@ -22,11 +22,13 @@
       #include <hyprland/src/layout/LayoutManager.hpp>
       #include <hyprland/src/render/OpenGL.hpp>
       #include <hyprland/src/state/MonitorState.hpp>
      +#include <hyprland/src/pointer/cursor/CursorShapeOverrideController.hpp>
       
       #include "globals.hpp"
       #include "BarPassElement.hpp"
       
       #include <climits>
      +#include <ctime>
       
       using namespace Render::GL;
       
      @@ -56,6 +58,10 @@
       
       CHyprBar::~CHyprBar() {
           std::erase(g_pGlobalState->bars, m_self);
      +    if (g_pGlobalState->pointerOwner == this) {
      +        g_pGlobalState->pointerOwner = nullptr;
      +        Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_UNKNOWN);
      +    }
       }
       
       SDecorationPositioningInfo CHyprBar::getPositioningInfo() {
      @@ -123,6 +129,13 @@
       }
       
       void CHyprBar::onMouseButton(Event::SCallbackInfo& info, IPointer::SButtonEvent e) {
      +    // a drag by this bar ends wherever you let go, even over a layer surface (a dock),
      +    // where inputIsValid() says no
      +    if (e.state != WL_POINTER_BUTTON_STATE_PRESSED && m_bDraggingThis) {
      +        handleUpEvent(info);
      +        return;
      +    }
      +
           if (!inputIsValid())
               return;
       
      @@ -154,6 +167,8 @@
           if (g_pGlobalState->config.iconOnHover->value())
               damageOnButtonHover();
       
      +    updateButtonCursor();
      +
           if (!m_bDragPending || m_bTouchEv || !validMapped(m_pWindow) || m_touchId != 0)
               return;
       
      @@ -215,6 +230,7 @@
                   if (m_bTouchEv)
                       g_pKeybindManager->m_dispatchers["settiled"]("activewindow");
                   g_pKeybindManager->m_dispatchers["mouse"]("0movewindow");
      +            notifyDragEnd();
                   Log::logger->log(Log::DEBUG, "[hyprbars] Dragging ended on {:x}", (uintptr_t)PWINDOW.get());
               }
       
      @@ -247,7 +263,7 @@
       }
       
       void CHyprBar::handleUpEvent(Event::SCallbackInfo& info) {
      -    if (m_pWindow.lock() != Desktop::focusState()->window())
      +    if (m_pWindow.lock() != Desktop::focusState()->window() && !m_bDraggingThis)
               return;
       
           if (m_bCancelledDown)
      @@ -258,6 +274,7 @@
           if (m_bDraggingThis) {
               g_pKeybindManager->changeMouseBindMode(MBIND_INVALID);
               m_bDraggingThis = false;
      +        notifyDragEnd();
               if (m_bTouchEv)
                   (void)Config::Actions::floatWindow(Config::Actions::eTogglableAction::TOGGLE_ACTION_DISABLE);
       
      @@ -273,9 +290,33 @@
           g_pKeybindManager->changeMouseBindMode(MBIND_MOVE);
           m_bDraggingThis = true;
           Log::logger->log(Log::DEBUG, "[hyprbars] Dragging initiated on {:x}", (uintptr_t)m_pWindow.lock().get());
      +    notifyDragStart();
           return;
       }
       
      +void CHyprBar::notifyDragStart() {
      +    const auto CMD     = g_pGlobalState->config.onDrag->value();
      +    const auto PWINDOW = m_pWindow.lock();
      +    m_dragName.clear();
      +    if (CMD.empty() || !PWINDOW)
      +        return;
      +
      +    static uint64_t dragCount = 0;
      +    const auto      POS       = PWINDOW->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
      +    m_dragName                = std::format("bar-{}-{}", (long long)std::time(nullptr), ++dragCount);
      +    m_dragArgs = std::format("0x{:x} {} at={},{}", (uintptr_t)PWINDOW.get(), PWINDOW->m_isFloating ? "true" : "false", (int)POS.x, (int)POS.y);
      +    Config::Supplementary::executor()->spawn(std::format("{} start {}", CMD, m_dragName));
      +}
      +
      +void CHyprBar::notifyDragEnd() {
      +    const auto CMD = g_pGlobalState->config.onDrag->value();
      +    if (CMD.empty() || m_dragName.empty())
      +        return;
      +
      +    Config::Supplementary::executor()->spawn(std::format("{} finish {} {}", CMD, m_dragName, m_dragArgs));
      +    m_dragName.clear();
      +}
      +
       bool CHyprBar::doButtonPress(Config::INTEGER barPadding, Config::INTEGER barButtonPadding, Config::INTEGER barHeight, Vector2D COORDS, const bool BUTTONSRIGHT) {
           //check if on a button
           float offset = barPadding;
      @@ -664,6 +705,46 @@
               m_bTitleColorChanged = true;
       }
       
      +// a pointing hand while the mouse is on one of this bar's buttons
      +void CHyprBar::updateButtonCursor() {
      +    bool hovering = false;
      +
      +    if (!m_hidden && !m_bDraggingThis && validMapped(m_pWindow) && g_pGlobalState->config.enabled->value() && inputIsValid()) {
      +        Desktop::CViewHitTester hitTester{*Desktop::viewState()};
      +        const auto              WINDOWATCURSOR =
      +            hitTester.windowAt(g_pInputManager->getMouseCoordsInternal(), Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);
      +
      +        if (WINDOWATCURSOR == m_pWindow.lock()) {
      +            const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
      +            const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
      +            const auto HEIGHT           = g_pGlobalState->config.barHeight->value();
      +            const bool BUTTONSRIGHT     = g_pGlobalState->config.barButtonsAlignment->value() != "left";
      +            const auto COORDS           = cursorRelativeToBar();
      +            float      offset           = BARPADDING;
      +
      +            for (auto& b : g_pGlobalState->buttons) {
      +                const auto BARBUF     = Vector2D{(int)assignedBoxGlobal().w, HEIGHT};
      +                Vector2D   currentPos = Vector2D{(BUTTONSRIGHT ? BARBUF.x - BARBUTTONPADDING - b.size - offset : offset), (BARBUF.y - b.size) / 2.0}.floor();
      +
      +                if (VECINRECT(COORDS, currentPos.x, currentPos.y, currentPos.x + b.size + BARBUTTONPADDING, currentPos.y + b.size)) {
      +                    hovering = true;
      +                    break;
      +                }
      +
      +                offset += BARBUTTONPADDING + b.size;
      +            }
      +        }
      +    }
      +
      +    if (hovering) {
      +        g_pGlobalState->pointerOwner = this;
      +        Pointer::Cursor::overrideController->setOverride("pointer", Pointer::Cursor::CURSOR_OVERRIDE_UNKNOWN);
      +    } else if (g_pGlobalState->pointerOwner == this) {
      +        g_pGlobalState->pointerOwner = nullptr;
      +        Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_UNKNOWN);
      +    }
      +}
      +
       void CHyprBar::damageOnButtonHover() {
           const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
           const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
      --- a/barDeco.hpp
      +++ b/barDeco.hpp
      @@ -107,6 +107,11 @@
           std::string         m_szLastTitle;
       
           bool                m_bDraggingThis  = false;
      +    std::string         m_dragName;      // on_drag: this drag's name, "" when not reported
      +    std::string         m_dragArgs;      // on_drag: "<address> <floating> at=<x>,<y>" at its start
      +    void                notifyDragStart();
      +    void                notifyDragEnd();
      +    void                updateButtonCursor();
           bool                m_bTouchEv       = false;
           bool                m_bDragPending   = false;
           bool                m_bCancelledDown = false;
      --- a/globals.hpp
      +++ b/globals.hpp
      @@ -28,6 +28,8 @@
           uint32_t                  nobarRuleIdx      = 0;
           uint32_t                  barColorRuleIdx   = 0;
           uint32_t                  titleColorRuleIdx = 0;
      +    // the bar that set the pointing-hand cursor (over one of its buttons), or nullptr
      +    CHyprBar*                 pointerOwner = nullptr;
       
           struct {
               SP<Config::Values::CColorValue>      barColor, textColor, inactiveButtonColor;
      @@ -37,7 +39,7 @@
               SP<Config::Values::CIntValue>        barPadding;
               SP<Config::Values::CIntValue>        barButtonPadding;
               SP<Config::Values::CBoolValue>       barBlur, barTitleEnabled, barPartOfWindow, barPrecedenceOverBorder, enabled, iconOnHover;
      -        SP<Config::Values::CStringValue>     barTextFont, barTextAlign, barButtonsAlignment, onDoubleClick;
      +        SP<Config::Values::CStringValue>     barTextFont, barTextAlign, barButtonsAlignment, onDoubleClick, onDrag;
           } config;
       };
       
      --- a/main.cpp
      +++ b/main.cpp
      @@ -251,6 +251,9 @@
           HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.enabled);
           HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.iconOnHover);
           HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.onDoubleClick);
      +    g_pGlobalState->config.onDrag =
      +        makeShared<Config::Values::CStringValue>("plugin:hyprbars:on_drag", "Command run when a drag by the bar starts and ends (start <name> / finish <name> <address> <floating> at=<x>,<y>)", "");
      +    HyprlandAPI::addConfigValueV2(PHANDLE, g_pGlobalState->config.onDrag);
       
           if (Config::mgr()->type() == Config::CONFIG_LEGACY)
               HyprlandAPI::addConfigKeyword(PHANDLE, "plugin:hyprbars:hyprbars-button", onNewButton, Hyprlang::SHandlerOptions{});
      '')
    ];
  });

  mkThemeDir =
    id: t:
    let
      c = t.colors;
      hex = name: "#${c.${name}}";
      argb = name: "#ff${c.${name}}";
      # Qt's palette roles, in the order qt6ct wants them: WindowText, Button, Light,
      # Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window, Shadow,
      # Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole,
      # ToolTipBase, ToolTipText, PlaceholderText
      qtRoles =
        text:
        lib.concatMapStringsSep ", " argb [
          text
          "overlay"
          "light"
          "midlight"
          "bgDim"
          "surface"
          text
          "fgBright"
          text
          "surface"
          "bg"
          "bgDim"
          "accent"
          "bg"
          "link"
          "linkVisited"
          "overlay"
        ]
        + ", #ff000000, "
        + lib.concatMapStringsSep ", " argb [
          "bg"
          "fg"
          "placeholder"
        ];
      gtkIni = ''
        [Settings]
        gtk-application-prefer-dark-theme=true
        gtk-cursor-theme-name=${t.cursor.name}
        gtk-cursor-theme-size=24
        gtk-font-name=SFProText Nerd Font 11
        gtk-icon-theme-name=${t.icons.name}
        gtk-theme-name=${t.gtk.name}
      '';
    in
    pkgs.linkFarm "theme-${id}" {
      "kitty.conf" = pkgs.writeText "kitty.conf" t.kitty;

      # the color variables that home.nix's rofi theme uses (@background, ...)
      "rofi.rasi" = pkgs.writeText "rofi.rasi" ''
        * {
            background: ${hex "bg"};
            background-alt: ${hex "overlay"};
            foreground: ${hex "fg"};
            selected: ${hex "accent"};
            active: ${hex "cyan"};
            urgent: ${hex "red"};
            placeholder-fg: ${hex "placeholder"};
        }
      '';

      "qt6ct.conf" = pkgs.writeText "qt6ct.conf" ''
        [ColorScheme]
        active_colors=${qtRoles "fg"}
        inactive_colors=${qtRoles "fg"}
        disabled_colors=${qtRoles "disabled"}
      '';

      # hyprpolkitagent and other hyprtoolkit apps. Anything left out here uses
      # hyprtoolkit's built-in grey, so every color it has is set.
      "hyprtoolkit.conf" = pkgs.writeText "hyprtoolkit.conf" (
        lib.hm.generators.toHyprconf {
          attrs = {
            background = "0xFF${lib.toUpper c.bg}";
            base = "0xFF${lib.toUpper c.overlay}";
            alternate_base = "0xFF${lib.toUpper c.surface}"; # password box, command box
            text = "0xFF${lib.toUpper c.fg}";
            bright_text = "0xFF${lib.toUpper c.fgBright}";
            link_text = "0xFF${lib.toUpper c.link}";
            accent = "0xFF${lib.toUpper c.accent}";
            accent_secondary = "0xFF${lib.toUpper c.blue}";
            icon_theme = t.icons.name;
            font_family = "SFProText Nerd Font";
            font_family_monospace = "SFMono Nerd Font";
          };
        }
      );

      # read by hyprland.lua when Hyprland starts or reloads its config
      "hyprland.lua" = pkgs.writeText "hyprland-theme.lua" ''
        return {
        ${hyprlandThemeColors c}}
      '';

      "gtk-3.0.ini" = pkgs.writeText "gtk-3.0.ini" gtkIni;
      "gtk-4.0.ini" = pkgs.writeText "gtk-4.0.ini" gtkIni;
      # libadwaita apps ignore gtk-theme-name but do load your own gtk.css, so the
      # theme comes in from there (the same thing home-manager's gtk4.theme does)
      "gtk-4.0.css" = pkgs.writeText "gtk-4.0.css" ''
        @import url("file://${t.gtk4Css or "${t.gtk.package}/share/themes/${t.gtk.name}/gtk-4.0/gtk.css"}");
      '';
      # ~/.icons/default/index.theme: the cursor apps use when they aren't told one
      "cursor.theme" = pkgs.writeText "cursor.theme" ''
        [Icon Theme]
        Name=Default
        Inherits=${t.cursor.name}
      '';
      # read by uwsm at login (see uwsm/env below), so the session starts with it.
      # HYPRCURSOR_THEME too: without it Hyprland doesn't wait for XCURSOR_THEME, it
      # takes the first hyprcursor-format theme it finds, and Catppuccin's cursors are
      # the only ones here that come in that format. So every login came up with the
      # Catppuccin cursor. Named here, Hyprland uses it (Catppuccin) or, if the theme
      # has no hyprcursor version, falls back to the XCursor one of the same name.
      "session.env" = pkgs.writeText "session.env" ''
        export XCURSOR_THEME=${lib.escapeShellArg t.cursor.name}
        export HYPRCURSOR_THEME=${lib.escapeShellArg t.cursor.name}
        export HYPRCURSOR_SIZE=24
      '';
      # for the theme command
      "env" = pkgs.writeText "theme.env" ''
        THEME_NAME=${lib.escapeShellArg t.name}
        THEME_VARIANT=${lib.escapeShellArg t.variant}
        GTK_THEME_NAME=${lib.escapeShellArg t.gtk.name}
        ICON_THEME=${lib.escapeShellArg t.icons.name}
        CURSOR_THEME=${lib.escapeShellArg t.cursor.name}
      '';
    };
  themeDirs = lib.genAttrs themes.order (id: mkThemeDir id themes.themes.${id});
  # what Theme.qml gets: names and colors, with the "#"
  qsThemes = lib.mapAttrs (id: t: {
    inherit (t) name variant;
    colors = lib.mapAttrs (_: v: "#" + v) t.colors;
  }) themes.themes;

  # `theme`: lists the themes, or switches to one. The bar's theme button runs it.
  #   theme                 which one is on, and the list
  #   theme <id>            switch (e.g. theme rose-pine)
  # Switching points ~/.local/state/theme/current at the theme's folder, picks its
  # wallpaper, and tells what's running now: kitty reloads its colors, the cursor and
  # the wallpaper change, GTK gets the new theme name. Quickshell watches
  # ~/.local/state/theme/name and recolors the bar by itself.
  themeSwitch = pkgs.writeShellApplication {
    name = "theme";
    runtimeEnv = awwwTransition; # the wallpaper animation
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      diffutils
      procps
      dconf
      systemd
      awww
    ];
    text = ''
      state="$HOME/.local/state/theme"
      greeter=/var/lib/greeter-theme   # read by the login screen (configuration.nix)
      default=${themes.default}
      ids="${lib.concatStringsSep " " themes.order}"
      # set by sourcing a theme's env file
      THEME_NAME="" THEME_VARIANT="" GTK_THEME_NAME="" ICON_THEME="" CURSOR_THEME=""

      dir_for() {
        case "''${1-}" in
      ${lib.concatMapStrings (id: "    ${id}) echo ${themeDirs.${id}} ;;\n") themes.order}    *) return 1 ;;
        esac
      }
      current() {
        local t
        t=$(cat "$state/name" 2>/dev/null || true)
        if dir_for "$t" >/dev/null; then echo "$t"; else echo "$default"; fi
      }
      # ln + mv, so the link is swapped in one step and never missing
      relink() {
        ln -sfn "$1" "$2.new"
        mv -T "$2.new" "$2"
      }
      # point state/current at this build's folder for the theme
      use() {
        mkdir -p "$state"
        relink "$(dir_for "$1")" "$state/current"
        # only written when it changes: Quickshell reloads the bar's colors on a write
        [ "$(cat "$state/name" 2>/dev/null || true)" = "$1" ] || printf '%s\n' "$1" >"$state/name"
      }
      # The theme's wallpaper: the one you picked for it last (the bar's wallpaper
      # widget, or `theme --wallpaper FILE`), kept in $state/wallpapers/<id>. If you
      # haven't picked one (or it's gone), the first picture (A to Z) in
      # ~/Pictures/Wallpapers/<id>/ (upper/lower case alike, the same order the
      # wallpaper widget shows), or ~/Pictures/Wallpapers/hk.png if that's empty.
      picked_for() {
        local f
        f=$(cat "$state/wallpapers/$1" 2>/dev/null || true)
        if [ -n "$f" ] && [ -f "$f" ]; then echo "$f"; fi
      }
      wallpaper_for() {
        local f
        f=$(picked_for "$1")
        if [ -z "$f" ]; then
          f=$(find "$HOME/Pictures/Wallpapers/$1" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) \
            2>/dev/null | LC_ALL=C sort -f | head -n 1) || true # no folder yet is fine
        fi
        echo "''${f:-$HOME/Pictures/Wallpapers/hk.png}"
      }
      use_wallpaper() {
        local f
        f=$(wallpaper_for "$1")
        [ "$(readlink "$state/wallpaper" 2>/dev/null || true)" = "$f" ] || relink "$f" "$state/wallpaper"
        note_wallpaper
      }
      # The wallpaper's path as plain text, for the bar's wallpaper widget (it can't
      # read links). Only written when it changes: the widget rereads it on a write.
      note_wallpaper() {
        local f
        f=$(readlink "$state/wallpaper" 2>/dev/null || true)
        [ "$(cat "$state/wallpaper.path" 2>/dev/null || true)" = "$f" ] && return 0
        printf '%s\n' "$f" >"$state/wallpaper.path.new" && mv -f "$state/wallpaper.path.new" "$state/wallpaper.path"
      }
      # The login screen runs as its own user and can't look in your home folder, so
      # it gets the theme name, cursor and a copy of the wallpaper in /var/lib/greeter-theme.
      sync_greeter() {
        [ -d "$greeter" ] && [ -w "$greeter" ] || return 0
        local id src ext dst="" stamp=""
        id=$(current)
        # shellcheck disable=SC1091
        . "$state/current/env"
        printf '%s\n' "$CURSOR_THEME" >"$greeter/cursor.new" && mv -f "$greeter/cursor.new" "$greeter/cursor"
        src=$(readlink -f "$state/wallpaper" || true)
        if [ -f "$src" ]; then
          ext="''${src##*.}"
          dst="$greeter/wallpaper.$ext"
          cmp -s "$src" "$dst" || { cp -f "$src" "$dst.new" && mv -f "$dst.new" "$dst"; }
          stamp="$id:$(basename "$src"):$(stat -c %Y "$src")"
        fi
        for old in "$greeter"/wallpaper.*; do
          [ -e "$old" ] && [ "$old" != "$dst" ] && rm -f "$old"
        done
        # a new stamp means "you switched themes": the login screen then shows the
        # theme's wallpaper, even if you'd picked another one there before
        printf '{"theme":"%s","wallpaper":"%s","stamp":"%s"}\n' "$id" "$dst" "$stamp" >"$greeter/state.json.new"
        mv -f "$greeter/state.json.new" "$greeter/state.json"
      }
      # GTK apps that are open follow the GNOME settings (dconf)
      tell_gtk() {
        # shellcheck disable=SC1091
        . "$state/current/env"
        dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME_NAME'" || true
        dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'" || true
        dconf write /org/gnome/desktop/interface/cursor-theme "'$CURSOR_THEME'" || true
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" || true
      }
      # everything already running in your session
      tell_session() {
        # shellcheck disable=SC1091
        . "$state/current/env"
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
          # Hyprland's config reads the theme's colors (window borders, title bars) from
          # "hyprland.lua", so read it again. First, so the lines below come after it.
          hyprctl reload >/dev/null || true
          hyprctl setcursor "$CURSOR_THEME" 24 >/dev/null || true
          # and for apps Hyprland starts from now on
          hyprctl eval "hl.env(\"XCURSOR_THEME\", \"$CURSOR_THEME\")" >/dev/null || true
          hyprctl eval "hl.env(\"HYPRCURSOR_THEME\", \"$CURSOR_THEME\")" >/dev/null || true
        fi
        systemctl --user set-environment XCURSOR_THEME="$CURSOR_THEME" HYPRCURSOR_THEME="$CURSOR_THEME" || true
        # hyprtoolkit apps (the polkit agent) watch ~/.config/hypr/hyprtoolkit.conf
        # itself, not the file it leads to, so the state/current swap goes unnoticed.
        # Putting the same link back in its place is noticed: they reread it.
        ht="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprtoolkit.conf"
        if [ -L "$ht" ]; then relink "$(readlink "$ht")" "$ht" || true; fi
        # kitty rereads its config (and so the colors) on SIGUSR1. On NixOS the
        # process is called .kitty-wrapped.
        pkill -USR1 -x kitty || true
        pkill -USR1 -x .kitty-wrapped || true
        awww img "$state/wallpaper" >/dev/null 2>&1 || true
        systemctl --user start --no-block rofi-wallpaper.service || true
      }

      case "''${1-}" in
        "")
          now=$(current)
          for id in $ids; do
            # shellcheck disable=SC1090,SC1091
            name=$(. "$(dir_for "$id")/env"; echo "$THEME_NAME $THEME_VARIANT")
            if [ "$id" = "$now" ]; then mark="*"; else mark=" "; fi
            printf '%s %-17s %s\n' "$mark" "$id" "$name"
          done
          ;;
        -h | --help)
          echo "usage: theme [${lib.concatStringsSep "|" themes.order}]"
          echo "       theme --wallpaper FILE   (this theme's wallpaper, remembered for it)"
          ;;
        --wallpaper)
          f=$(realpath -s -- "''${2-}" 2>/dev/null || true)
          if [ -z "''${2-}" ] || [ ! -f "$f" ]; then
            echo "theme: no picture at: ''${2-}" >&2
            exit 1
          fi
          id=$(current)
          mkdir -p "$state/wallpapers"
          printf '%s\n' "$f" >"$state/wallpapers/$id"
          use_wallpaper "$id"
          awww img "$state/wallpaper" >/dev/null 2>&1 || true
          systemctl --user start --no-block rofi-wallpaper.service || true
          sync_greeter
          ;;
        --refresh)
          # home-manager runs this on every rebuild: the theme folders get new store
          # paths, so the link is pointed at this build's copy of the same theme
          use "$(current)"
          [ -e "$state/wallpaper" ] || use_wallpaper "$(current)"
          note_wallpaper
          ;;
        --login)
          # at login (theme-session service): pick up new pictures in the folder too
          use "$(current)"
          use_wallpaper "$(current)"
          tell_gtk
          sync_greeter
          ;;
        *)
          if ! dir_for "$1" >/dev/null; then
            echo "theme: no theme called '$1'. These exist: $ids" >&2
            exit 1
          fi
          use "$1"
          use_wallpaper "$1"
          tell_gtk
          tell_session
          sync_greeter
          ;;
      esac
    '';
  };
in
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
    import Quickshell.Wayland
    import Quickshell.Services.SystemTray
    import Quickshell.Hyprland

    ShellRoot {
        // ── Fading out of the session ──
        // Log out, Restart and Power off: black spreads out from the middle of every
        // screen (CenterFade.qml), above everything, then the command runs. (Fading in at
        // login is done by fade.qml, which Hyprland starts before anything else.)
        Scope {
            id: session

            property var leaveCmd: null
            property real cover: 0       // 0 = nothing, 1 = all black

            NumberAnimation {
                id: coverAnim
                target: session
                property: "cover"
                from: 0
                to: 1
                duration: 700
                easing.type: Easing.InOutCubic
            }
            // hide the mouse pointer so it isn't left floating on the black
            function pointer(visible) {
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { invisible = " + !visible + " } })"]);
            }
            // fade to black with the shutdown sound, then run `cmd` once both are done
            // (so the sound isn't cut off by the power going off)
            property bool faded: false
            property bool soundDone: false
            function leave(cmd) {
                if (leaveCmd !== null)
                    return;
                leaveCmd = cmd;
                Ui.leaving = true;   // every open widget popup slides shut (Widget.qml)
                pointer(false);
                coverAnim.start();
                leaveTimer.start();
                if (Sounds.enabled) {
                    byeSound.running = true;
                    byeSoundLimit.start();
                } else {
                    soundDone = true;
                }
            }
            function goIfDone() {
                if (faded && soundDone)
                    Quickshell.execDetached(leaveCmd);
            }
            Process {
                id: byeSound
                command: ["${pkgs.pipewire}/bin/pw-play", Sounds.path("system-shutdown")]
                onExited: {
                    session.soundDone = true;
                    session.goIfDone();
                }
            }
            Timer {
                id: byeSoundLimit       // never wait on the sound more than 3 s
                interval: 3000
                onTriggered: if (!session.soundDone) {
                    session.soundDone = true;
                    session.goIfDone();
                }
            }
            function logout() {
                leave(["uwsm", "stop"]);
            }
            Timer {
                id: leaveTimer
                interval: 750      // just after the 700 ms fade
                onTriggered: {
                    session.faded = true;
                    session.goIfDone();
                }
            }
            // so the Super+Shift+E key can use it: quickshell ipc call session logout
            IpcHandler {
                target: "session"
                function logout(): void {
                    session.logout();
                }
            }
            // so the Super + drag bind can say when a window drag starts and ends
            // (WindowDrag.qml): quickshell ipc call windowdrag start / finish ...
            IpcHandler {
                target: "windowdrag"
                function start(name: string): void {
                    WindowDrag.start(name);
                }
                function finish(name: string, address: string, floating: bool, at: string): void {
                    WindowDrag.finish(name, address, floating, at);
                }
            }

            Variants {
                model: Quickshell.screens

                PanelWindow {
                    required property var modelData
                    screen: modelData
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "session-fade"
                    color: "transparent"
                    mask: Region {}                 // clicks go straight through
                    visible: session.cover > 0      // only exists while fading out

                    CenterFade {
                        anchors.fill: parent
                        mode: "cover"
                        progress: session.cover
                    }
                }
            }
        }

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
            // add a whole list of songs to the end of the queue, in order
            function enqueueAll(list) {
                for (const s of list)
                    send(["loadfile", s.path, "append-play"]);
            }
            // put a whole list of songs straight after the current one, in order (each goes
            // in right after the current song, so they're sent last one first)
            function playAllNext(list) {
                for (let i = list.length - 1; i >= 0; i--)
                    send(["loadfile", list[i].path, "insert-next-play"]);
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
                // your own order from here on: the sort chip goes off
                queueSort = "";
                send(["playlist-move", from, to > from ? to + 1 : to]);
            }
            // Sort the whole queue by "album", "artist" or "title" (the song that's
            // playing stays playing, it just moves with the rest). Works out the new order,
            // then moves entries into place one by one, top to bottom, with the same
            // playlist-move that drag-to-reorder uses. Songs that aren't in the library
            // (so have no tags) go to the end.
            //
            // The queue sort is a mode: the chip stays lit (green) while it's on, and songs
            // you add get sorted in. Clicking the lit chip again doesn't turn it off; it
            // stays on until you change the order yourself (dragging a song, see move()),
            // or pick another sort.
            property string queueSort: ""     // "", "album", "artist" or "title"
            property var sortedIds: ({})      // ids the sort has seen (id -> true)
            property var expectIds: null      // the order our moves will end on; null = not busy
            function setQueueSort(by) {
                if (by === queueSort)
                    return;
                queueSort = by;
                sortQueue(by);
            }
            onQueueChanged: {
                if (expectIds !== null) {
                    // our own moves are still arriving one by one; wait for the last
                    if (queue.map(e => e.id).join() !== expectIds.join())
                        return;
                    expectIds = null;
                }
                checkSort();
            }
            function checkSort() {
                if (queueSort === "")
                    return;
                // songs added while sorted: sort them in
                const fresh = queue.filter(e => !sortedIds[e.id]);
                if (fresh.length > 0)
                    sortQueue(queueSort);
            }
            Timer {
                // in case mpv never reports the exact order we expected
                running: music.expectIds !== null
                interval: 2000
                onTriggered: {
                    music.expectIds = null;
                    music.checkSort();
                }
            }
            // Move entries so the queue ends up in `wanted` order, top to bottom, with the
            // same playlist-move that drag-to-reorder uses.
            function applyOrder(wanted) {
                const now = queue.slice();      // mirror of mpv's list as the moves happen
                let moved = false;
                for (let i = 0; i < wanted.length; i++) {
                    const from = now.indexOf(wanted[i]);
                    if (from === i || from < 0)
                        continue;
                    send(["playlist-move", from, i]);   // lands in front of slot i, i.e. at i
                    now.splice(i, 0, now.splice(from, 1)[0]);
                    moved = true;
                }
                if (moved)
                    expectIds = now.map(e => e.id);
            }
            function sortQueue(by) {
                const key = e => {
                    const s = byPath[e.filename];
                    if (!s)
                        return ["\uffff", "", "", e.filename];
                    const k = {
                        album: [s.album, s.artist, s.path],
                        artist: [s.artist, s.album, s.path],
                        title: [s.title, s.artist, s.path]
                    }[by];
                    return k.map(x => (x || "\uffff").toLowerCase());
                };
                const cmp = (a, b) => {
                    const ka = key(a), kb = key(b);
                    for (let i = 0; i < ka.length; i++) {
                        const c = ka[i].localeCompare(kb[i]);
                        if (c !== 0)
                            return c;
                    }
                    return 0;
                };
                const wanted = queue.slice().sort(cmp);
                const seen = {};
                for (const e of queue)
                    seen[e.id] = true;
                sortedIds = seen;
                applyOrder(wanted);
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
                        added: Number(f[1]),      // the file's modified time, for "Recently added"
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
        // USB devices and audio outputs coming and going: a notice and a sound
        DeviceWatch {}
        // battery warnings: a laptop's battery and Bluetooth devices'
        BatteryWatch {}

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
                if (n.lastGeneration) {        // re-sent after a config reload: not new
                    // ...but a clock alarm still unread keeps ringing
                    if (n.hints && n.hints["x-repeat-sound"] && unread.includes(n.id))
                        startRinging(n);
                    return;
                }
                if (n.hints && n.hints["x-repeat-sound"])
                    startRinging(n);
                unread = unread.concat([n.id]);
                arrived = Object.assign({}, arrived, {
                    [n.id]: new Date()
                });
                toasts.add(n);                 // the popup at the top right (below)
                // its sound (Sounds.qml), unless it asks for none (the clock and the
                // device notices play their own)
                if (!(n.hints && n.hints["suppress-sound"]))
                    Sounds.play(n.urgency === NotificationUrgency.Critical ? "software-update-urgent" : "message-new-instant");
            }

            function markAllRead() {
                unread = [];
            }
            function markRead(id) {
                unread = unread.filter(x => x !== id);
            }

            // ── Ringing ──
            // The clock's timers, events and reminders (Planner.qml's ring()) come with an
            // x-repeat-sound hint: their sound plays, a short pause, plays again... until
            // the notification is X'd (popup or notification center: dismissed) or marked
            // read. Its popup stays up meanwhile (toasts below). A few at once ring as one,
            // with the newest one's sound.
            property var ringing: ({})        // notification id -> sound
            readonly property bool isRinging: Object.keys(ringing).length > 0
            property string ringSound: ""
            function startRinging(n) {
                ringing = Object.assign({}, ringing, {
                    [n.id]: n.hints["x-repeat-sound"]
                });
                ringSound = n.hints["x-repeat-sound"];
                n.closed.connect(() => stopRinging(n.id));   // X'd, or the app closed it
                if (!ringer.running)
                    ringer.running = Sounds.enabled;
            }
            function stopRinging(id) {
                if (!(id in ringing))
                    return;
                const r = Object.assign({}, ringing);
                delete r[id];
                ringing = r;
            }
            // marked read (one or all): stops ringing
            onUnreadChanged: {
                for (const id in ringing)
                    if (!unread.includes(Number(id)))
                        stopRinging(Number(id));
            }
            // nothing left ringing: stop right away, even mid-sound
            onIsRingingChanged: if (!isRinging) {
                ringGap.stop();
                ringer.running = false;
            }
        }
        // plays the sound once; the pause after it, then again while something's ringing
        Process {
            id: ringer
            command: ["${pkgs.pipewire}/bin/pw-play", Sounds.path(notifs.ringSound)]
            onExited: if (notifs.isRinging)
                ringGap.restart()
        }
        Timer {
            id: ringGap
            interval: 1500      // the pause between rings
            onTriggered: if (notifs.isRinging && Sounds.enabled)
                ringer.running = true
        }

        // ── Notification popups ──
        // Every new notification also slides in at the top right of the screen you're
        // on, stays 10 s, then slides back out. It's still in the notification center
        // afterwards (and still unread there). Point at a popup to keep it up while you
        // read; click it (or its x) to send it away now. At most 4 at once, newest on top.
        Scope {
            id: toasts

            readonly property int duration: 10000   // ms on screen
            readonly property int maxShown: 4
            property var objs: ({})                   // notification id -> notification

            ListModel {
                id: toastModel                          // { nid }, newest first
            }
            function add(n) {
                remove(n.id);                           // an app replacing its own notification
                objs[n.id] = n;
                toastModel.insert(0, { "nid": n.id });
                while (toastModel.count > maxShown)
                    toastModel.remove(toastModel.count - 1);
                n.closed.connect(() => toasts.remove(n.id));   // dismissed or closed by the app
            }
            function remove(id) {
                for (let i = 0; i < toastModel.count; i++) {
                    if (toastModel.get(i).nid === id) {
                        toastModel.remove(i);
                        return;
                    }
                }
            }

            // keeps the window up a moment after the last one leaves, for its slide-out
            Timer {
                id: toastLinger
                interval: 400
            }
            Connections {
                target: toastModel
                function onCountChanged() {
                    if (toastModel.count === 0)
                        toastLinger.restart();
                }
            }

            PanelWindow {
                // the monitor you're on (the first one if Hyprland hasn't said yet)
                screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
                visible: toastModel.count > 0 || toastLinger.running
                anchors {
                    top: true
                    right: true
                }
                // Placed in the space the bar leaves free, so it always starts below the
                // bar (and below the bar's curved corners, Theme.barCurve). Normal + zone 0:
                // keeps out of the bar's reserved space without reserving any itself.
                // (Ignore, which this used before, measured from the very top of the
                // screen, so the margin alone wasn't enough and it sat over the bar.)
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                margins {
                    top: (Theme.barCurve ? Theme.radius : 0) + 8
                    right: 8
                }
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "notification-popups"
                color: "transparent"
                implicitWidth: 344
                implicitHeight: 560
                // only the cards take clicks; the empty part below lets them through
                mask: Region {
                    width: toastList.width
                    height: toastList.contentHeight
                }

                ListView {
                    id: toastList
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 344
                    height: parent.height
                    interactive: false
                    spacing: 8
                    model: toastModel

                    // slide in from the right, slide back out, the others move up/down
                    add: Transition {
                        NumberAnimation {
                            property: "x"
                            from: 360
                            to: 0
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                        }
                    }
                    remove: Transition {
                        NumberAnimation {
                            property: "x"
                            to: 360
                            duration: 260
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 260
                        }
                    }
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }

                    delegate: Rectangle {
                        id: toast
                        required property int nid
                        readonly property var n: toasts.objs[nid] ?? null
                        readonly property bool critical: !!n && n.urgency === NotificationUrgency.Critical
                        // a clock alarm that's ringing (notifs.ringing): stays up until you stop it
                        readonly property bool ringing: nid in notifs.ringing

                        width: ListView.view.width
                        height: toastContent.implicitHeight + 24
                        radius: 12
                        color: Theme.glass     // see-through and blurred, like the bar
                        border.width: 1
                        border.color: critical ? Theme.red : Theme.pill

                        // how long it has left; pauses while you point at it
                        property real remaining: 1
                        NumberAnimation on remaining {
                            id: countdown
                            from: 1
                            to: 0
                            duration: toasts.duration
                            paused: toastHover.hovered || toast.ringing
                            onFinished: toasts.remove(toast.nid)
                        }

                        HoverHandler {
                            id: toastHover
                        }
                        // click anywhere (or the x): send it away now. It stays in the notification
                        // center; a ringing alarm is marked read there, which stops it.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (toast.ringing)
                                    notifs.markRead(toast.nid);
                                toasts.remove(toast.nid);
                            }
                        }

                        Column {
                            id: toastContent
                            x: 14
                            y: 12
                            width: parent.width - 28
                            spacing: 3

                            // app name · time, and the x
                            Item {
                                width: parent.width
                                height: toastApp.implicitHeight

                                Text {
                                    id: toastApp
                                    anchors.left: parent.left
                                    anchors.right: toastClose.left
                                    anchors.rightMargin: 8
                                    text: (toast.n && toast.n.appName ? toast.n.appName : "Notification") + "  ·  " + Qt.formatDateTime(new Date(), "h:mm AP") + (toast.ringing ? "  ·  click to stop" : "")
                                    elide: Text.ElideRight
                                    color: toast.critical ? Theme.red : Theme.accent
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.8
                                    font.weight: 600
                                }
                                Text {
                                    id: toastClose
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "close"
                                    color: Theme.text
                                    opacity: toastHover.hovered ? 0.8 : 0.4
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize * 0.9
                                }
                            }
                            Text {
                                width: parent.width
                                text: toast.n ? toast.n.summary : ""
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 700
                                font.letterSpacing: Theme.letterSpacing
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: toast.n ? toast.n.body : ""
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

                        // time left, as a thin line along the bottom
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.bottomMargin: 6
                            width: (parent.width - 24) * toast.remaining
                            height: 2
                            radius: 1
                            color: toast.critical ? Theme.red : Theme.accent
                            opacity: 0.6
                        }
                    }
                }
            }
        }

        // ── The dock ── (Dock.qml): one per screen, hidden at the bottom edge
        Variants {
            model: Quickshell.screens

            Dock {
                required property var modelData
                screen: modelData
            }
        }

        // ── The workspaces dock ── (WorkspaceDock.qml): one per screen, hidden at the
        // left edge
        Variants {
            model: Quickshell.screens

            WorkspaceDock {
                required property var modelData
                screen: modelData
            }
        }

        // ── The title bar over a fullscreen window ── (FullscreenBar.qml): one per
        // screen, there only while that screen's focused window is fullscreen
        Variants {
            model: Quickshell.screens

            FullscreenBar {
                required property var modelData
                screen: modelData
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
                // The window covers the whole screen: the widgets' popups are drawn in it
                // (Widget.qml), so the bar and an open popup are one surface, blurred
                // together with no edge between them. Everything but the bar and an open
                // popup is clear and lets clicks through (mask), and windows only make
                // room for the bar itself (exclusiveZone).
                implicitHeight: modelData.height
                exclusiveZone: Theme.barHeight
                color: "transparent"
                // the name Hyprland's blur rule for the bar looks for
                WlrLayershell.namespace: "bar"

                // the widget whose popup is open on this bar, if any
                readonly property var openWidget: Ui.openWidget && Ui.openWidget.barContent === bar.contentItem ? Ui.openWidget : null
                // Takes clicks: the bar, and an open popup (only the part showing).
                mask: Region {
                    item: barBody
                    Region {
                        item: bar.openWidget ? bar.openWidget.popupItem : null
                    }
                }
                // Typing goes to an open popup (search boxes, the calendar's add row...):
                // the bar takes the keyboard when you click in it while a popup is open.
                // Otherwise it never does, so it can't take focus from your windows.
                WlrLayershell.keyboardFocus: bar.openWidget ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                // ── the inward curves under both ends of the bar ──
                // So the bar looks like it wraps around the top corners of the screen.
                BarCorner {
                    visible: Theme.barCurve
                    anchors.left: parent.left
                    y: Theme.barHeight
                }
                BarCorner {
                    visible: Theme.barCurve
                    mirrored: true
                    anchors.right: parent.right
                    y: Theme.barHeight
                }

                // the bar itself
                Item {
                    id: barBody
                    width: parent.width
                    height: Theme.barHeight

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.glass     // see-through, blurred (Theme.glassOpacity)
                    }

                    SystemClock {
                        id: clock
                        precision: SystemClock.Minutes
                    }
                    // SystemClock moves on with a timer, and that timer doesn't count the
                    // time the computer spends asleep, so after waking the clock could be
                    // up to a minute behind (same when the time gets corrected over the
                    // network). Every 2 s this checks that it shows the right minute, and
                    // makes it read the time again if not.
                    Timer {
                        interval: 2000
                        running: true
                        repeat: true
                        onTriggered: {
                            const now = new Date();
                            const shown = clock.date;
                            if (now.getMinutes() !== shown.getMinutes() || now.getHours() !== shown.getHours() || now.getDate() !== shown.getDate()) {
                                clock.enabled = false;
                                clock.enabled = true;
                            }
                        }
                    }
                    /*
                    Poll {
                        id: bluetooth
                        cmd: "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"
                    }
                    */
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        // (The workspace switcher is on the left edge now: WorkspaceDock.qml.)

                        // ── Display: brightness, night light, color filters ──
                        // Icon only, like Bluetooth. The icon shows what's on: a filter, night
                        // light, or plain brightness.
                        Widget {
                            id: dispWidget
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
                                // "backlight": a laptop screen; brightness is set for real with
                                //              brightnessctl (the panel actually dims).
                                // "software":  no backlight (a desktop monitor), so it's dimmed by
                                //              Hyprland's screen shader instead, like night light.
                                property string mode: "backlight"
                                property int brightness: 100     // percent
                                property bool nightOn: false
                                property int kelvin: 4000        // night light warmth: lower = warmer
                                property string filter: "none"   // none / invert / grayscale / sepia / contrast

                                // ── How night light, software dimming and the filters work ──
                                // All three are one screen shader: a tiny GPU program Hyprland runs
                                // over the finished picture of the whole screen. Whenever something
                                // changes, a new shader is written with the settings baked in and
                                // Hyprland is told to use it. When everything is off there's no
                                // shader at all, so it costs nothing.
                                // (This used to go through hyprsunset, which needs the GPU driver to
                                // support Hyprland's color-matrix feature. NVIDIA's doesn't reliably,
                                // which is why night light and software brightness did nothing.)

                                // Night light color: how much red / green / blue light to keep at a
                                // given temperature (Tanner Helland's well-known approximation of a
                                // black body's color; 6500 K is about white).
                                function tint(k) {
                                    const t = k / 100;
                                    const clamp = v => Math.max(0, Math.min(255, v)) / 255;
                                    const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
                                    const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
                                    const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
                                    return [clamp(r), clamp(g), clamp(b)];
                                }
                                // The GLSL for the current settings, or "" when nothing is on.
                                function shaderSource() {
                                    const dim = mode === "software" && brightness < 100;
                                    if (!nightOn && !dim && filter === "none")
                                        return "";
                                    const f = n => n.toFixed(4);
                                    const lines = [];
                                    if (filter === "invert")
                                        lines.push("col = 1.0 - col;");
                                    else if (filter === "grayscale")
                                        lines.push("col = vec3(dot(col, vec3(0.2126, 0.7152, 0.0722)));");
                                    else if (filter === "sepia")
                                        lines.push("col = min(vec3(dot(col, vec3(0.393, 0.769, 0.189)), dot(col, vec3(0.349, 0.686, 0.168)), dot(col, vec3(0.272, 0.534, 0.131))), vec3(1.0));");
                                    else if (filter === "contrast")
                                        lines.push("col = clamp((col - 0.5) * 1.35 + 0.5, 0.0, 1.0);");
                                    if (nightOn) {
                                        const c = tint(kelvin);
                                        lines.push("col *= vec3(" + f(c[0]) + ", " + f(c[1]) + ", " + f(c[2]) + ");");
                                    }
                                    if (dim)
                                        lines.push("col *= " + f(brightness / 100) + ";");
                                    return ["#version 300 es", "precision highp float;", "in vec2 v_texcoord;", "uniform sampler2D tex;", "layout(location = 0) out vec4 fragColor;", "void main() {", "    vec4 c = texture(tex, v_texcoord);", "    vec3 col = c.rgb;"].concat(lines.map(l => "    " + l)).concat(["    fragColor = vec4(col, c.a);", "}", ""]).join("\n");
                                }

                                // Writes the shader and switches Hyprland to it. One change at a time:
                                // while Hyprland is busy with one, newer changes wait, and only the
                                // latest is sent. (Before, every click went out at once and Hyprland
                                // worked through the backlog, which is why filters came in bursts.)
                                // the shader files live in RAM (XDG_RUNTIME_DIR) and are gone after a reboot
                                readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-display"
                                property int shaderSlot: 0       // rotates between 3 file names so Hyprland sees a new path
                                property bool effectsDirty: false
                                function applyEffects() {
                                    if (!restored)
                                        return;
                                    if (effectsSetter.running) {
                                        effectsDirty = true;
                                        return;
                                    }
                                    const src = shaderSource();
                                    let path = "";
                                    if (src !== "") {
                                        shaderSlot = (shaderSlot + 1) % 3;
                                        path = runDir + "/effect-" + shaderSlot + ".frag";
                                    }
                                    const state = JSON.stringify({
                                        "brightness": mode === "software" ? brightness : 100,
                                        "nightOn": nightOn,
                                        "kelvin": kelvin,
                                        "filter": filter
                                    });
                                    // $1 folder, $2 shader file ("" = none), $3 shader text, $4 settings file, $5 settings
                                    // Why dim_strength: changing only the shader makes Hyprland redraw just the
                                    // parts of the screen that change, and it keeps 2-3 screen buffers, so old
                                    // and new frames alternate for a while: the flicker, and filters that take
                                    // a while to go away. Setting any window-look option (here dim_strength,
                                    // to the value it already has) makes Hyprland redraw the whole screen for
                                    // the next frames, which gets every buffer up to date. Done twice, a moment
                                    // apart, to cover all of them. (Hyprland does the same "3 full frames"
                                    // trick itself when a monitor is plugged in.)
                                    effectsSetter.command = ["sh", "-c", "mkdir -p \"$1\" \"$(dirname \"$4\")\"; printf '%s' \"$5\" > \"$4\"; [ -n \"$2\" ] && printf '%s' \"$3\" > \"$2\"; keep='dim_strength = hl.get_config(\"decoration.dim_strength\")'; hyprctl eval \"hl.config({ decoration = { screen_shader = \\\"$2\\\", $keep } })\"; sleep 0.05; exec hyprctl eval \"hl.config({ decoration = { $keep } })\"", "sh", runDir, path, src, statePath, state];
                                    effectsSetter.running = true;
                                }
                                Process {
                                    id: effectsSetter
                                    onExited: if (disp.effectsDirty) {
                                        disp.effectsDirty = false;
                                        disp.applyEffects();
                                    }
                                }
                                // ── remember the settings, and put them back after a restart or login ──
                                // (written by applyEffects above)
                                readonly property string statePath: Quickshell.env("HOME") + "/.local/state/quickshell/display.json"
                                FileView {
                                    id: stateFile
                                    path: disp.statePath
                                    blockLoading: true
                                    printErrors: false
                                }
                                property bool restored: false

                                // Read the real brightness (and whether there's a backlight at all)
                                // at start and each time the popup opens, so the keys are picked up.
                                readonly property bool shown: dispWidget.popupShown
                                onShownChanged: if (shown)
                                    reader.running = true
                                Process {
                                    id: reader
                                    running: true
                                    // prints e.g. "45" (percent), or nothing when there's no backlight
                                    command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -n1 | cut -d, -f4 | tr -d %"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            const v = parseInt(text.trim());
                                            if (!disp.restored) {
                                                // first read: decide the mode, then bring back the saved settings
                                                disp.mode = isNaN(v) ? "software" : "backlight";
                                                let saved = {};
                                                try {
                                                    saved = JSON.parse(stateFile.text() || "{}");
                                                } catch (e) {}
                                                disp.nightOn = saved.nightOn === true;
                                                disp.kelvin = saved.kelvin || 4000;
                                                disp.filter = saved.filter || "none";
                                                if (disp.mode === "software")
                                                    disp.brightness = saved.brightness || 100;
                                                disp.restored = true;
                                                disp.applyEffects();
                                            }
                                            if (disp.mode === "backlight" && !isNaN(v) && !brightSlider.pressed)
                                                disp.brightness = v;
                                        }
                                    }
                                }

                                // Laptop backlight: same one-at-a-time idea as above.
                                property bool brightDirty: false
                                function pushBrightness() {
                                    if (mode === "software") {
                                        applyEffects();
                                        return;
                                    }
                                    if (brightSetter.running) {
                                        brightDirty = true;
                                        return;
                                    }
                                    brightSetter.command = ["brightnessctl", "-q", "-c", "backlight", "set", brightness + "%"];
                                    brightSetter.running = true;
                                }
                                Process {
                                    id: brightSetter
                                    onExited: if (disp.brightDirty) {
                                        disp.brightDirty = false;
                                        disp.pushBrightness();
                                    }
                                }

                                function pushNight() {
                                    applyEffects();
                                }
                                // Picking the active filter again turns it off.
                                function setFilter(name) {
                                    filter = filter === name ? "none" : name;
                                    applyEffects();
                                }
                                function reset() {
                                    brightness = 100;
                                    nightOn = false;
                                    filter = "none";
                                    if (mode === "backlight")
                                        pushBrightness();
                                    applyEffects();
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
                                        onClicked: disp.reset()
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
                                        // (a laptop backlight at 1% still glows; software dimming stops at 10%)
                                        from: disp.mode === "backlight" ? 1 : 10
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
                            id: btWidget
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
                                    value: btWidget.popupShown
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

                                // Scrolls once the list is taller than 360 px (lots of devices or networks around).
                                Flickable {
                                    id: btScroll
                                    width: 280
                                    height: Math.min(contentHeight, 360)
                                    contentHeight: btRows.implicitHeight
                                    visible: btRows.implicitHeight > 0
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ThinScrollBar {}

                                    // Scrolls just enough to show all of `row` (used while a row's drop-down opens).
                                    function show(row) {
                                        if (row.y + row.height > contentY + height)
                                            contentY = Math.min(row.y + row.height, contentHeight) - height;
                                        if (row.y < contentY)
                                            contentY = row.y;
                                    }

                                    Column {
                                        id: btRows
                                        width: btScroll.width
                                        spacing: 4

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
                                                // keep it in view while its drop-down glides open
                                                onHeightChanged: if (expanded)
                                                    btScroll.show(btRow)

                                                width: 280
                                                height: btHeader.height + btDrop.height
                                                radius: Theme.radius
                                                // a device that shows up fades in instead of popping in
                                                NumberAnimation on opacity {
                                                    from: 0
                                                    to: 1
                                                    duration: 200
                                                }
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
                                                            color: btActionMouse.containsMouse && !busy ? tint : Theme.glass
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
                            }
                        }

                        // ── Theme and wallpaper ──
                        // Icon only, like Bluetooth. Left: the color themes (the themes block at
                        // the top of home.nix); each row shows that theme's own colors, click one
                        // to switch. The bar fades over, and the theme command does the rest (see
                        // "Themes" in home.nix). Right: the pictures in that theme's wallpaper
                        // folder (WallpaperPicker.qml); click one to use it. Picking a theme
                        // shows its folder right away, with its own remembered wallpaper. The
                        // popup stays open, so you can try a few.
                        Widget {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "palette"

                            Row {
                                spacing: 14

                                Column {
                                    id: themeList
                                    spacing: 4
                                    width: 280

                                    Item {
                                        width: parent.width
                                        height: 26

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Theme"
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 1.2
                                            font.weight: 700
                                            font.letterSpacing: Theme.letterSpacing
                                        }
                                    }

                                    Repeater {
                                        model: Theme.order

                                        Rectangle {
                                            id: themeRow
                                            required property string modelData
                                            readonly property var info: Theme.themes[modelData]
                                            readonly property var colors: info.colors
                                            readonly property bool selected: Theme.current === modelData

                                            width: themeList.width
                                            height: 44
                                            radius: Theme.radius
                                            color: themeMouse.containsMouse || selected ? Theme.pill : "transparent"

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 120
                                                }
                                            }

                                            Item {
                                                anchors.fill: parent
                                                scale: themeMouse.pressed ? 0.85 : 1

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 120
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }

                                                // a little preview: the theme's background with its colors on it
                                                Rectangle {
                                                    id: themePreview
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 64
                                                    height: 28
                                                    radius: 6
                                                    color: themeRow.colors.bg
                                                    border.width: 1
                                                    border.color: themeRow.colors.overlay

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 3

                                                        Repeater {
                                                            model: ["red", "yellow", "green", "blue", "magenta"]

                                                            Rectangle {
                                                                required property string modelData
                                                                width: 8
                                                                height: 8
                                                                radius: 4
                                                                color: themeRow.colors[modelData]
                                                            }
                                                        }
                                                    }
                                                }
                                                Column {
                                                    anchors {
                                                        left: themePreview.right
                                                        right: themeCheck.left
                                                        leftMargin: 10
                                                        rightMargin: 8
                                                        verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: themeRow.info.name
                                                        elide: Text.ElideRight
                                                        color: themeRow.selected ? Theme.accent : Theme.text
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSize
                                                        font.weight: themeRow.selected ? 700 : 500
                                                        font.letterSpacing: Theme.letterSpacing
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        text: themeRow.info.variant
                                                        elide: Text.ElideRight
                                                        color: Theme.text
                                                        opacity: 0.6
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSize * 0.85
                                                    }
                                                }
                                                Text {
                                                    id: themeCheck
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "check"
                                                    opacity: themeRow.selected ? 1 : 0
                                                    color: Theme.accent
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize
                                                    font.variableAxes: Theme.iconAxes

                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 120
                                                        }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: themeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Theme.set(themeRow.modelData)
                                            }
                                        }
                                    }
                                }
                                // between the two
                                Rectangle {
                                    width: 1
                                    height: Math.max(themeList.height, picker.height)
                                    color: Theme.pill
                                }
                                WallpaperPicker {
                                    id: picker
                                }
                            }
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
                                        // point at it: the album and artist
                                        HoverHandler {
                                            id: nowCoverHover
                                        }
                                        HoverTip {
                                            show: nowCoverHover.hovered && !!media.player
                                            cut: true
                                            title: media.player ? (media.player.trackAlbum || media.player.trackTitle) : ""
                                            detail: media.player ? media.player.trackArtist : ""
                                        }
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
                                    // Library views: every song, or songs grouped by artist / album.
                                    // Clicking an artist or album "opens" it (pick); the back arrow closes it.
                                    property string view: "songs"        // "songs", "artists" or "albums"
                                    property var pick: null              // { kind, name, artist, songs } or null
                                    onViewChanged: pick = null
                                    onTabChanged: pick = null

                                    // ── picking songs to queue together ──
                                    // The checklist button (or Ctrl + click on a song) starts it: clicking
                                    // songs then picks them (and unpicks them) instead of playing them, and
                                    // a bar above the list adds them all to the queue at once, in the order
                                    // you picked them. Picks stay while you go between Songs, artists and
                                    // albums, so you can gather them from anywhere.
                                    property bool selecting: false
                                    property var selected: []            // the songs picked, in order
                                    property int justAdded: 0            // "Added N" for a moment after
                                    function isSelected(song) {
                                        return selected.some(s => s.path === song.path);
                                    }
                                    function toggleSelected(song) {
                                        selected = isSelected(song) ? selected.filter(s => s.path !== song.path) : selected.concat([song]);
                                    }
                                    function selectAll(list) {
                                        selected = selected.concat(list.filter(song => !isSelected(song)));
                                    }
                                    function endSelecting() {
                                        selecting = false;
                                        selected = [];
                                    }
                                    function added(n) {
                                        justAdded = n;
                                        addedTimer.restart();
                                    }
                                    function queueSelected(next) {
                                        if (selected.length === 0)
                                            return;
                                        if (next)
                                            music.playAllNext(selected);
                                        else
                                            music.enqueueAll(selected);
                                        added(selected.length);
                                        endSelecting();
                                    }
                                    Timer {
                                        id: addedTimer
                                        interval: 2000
                                        onTriggered: lib.justAdded = 0
                                    }

                                    // ── sorting the library (the sort button next to Songs/Artists/Albums) ──
                                    // One choice for song lists and one for artist/album lists. "" is the
                                    // default: songs in library order (artist, album, then track order),
                                    // artists and albums A to Z. Clicking the lit choice again goes back
                                    // to the default.
                                    property string songSort: ""
                                    property string groupSort: ""
                                    property bool sortOpen: false        // the list of choices is showing
                                    readonly property var songSorts: [
                                        { id: "az", name: "A–Z" },
                                        { id: "za", name: "Z–A" },
                                        { id: "artist", name: "Artist" },
                                        { id: "album", name: "Album" },
                                        { id: "short", name: "Shortest" },
                                        { id: "long", name: "Longest" },
                                        { id: "recent", name: "Recently added" },
                                        { id: "oldest", name: "Oldest added" }
                                    ]
                                    readonly property var groupSorts: [
                                        { id: "za", name: "Z–A" },
                                        { id: "most", name: "Most songs" },
                                        { id: "long", name: "Longest" },
                                        { id: "recent", name: "Recently added" }
                                    ]
                                    // which list the sort button is about right now
                                    readonly property bool sortingGroups: view !== "songs" && !pick
                                    readonly property string activeSort: sortingGroups ? groupSort : songSort
                                    function pickSort(id) {
                                        if (sortingGroups)
                                            groupSort = groupSort === id ? "" : id;
                                        else
                                            songSort = songSort === id ? "" : id;
                                    }
                                    // A to Z, ignoring upper/lower case (Qt's JavaScript ignores
                                    // localeCompare's options, so the case is folded by hand). Empty
                                    // tags go last.
                                    function byText(a, b) {
                                        return (a || "￿").toLowerCase().localeCompare((b || "￿").toLowerCase());
                                    }
                                    function songName(s) {
                                        return s.title || s.path.split("/").pop();
                                    }
                                    function sortSongs(list, by) {
                                        const cmp = {
                                            az: (a, b) => byText(songName(a), songName(b)),
                                            za: (a, b) => byText(songName(b), songName(a)),
                                            artist: (a, b) => byText(a.artist, b.artist) || byText(a.album, b.album) || byText(a.path, b.path),
                                            album: (a, b) => byText(a.album, b.album) || byText(a.path, b.path),
                                            short: (a, b) => a.length - b.length,
                                            long: (a, b) => b.length - a.length,
                                            recent: (a, b) => b.added - a.added,
                                            oldest: (a, b) => a.added - b.added
                                        }[by];
                                        return cmp ? list.slice().sort(cmp) : list;
                                    }

                                    // the songs listed: the open artist/album, or the library narrowed
                                    // down by the search box, in the chosen order
                                    readonly property var results: {
                                        let list;
                                        if (pick) {
                                            list = pick.songs;
                                        } else {
                                            const q = search.text.toLowerCase();
                                            list = q === "" ? music.songs : music.songs.filter(s => (s.title + " " + s.artist + " " + s.album).toLowerCase().includes(q));
                                        }
                                        return sortSongs(list, songSort);
                                    }
                                    // artists or albums, each with its songs (in library order:
                                    // artist, album, then file name, so albums keep track order)
                                    readonly property var groups: {
                                        if (view === "songs")
                                            return [];
                                        const map = {};
                                        const list = [];
                                        for (const s of music.songs) {
                                            const name = view === "artists" ? (s.artist || "Unknown artist") : (s.album || "Unknown album");
                                            const id = view === "artists" ? name : name + "\n" + s.artist;
                                            let g = map[id];
                                            if (!g) {
                                                g = map[id] = {
                                                    kind: view,
                                                    name: name,
                                                    artist: s.artist,
                                                    cover: "",
                                                    songs: [],
                                                    length: 0,      // all its songs together, in seconds
                                                    added: 0        // its newest song's time
                                                };
                                                list.push(g);
                                            }
                                            g.songs.push(s);
                                            g.length += s.length || 0;
                                            g.added = Math.max(g.added, s.added || 0);
                                            if (g.cover === "" && s.cover !== "")
                                                g.cover = s.cover;
                                        }
                                        const q = search.text.toLowerCase();
                                        const shown = q === "" ? list : list.filter(g => (g.name + " " + g.artist).toLowerCase().includes(q));
                                        const az = (a, b) => byText(a.name, b.name);
                                        const cmp = {
                                            za: (a, b) => byText(b.name, a.name),
                                            most: (a, b) => (b.songs.length - a.songs.length) || az(a, b),
                                            long: (a, b) => (b.length - a.length) || az(a, b),
                                            recent: (a, b) => (b.added - a.added) || az(a, b)
                                        }[groupSort] || az;
                                        return shown.sort(cmp);
                                    }

                                    // the queue, narrowed down by its search box (title, artist, album,
                                    // or the file name for songs that aren't in the library)
                                    readonly property string queueQuery: queueSearch.text.trim().toLowerCase()
                                    readonly property var queueShown: {
                                        const q = queueQuery;
                                        if (q === "")
                                            return music.queue;
                                        return music.queue.filter(e => {
                                            const s = music.byPath[e.filename];
                                            const text = s ? s.title + " " + s.artist + " " + s.album : e.filename.split("/").pop();
                                            return text.toLowerCase().includes(q);
                                        });
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
                                                tip: "Play everything listed"
                                                onClicked: music.playAll(lib.results)
                                            }
                                            IconButton {        // add everything that's listed to the end of the queue
                                                icon: "playlist_add"
                                                tip: "Add everything listed to the queue"
                                                onClicked: {
                                                    music.enqueueAll(lib.results);
                                                    lib.added(lib.results.length);
                                                }
                                            }
                                            IconButton {        // pick songs, then queue them together
                                                icon: "checklist"
                                                iconColor: lib.selecting ? Theme.accent : Theme.text
                                                tip: lib.selecting ? "Stop picking songs" : "Pick songs to queue together"
                                                onClicked: if (lib.selecting)
                                                    lib.endSelecting()
                                                else
                                                    lib.selecting = true
                                            }
                                            IconButton {
                                                icon: "shuffle"
                                                tip: music.shuffled ? "Shuffle: on" : "Shuffle: off"
                                                iconColor: music.shuffled ? Theme.accent : Theme.text
                                                onClicked: music.toggleShuffle()
                                            }
                                            IconButton {
                                                icon: music.repeat === "one" ? "repeat_one" : "repeat"
                                                tip: music.repeat === "one" ? "Repeat: this song" : music.repeat === "all" ? "Repeat: the queue" : "Repeat: off"
                                                iconColor: music.repeat === "off" ? Theme.text : Theme.accent
                                                onClicked: music.cycleRepeat()
                                            }
                                            IconButton {        // empty the queue (keeps the song that's playing)
                                                icon: "clear_all"
                                                tip: "Empty the queue (keeps what's playing)"
                                                onClicked: music.clearQueue()
                                            }
                                            IconButton {        // scan ~/Music again
                                                icon: "refresh"
                                                tip: music.scanning ? "Scanning ~/Music..." : "Scan ~/Music again"
                                                iconColor: music.scanning ? Theme.accent : Theme.text
                                                onClicked: music.rescan()
                                            }
                                        }
                                    }

                                    // ── search ──
                                    TextField {
                                        id: search
                                        visible: lib.tab === "library" && !lib.pick
                                        width: parent.width
                                        placeholderText: lib.view === "artists" ? "Search artists" : lib.view === "albums" ? "Search albums" : "Search songs, artists, albums"
                                        placeholderTextColor: Theme.pillIcon
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                        leftPadding: 12
                                        rightPadding: 12
                                        background: Rectangle {
                                            radius: height / 2
                                            color: Theme.glass
                                            border.width: 1
                                            border.color: search.activeFocus ? Theme.accent : Theme.pillIcon
                                        }
                                    }

                                    // ── Songs / Artists / Albums, and the sort button ──
                                    Item {
                                        visible: lib.tab === "library" && !lib.pick
                                        width: parent.width
                                        height: 28

                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            Repeater {
                                                model: [
                                                    {
                                                        id: "songs",
                                                        name: "Songs"
                                                    },
                                                    {
                                                        id: "artists",
                                                        name: "Artists"
                                                    },
                                                    {
                                                        id: "albums",
                                                        name: "Albums"
                                                    }
                                                ]
                                                Chip {
                                                    required property var modelData
                                                    label: modelData.name
                                                    selected: lib.view === modelData.id   // Songs, to start with
                                                    onClicked: lib.view = modelData.id
                                                }
                                            }
                                        }

                                        // the sort button: lit while a sort other than the default is on,
                                        // with its name next to it
                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: {
                                                    const all = lib.sortingGroups ? lib.groupSorts : lib.songSorts;
                                                    const s = all.find(x => x.id === lib.activeSort);
                                                    return s ? s.name : "";
                                                }
                                                color: Theme.accent
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.85
                                                font.weight: 600
                                            }
                                            IconButton {
                                                icon: "sort"
                                                tip: "Sort"
                                                iconColor: lib.sortOpen || lib.activeSort !== "" ? Theme.accent : Theme.text
                                                onClicked: lib.sortOpen = !lib.sortOpen
                                            }
                                        }
                                    }

                                    // ── inside an artist or album: back arrow, name, play it all ──
                                    Item {
                                        visible: lib.tab === "library" && lib.pick !== null
                                        width: parent.width
                                        height: 36
                                        IconButton {
                                            id: backButton
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "arrow_back"
                                            tip: "Back"
                                            onClicked: lib.pick = null
                                        }
                                        Column {
                                            anchors.left: backButton.right
                                            anchors.leftMargin: 6
                                            anchors.right: pickPlay.left
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: lib.pick ? lib.pick.name : ""
                                                color: Theme.text
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 1.1
                                                font.weight: 700
                                                font.letterSpacing: Theme.letterSpacing
                                            }
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: !lib.pick ? "" : (lib.pick.kind === "albums" && lib.pick.artist ? lib.pick.artist + "  ·  " : "") + lib.pick.songs.length + (lib.pick.songs.length === 1 ? " song" : " songs")
                                                color: Theme.text
                                                opacity: 0.6
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSize * 0.85
                                            }
                                        }
                                        IconButton {
                                            id: pickPlay
                                            anchors.right: pickQueue.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "play_circle"
                                            tip: "Play all"
                                            onClicked: music.playAll(lib.results)
                                        }
                                        IconButton {
                                            id: pickQueue
                                            anchors.right: pickSort.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "playlist_add"
                                            tip: "Add all to the queue"
                                            onClicked: {
                                                music.enqueueAll(lib.results);
                                                lib.added(lib.results.length);
                                            }
                                        }
                                        // an artist's songs can be sorted too (an album keeps its track order)
                                        IconButton {
                                            id: pickSort
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!lib.pick && lib.pick.kind === "artists"
                                            width: visible ? implicitWidth : 0
                                            icon: "sort"
                                            tip: "Sort"
                                            iconColor: lib.sortOpen || lib.songSort !== "" ? Theme.accent : Theme.text
                                            onClicked: lib.sortOpen = !lib.sortOpen
                                        }
                                    }

                                    // ── the sort choices (open with the sort button) ──
                                    Flow {
                                        visible: lib.sortOpen && lib.tab === "library" && (!lib.pick || lib.pick.kind === "artists")
                                        width: parent.width
                                        spacing: 4

                                        Repeater {
                                            model: lib.sortingGroups ? lib.groupSorts : lib.songSorts
                                            Chip {
                                                required property var modelData
                                                label: modelData.name
                                                selected: lib.activeSort === modelData.id
                                                onClicked: lib.pickSort(modelData.id)   // again = back to the default
                                            }
                                        }
                                    }

                                    // ── queue: sort it ──
                                    Row {
                                        visible: lib.tab === "queue" && music.queue.length > 1
                                        spacing: 4
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Sort by"
                                            color: Theme.text
                                            opacity: 0.6
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.9
                                            rightPadding: 4
                                        }
                                        Repeater {
                                            model: [
                                                {
                                                    id: "album",
                                                    name: "Album"
                                                },
                                                {
                                                    id: "artist",
                                                    name: "Artist"
                                                },
                                                {
                                                    id: "title",
                                                    name: "Title"
                                                }
                                            ]
                                            Chip {
                                                required property var modelData
                                                label: modelData.name
                                                // lit while the queue is kept sorted this way, until
                                                // you drag a song somewhere else
                                                selected: music.queueSort === modelData.id
                                                onClicked: music.setQueueSort(modelData.id)
                                            }
                                        }
                                    }

                                    // ── queue: search it ──
                                    // While you're searching, dragging is off (the list has gaps, so
                                    // there's no telling where a dropped song should land). Clicking a
                                    // song still jumps to it.
                                    TextField {
                                        id: queueSearch
                                        visible: lib.tab === "queue" && music.queue.length > 0
                                        width: parent.width
                                        placeholderText: "Search the queue"
                                        placeholderTextColor: Theme.pillIcon
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                        leftPadding: 12
                                        rightPadding: 12
                                        Keys.onEscapePressed: text = ""
                                        background: Rectangle {
                                            radius: height / 2
                                            color: Theme.glass
                                            border.width: 1
                                            border.color: queueSearch.activeFocus ? Theme.accent : Theme.pillIcon
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
                                                return music.queue.length === 0 ? "The queue is empty." : lib.queueShown.length === 0 ? "Nothing in the queue matches." : "";
                                            if (music.songs.length === 0)
                                                return music.scanning ? "Scanning ~/Music..." : "No songs found in ~/Music.";
                                            if (lib.view !== "songs" && !lib.pick)
                                                return lib.groups.length === 0 ? "No matches." : "";
                                            return lib.results.length === 0 ? "No matches." : "";
                                        }
                                        color: Theme.text
                                        opacity: 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                    }

                                    // ── picking songs: how many, and what to do with them ──
                                    // (also "Added N to the queue" for a moment after any of the queue-all
                                    // buttons)
                                    Rectangle {
                                        visible: lib.tab === "library" && (lib.selecting || lib.justAdded > 0)
                                        width: parent.width
                                        height: 34
                                        radius: Theme.radius
                                        color: Theme.pill

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.right: pickedButtons.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            text: lib.justAdded > 0 && !lib.selecting ? "Added " + lib.justAdded + (lib.justAdded === 1 ? " song" : " songs") + " to the queue" : lib.selected.length === 0 ? "Click songs to pick them" : lib.selected.length + (lib.selected.length === 1 ? " song picked" : " songs picked")
                                            color: lib.justAdded > 0 && !lib.selecting ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.9
                                            font.weight: 600
                                        }
                                        Row {
                                            id: pickedButtons
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: lib.selecting
                                            IconButton {
                                                icon: "select_all"
                                                tip: "Pick everything listed"
                                                onClicked: lib.selectAll(lib.results)
                                            }
                                            IconButton {
                                                icon: "queue_play_next"
                                                tip: "Play them next"
                                                iconColor: lib.selected.length > 0 ? Theme.text : Theme.pillIcon
                                                onClicked: lib.queueSelected(true)
                                            }
                                            IconButton {
                                                icon: "playlist_add"
                                                tip: "Add them to the end of the queue"
                                                iconColor: lib.selected.length > 0 ? Theme.accent : Theme.pillIcon
                                                onClicked: lib.queueSelected(false)
                                            }
                                            IconButton {
                                                icon: "close"
                                                iconColor: Theme.red
                                                tip: "Stop picking (forget the picks)"
                                                onClicked: lib.endSelecting()
                                            }
                                        }
                                    }

                                    // ── the library list ──
                                    // ListView only creates rows that are on screen, so thousands of songs are fine.
                                    ListView {
                                        id: songList
                                        visible: lib.tab === "library" && (lib.view === "songs" || lib.pick !== null) && lib.results.length > 0
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
                                            // picked, while picking songs to queue together
                                            readonly property bool picked: lib.selecting && lib.isSelected(modelData)

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
                                            color: song.picked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, songMouse.containsMouse ? 0.32 : 0.22) : songMouse.containsMouse ? Theme.pill : "transparent"
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

                                            // Click the row to play it now (while picking songs: pick it, or
                                            // unpick it; Ctrl + click starts picking). Everything else sits
                                            // inside this MouseArea, so hovering the buttons still counts as
                                            // hovering the row.
                                            MouseArea {
                                                id: songMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    if (lib.selecting || (mouse.modifiers & Qt.ControlModifier)) {
                                                        lib.selecting = true;
                                                        lib.toggleSelected(song.modelData);
                                                    } else {
                                                        music.playNow(song.modelData.path);
                                                    }
                                                }

                                                // album cover with rounded corners
                                                ClippingRectangle {
                                                    id: songCover
                                                    x: 5
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 36
                                                    height: 36
                                                    radius: 6
                                                    color: Theme.pill
                                                    // point at it: the album and artist
                                                    HoverHandler {
                                                        id: songCoverHover
                                                    }
                                                    HoverTip {
                                                        show: songCoverHover.hovered
                                                        cut: true
                                                        title: song.modelData.album || "No album"
                                                        detail: song.modelData.artist
                                                    }

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
                                                    // picked: a check over the cover
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: song.picked
                                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "check"
                                                            color: Theme.bg
                                                            font.family: Theme.iconFont
                                                            font.pixelSize: Theme.iconSize
                                                            font.variableAxes: Theme.iconAxes
                                                        }
                                                    }
                                                }

                                                Column {
                                                    anchors.left: songCover.right
                                                    anchors.leftMargin: 10
                                                    anchors.right: songSide.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        id: songTitle
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
                                                        id: songDetail
                                                        width: parent.width
                                                        text: [song.modelData.artist, song.modelData.album].filter(s => s).join("  ·  ")
                                                        elide: Text.ElideRight
                                                        color: Theme.text
                                                        opacity: 0.6
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSize * 0.85
                                                    }
                                                }
                                                // the whole title, if it's cut short (HoverTip.qml)
                                                HoverTip {
                                                    show: songMouse.containsMouse && !songCoverHover.hovered
                                                    cut: songTitle.truncated || songDetail.truncated
                                                    title: song.modelData.title
                                                    detail: songDetail.text
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
                                                        visible: (!songMouse.containsMouse || lib.selecting) && song.pending === "" && !song.added
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
                                                        visible: songMouse.containsMouse && song.pending === "" && !song.added && !lib.selecting
                                                        IconButton {
                                                            icon: "queue_play_next"         // play after the current song
                                                            tip: "Play next"
                                                            onClicked: {
                                                                song.pending = "next";
                                                                resetTimer.restart();
                                                            }
                                                        }
                                                        IconButton {
                                                            icon: "playlist_add"            // add to the end of the queue
                                                            tip: "Add to the end of the queue"
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
                                                            color: confirmMouse.containsMouse ? Theme.green : Theme.glass
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
                                                            tip: "Cancel"
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

                                    // ── artists / albums ──
                                    // Click one to see its songs; the play button plays all of them.
                                    ListView {
                                        id: groupList
                                        visible: lib.tab === "library" && lib.view !== "songs" && !lib.pick && lib.groups.length > 0
                                        width: parent.width
                                        height: 320
                                        clip: true
                                        spacing: 2
                                        model: lib.groups
                                        boundsBehavior: Flickable.StopAtBounds
                                        ScrollBar.vertical: ScrollBar {
                                            id: groupBar
                                            contentItem: Rectangle {
                                                implicitWidth: 4
                                                radius: 2
                                                color: Theme.pillIcon
                                                opacity: groupBar.size < 1 ? (groupBar.active ? 1 : 0.4) : 0
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 200
                                                    }
                                                }
                                            }
                                        }

                                        delegate: Rectangle {
                                            id: group
                                            required property var modelData      // { kind, name, artist, cover, songs }
                                            width: ListView.view.width - 8
                                            height: 46
                                            radius: Theme.radius
                                            color: groupMouse.containsMouse ? Theme.pill : "transparent"
                                            scale: groupMouse.pressed ? 0.95 : 1
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

                                            MouseArea {
                                                id: groupMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: lib.pick = group.modelData

                                                // artists get a round picture, albums a rounded square
                                                ClippingRectangle {
                                                    id: groupCover
                                                    x: 5
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 36
                                                    height: 36
                                                    radius: group.modelData.kind === "artists" ? 18 : 6
                                                    color: Theme.pill
                                                    // point at it: the album and artist (or the artist)
                                                    HoverHandler {
                                                        id: groupCoverHover
                                                    }
                                                    HoverTip {
                                                        show: groupCoverHover.hovered
                                                        cut: true
                                                        title: group.modelData.name
                                                        detail: groupDetail.text
                                                    }
                                                    Image {
                                                        anchors.fill: parent
                                                        source: group.modelData.cover
                                                        sourceSize: Qt.size(72, 72)
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: group.modelData.cover === ""
                                                        text: group.modelData.kind === "artists" ? "person" : "album"
                                                        color: Theme.pillIcon
                                                        font.family: Theme.iconFont
                                                        font.pixelSize: Theme.iconSize
                                                    }
                                                }
                                                Column {
                                                    anchors.left: groupCover.right
                                                    anchors.leftMargin: 10
                                                    anchors.right: groupQueue.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text {
                                                        id: groupName
                                                        width: parent.width
                                                        text: group.modelData.name
                                                        elide: Text.ElideRight
                                                        color: Theme.text
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSize
                                                        font.weight: 700
                                                        font.letterSpacing: Theme.letterSpacing
                                                    }
                                                    Text {
                                                        id: groupDetail
                                                        width: parent.width
                                                        text: (group.modelData.kind === "albums" && group.modelData.artist ? group.modelData.artist + "  ·  " : "") + group.modelData.songs.length + (group.modelData.songs.length === 1 ? " song" : " songs")
                                                        elide: Text.ElideRight
                                                        color: Theme.text
                                                        opacity: 0.6
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSize * 0.85
                                                    }
                                                }
                                                // the whole name, if it's cut short (HoverTip.qml)
                                                HoverTip {
                                                    show: groupMouse.containsMouse && !groupCoverHover.hovered
                                                    cut: groupName.truncated || groupDetail.truncated
                                                    title: group.modelData.name
                                                    detail: groupDetail.text
                                                }
                                                IconButton {        // add everything by this artist / on this album to the queue
                                                    id: groupQueue
                                                    anchors.right: groupPlay.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: groupMouse.containsMouse
                                                    icon: "playlist_add"
                                                    tip: group.modelData.kind === "artists" ? "Add this artist to the queue" : "Add this album to the queue"
                                                    onClicked: {
                                                        music.enqueueAll(group.modelData.songs);
                                                        lib.added(group.modelData.songs.length);
                                                    }
                                                }
                                                IconButton {        // play everything by this artist / on this album
                                                    id: groupPlay
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: groupMouse.containsMouse
                                                    icon: "play_arrow"
                                                    tip: group.modelData.kind === "artists" ? "Play this artist" : "Play this album"
                                                    onClicked: music.playAll(group.modelData.songs)
                                                }
                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !groupMouse.containsMouse
                                                    text: "chevron_right"
                                                    color: Theme.pillIcon
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize
                                                }
                                            }
                                        }
                                    }

                                    // ── the queue ──
                                    ListView {
                                        id: queueList
                                        visible: lib.tab === "queue" && lib.queueShown.length > 0
                                        width: parent.width
                                        height: 356
                                        clip: true
                                        spacing: 2
                                        // ScriptModel compares the new queue with the old one and only
                                        // updates the rows that changed. A plain array (model: music.queue)
                                        // makes the ListView throw every row away and rebuild the list on
                                        // each mpv update, which is what jumped it back to the top after a drop.
                                        model: ScriptModel {
                                            values: lib.queueShown
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
                                            // where it is in mpv's queue (not the same as the row while searching)
                                            readonly property int queueIndex: lib.queueQuery === "" ? index : music.queue.findIndex(e => e.id === modelData.id)

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
                                                onClicked: music.jumpTo(entry.queueIndex)

                                                // grab here and drag up or down to move the song
                                                Text {
                                                    id: dragHandle
                                                    x: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: lib.queueQuery === ""     // no dragging while searching
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
                                                    // point at it: the album and artist
                                                    HoverHandler {
                                                        id: entryCoverHover
                                                    }
                                                    HoverTip {
                                                        show: entryCoverHover.hovered && queueList.dragFrom < 0
                                                        cut: true
                                                        title: entry.info ? (entry.info.album || "No album") : "Not in your library"
                                                        detail: entry.info ? entry.info.artist : entry.modelData.filename
                                                    }

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
                                                        id: entryTitle
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
                                                        id: entryDetail
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
                                                // the whole title, if it's cut short (HoverTip.qml); not while
                                                // dragging songs around the queue
                                                HoverTip {
                                                    show: entryMouse.containsMouse && queueList.dragFrom < 0 && !entryCoverHover.hovered
                                                    cut: entryTitle.truncated || entryDetail.truncated
                                                    title: entryTitle.text
                                                    detail: entryDetail.text
                                                }

                                                IconButton {
                                                    id: removeButton
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: entryMouse.containsMouse        // only while hovered
                                                    icon: "close"
                                                    iconColor: Theme.red
                                                    tip: "Take it out of the queue"
                                                    onClicked: music.remove(entry.queueIndex)
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
                                    tip: "Previous"
                                    implicitWidth: 16
                                    onClicked: if (media.player && media.player.canGoPrevious)
                                        media.player.previous()
                                }
                                IconButton {
                                    icon: media.player && media.player.isPlaying ? "pause" : "play_arrow"
                                    tip: media.player && media.player.isPlaying ? "Pause" : "Play"
                                    implicitWidth: 16
                                    onClicked: if (media.player && media.player.canTogglePlaying)
                                        media.player.togglePlaying()
                                }
                                IconButton {
                                    icon: "skip_next"
                                    tip: "Next"
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

                        // ── Dock: what's pinned on the dock at the bottom of the screen ──
                        // (DockControl.qml; the open apps and the tray are on the dock now)
                        DockControl {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Weather {
                            anchors.verticalCenter: parent.verticalCenter
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
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ThinScrollBar {}

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
                            id: netWidget
                            anchors.verticalCenter: parent.verticalCenter
                            // What the pill shows, straight from NetworkManager (it changes the moment
                            // you connect or disconnect, no polling): the Wi-Fi network when Wi-Fi is
                            // connected, else wired, else offline. Wi-Fi wins when both are up (it
                            // used to show whichever device nmcli listed first, which was always
                            // the wired one).
                            button: Pill {
                                readonly property var wifi: {
                                    for (const d of Networking.devices.values)
                                        if (d.type === DeviceType.Wifi)
                                            for (const n of d.networks.values)
                                                if (n.connected)
                                                    return n;
                                    return null;
                                }
                                readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)

                                icon: wifi ? "wifi" : wired ? "lan" : "wifi_off"
                                iconColor: Theme.green
                                text: wifi ? wifi.name : wired ? "Wired" : "offline"
                            }

                            Column {
                                id: netList
                                spacing: 4

                                // Every network from every device (Wi-Fi and wired): connected first,
                                // then strongest signal, then A to Z. Signal is counted in steps of 25%,
                                // not to the exact percent: it wobbles all the time, and sorting on the
                                // exact number kept reshuffling the rows. Wired networks have no
                                // signalStrength, hence ?? 0.
                                function bars(n) {
                                    return Math.round((n.signalStrength ?? 0) * 4);
                                }
                                readonly property var networks: [].concat(...Networking.devices.values.map(d => d.networks.values)).sort((a, b) => (b.connected - a.connected) || (bars(b) - bars(a)) || a.name.localeCompare(b.name))

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
                                            value: netWidget.popupShown
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
                                // A wired port only has a network to connect to while a cable is
                                // plugged in (NetworkManager sees a link); this says so instead of
                                // the port just not being there.
                                Repeater {
                                    model: Networking.devices.values.filter(d => d.type === DeviceType.Wired && !d.hasLink)
                                    Text {
                                        required property var modelData
                                        leftPadding: 10
                                        text: "Wired  (" + modelData.name + "): no cable"
                                        color: Theme.text
                                        opacity: 0.5
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.9
                                    }
                                }

                                // Scrolls once the list is taller than 360 px (lots of devices or networks around).
                                Flickable {
                                    id: netScroll
                                    width: 280
                                    height: Math.min(contentHeight, 360)
                                    contentHeight: netRows.implicitHeight
                                    visible: netRows.implicitHeight > 0
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ThinScrollBar {}

                                    // Scrolls just enough to show all of `row` (used while a row's drop-down opens).
                                    function show(row) {
                                        if (row.y + row.height > contentY + height)
                                            contentY = Math.min(row.y + row.height, contentHeight) - height;
                                        if (row.y < contentY)
                                            contentY = row.y;
                                    }

                                    Column {
                                        id: netRows
                                        width: netScroll.width
                                        spacing: 4

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
                                                // keep it in view while its drop-down glides open
                                                onHeightChanged: if (expanded)
                                                    netScroll.show(netRow)

                                                width: 280
                                                height: header.height + drop.height
                                                radius: Theme.radius
                                                // a network that shows up fades in instead of popping in
                                                NumberAnimation on opacity {
                                                    from: 0
                                                    to: 1
                                                    duration: 200
                                                }
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
                                                        // wired: its network is named after the port (enp5s0...)
                                                        text: netRow.isWifi ? netRow.network.name : "Wired  (" + netRow.network.name + ")"
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
                                                                color: Theme.glass
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
                                                            color: disconnectMouse.containsMouse ? Theme.red : Theme.glass
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
                            }
                        }
                        // ── Clock: calendar, events, timers, stopwatch (Clock.qml) ──
                        Clock {
                            anchors.verticalCenter: parent.verticalCenter
                            now: clock.date
                        }
                        // the timer's pause / play, beside the clock while one is going or
                        // paused (the one the clock shows: Planner.barTimer)
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Planner.barTimer !== null
                            color: Theme.pill
                            icon: Planner.barTimerPaused ? "play_arrow" : "pause"
                            iconColor: Theme.accent
                            tip: Planner.barTimerPaused ? "Start the timer again" : "Pause the timer"
                            tipBelow: true
                            onClicked: {
                                const t = Planner.barTimer;
                                if (!t)
                                    return;
                                if (Planner.barTimerPaused)
                                    Planner.resumeTimer(t.id);
                                else
                                    Planner.pauseTimer(t.id);
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
                                                    color: partRow.picked ? Theme.glass : Theme.pill
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

                                // ── power profile (power-profiles-daemon) ──
                                // Power saver, Balanced or Performance, for the whole computer.
                                // Some programs can hold a profile while they run (a game asking
                                // for Performance); that's listed under it.
                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.pill
                                }
                                Item {
                                    width: parent.width
                                    height: 26
                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Power profile"
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                        font.weight: 700
                                        font.letterSpacing: Theme.letterSpacing
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        Repeater {
                                            model: [
                                                {
                                                    profile: PowerProfile.PowerSaver,
                                                    name: "Saver",
                                                    tint: Theme.green
                                                },
                                                {
                                                    profile: PowerProfile.Balanced,
                                                    name: "Balanced",
                                                    tint: Theme.blue
                                                },
                                                {
                                                    profile: PowerProfile.Performance,
                                                    name: "Performance",
                                                    tint: Theme.orange
                                                }
                                            ]
                                            Chip {
                                                required property var modelData
                                                // Performance only where the computer has it
                                                visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                                label: modelData.name
                                                tint: modelData.tint
                                                selected: PowerProfiles.profile === modelData.profile
                                                onClicked: PowerProfiles.profile = modelData.profile
                                            }
                                        }
                                    }
                                }
                                // why Performance is running slower than it should, if it is
                                Text {
                                    visible: PowerProfiles.profile === PowerProfile.Performance && PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: "Held back: " + PerformanceDegradationReason.toString(PowerProfiles.degradationReason).toLowerCase()
                                    color: Theme.orange
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
                                }
                                // programs holding a profile
                                Text {
                                    visible: PowerProfiles.holds.length > 0
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: PowerProfiles.holds.map(h => (h.applicationId || "A program") + " is holding " + PowerProfile.toString(h.profile)).join("\n")
                                    color: Theme.text
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.85
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
                                            cmd: ["systemctl", "reboot"],
                                            fade: true
                                        },
                                        {
                                            icon: "power_settings_new",
                                            name: "Power off",
                                            cmd: ["systemctl", "poweroff"],
                                            fade: true
                                        },
                                        {
                                            icon: "lock",
                                            name: "Lock",
                                            cmd: ["${lockCmd}/bin/lock"]
                                        },
                                        {
                                            icon: "logout",
                                            name: "Log out",
                                            cmd: ["uwsm", "stop"],
                                            fade: true
                                        }
                                    ]

                                    Rectangle {
                                        id: powerRow
                                        required property var modelData        // { icon, name, cmd, fade }

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
                                            // fade: true = fade the screen to black first (see `session` at the top)
                                            onClicked: powerRow.modelData.fade ? session.leave(powerRow.modelData.cmd) : Quickshell.execDetached(powerRow.modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  # Shared state that every bar file can see (like Theme, but for "what's happening").
  xdg.configFile."quickshell/Ui.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell

    Singleton {
        // true while fading out for Log out / Restart / Power off
        property bool leaving: false
        // the bar widget whose popup is open (only one at a time; see Widget.qml)
        property var openWidget: null
    }
  '';

  # The center-outward fade used for logging in and out (also a copy in the login screen).
  xdg.configFile."quickshell/CenterFade.qml".text = ''
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
  # The fade-in after you log in (started by Hyprland, see hyprland.start).
  xdg.configFile."quickshell/fade.qml".text = ''
    // Fades the desktop in after you log in: the screen starts black and the desktop
    // opens up from the middle outward (CenterFade.qml).
    //
    // Hyprland starts this the moment it starts (hyprland.start in the Hyprland config),
    // before the wallpaper and the bar. Those two wait until this has covered the screen
    // (ExecStartPre on their services), so nothing pops in before the fade. It waits for
    // the wallpaper (up to ~3 s) and a moment for the bar, fades, shows the mouse pointer
    // again and quits.
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland

    ShellRoot {
        id: root

        // tells the waiting services "the screen is covered" (one per Hyprland instance)
        readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-fade-up-" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        property real progress: 0      // 0 = black, 1 = desktop fully visible

        Timer {
            interval: 50               // first frame is up by now
            running: true
            onTriggered: {
                Quickshell.execDetached(["${pkgs.coreutils}/bin/touch", root.marker]);
                // The login sound: on the black screen, so it carries on while the
                // desktop fades in. This early, PipeWire is running (audio-at-login in
                // home.nix) but WirePlumber may not have set up your speakers /
                // headphones yet, and a sound with nowhere to go is lost. So it waits
                // until there's a default output (wpctl fails until then), up to 4 s,
                // then plays. Detached, so it isn't cut off when this quits.
                if (Sounds.enabled)
                    Quickshell.execDetached(["sh", "-c", "for _ in $(${pkgs.coreutils}/bin/seq 40); do ${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break; ${pkgs.coreutils}/bin/sleep 0.1; done; exec ${pkgs.pipewire}/bin/pw-play \"$0\"", Sounds.path("system-ready")]);
            }
        }
        // wallpaper up (awww answers with "image: ..."), then ~0.35 s for the bar to draw
        Process {
            running: true
            command: ["sh", "-c", "for _ in $(seq 30); do ${pkgs.awww}/bin/awww query 2>/dev/null | grep -q image && break; sleep 0.1; done; sleep 0.35"]
            onExited: reveal.start()
        }
        NumberAnimation {
            id: reveal
            target: root
            property: "progress"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.InOutCubic
            onFinished: {
                // the pointer was hidden at login (hyprland.start); bring it back
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { invisible = false } })"]);
                quitTimer.start();
            }
        }
        Timer {
            id: quitTimer
            interval: 100
            onTriggered: Qt.quit()
        }

        Variants {
            model: Quickshell.screens

            PanelWindow {
                required property var modelData
                screen: modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "desktop-fade"
                color: "transparent"
                mask: Region {}

                CenterFade {
                    anchors.fill: parent
                    mode: "reveal"
                    progress: root.progress
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/Theme.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io

    // The bar's colors, from the theme you picked (the themes block at the top of home.nix has all of them).
    // `current` follows ~/.local/state/theme/name, which the theme command writes, so
    // switching from a terminal recolors the bar too. Colors fade over `fade` ms.
    Singleton {
        id: theme

        // every theme: { id: { name, variant, colors: { bg, fg, accent, ... } } }
        readonly property var themes: (${builtins.toJSON qsThemes})
        readonly property var order: ${builtins.toJSON themes.order}
        readonly property string defaultTheme: "${themes.default}"
        readonly property string themeCommand: "${themeCmd}"
        // where your wallpapers for each theme go: <this>/<id>/
        readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

        property string current: defaultTheme
        readonly property var c: (themes[current] || themes[defaultTheme]).colors
        property int fade: 350
        // no fading while starting up (the saved theme is loaded right away instead)
        property bool ready: false
        Component.onCompleted: Qt.callLater(() => theme.ready = true)

        // Switch to another theme: the bar right away, everything else through `theme`.
        function set(id) {
            if (!themes[id] || id === current)
                return;
            current = id;
            Quickshell.execDetached([themeCommand, id]);
        }

        FileView {
            id: nameFile
            path: Quickshell.env("HOME") + "/.local/state/theme/name"
            blockLoading: true      // so the first frame already has the right colors
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                const id = text().trim();
                if (theme.themes[id])
                    theme.current = id;
            }
        }

        property color bg: c.bg
        // pills, buttons, hovered rows: the theme's overlay color, as see-through as
        // the glass under them (glassOpacity below), so everything has the same look
        property color pillSolid: c.overlay
        readonly property color pill: Qt.rgba(pillSolid.r, pillSolid.g, pillSolid.b, glassOpacity)
        property color pillIcon: c.dim
        property color text: c.fg
        property color red: c.red
        property color green: c.green
        property color blue: c.blue
        property color yellow: c.yellow
        property color magenta: c.magenta
        property color cyan: c.cyan
        property color orange: c.orange
        property color accent: c.accent

        Behavior on bg { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on pillSolid { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on pillIcon { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on text { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on red { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on green { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on blue { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on yellow { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on magenta { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on cyan { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on orange { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
        Behavior on accent { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }

        // The bar, its widgets, the dock and the notification popups: the theme's
        // background, see-through, with Hyprland blurring what's behind them (the layer
        // rules in the Hyprland config: "bar", "dock", "notification-popups"). The
        // pills, buttons and text boxes on them use it too (pill above, glass below).
        // 1 = solid, 0 = clear. 0.8 = mostly solid, so the theme's colors stay clear,
        // with a little of what's behind showing through.
        // The bar and the widgets that drop out of it all use this one color, so an
        // open widget and the bar read as one piece.
        property real glassOpacity: 0.8
        readonly property color glass: Qt.rgba(bg.r, bg.g, bg.b, glassOpacity)

        property int barHeight: 38
        // the bar curves inward under both ends (Theme.radius big), like it wraps
        // around the top corners of the screen; false = a plain straight bar
        property bool barCurve: true
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
    // Click to open. It closes when you click the same button again, open another
    // widget, or click anywhere that isn't the popup or the bar. Clicking other things
    // on the bar (workspaces, media buttons, ...) leaves it open.
    //
    //   Widget {
    //       button: Image { width: 18; height: 18; source: "file:///home/garinh/Pictures/x.png" }
    //       Text { text: "hello"; color: Theme.text }      // ← popup content
    //   }
    //
    // `button:` is what sits in the bar: any item (Image, Text, Row, Rectangle, ...).
    // Leave it out to get a plain icon from `icon:` instead.
    // Everything else you write inside Widget { } is the popup's content.
    // `popupShown` is true while the popup is on screen (opening, open or closing), for
    // content that should only do something while it can be seen.
    //
    // Popup size: leave popupWidth / popupHeight at 0 to fit the content, or set pixels.
    //
    // The popup is drawn inside the bar's own window, not in a window of its own. The
    // bar's window covers the whole screen for that (shell.qml; everything outside the
    // bar and an open popup is clear and lets clicks through), so the bar and an open
    // popup are one surface: Hyprland blurs them together, in one go, and there's no
    // edge between them. (As a separate popup window, Hyprland blurred it on its own,
    // after the bar, and the bar's glass got blurred into its top edge: a visible line.)
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
        property int duration: 320       // slide-down (open) time in ms, for an average-size popup
        property int closeDuration: 260  // slide-up (close) time in ms; closing a bit faster feels snappier
        // The slides' speed curves: cubic béziers [x1, y1, x2, y2], like CSS's
        // cubic-bezier(). Opening is a soft ease-out: quick out of the bar, then a long
        // gentle settle. Closing is a light ease-in-out, so it's pulled back in smoothly
        // instead of snapping. (Try them at cubic-bezier.com.)
        property var openCurve: [0.3, 0.6, 0.35, 1]
        property var closeCurve: [0.45, 0, 0.55, 1]
        // A bigger popup travels further, so it gets a little longer (up to 1.2x for a
        // very tall one, 0.9x for a small one) and moves at about the same pace either way.
        function timeFor(base, height) {
            return Math.round(base * (0.9 + 0.3 * Math.min(1, height / 900)));
        }

        // true while the popup is open (or opening)
        property bool open: false
        // How far open the popup is: 0 = closed, 1 = fully open. This is what gets
        // animated; the shape's height and the content's position follow it.
        property real openness: 0
        // the popup is on screen (opening, open, or closing)
        readonly property bool popupShown: openness > 0

        // For the bar (shell.qml): the window this sits in, and the popup's area, which
        // the bar adds to the part of its window that takes clicks while it's open.
        readonly property Item barContent: root.QsWindow.contentItem
        readonly property Item popupItem: popup

        // Children written inside Widget { } go into `area`, inside the popup.
        default property alias content: area.data

        implicitWidth: Math.max(Theme.moduleHeight, buttonLoader.width)
        implicitHeight: Theme.moduleHeight

        // Centered under the button, kept on the screen. Item positions aren't reactive,
        // so this is worked out when it opens and when its width changes.
        function place() {
            const win = root.QsWindow.contentItem;
            if (!win)
                return;
            const mid = root.mapToItem(win, root.width / 2, 0).x;
            popup.x = Math.round(Math.max(0, Math.min(win.width - popup.width, mid - popup.width / 2)));
        }

        function openPopup() {
            // one popup at a time: close whichever widget is open now (any monitor's bar)
            if (Ui.openWidget && Ui.openWidget !== root)
                Ui.openWidget.closePopup()
            Ui.openWidget = root
            root.open = true
            root.place()
            grab.active = true
            // Opening: sliding down out of the bar (openCurve)
            closeSlide.stop()
            resize.stop()
            popup.shownHeight = popup.bodyHeight
            openSlide.duration = root.timeFor(root.duration, popup.bodyHeight)
            openSlide.restart()
        }

        function closePopup() {
            if (!root.open)
                return
            root.open = false
            grab.active = false
            if (Ui.openWidget === root)
                Ui.openWidget = null
            // Closing: back up into the bar (closeCurve)
            openSlide.stop()
            resize.stop()
            closeSlide.duration = root.timeFor(root.closeDuration, popup.shownHeight)
            closeSlide.restart()
        }

        NumberAnimation {
            id: openSlide
            target: root
            property: "openness"
            to: 1
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.openCurve.concat([1, 1])
        }
        NumberAnimation {
            id: closeSlide
            target: root
            property: "openness"
            to: 0
            duration: root.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.closeCurve.concat([1, 1])
        }

        // Click-off-to-close, through Hyprland's focus grab. While the popup is open the
        // grab covers the bar's window (and so the popup in it): clicks there work
        // normally (other widgets and bar buttons react on the first click), and typed
        // keys go to it (the bar takes the keyboard while a popup is open, see
        // keyboardFocus in shell.qml). A click anywhere else ends the grab and Hyprland
        // tells us (onCleared), so the popup slides back into the bar. (Hyprland spends
        // that outside click on ending the grab; it doesn't reach the app you clicked.)
        HyprlandFocusGrab {
            id: grab
            windows: root.QsWindow.window ? [root.QsWindow.window] : []
            onCleared: root.closePopup()
        }
        // e.g. a monitor unplugged while its bar had the open popup
        Component.onDestruction: if (Ui.openWidget === root)
            Ui.openWidget = null

        // Log out / Restart / Power off: close, so the whole screen fades to black.
        Connections {
            target: Ui
            function onLeavingChanged() {
                if (Ui.leaving)
                    root.closePopup()
            }
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

        // The popup: drawn straight into the bar's window (see the top of this file),
        // with its top on the bar's bottom edge.
        Item {
            id: popup
            parent: root.QsWindow.contentItem
            z: 100                  // over the rest of the bar (its corner curves)
            visible: root.popupShown
            y: Theme.barHeight
            width: implicitWidth
            height: shape.height    // only the part showing takes clicks (the bar's mask)

            // Content size (+ padding), plus room for a curve on each side.
            readonly property real bodyWidth: root.popupWidth > 0 ? root.popupWidth : Math.ceil(area.childrenRect.width + root.padding * 2)
            readonly property real bodyHeight: root.popupHeight > 0 ? root.popupHeight : Math.ceil(area.childrenRect.height + root.padding * 2)
            implicitWidth: bodyWidth + root.curve * 2
            onImplicitWidthChanged: if (root.open)
                root.place()

            onBodyHeightChanged: {
                // open (or opening): glide to the new size; closed: just take it
                if (root.open) {
                    // a bit longer for a bigger change, so a whole section appearing
                    // doesn't rush and a single row doesn't drag (200 to 340 ms)
                    resize.duration = Math.round(Math.min(340, 200 + Math.abs(bodyHeight - shownHeight) * 0.25));
                    resize.to = bodyHeight;
                    resize.restart();
                } else if (!closeSlide.running) {
                    shownHeight = bodyHeight;
                }
            }

            // The height the shape shows. It follows bodyHeight, and glides there on the
            // same soft curve as opening (openCurve) when the content grows or shrinks
            // while the popup is open: a row appearing, a tab switching, the weather
            // arriving. (See onBodyHeightChanged above.)
            property real shownHeight: 0
            NumberAnimation {
                id: resize
                target: popup
                property: "shownHeight"
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.openCurve.concat([1, 1])
            }

            // The background: a box whose top corners flare outward into the bar.
            //
            //   bar  ────╮                    ╭────  bar
            //            │    (your content)  │
            //            ╰────────────────────╯
            Shape {
                id: shape
                width: popup.implicitWidth
                height: root.openness * popup.shownHeight     // grows down as it opens
                visible: height > 0.5
                preferredRendererType: Shape.CurveRenderer    // smooth, anti-aliased curves

                // Curves can't be bigger than half the height, so they grow in while opening.
                readonly property real c: Math.min(root.curve, height / 2)
                readonly property real r: Math.min(root.cornerRadius, height / 2)
                readonly property real boxLeft: root.curve                // left side of the box
                readonly property real boxRight: width - root.curve      // right side of the box

                ShapePath {
                    fillColor: Theme.glass         // the bar's color, in the same window: one piece
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
                    // Slides down out of the bar while opening. Once open it stays put, and
                    // the shape grows or shrinks underneath when the content does.
                    y: (root.openness - 1) * popup.shownHeight + root.padding
                    width: popup.bodyWidth - root.padding * 2
                    height: popup.bodyHeight - root.padding * 2
                    opacity: root.openness
                }
            }
        }
    }
  '';

  # Calendar events, timers and the stopwatch behind the clock widget (Clock.qml).
  xdg.configFile."quickshell/Planner.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io

    // Everything the clock widget keeps: calendar events, timers and the stopwatch.
    // One copy for every monitor's bar, saved in ~/.local/state/quickshell/planner.json,
    // so it all carries on after Quickshell restarts or the computer sleeps. That works
    // because times are kept as clock times ("ends at 14:05:30"), not as counters.
    //
    // A timer that runs out, and an event with a time when it comes, send a notification
    // (it shows up top right like any other) and play a sound.
    Singleton {
        id: p

        readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

        // [{ id, date, time, title, repeat, days, mdays, dates, until, skip, last }]
        //   date    the first day, "2026-10-23"
        //   time    "14:30" (24-hour), or "" for all day (no reminder)
        //   repeat  "" (just that day), "daily", "weekly", "monthly", "dates" or "yearly"
        //   days    weekly: which weekdays, 0 = Sunday ... 6 = Saturday
        //   mdays   monthly: which days of the month (1-31)
        //   dates   "dates": the exact days it happens on, picked one by one
        //   until   the last day it can happen ("" = no end); daily, weekly and monthly
        //           ones run for as long as you pick (a year to start with), yearly ones
        //           for good
        //   skip    days taken out of a repeating one ("skip this day")
        //   last    the day of the last reminder sent, so each day reminds once
        property var events: []
        // Reminders: things to do that aren't part of the schedule (take the bins out,
        // water the plants). Same fields and repeat rules as events, plus `done`: the
        // day you last ticked it off. They aren't on the calendar or in the bar; they
        // just remind you at their time. A time is required.
        property var reminders: []
        // [{ id, label, total, end, left, done }], all in ms. While running, `end` is when
        // it runs out (Date.now() time); while paused, end is 0 and `left` is what's left.
        property var timers: []
        // the stopwatch: when the current run started (0 = stopped), plus earlier runs
        property double swStart: 0
        property double swBase: 0
        property var laps: []          // total time at each lap, first lap first

        readonly property bool swRunning: swStart > 0

        // "now", updated by the ticker below (4 times a second while a timer runs)
        property double now: Date.now()

        // the running timer that ends first (for the bar), or null
        readonly property var nextTimer: {
            let best = null;
            for (const t of timers)
                if (!t.done && t.end > 0 && (!best || t.end < best.end))
                    best = t;
            return best;
        }
        readonly property bool timersRunning: nextTimer !== null
        // the timer the bar shows: the running one that ends first, else the last one you
        // paused (the list is newest first); null if there's neither
        readonly property var barTimer: nextTimer ?? (timers.find(t => !t.done && t.end === 0 && t.left > 0) ?? null)
        readonly property bool barTimerPaused: barTimer !== null && barTimer.end === 0

        // today's events, and the one the bar shows: the next one today with a time (still
        // shown for 30 minutes after it starts), else today's all-day one; null if none
        readonly property string todayKey: key(new Date(now))
        readonly property var today: eventsOn(todayKey)
        readonly property var nextEvent: {
            const d = new Date(now);
            const mins = d.getHours() * 60 + d.getMinutes();
            for (const e of today) {
                if (e.time === "")
                    continue;
                const t = e.time.split(":").map(Number);
                if (t[0] * 60 + t[1] + 30 >= mins)
                    return e;
            }
            return today.find(e => e.time === "") ?? null;
        }

        // ── the ticker: runs out timers and sends event reminders ──
        Timer {
            interval: p.timersRunning ? 250 : 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                p.now = Date.now();
                p.check();
            }
        }
        function check() {
            let changed = false;
            const ts = timers.map(t => {
                if (t.done || t.end === 0 || now < t.end)
                    return t;
                changed = true;
                ring("Timer done", t.label !== "" ? t.label : fmtLength(t.total) + " timer");
                return Object.assign({}, t, { "done": true });
            });
            // each event's reminder for today, once
            const k = key(new Date(now));
            const es = events.map(e => {
                if (e.time === "" || e.last === k || !occursOn(e, k))
                    return e;
                const due = dueAt(k, e.time);
                if (now < due)
                    return e;
                changed = true;
                // missed by more than 15 minutes (Quickshell or the computer was off): skip it
                if (now - due < 15 * 60000)
                    ring(e.title, fmtTime(e.time) + (e.repeat ? "  ·  " + repeatText(e) : ""));
                return Object.assign({}, e, { "last": k });
            });
            // and each reminder's, for today (not if it's ticked off already)
            const rs = reminders.map(e => {
                if (e.last === k || e.done === k || !occursOn(e, k))
                    return e;
                const due = dueAt(k, e.time);
                if (now < due)
                    return e;
                changed = true;
                if (now - due < 15 * 60000)
                    ring("Reminder", e.title, "bell");
                return Object.assign({}, e, { "last": k });
            });
            if (changed) {
                timers = ts;
                events = es;
                reminders = rs;
                save();
            }
        }
        // A notification that rings: its sound plays over and over until you X it (on the
        // popup or in the notification center) or mark it read. The notification server
        // in shell.qml does the ringing, for any notification with an x-repeat-sound hint
        // (the name of the sound, Sounds.qml).
        function ring(title, body, sound) {
            Quickshell.execDetached(["${pkgs.libnotify}/bin/notify-send", "-a", "Clock", "-i", "alarm", "-h", "boolean:suppress-sound:true", "-h", "string:x-repeat-sound:" + (sound || "alarm-clock-elapsed"), title, body]);
        }

        // ── saving and loading ──
        FileView {
            id: file
            path: p.stateDir + "/planner.json"
            blockLoading: true
            printErrors: false
        }
        Component.onCompleted: {
            try {
                const s = JSON.parse(file.text() || "{}");
                // events saved before repeating ones existed: same thing, new fields
                events = (s.events || []).map(e => Object.assign({
                        "repeat": "",
                        "days": [],
                        "mdays": [],
                        "dates": [],
                        "until": "",
                        "skip": [],
                        "last": e.notified ? e.date : ""
                    }, e));
                reminders = s.reminders || [];
                timers = s.timers || [];
                swStart = s.swStart || 0;
                swBase = s.swBase || 0;
                laps = s.laps || [];
            } catch (e) {}
        }
        // written to a new file that then replaces the old one, so it's never half-written
        function save() {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/planner.json.$$\" && mv -f \"$1/planner.json.$$\" \"$1/planner.json\"", "sh", stateDir, JSON.stringify({
                    "events": events,
                    "reminders": reminders,
                    "timers": timers,
                    "swStart": swStart,
                    "swBase": swBase,
                    "laps": laps
                })]);
        }
        function newId() {
            return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
        }

        // ── dates and times ──
        // a date as the key events are filed under: "2026-10-23"
        function key(d) {
            return Qt.formatDate(d, "yyyy-MM-dd");
        }
        function dateOf(k) {
            const a = k.split("-").map(Number);
            return new Date(a[0], a[1] - 1, a[2]);
        }
        // when "HH:MM" on day k is, in Date.now() time
        function dueAt(k, hm) {
            const d = dateOf(k);
            const t = hm.split(":").map(Number);
            d.setHours(t[0], t[1], 0, 0);
            return d.getTime();
        }
        // what you type for an event's time -> "HH:MM" (24-hour), "" for none (all day),
        // or null if it isn't a time. "2pm", "2:30 pm", "2:30p", "14:30", "9" all work.
        function parseTime(text) {
            const t = text.trim().toLowerCase().replace(/\s+/g, "").replace(/\./g, "");
            if (t === "")
                return "";
            const m = t.match(/^(\d{1,2})(?::?(\d{2}))?(am|pm|a|p)?$/);
            if (!m)
                return null;
            let h = Number(m[1]);
            const min = m[2] ? Number(m[2]) : 0;
            if (min > 59)
                return null;
            if (m[3]) {
                if (h < 1 || h > 12)
                    return null;
                const pm = m[3][0] === "p";
                if (pm && h < 12)
                    h += 12;
                if (!pm && h === 12)
                    h = 0;
            } else if (h > 23) {
                return null;
            }
            return String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0");
        }
        // "14:30" -> "2:30 PM" (your locale's clock)
        function fmtTime(hm) {
            if (hm === "")
                return "All day";
            const t = hm.split(":").map(Number);
            return Qt.formatTime(new Date(2000, 0, 1, t[0], t[1]), Qt.locale().timeFormat(Locale.ShortFormat));
        }
        // what you type for a timer's length -> ms, or 0 if it isn't one.
        // "5" = 5 minutes, "1:30" = 1 min 30 s, "1:00:00" = an hour, "1h 20m", "90s", "2.5"
        function parseDuration(text) {
            const t = text.trim().toLowerCase().replace(/\s+/g, "");
            if (t === "")
                return 0;
            if (/^\d+(\.\d+)?$/.test(t))
                return Math.round(Number(t) * 60000);
            if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
                const a = t.split(":").map(Number);
                const s = a.length === 3 ? a[0] * 3600 + a[1] * 60 + a[2] : a[0] * 60 + a[1];
                return s * 1000;
            }
            const m = t.match(/^(?:(\d+(?:\.\d+)?)h)?(?:(\d+)m(?:in)?)?(?:(\d+)s)?$/);
            if (!m || (!m[1] && !m[2] && !m[3]))
                return 0;
            return Math.round(((Number(m[1]) || 0) * 3600 + (Number(m[2]) || 0) * 60 + (Number(m[3]) || 0)) * 1000);
        }
        // ms -> "4:05", or "1:04:05" from an hour up (rounded up: "0:01" until it's done)
        function fmtLeft(ms) {
            const s = Math.ceil(Math.max(0, ms) / 1000);
            const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
            const ss = String(sec).padStart(2, "0");
            return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
        }
        // ms -> "5 min", "1 h 30 min", "45 s"
        function fmtLength(ms) {
            const s = Math.round(ms / 1000);
            const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
            const out = [];
            if (h > 0)
                out.push(h + " h");
            if (m > 0)
                out.push(m + " min");
            if (sec > 0 || out.length === 0)
                out.push(sec + " s");
            return out.join(" ");
        }
        // ms -> "01:23.45", or "1:01:23.45" from an hour up
        function fmtWatch(ms) {
            const cs = Math.floor(Math.max(0, ms) / 10);
            const h = Math.floor(cs / 360000), m = Math.floor(cs % 360000 / 6000), s = Math.floor(cs % 6000 / 100), c = cs % 100;
            const tail = String(s).padStart(2, "0") + "." + String(c).padStart(2, "0");
            return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + tail : String(m).padStart(2, "0") + ":" + tail;
        }

        // ── events ──
        // does event e happen on day k ("2026-10-23")?
        function occursOn(e, k) {
            if (k < e.date || (e.until && k > e.until) || (e.skip || []).indexOf(k) >= 0)
                return false;
            const r = e.repeat || "";
            if (r === "")
                return k === e.date;
            if (r === "daily")
                return true;
            if (r === "dates")
                return (e.dates || []).indexOf(k) >= 0;
            const d = dateOf(k), s = dateOf(e.date);
            if (r === "weekly")
                return (e.days && e.days.length > 0 ? e.days : [s.getDay()]).indexOf(d.getDay()) >= 0;
            if (r === "monthly")         // a month without that day (the 31st) is skipped
                return (e.mdays && e.mdays.length > 0 ? e.mdays : [s.getDate()]).indexOf(d.getDate()) >= 0;
            if (r === "yearly")
                return d.getDate() === s.getDate() && d.getMonth() === s.getMonth();
            return false;
        }
        function eventsOn(k) {
            return events.filter(e => occursOn(e, k)).sort((a, b) => a.time === b.time ? 0 : a.time === "" ? -1 : b.time === "" ? 1 : a.time < b.time ? -1 : 1);
        }
        readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        // 1 -> "1st", 22 -> "22nd"
        function ordinal(n) {
            const s = n % 100 >= 11 && n % 100 <= 13 ? "th" : ["th", "st", "nd", "rd"][n % 10] || "th";
            return n + s;
        }
        // in words: "Every day", "Every Mon, Wed", "Every month on the 1st, 15th",
        // "Every year on Oct 23", "On 4 dates: Oct 26, Oct 30, Nov 2 +1" (+ "until ...")
        function repeatText(e) {
            const r = e.repeat || "";
            const start = dateOf(e.date);
            let t = "";
            if (r === "daily")
                t = "Every day";
            else if (r === "weekly")
                t = "Every " + [1, 2, 3, 4, 5, 6, 0].filter(d => (e.days || []).indexOf(d) >= 0).map(d => dayNames[d]).join(", ");
            else if (r === "monthly")
                t = "Every month on the " + (e.mdays && e.mdays.length > 0 ? e.mdays : [start.getDate()]).slice().sort((a, b) => a - b).map(ordinal).join(", ");
            else if (r === "yearly")
                t = "Every year on " + Qt.formatDate(start, "MMM d");
            else if (r === "dates") {
                const ds = (e.dates || []).slice().sort();
                t = (ds.length === 1 ? "On 1 date: " : "On " + ds.length + " dates: ") + ds.slice(0, 3).map(k => Qt.formatDate(dateOf(k), "MMM d")).join(", ") + (ds.length > 3 ? " +" + (ds.length - 3) : "");
                return t;
            }
            if (t !== "" && e.until)
                t += " until " + Qt.formatDate(dateOf(e.until), "MMM d, yyyy");
            return t;
        }
        // How an event added on day k with this repeat rule would look (the summary line
        // in the Repeat page, and what addEvent saves). rule: { repeat, days, mdays, dates,
        // span }:
        //   repeat  "", "daily", "weekly", "monthly", "dates" or "yearly"
        //   days    weekly: weekdays (0 = Sunday)   mdays  monthly: days of the month
        //   dates   "dates": the exact days ("2026-10-26", ...)
        //   span    daily / weekly / monthly: how many months it runs; 0 = no end
        function previewRepeat(k, rule) {
            const r = rule.repeat || "";
            let date = k, until = "";
            if (r === "dates" && rule.dates.length > 0)
                date = rule.dates.slice().sort()[0];       // starts on the first one
            if ((r === "daily" || r === "weekly" || r === "monthly") && rule.span > 0) {
                const end = dateOf(k);
                end.setMonth(end.getMonth() + rule.span);
                end.setDate(end.getDate() - 1);            // up to the day before
                until = key(end);
            }
            return {
                "date": date,
                "repeat": r,
                "days": r === "weekly" ? rule.days : [],
                "mdays": r === "monthly" ? rule.mdays : [],
                "dates": r === "dates" ? rule.dates.slice().sort() : [],
                "until": until
            };
        }
        // a new event on day k ("2026-10-23"), with a repeat rule (previewRepeat above)
        function addEvent(k, time, title, rule) {
            const e = Object.assign(previewRepeat(k, rule || { "repeat": "" }), {
                "id": newId(),
                "time": time,
                "title": title,
                "skip": [],
                "last": ""
            });
            // already past today: no reminder for today
            const today = key(new Date());
            if (time !== "" && occursOn(e, today) && dueAt(today, time) <= Date.now())
                e.last = today;
            events = events.concat([e]);
            save();
        }
        // ── every event, for the "All events" list ──
        // the last day an event happened, up to today ("" if it hasn't yet)
        function lastDay(e) {
            const d = new Date(now);
            const first = dateOf(e.date);
            for (let i = 0; i < 400 && d >= first; i++) {
                const k = key(d);
                if (occursOn(e, k))
                    return k;
                d.setDate(d.getDate() - 1);
            }
            return e.date;
        }
        // [{ e, next, last, group }]: what's coming, by its next day and time, then
        // what's over, most recent first
        readonly property var allEvents: {
            const rows = events.map(e => {
                const next = nextDay(e);
                return {
                    "e": e,
                    "next": next,
                    "last": next === "" ? lastDay(e) : "",
                    "group": next === "" ? "Over" : "Coming up"
                };
            });
            const coming = rows.filter(r => r.next !== "").sort((a, b) => a.next === b.next ? (a.e.time < b.e.time ? -1 : 1) : a.next < b.next ? -1 : 1);
            const over = rows.filter(r => r.next === "").sort((a, b) => a.last < b.last ? 1 : -1);
            return coming.concat(over);
        }

        // ── reminders ──
        // a new reminder at time ("14:30"), starting today, with a repeat rule
        function addReminder(time, title, rule) {
            const today = key(new Date());
            const e = Object.assign(previewRepeat(today, rule || { "repeat": "" }), {
                "id": newId(),
                "time": time,
                "title": title,
                "skip": [],
                "last": "",
                "done": ""
            });
            if (occursOn(e, today) && dueAt(today, time) <= Date.now())
                e.last = today;          // its time today has passed: from the next one on
            reminders = reminders.concat([e]);
            save();
        }
        function removeReminder(id) {
            reminders = reminders.filter(e => e.id !== id);
            save();
        }
        // tick today's off (or untick it); a ticked one doesn't remind you today
        function toggleDone(id) {
            const k = key(new Date());
            reminders = reminders.map(e => e.id === id ? Object.assign({}, e, {
                        "done": e.done === k ? "" : k
                    }) : e);
            save();
        }
        // the next day it's due, from today on ("" = never again); a ticked-off or
        // already-reminded today counts as done
        function nextDay(e) {
            const d = new Date(now);
            for (let i = 0; i < 400; i++) {
                const k = key(d);
                if (e.until && k > e.until)
                    return "";
                if (occursOn(e, k) && !(i === 0 && e.done === k))
                    return k;
                d.setDate(d.getDate() + 1);
            }
            return "";
        }
        // "Today", "Tomorrow", "Mon, Oct 26"
        function dayText(k) {
            if (k === "")
                return "No more";
            const t = new Date(now);
            if (k === key(t))
                return "Today";
            t.setDate(t.getDate() + 1);
            if (k === key(t))
                return "Tomorrow";
            return Qt.formatDate(dateOf(k), "ddd, MMM d");
        }
        // reminders, soonest first, for the list
        readonly property var reminderList: reminders.map(e => ({
                    "e": e,
                    "next": nextDay(e)
                })).sort((a, b) => (a.next || "9999") === (b.next || "9999") ? (a.e.time < b.e.time ? -1 : 1) : (a.next || "9999") < (b.next || "9999") ? -1 : 1)
        readonly property int remindersToday: reminderList.filter(x => x.next === key(new Date(now))).length

        // the whole event (every day it repeats on)
        function removeEvent(id) {
            events = events.filter(e => e.id !== id);
            save();
        }
        // just one day of a repeating event
        function skipDay(id, k) {
            events = events.map(e => e.id === id ? Object.assign({}, e, {
                        "skip": (e.skip || []).concat([k])
                    }) : e);
            save();
        }

        // ── timers ──
        function left(t) {
            return t.done ? 0 : t.end > 0 ? Math.max(0, t.end - now) : t.left;
        }
        function addTimer(ms, label) {
            if (ms <= 0)
                return;
            now = Date.now();
            timers = [{
                    "id": newId(),
                    "label": label,
                    "total": ms,
                    "end": now + ms,
                    "left": ms,
                    "done": false
                }].concat(timers);
            save();
        }
        function updateTimer(id, f) {
            now = Date.now();
            timers = timers.map(t => t.id === id ? Object.assign({}, t, f(t)) : t);
            save();
        }
        function pauseTimer(id) {
            updateTimer(id, t => ({
                        "end": 0,
                        "left": Math.max(0, t.end - now)
                    }));
        }
        function resumeTimer(id) {
            updateTimer(id, t => ({
                        "end": now + t.left
                    }));
        }
        function restartTimer(id) {
            updateTimer(id, t => ({
                        "end": now + t.total,
                        "left": t.total,
                        "done": false
                    }));
        }
        function removeTimer(id) {
            timers = timers.filter(t => t.id !== id);
            save();
        }

        // ── the stopwatch ──
        function watchTime(at) {
            return swBase + (swStart > 0 ? at - swStart : 0);
        }
        function startWatch() {
            if (swStart === 0) {
                swStart = Date.now();
                save();
            }
        }
        function pauseWatch() {
            if (swStart > 0) {
                swBase += Date.now() - swStart;
                swStart = 0;
                save();
            }
        }
        function lap() {
            if (swStart > 0) {
                laps = laps.concat([watchTime(Date.now())]);
                save();
            }
        }
        function resetWatch() {
            swStart = 0;
            swBase = 0;
            laps = [];
            save();
        }
    }
  '';

  # What a Repeat page has picked (RepeatPicker.qml edits it; Planner.qml reads its rule).
  xdg.configFile."quickshell/RepeatState.qml".text = ''
    import QtQuick

    // How often something happens, as picked on a Repeat page (RepeatPicker.qml):
    // the kind, its days, and for how long. `rule` is what Planner.addEvent /
    // addReminder take. The clock widget has one for events and one for reminders.
    QtObject {
        id: pick

        // the day it all starts from (its weekday, its date...)
        property string startKey: ""
        // a different start day: the picks start over from it, same kind
        onStartKeyChanged: {
            const r = repeat;
            reset();
            if (r !== "")
                setRepeat(r);
        }
        property string repeat: ""     // "", "daily", "weekly", "monthly", "dates", "yearly"
        property var days: []          // weekly: weekdays, 0 = Sunday
        property var mdays: []         // monthly: days of the month
        property var dates: []         // dates: the exact days
        property int span: 12          // daily / weekly / monthly: months it runs, 0 = no end
        readonly property var rule: ({
                "repeat": repeat,
                "days": days,
                "mdays": mdays,
                "dates": dates,
                "span": span
            })
        // a sensible start for each kind, from the start day
        function setRepeat(r) {
            const d = Planner.dateOf(startKey);
            if (r === "weekly" && days.length === 0)
                days = [d.getDay()];
            if (r === "monthly" && mdays.length === 0)
                mdays = [d.getDate()];
            if (r === "dates" && dates.length === 0)
                dates = [startKey];
            repeat = r;
        }
        // flip one in or out of a list (keeping at least one)
        function toggled(list, x) {
            const i = list.indexOf(x);
            if (i < 0)
                return list.concat([x]);
            return list.length > 1 ? list.filter(y => y !== x) : list;
        }
        function reset() {
            repeat = "";
            days = [];
            mdays = [];
            dates = [];
            span = 12;
        }
    }
  '';

  # A Repeat page: pick how often something happens (the clock's events and reminders).
  xdg.configFile."quickshell/RepeatPicker.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic

    // How often something happens (an event, a reminder). Pick a kind, then the days:
    //   Weekly   any weekdays (swim lessons: Mon and Wed)
    //   Monthly  any days of the month (the 1st and the 15th)
    //   Dates    any days at all, picked one by one on a calendar
    //   Daily / Yearly  every day, or every year on the start day
    // Daily, weekly and monthly ones run for as long as you pick (a year to start
    // with). What's picked lives in `pick` (a RepeatState), so it's kept when this
    // page slides away; Back and Done just say so (done).
    Column {
        id: picker

        property string startKey: ""     // the day it starts from
        property QtObject pick: null     // a RepeatState: what's picked
        property string heading: "Repeat"
        signal done                      // back, or Done
        spacing: 10

        // ‹  Repeat                Done
        Item {
            width: parent.width
            height: 26
            IconButton {
                id: repeatBack
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_back"
                onClicked: picker.done()
            }
            Text {
                anchors.left: repeatBack.right
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: picker.heading
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 1.1
                font.weight: 700
                font.letterSpacing: Theme.letterSpacing
            }
            Chip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "Done"
                selected: true
                onClicked: picker.done()
            }
        }

        // the kind
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: [
                    {
                        id: "",
                        name: "Never"
                    },
                    {
                        id: "daily",
                        name: "Daily"
                    },
                    {
                        id: "weekly",
                        name: "Weekly"
                    },
                    {
                        id: "monthly",
                        name: "Monthly"
                    },
                    {
                        id: "dates",
                        name: "Dates"
                    },
                    {
                        id: "yearly",
                        name: "Yearly"
                    }
                ]
                Chip {
                    required property var modelData
                    label: modelData.name
                    selected: picker.pick.repeat === modelData.id
                    onClicked: picker.pick.setRepeat(modelData.id)
                }
            }
        }

        // ── Weekly: a week, Monday first like the calendar ──
        Row {
            visible: picker.pick.repeat === "weekly"
            spacing: 4
            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0]
                Rectangle {
                    id: wd
                    required property int modelData
                    readonly property bool on: picker.pick.days.indexOf(modelData) >= 0
                    width: (picker.width - 6 * 4) / 7
                    height: 44
                    radius: Theme.radius
                    color: on ? Theme.accent : wdMouse.containsMouse ? Theme.pill : "transparent"
                    border.width: 1
                    border.color: on ? Theme.accent : Theme.pill
                    scale: wdMouse.pressed ? 0.9 : 1
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
                        text: Planner.dayNames[wd.modelData]
                        color: wd.on ? Theme.bg : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                        font.weight: 700
                    }
                    MouseArea {
                        id: wdMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.pick.days = picker.pick.toggled(picker.pick.days, wd.modelData)
                    }
                }
            }
        }

        // ── Monthly: the days of a month, 1 to 31 ──
        Grid {
            visible: picker.pick.repeat === "monthly"
            columns: 7
            spacing: 4
            Repeater {
                model: 31
                Rectangle {
                    id: md
                    required property int index
                    readonly property int day: index + 1
                    readonly property bool on: picker.pick.mdays.indexOf(day) >= 0
                    width: (picker.width - 6 * 4) / 7
                    height: 30
                    radius: height / 2
                    color: on ? Theme.accent : mdMouse.containsMouse ? Theme.pill : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: md.day
                        color: md.on ? Theme.bg : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        font.weight: md.on ? 700 : 500
                    }
                    MouseArea {
                        id: mdMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.pick.mdays = picker.pick.toggled(picker.pick.mdays, md.day)
                    }
                }
            }
        }

        // ── Dates: any days, on a calendar of their own ──
        Column {
            id: datePick
            visible: picker.pick.repeat === "dates"
            width: parent.width
            spacing: 6

            // the month on show (starts on the day picked in the calendar)
            property int viewYear: Planner.dateOf(picker.startKey).getFullYear()
            property int viewMonth: Planner.dateOf(picker.startKey).getMonth()
            function step(by) {
                const d = new Date(viewYear, viewMonth + by, 1);
                viewYear = d.getFullYear();
                viewMonth = d.getMonth();
            }

            Item {
                width: parent.width
                height: 26
                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_left"
                    onClicked: datePick.step(-1)
                }
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDate(new Date(datePick.viewYear, datePick.viewMonth, 1), "MMMM yyyy")
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize
                    font.weight: 700
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_right"
                    onClicked: datePick.step(1)
                }
            }
            DayOfWeekRow {
                width: dateGrid.width
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
            MonthGrid {
                id: dateGrid
                width: parent.width
                height: 186
                month: datePick.viewMonth
                year: datePick.viewYear

                delegate: Item {
                    id: dd
                    required property var model
                    readonly property string dayKey: Planner.key(model.date)
                    readonly property bool on: picker.pick.dates.indexOf(dayKey) >= 0
                    readonly property bool inMonth: model.month === dateGrid.month
                    implicitWidth: 34
                    implicitHeight: 28
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: dd.on ? Theme.accent : ddMouse.containsMouse ? Theme.pill : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: dd.model.day
                        color: dd.on ? Theme.bg : Theme.text
                        opacity: dd.inMonth ? 1 : 0.3
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        font.weight: dd.on ? 700 : 500
                    }
                    MouseArea {
                        id: ddMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.pick.dates = picker.pick.toggled(picker.pick.dates, dd.dayKey)
                    }
                }
            }
        }

        // ── Daily / Yearly: nothing to pick ──
        Text {
            visible: picker.pick.repeat === "daily" || picker.pick.repeat === "yearly" || picker.pick.repeat === ""
            width: parent.width
            wrapMode: Text.Wrap
            text: picker.pick.repeat === "" ? "Just once, on " + Qt.formatDate(Planner.dateOf(picker.startKey), "dddd, MMMM d") + "." : picker.pick.repeat === "daily" ? "Every day, starting " + Qt.formatDate(Planner.dateOf(picker.startKey), "MMMM d") + "." : "Every year on " + Qt.formatDate(Planner.dateOf(picker.startKey), "MMMM d") + ", for good (birthdays, anniversaries)."
            color: Theme.text
            opacity: 0.7
            font.family: Theme.font
            font.pixelSize: Theme.textSize * 0.9
        }

        // ── for how long (daily, weekly, monthly) ──
        Column {
            visible: picker.pick.repeat === "daily" || picker.pick.repeat === "weekly" || picker.pick.repeat === "monthly"
            width: parent.width
            spacing: 4
            Text {
                text: "For"
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.85
                font.weight: 600
            }
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: [
                        {
                            months: 1,
                            name: "1 month"
                        },
                        {
                            months: 3,
                            name: "3 months"
                        },
                        {
                            months: 6,
                            name: "6 months"
                        },
                        {
                            months: 12,
                            name: "1 year"
                        },
                        {
                            months: 0,
                            name: "No end"
                        }
                    ]
                    Chip {
                        required property var modelData
                        label: modelData.name
                        selected: picker.pick.span === modelData.months
                        onClicked: picker.pick.span = modelData.months
                    }
                }
            }
        }

        // what it'll do, in words
        Text {
            visible: picker.pick.repeat !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Planner.repeatText(Planner.previewRepeat(picker.startKey, picker.pick.rule))
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.textSize * 0.85
            font.weight: 600
        }
    }
  '';

  # The clock in the bar, with the calendar, timers and stopwatch (data: Planner.qml).
  xdg.configFile."quickshell/Clock.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic
    import Quickshell

    // ── Clock ──
    // In the bar: the time, plus the time left on the timer that ends first while one
    // runs (or on the one you paused, marked "paused"; the pause / play button beside
    // the clock in shell.qml goes with it). Click for the card: the time and date, then three tabs:
    //   Calendar   the month (‹ › to change it, the month's name for back to today).
    //              Days with events get a dot. Click a day to see its events and to add
    //              one: a title, and a time if you want a reminder then ("9:30" with the
    //              AM / PM switch beside it, or "2pm", "14:30"); no time = all day.
    //   Timers     a preset, or type a length ("5" = 5 minutes, "1:30", "1h 20m") and an
    //              optional label. Pause, start again, remove. When one runs out you get a
    //              notification and a sound.
    //   Stopwatch  start / pause, laps, reset.
    // Everything lives in Planner.qml, which saves it, so timers keep going and events
    // stay put through restarts and sleep.
    Widget {
        id: root

        property date now: new Date()      // the bar's clock: shell.qml passes clock.date

        // the time; then a running timer's time left, or else today's next event
        // (its name and time; an all-day one just by name)
        button: Pill {
            readonly property var ev: Planner.nextEvent
            function short(t) {
                return t.length > 18 ? t.slice(0, 17).trim() + "…" : t;
            }
            readonly property var tm: Planner.barTimer
            icon: tm ? "timer" : ev ? "event" : "schedule"
            iconColor: tm || ev ? Theme.accent : Theme.red
            text: Qt.formatDateTime(root.now, "hh:mm AP") + (tm ? "  ·  " + Planner.fmtLeft(Planner.left(tm)) + (Planner.barTimerPaused ? " paused" : "") : ev ? "  ·  " + short(ev.title) + (ev.time !== "" ? " " + Planner.fmtTime(ev.time) : "") : "")
        }

        Column {
            id: card
            width: 330
            spacing: 8

            property string tab: "calendar"     // "calendar", "reminders", "timers" or "stopwatch"
            property string page: "main"        // the tab's page: "main", "repeat", or "all" (every event)
            onTabChanged: page = "main"
            // the month on show, and the day picked (its events are listed)
            property int viewYear: root.now.getFullYear()
            property int viewMonth: root.now.getMonth()
            property string selected: Planner.key(root.now)

            // back to this month and today each time it opens
            readonly property bool open: root.popupShown
            onOpenChanged: if (open) {
                viewYear = root.now.getFullYear();
                viewMonth = root.now.getMonth();
                selected = Planner.key(root.now);
                page = "main";
            }
            function stepMonth(by) {
                const d = new Date(viewYear, viewMonth + by, 1);
                viewYear = d.getFullYear();
                viewMonth = d.getMonth();
            }

            // ── time and date ──
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "hh:mm AP")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 2.4
                font.weight: 700
                font.letterSpacing: Theme.letterSpacing
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                font.weight: 600
            }

            // ── tabs ──
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 4
                bottomPadding: 2
                spacing: 4
                Repeater {
                    model: [
                        {
                            id: "calendar",
                            name: "Calendar"
                        },
                        {
                            id: "reminders",
                            name: "Reminders"
                        },
                        {
                            id: "timers",
                            name: "Timers"
                        },
                        {
                            id: "stopwatch",
                            name: "Stopwatch"
                        }
                    ]
                    Chip {
                        required property var modelData
                        // reminders: how many are due today
                        label: modelData.name + (modelData.id === "reminders" && Planner.remindersToday > 0 ? " " + Planner.remindersToday : "")
                        selected: card.tab === modelData.id
                        onClicked: card.tab = modelData.id
                    }
                }
            }

            // ════ Calendar ════
            // Two pages side by side, and the card swipes between them: the calendar, and
            // "Repeat" (how often a new event happens; the Repeat button under the form).
            Item {
                id: calPages
                visible: card.tab === "calendar"
                width: parent.width
                // the page on show's height; while swiping, the taller of the two, so neither
                // gets cut off on the way
                height: mainSlide.running || repeatSlide.running || allSlide.running ? Math.max(repeatPage.height, calMain.height, allPage.height) : card.page === "repeat" ? repeatPage.height : card.page === "all" ? allPage.height : calMain.height
                clip: true

                // the slide: the same soft curve the popups open on
                readonly property var curve: [0.3, 0.6, 0.35, 1, 1, 1]

                // ── what the Repeat page has picked (used by the + button) ──
                RepeatState {
                    id: repeatPick
                    startKey: card.selected
                }

                // ════ page 1: the calendar ════
                Column {
                    id: calMain
                    x: card.page === "main" ? 0 : -calPages.width - 24
                    Behavior on x {
                        NumberAnimation {
                            id: mainSlide
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calPages.curve
                        }
                    }
                    width: parent.width
                    spacing: 6

                    // ‹  October 2026  ›
                    Item {
                        width: parent.width
                        height: 26
                        IconButton {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "chevron_left"
                            onClicked: card.stepMonth(-1)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDate(new Date(card.viewYear, card.viewMonth, 1), "MMMM yyyy")
                            color: monthMouse.containsMouse ? Theme.text : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 1.1
                            font.weight: 700
                            font.letterSpacing: Theme.letterSpacing
                            MouseArea {
                                id: monthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {         // back to today
                                    card.viewYear = root.now.getFullYear();
                                    card.viewMonth = root.now.getMonth();
                                    card.selected = Planner.key(root.now);
                                }
                            }
                        }
                        IconButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "chevron_right"
                            onClicked: card.stepMonth(1)
                        }
                    }

                    // Sun Mon Tue ...
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

                    MonthGrid {
                        id: grid
                        width: parent.width
                        height: 186
                        month: card.viewMonth          // 0 = January
                        year: card.viewYear

                        delegate: Item {
                            id: day
                            required property var model
                            readonly property string dayKey: Planner.key(model.date)
                            // compared against the clock, so it moves to the new day at midnight
                            readonly property bool isToday: dayKey === Planner.key(root.now)
                            readonly property bool isPicked: dayKey === card.selected
                            readonly property bool inMonth: model.month === grid.month

                            implicitWidth: 34
                            implicitHeight: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: day.isToday ? Theme.accent : dayMouse.containsMouse ? Theme.pill : "transparent"
                                border.width: day.isPicked && !day.isToday ? 1.5 : 0
                                border.color: Theme.accent
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                text: day.model.day
                                color: day.isToday ? Theme.bg : Theme.text
                                opacity: day.inMonth ? 1 : 0.3      // days of the months either side
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: day.isToday || day.isPicked ? 700 : 500
                            }
                            // has events
                            Rectangle {
                                visible: Planner.eventsOn(day.dayKey).length > 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: 4
                                height: 4
                                radius: 2
                                color: day.isToday ? Theme.bg : Theme.accent
                                opacity: day.inMonth ? 1 : 0.4
                            }
                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    card.selected = day.dayKey;
                                    if (!day.inMonth)
                                        card.stepMonth(day.model.date < new Date(card.viewYear, card.viewMonth, 1) ? -1 : 1);
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.pill
                    }

                    // the picked day's events; "All events" swipes to the list of every one
                    Item {
                        width: parent.width
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.selected === Planner.key(root.now) ? "Today" : Qt.formatDate(Planner.dateOf(card.selected), "dddd, MMMM d")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 700
                            font.letterSpacing: Theme.letterSpacing
                        }
                        Chip {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: "All events" + (Planner.events.length > 0 ? "  " + Planner.events.length : "")
                            onClicked: card.page = "all"
                        }
                    }
                    ListView {
                        id: eventList
                        width: parent.width
                        height: Math.min(contentHeight, 150)
                        visible: count > 0
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: Planner.eventsOn(card.selected)
                        ScrollBar.vertical: ThinScrollBar {}

                        delegate: Rectangle {
                            id: ev
                            required property var modelData
                            readonly property bool hoveredRow: evMouse.containsMouse
                            width: ListView.view.width
                            height: 30
                            radius: Theme.radius
                            color: evMouse.containsMouse ? Theme.pill : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            // hover the row for its remove button (the button is inside, so
                            // pointing at it keeps the row hovered)
                            MouseArea {
                                id: evMouse
                                anchors.fill: parent
                                hoverEnabled: true

                            Text {
                                id: evTime
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72
                                text: Planner.fmtTime(ev.modelData.time)
                                color: ev.modelData.time === "" ? Theme.text : Theme.accent
                                opacity: ev.modelData.time === "" ? 0.6 : 1
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.9
                                font.weight: 700
                            }
                            Row {
                                anchors.left: evTime.right
                                anchors.right: evButtons.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    width: Math.min(implicitWidth, parent.width - (evRepeat.visible ? evRepeat.width + 4 : 0))
                                    text: ev.modelData.title
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize
                                    font.weight: 600
                                }
                                // repeats: a little loop (hover the row for how)
                                Text {
                                    id: evRepeat
                                    visible: !!ev.modelData.repeat
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "repeat"
                                    color: Theme.accent
                                    opacity: 0.8
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize * 0.85
                                    font.variableAxes: Theme.iconAxes
                                }
                            }
                            Row {
                                id: evButtons
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: evMouse.containsMouse
                                width: visible ? implicitWidth : 0     // the title gets the room until then
                                // a repeating one: take just this day out
                                IconButton {
                                    visible: !!ev.modelData.repeat
                                    icon: "event_busy"
                                    onClicked: Planner.skipDay(ev.modelData.id, card.selected)
                                }
                                // delete it (a repeating one: every day of it)
                                IconButton {
                                    icon: ev.modelData.repeat ? "delete_sweep" : "close"
                                    iconColor: Theme.red
                                    onClicked: Planner.removeEvent(ev.modelData.id)
                                }
                            }
                            }
                        }
                    }
                    // how the event you're pointing at repeats, and what its buttons do
                    Text {
                        readonly property var hovered: {
                            for (let i = 0; i < eventList.count; i++) {
                                const it = eventList.itemAtIndex(i);
                                if (it && it.hoveredRow)
                                    return it.modelData;
                            }
                            return null;
                        }
                        visible: !!hovered && !!hovered.repeat
                        width: parent.width
                        leftPadding: 8
                        wrapMode: Text.Wrap
                        text: hovered && hovered.repeat ? Planner.repeatText(hovered) + ". Buttons: skip just this day, or delete every day of it." : ""
                        textFormat: Text.PlainText
                        color: Theme.text
                        opacity: 0.6
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.8
                    }
                    Text {
                        visible: eventList.count === 0
                        text: "No events"
                        color: Theme.text
                        opacity: 0.5
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                    }

                    // add one: title, time (optional), AM / PM, +
                    Row {
                        id: addRow
                        width: parent.width
                        spacing: 6

                        // The AM / PM switch next to the time. It's used when the time you type
                        // could be either ("9:55", "9"); a time that says which itself ("9:55pm")
                        // or a 24-hour one ("21:55", "0:30") doesn't need it, and it dims.
                        // Starts on whichever half of the day it is now, each time the card opens.
                        property bool pm: false
                        Connections {
                            target: card
                            function onOpenChanged() {
                                if (card.open)
                                    addRow.pm = root.now.getHours() >= 12;
                            }
                        }
                        readonly property string typed: evWhen.text.trim()
                        readonly property bool saysWhich: /[ap]\.?m?\.?$/i.test(typed.replace(/\s/g, ""))
                        readonly property bool needsHalf: {
                            const m = typed.match(/^(\d{1,2})/);
                            return !saysWhich && !!m && Number(m[1]) >= 1 && Number(m[1]) <= 12;
                        }
                        // what's typed, with the switch's AM / PM added when it's needed
                        readonly property string timeText: needsHalf ? typed + (pm ? "pm" : "am") : typed

                        function submit() {
                            const title = evTitle.text.trim();
                            const time = Planner.parseTime(timeText);
                            if (title === "" || time === null) {
                                if (title === "")
                                    evTitle.forceActiveFocus();
                                return;
                            }
                            Planner.addEvent(card.selected, time, title, repeatPick.rule);
                            evTitle.text = "";
                            evWhen.text = "";
                            repeatPick.reset();
                        }

                        TextField {
                            id: evTitle
                            width: parent.width - evWhen.width - halfSwitch.width - evAdd.width - parent.spacing * 3
                            placeholderText: "New event"
                            placeholderTextColor: Theme.pillIcon
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            leftPadding: 12
                            rightPadding: 12
                            onAccepted: parent.submit()
                            background: Rectangle {
                                radius: height / 2
                                color: Theme.glass
                                border.width: 1
                                border.color: evTitle.activeFocus ? Theme.accent : Theme.pillIcon
                            }
                        }
                        TextField {
                            id: evWhen
                            width: 64
                            // red while what's typed isn't a time
                            readonly property bool bad: Planner.parseTime(addRow.timeText) === null
                            placeholderText: "9:30"
                            placeholderTextColor: Theme.pillIcon
                            color: bad ? Theme.red : Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            leftPadding: 10
                            rightPadding: 10
                            onAccepted: parent.submit()
                            background: Rectangle {
                                radius: height / 2
                                color: Theme.glass
                                border.width: 1
                                border.color: evWhen.bad ? Theme.red : evWhen.activeFocus ? Theme.accent : Theme.pillIcon
                            }
                        }
                        // AM / PM: click to switch
                        Rectangle {
                            id: halfSwitch
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: evWhen.height
                            radius: height / 2
                            color: halfMouse.containsMouse && addRow.needsHalf ? Theme.pill : Theme.glass
                            border.width: 1
                            border.color: addRow.needsHalf ? Theme.accent : Theme.pillIcon
                            opacity: addRow.needsHalf || addRow.typed === "" ? 1 : 0.4
                            scale: halfMouse.pressed ? 0.9 : 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
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
                                text: addRow.pm ? "PM" : "AM"
                                color: addRow.needsHalf ? Theme.accent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.9
                                font.weight: 700
                            }
                            MouseArea {
                                id: halfMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addRow.pm = !addRow.pm
                            }
                        }
                        IconButton {
                            id: evAdd
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add"
                            iconColor: evTitle.text.trim() !== "" && !evWhen.bad ? Theme.accent : Theme.text
                            onClicked: parent.submit()
                        }
                    }


                    // how often it happens: opens the Repeat page
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: height / 2
                        color: repeatBtnMouse.containsMouse ? Theme.pill : "transparent"
                        border.width: 1
                        border.color: repeatPick.repeat !== "" ? Theme.accent : Theme.pill
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Text {
                            id: repeatBtnIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "repeat"
                            color: repeatPick.repeat !== "" ? Theme.accent : Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: Theme.iconAxes
                        }
                        Text {
                            anchors.left: repeatBtnIcon.right
                            anchors.leftMargin: 8
                            anchors.right: repeatBtnArrow.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: repeatPick.repeat === "" ? "Repeat: never" : Planner.repeatText(Planner.previewRepeat(card.selected, repeatPick.rule))
                            color: Theme.text
                            opacity: repeatPick.repeat === "" ? 0.7 : 1
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.85
                            font.weight: 600
                        }
                        Text {
                            id: repeatBtnArrow
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_right"
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: Theme.iconAxes
                        }
                        MouseArea {
                            id: repeatBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.page = "repeat"
                        }
                    }
                }

                // ════ page 2: Repeat (RepeatPicker.qml) ════
                RepeatPicker {
                    id: repeatPage
                    x: card.page === "repeat" ? 0 : calPages.width + 24
                    Behavior on x {
                        NumberAnimation {
                            id: repeatSlide
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calPages.curve
                        }
                    }
                    width: parent.width
                    startKey: card.selected
                    pick: repeatPick
                    onDone: card.page = "main"
                }
                // ════ page 3: every event ════
                // All of them in one scrolling list: what's coming first (by the next day
                // each one happens), then the ones that are over (most recent first).
                // Each says when: its next day and time, how it repeats, or when it was.
                // Click one to go to its (next) day in the calendar; hover for its x.
                Column {
                    id: allPage
                    x: card.page === "all" ? 0 : calPages.width + 24
                    Behavior on x {
                        NumberAnimation {
                            id: allSlide
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calPages.curve
                        }
                    }
                    width: parent.width
                    spacing: 8

                    // ‹  All events                  12
                    Item {
                        width: parent.width
                        height: 26
                        IconButton {
                            id: allBack
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "arrow_back"
                            onClicked: card.page = "main"
                        }
                        Text {
                            anchors.left: allBack.right
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: "All events"
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 1.1
                            font.weight: 700
                            font.letterSpacing: Theme.letterSpacing
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: Planner.allEvents.filter(x => x.next !== "").length + " coming · " + Planner.allEvents.filter(x => x.next === "").length + " past"
                            color: Theme.text
                            opacity: 0.6
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.85
                        }
                    }

                    Text {
                        visible: Planner.allEvents.length === 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "No events yet. Pick a day in the calendar and add one there."
                        color: Theme.text
                        opacity: 0.5
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                    }

                    ListView {
                        id: allList
                        visible: count > 0
                        width: parent.width
                        height: Math.min(contentHeight, 380)
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: Planner.allEvents
                        ScrollBar.vertical: ThinScrollBar {}
                        // "Coming up" and "Over" headings
                        section.property: "group"
                        section.delegate: Text {
                            required property string section
                            width: ListView.view.width
                            topPadding: 6
                            bottomPadding: 2
                            leftPadding: 8
                            text: section
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.85
                            font.weight: 700
                        }

                        delegate: Rectangle {
                            id: ae
                            required property var modelData
                            readonly property var e: modelData.e
                            readonly property bool past: modelData.next === ""
                            width: ListView.view.width
                            height: 44
                            radius: Theme.radius
                            color: aeMouse.containsMouse ? Theme.pill : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            MouseArea {
                                id: aeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // to its next day (or the day it was) in the calendar
                                onClicked: {
                                    const k = ae.modelData.next || ae.modelData.last;
                                    const d = Planner.dateOf(k);
                                    card.viewYear = d.getFullYear();
                                    card.viewMonth = d.getMonth();
                                    card.selected = k;
                                    card.page = "main";
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: aeDelete.left
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Row {
                                        width: parent.width
                                        spacing: 4
                                        Text {
                                            width: Math.min(implicitWidth, parent.width - (aeRepeat.visible ? aeRepeat.width + 4 : 0))
                                            text: ae.e.title
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            opacity: ae.past ? 0.55 : 1
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize
                                            font.weight: 600
                                        }
                                        Text {
                                            id: aeRepeat
                                            visible: !!ae.e.repeat
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "repeat"
                                            color: Theme.accent
                                            opacity: 0.8
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize * 0.85
                                            font.variableAxes: Theme.iconAxes
                                        }
                                    }
                                    // when: next (or last) day and time, then how it repeats
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: (ae.past ? "Was " + Qt.formatDate(Planner.dateOf(ae.modelData.last), "ddd, MMM d, yyyy") : Planner.dayText(ae.modelData.next)) + (ae.e.time !== "" ? "  " + Planner.fmtTime(ae.e.time) : "  all day") + (ae.e.repeat ? "  ·  " + Planner.repeatText(ae.e) : "")
                                        color: !ae.past && ae.modelData.next === Planner.todayKey ? Theme.accent : Theme.text
                                        opacity: !ae.past && ae.modelData.next === Planner.todayKey ? 1 : 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.8
                                    }
                                }
                                IconButton {
                                    id: aeDelete
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: aeMouse.containsMouse
                                    width: visible ? implicitWidth : 0
                                    icon: ae.e.repeat ? "delete_sweep" : "close"
                                    iconColor: Theme.red
                                    onClicked: Planner.removeEvent(ae.e.id)
                                }
                            }
                        }
                    }
                }
            }

            // ════ Reminders ════
            // Things to do that aren't part of your schedule (take the bins out, water the
            // plants), each at a time, repeating however you like. They remind you with a
            // notification and the bell; tick one off and it won't remind you again today.
            // Not on the calendar or in the bar. Two pages, like the calendar: the list
            // and the form, and Repeat (RepeatPicker.qml) swiping in from the right.
            Item {
                id: remPages
                visible: card.tab === "reminders"
                width: parent.width
                height: remMainSlide.running || remRepeatSlide.running ? Math.max(remRepeat.height, remMain.height) : card.page === "repeat" ? remRepeat.height : remMain.height
                clip: true

                RepeatState {
                    id: remPick
                    startKey: Planner.todayKey
                }

                Column {
                    id: remMain
                    x: card.page === "repeat" ? -remPages.width - 24 : 0
                    Behavior on x {
                        NumberAnimation {
                            id: remMainSlide
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calPages.curve
                        }
                    }
                    width: parent.width
                    spacing: 6

                    ListView {
                        id: remList
                        width: parent.width
                        height: Math.min(contentHeight, 240)
                        visible: count > 0
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: Planner.reminderList
                        ScrollBar.vertical: ThinScrollBar {}

                        delegate: Rectangle {
                            id: rem
                            required property var modelData
                            readonly property var e: modelData.e
                            readonly property bool dueToday: modelData.next === Planner.todayKey
                            readonly property bool doneToday: e.done === Planner.todayKey
                            width: ListView.view.width
                            height: 42
                            radius: Theme.radius
                            color: remMouse.containsMouse ? Theme.pill : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            MouseArea {
                                id: remMouse
                                anchors.fill: parent
                                hoverEnabled: true

                                // tick it off for today (only when it's on today)
                                Rectangle {
                                    id: remCheck
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: rem.doneToday ? Theme.accent : "transparent"
                                    border.width: 2
                                    border.color: rem.doneToday || rem.dueToday ? Theme.accent : Theme.pillIcon
                                    opacity: rem.dueToday || rem.doneToday ? 1 : 0.4
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: rem.doneToday
                                        text: "check"
                                        color: Theme.bg
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        font.variableAxes: Theme.iconAxes
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: rem.dueToday || rem.doneToday
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: Planner.toggleDone(rem.e.id)
                                    }
                                }
                                Column {
                                    anchors.left: remCheck.right
                                    anchors.leftMargin: 10
                                    anchors.right: remDelete.left
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        text: rem.e.title
                                        elide: Text.ElideRight
                                        color: Theme.text
                                        opacity: rem.doneToday ? 0.5 : 1
                                        font.strikeout: rem.doneToday
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize
                                        font.weight: 600
                                    }
                                    // when it's next, and how it repeats
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: (rem.doneToday ? "Done today" : Planner.dayText(rem.modelData.next) + " " + Planner.fmtTime(rem.e.time)) + (rem.e.repeat ? "  ·  " + Planner.repeatText(rem.e) : "")
                                        color: rem.dueToday && !rem.doneToday ? Theme.accent : Theme.text
                                        opacity: rem.dueToday && !rem.doneToday ? 1 : 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.8
                                    }
                                }
                                IconButton {
                                    id: remDelete
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: remMouse.containsMouse
                                    width: visible ? implicitWidth : 0
                                    icon: "close"
                                    iconColor: Theme.red
                                    onClicked: Planner.removeReminder(rem.e.id)
                                }
                            }
                        }
                    }
                    Text {
                        visible: remList.count === 0
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "No reminders. Add one below: what, when, and how often."
                        color: Theme.text
                        opacity: 0.5
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.pill
                    }

                    // add one: what, time, AM / PM, +   (it starts today)
                    Row {
                        id: remRow
                        width: parent.width
                        spacing: 6

                        // AM / PM, like the event form's
                        property bool pm: root.now.getHours() >= 12
                        readonly property string typed: remWhen.text.trim()
                        readonly property bool saysWhich: /[ap]\.?m?\.?$/i.test(typed.replace(/\s/g, ""))
                        readonly property bool needsHalf: {
                            const m = typed.match(/^(\d{1,2})/);
                            return !saysWhich && !!m && Number(m[1]) >= 1 && Number(m[1]) <= 12;
                        }
                        readonly property string timeText: needsHalf ? typed + (pm ? "pm" : "am") : typed
                        // a reminder needs a time
                        readonly property string time: typed === "" ? "" : (Planner.parseTime(timeText) ?? "")
                        readonly property bool bad: typed !== "" && Planner.parseTime(timeText) === null

                        function submit() {
                            const title = remTitle.text.trim();
                            if (title === "") {
                                remTitle.forceActiveFocus();
                                return;
                            }
                            if (time === "") {
                                remWhen.forceActiveFocus();
                                return;
                            }
                            Planner.addReminder(time, title, remPick.rule);
                            remTitle.text = "";
                            remWhen.text = "";
                            remPick.reset();
                        }

                        TextField {
                            id: remTitle
                            width: parent.width - remWhen.width - remHalf.width - remAdd.width - parent.spacing * 3
                            placeholderText: "New reminder"
                            placeholderTextColor: Theme.pillIcon
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            leftPadding: 12
                            rightPadding: 12
                            onAccepted: parent.submit()
                            background: Rectangle {
                                radius: height / 2
                                color: Theme.glass
                                border.width: 1
                                border.color: remTitle.activeFocus ? Theme.accent : Theme.pillIcon
                            }
                        }
                        TextField {
                            id: remWhen
                            width: 64
                            placeholderText: "9:00"
                            placeholderTextColor: Theme.pillIcon
                            color: remRow.bad ? Theme.red : Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            leftPadding: 10
                            rightPadding: 10
                            onAccepted: parent.submit()
                            background: Rectangle {
                                radius: height / 2
                                color: Theme.glass
                                border.width: 1
                                border.color: remRow.bad ? Theme.red : remWhen.activeFocus ? Theme.accent : Theme.pillIcon
                            }
                        }
                        Rectangle {
                            id: remHalf
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: remWhen.height
                            radius: height / 2
                            color: remHalfMouse.containsMouse && remRow.needsHalf ? Theme.pill : Theme.bg
                            border.width: 1
                            border.color: remRow.needsHalf ? Theme.accent : Theme.pillIcon
                            opacity: remRow.needsHalf || remRow.typed === "" ? 1 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: remRow.pm ? "PM" : "AM"
                                color: remRow.needsHalf ? Theme.accent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.9
                                font.weight: 700
                            }
                            MouseArea {
                                id: remHalfMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: remRow.pm = !remRow.pm
                            }
                        }
                        IconButton {
                            id: remAdd
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add"
                            iconColor: remTitle.text.trim() !== "" && remRow.time !== "" ? Theme.accent : Theme.text
                            onClicked: parent.submit()
                        }
                    }

                    // how often: opens the Repeat page
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: height / 2
                        color: remRepeatMouse.containsMouse ? Theme.pill : "transparent"
                        border.width: 1
                        border.color: remPick.repeat !== "" ? Theme.accent : Theme.pill
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Text {
                            id: remRepeatIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "repeat"
                            color: remPick.repeat !== "" ? Theme.accent : Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: Theme.iconAxes
                        }
                        Text {
                            anchors.left: remRepeatIcon.right
                            anchors.leftMargin: 8
                            anchors.right: remRepeatArrow.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: remPick.repeat === "" ? "Repeat: just today" : Planner.repeatText(Planner.previewRepeat(Planner.todayKey, remPick.rule))
                            color: Theme.text
                            opacity: remPick.repeat === "" ? 0.7 : 1
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.85
                            font.weight: 600
                        }
                        Text {
                            id: remRepeatArrow
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_right"
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: Theme.iconAxes
                        }
                        MouseArea {
                            id: remRepeatMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.page = "repeat"
                        }
                    }
                }

                RepeatPicker {
                    id: remRepeat
                    x: card.page === "repeat" ? 0 : remPages.width + 24
                    Behavior on x {
                        NumberAnimation {
                            id: remRepeatSlide
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: calPages.curve
                        }
                    }
                    width: parent.width
                    heading: "Repeat reminder"
                    startKey: Planner.todayKey
                    pick: remPick
                    onDone: card.page = "main"
                }
            }

            // ════ Timers ════
            Column {
                visible: card.tab === "timers"
                width: parent.width
                spacing: 8

                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [
                            {
                                name: "1 min",
                                ms: 60000
                            },
                            {
                                name: "5 min",
                                ms: 300000
                            },
                            {
                                name: "10 min",
                                ms: 600000
                            },
                            {
                                name: "15 min",
                                ms: 900000
                            },
                            {
                                name: "25 min",
                                ms: 1500000
                            },
                            {
                                name: "1 hour",
                                ms: 3600000
                            }
                        ]
                        Chip {
                            required property var modelData
                            label: modelData.name
                            onClicked: Planner.addTimer(modelData.ms, "")
                        }
                    }
                }

                // your own: length, label (optional), start
                Row {
                    width: parent.width
                    spacing: 6

                    function start() {
                        const ms = Planner.parseDuration(tLength.text);
                        if (ms <= 0) {
                            tLength.forceActiveFocus();
                            return;
                        }
                        Planner.addTimer(ms, tLabel.text.trim());
                        tLength.text = "";
                        tLabel.text = "";
                    }

                    TextField {
                        id: tLength
                        width: 96
                        readonly property bool bad: text.trim() !== "" && Planner.parseDuration(text) <= 0
                        placeholderText: "Length"
                        placeholderTextColor: Theme.pillIcon
                        color: bad ? Theme.red : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        leftPadding: 12
                        rightPadding: 10
                        onAccepted: parent.start()
                        background: Rectangle {
                            radius: height / 2
                            color: Theme.glass
                            border.width: 1
                            border.color: tLength.bad ? Theme.red : tLength.activeFocus ? Theme.accent : Theme.pillIcon
                        }
                    }
                    TextField {
                        id: tLabel
                        width: parent.width - tLength.width - tStart.width - parent.spacing * 2
                        placeholderText: "Label"
                        placeholderTextColor: Theme.pillIcon
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        leftPadding: 12
                        rightPadding: 12
                        onAccepted: parent.start()
                        background: Rectangle {
                            radius: height / 2
                            color: Theme.glass
                            border.width: 1
                            border.color: tLabel.activeFocus ? Theme.accent : Theme.pillIcon
                        }
                    }
                    IconButton {
                        id: tStart
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "play_arrow"
                        iconColor: Planner.parseDuration(tLength.text) > 0 ? Theme.accent : Theme.text
                        onClicked: parent.start()
                    }
                }

                ListView {
                    id: timerList
                    width: parent.width
                    height: Math.min(contentHeight, 240)
                    visible: count > 0
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: Planner.timers
                    ScrollBar.vertical: ThinScrollBar {}

                    delegate: Rectangle {
                        id: tm
                        required property var modelData
                        readonly property double leftMs: Planner.left(modelData)
                        readonly property bool paused: !modelData.done && modelData.end === 0

                        width: ListView.view.width
                        height: 56
                        radius: Theme.radius
                        color: Theme.pill
                        border.width: 1
                        border.color: tm.modelData.done ? Theme.accent : "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: tmButtons.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: tm.modelData.done ? "Done" : Planner.fmtLeft(tm.leftMs)
                                color: tm.modelData.done ? Theme.accent : Theme.text
                                opacity: tm.paused ? 0.6 : 1
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 1.6
                                font.weight: 700
                                font.letterSpacing: Theme.letterSpacing
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (tm.modelData.label !== "" ? tm.modelData.label + "  ·  " : "") + Planner.fmtLength(tm.modelData.total) + (tm.paused ? "  ·  paused" : "")
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                            }
                        }
                        Row {
                            id: tmButtons
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            IconButton {
                                visible: !tm.modelData.done
                                icon: tm.paused ? "play_arrow" : "pause"
                                onClicked: tm.paused ? Planner.resumeTimer(tm.modelData.id) : Planner.pauseTimer(tm.modelData.id)
                            }
                            IconButton {
                                icon: "replay"            // from the top again
                                onClicked: Planner.restartTimer(tm.modelData.id)
                            }
                            IconButton {
                                icon: "close"
                                iconColor: Theme.red
                                onClicked: Planner.removeTimer(tm.modelData.id)
                            }
                        }
                        // how much is left, along the bottom
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: tm.radius
                            anchors.bottomMargin: 4
                            width: (parent.width - tm.radius * 2) * (tm.modelData.total > 0 ? tm.leftMs / tm.modelData.total : 0)
                            height: 2
                            radius: 1
                            color: Theme.accent
                            opacity: tm.paused ? 0.4 : 1
                        }
                    }
                }
                Text {
                    visible: timerList.count === 0
                    text: "No timers"
                    color: Theme.text
                    opacity: 0.5
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 0.9
                }
            }

            // ════ Stopwatch ════
            Column {
                id: watch
                visible: card.tab === "stopwatch"
                width: parent.width
                spacing: 10

                // ticks quickly only while you can see it running
                property double at: Date.now()
                Timer {
                    interval: 33
                    repeat: true
                    running: card.open && card.tab === "stopwatch" && Planner.swRunning
                    onTriggered: watch.at = Date.now()
                }
                readonly property double elapsed: Planner.swRunning ? Planner.watchTime(at) : Planner.swBase

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: Planner.fmtWatch(watch.elapsed)
                    color: Planner.swRunning ? Theme.text : watch.elapsed > 0 ? Theme.accent : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 2.6
                    font.weight: 700
                    font.letterSpacing: Theme.letterSpacing
                    font.features: ({
                            "tnum": 1
                        })
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Chip {
                        label: Planner.swRunning ? "Pause" : watch.elapsed > 0 ? "Resume" : "Start"
                        selected: true
                        tint: Planner.swRunning ? Theme.yellow : Theme.green
                        onClicked: Planner.swRunning ? Planner.pauseWatch() : Planner.startWatch()
                    }
                    Chip {
                        visible: Planner.swRunning
                        label: "Lap"
                        onClicked: Planner.lap()
                    }
                    Chip {
                        visible: !Planner.swRunning && watch.elapsed > 0
                        label: "Reset"
                        tint: Theme.red
                        onClicked: Planner.resetWatch()
                    }
                }

                // laps, newest on top. The quickest one is green, the slowest red.
                ListView {
                    id: lapList
                    width: parent.width
                    height: Math.min(contentHeight, 168)
                    visible: count > 0
                    clip: true
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ThinScrollBar {}

                    // [{ n, split, total }], newest first
                    readonly property var rows: Planner.laps.map((t, i) => ({
                                "n": i + 1,
                                "split": t - (i > 0 ? Planner.laps[i - 1] : 0),
                                "total": t
                            })).reverse()
                    readonly property double fastest: rows.length >= 2 ? Math.min.apply(null, rows.map(r => r.split)) : -1
                    readonly property double slowest: rows.length >= 2 ? Math.max.apply(null, rows.map(r => r.split)) : -1
                    model: rows

                    delegate: Item {
                        id: lapRow
                        required property var modelData
                        width: ListView.view.width
                        height: 26
                        readonly property color tint: modelData.split === lapList.fastest ? Theme.green : modelData.split === lapList.slowest ? Theme.red : Theme.text
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Lap " + lapRow.modelData.n
                            color: lapRow.tint
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 600
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: Planner.fmtWatch(lapRow.modelData.split)
                            color: lapRow.tint
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 700
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Planner.fmtWatch(lapRow.modelData.total)
                            color: Theme.text
                            opacity: 0.5
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.9
                        }
                    }
                }
            }
        }
    }
  '';

  # The wallpaper half of the bar's theme popup: the pictures in the current theme's folder.
  xdg.configFile."quickshell/WallpaperPicker.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic
    import Qt.labs.folderlistmodel
    import Quickshell
    import Quickshell.Io
    import Quickshell.Widgets

    // ── Wallpaper picker ── (the right half of the bar's theme popup, shell.qml)
    // Shows the pictures in ~/Pictures/Wallpapers/<theme>/ (the theme that's on). Click
    // one to make it the wallpaper. It's remembered for that theme: switch themes and
    // back and it's still the one. A theme you haven't picked one for uses the first
    // picture in its folder (A to Z). New pictures in the folder show up by themselves.
    //
    // The picking is done by `theme --wallpaper <file>` (home.nix), which also updates
    // the lock and login screens and rofi. It keeps your picks in
    // ~/.local/state/theme/wallpapers/<theme>, one line each: the picture's path.
    Column {
        id: root

        readonly property string dir: Theme.wallpaperDir + "/" + Theme.current
        // the wallpaper now: the theme command writes its path here whenever it changes
        readonly property string current: picked !== "" ? picked : wallpaperFile.text().trim()
        // what you just clicked, shown right away until the command catches up
        property string picked: ""

        function pick(path) {
            picked = path;
            pickedReset.restart();
            Quickshell.execDetached([Theme.themeCommand, "--wallpaper", path]);
        }
        function shuffle() {
            if (pictures.count < 2)
                return;
            let i;
            do
                i = Math.floor(Math.random() * pictures.count);
            while (pictures.get(i, "filePath") === current);
            pick(pictures.get(i, "filePath"));
        }

        Column {
            id: card
            width: 3 * 120 + 2 * 6
            spacing: 8

            FileView {
                id: wallpaperFile
                path: Quickshell.env("HOME") + "/.local/state/theme/wallpaper.path"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: root.picked = ""
            }
            Timer {
                id: pickedReset
                interval: 4000         // if the command never answered, show what's really on
                onTriggered: root.picked = ""
            }

            FolderListModel {
                id: pictures
                folder: "file://" + root.dir
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"]
                caseSensitive: false
                showDirs: false
                sortField: FolderListModel.Name
            }

            // ── title, and buttons ──
            Item {
                width: parent.width
                height: 26
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wallpaper"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 1.2
                        font.weight: 700
                        font.letterSpacing: Theme.letterSpacing
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.themes[Theme.current] ? Theme.themes[Theme.current].name : Theme.current
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                        font.weight: 600
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    IconButton {
                        visible: pictures.count > 1
                        icon: "shuffle"            // a random other one
                        onClicked: root.shuffle()
                    }
                    IconButton {
                        icon: "folder_open"        // the folder, in your file manager
                        onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec xdg-open \"$1\"", "sh", root.dir])
                    }
                }
            }

            // ── the pictures ──
            GridView {
                id: grid
                visible: pictures.count > 0
                width: parent.width + 6           // the last column's gap hangs off the edge
                height: Math.min(Math.ceil(pictures.count / 3), 3.5) * cellHeight
                cellWidth: 126
                cellHeight: 78
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: pictures
                ScrollBar.vertical: ThinScrollBar {}

                delegate: Item {
                    id: tile
                    required property string filePath
                    required property string fileName
                    readonly property bool isCurrent: filePath === root.current

                    width: 120
                    height: 72

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.pill
                        scale: tileMouse.pressed ? 0.94 : tileMouse.containsMouse ? 1.03 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            id: thumb
                            anchors.fill: parent
                            source: "file://" + tile.filePath
                            sourceSize: Qt.size(240, 144)     // decoded small: quick, and light on memory
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: thumb.status !== Image.Ready
                            text: thumb.status === Image.Error ? "broken_image" : "image"
                            color: Theme.pillIcon
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize * 1.4
                            font.variableAxes: Theme.iconAxes
                        }
                        // the one that's on: an outline and a check
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: "transparent"
                            border.width: tile.isCurrent ? 2 : 0
                            border.color: Theme.accent
                        }
                        Rectangle {
                            visible: tile.isCurrent
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 5
                            width: 18
                            height: 18
                            radius: 9
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: "check"
                                color: Theme.bg
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                font.variableAxes: Theme.iconAxes
                            }
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!tile.isCurrent)
                            root.pick(tile.filePath)
                    }
                    ToolTip.visible: tileMouse.containsMouse
                    ToolTip.delay: 600
                    ToolTip.text: tile.fileName
                }
            }

            // ── nothing in the folder yet ──
            Text {
                visible: pictures.count === 0
                width: parent.width
                wrapMode: Text.Wrap
                text: "No pictures in ~/Pictures/Wallpapers/" + Theme.current + "/ yet. Put some there (the folder button opens it) and they show up here."
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.9
            }

            // the one that's on, by name
            Text {
                visible: root.current !== ""
                width: parent.width
                elide: Text.ElideMiddle
                text: root.current.split("/").pop()
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.85
            }
        }
    }
  '';

  # An app's icon, or a letter tile when there isn't one (the dock and its bar button).
  xdg.configFile."quickshell/AppIcon.qml".text = ''
    import QtQuick
    import Quickshell

    // An app's icon from your icon theme, or from the file its desktop entry names.
    // When there's no icon to be found (some games, launchers and Java apps don't
    // install one, or name one your theme doesn't have), a rounded tile with the app's
    // first letter, instead of Qt's black-and-magenta "missing" square.
    Item {
        id: root

        property string icon: ""    // an icon name ("firefox"), or a file path
        property string name: ""    // the app's name, for the letter

        readonly property string path: {
            if (icon === "")
                return "";
            if (icon.startsWith("/"))
                return "file://" + icon;
            if (icon.indexOf("://") > 0)
                return icon;
            return Quickshell.iconPath(icon, true);    // "" when the theme hasn't got it
        }

        Image {
            id: img
            anchors.fill: parent
            visible: root.path !== "" && status !== Image.Error
            source: root.path
            sourceSize: Qt.size(root.width * 2, root.height * 2)
            asynchronous: true
        }
        Rectangle {
            visible: !img.visible
            anchors.fill: parent
            anchors.margins: Math.round(parent.width * 0.06)
            radius: width * 0.28
            color: Theme.pill
            Text {
                anchors.centerIn: parent
                text: (root.name || root.icon || "?").trim().charAt(0).toUpperCase()
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: parent.height * 0.5
                font.weight: 700
            }
        }
    }
  '';

  # The dock's apps and your pins (Dock.qml shows them, DockControl.qml edits the pins).
  xdg.configFile."quickshell/DockData.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Hyprland
    import Quickshell.Io
    import Quickshell.Wayland

    // What the dock (Dock.qml) shows: the apps you pinned, then everything else that
    // has a window open. Apps are known by their desktop entry id ("firefox",
    // "org.gnome.Nautilus"); a window is matched to its app the same way the old
    // tray widget did it (DesktopEntries.heuristicLookup on its app id).
    // Your pins, in order, are saved in ~/.local/state/quickshell/dock.json.
    Singleton {
        id: d

        readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
        property var pins: []             // desktop entry ids, in dock order

        // ── the apps, for the dock ──
        // [{ key, pinned, windows: [toplevel, ...] }]: pinned first (in your order), then
        // the other open apps in the order they were opened
        readonly property var apps: {
            const out = [];
            const byKey = {};
            for (const k of pins) {
                const a = {
                    "key": k,
                    "pinned": true,
                    "windows": []
                };
                byKey[k] = a;
                out.push(a);
            }
            for (const t of ToplevelManager.toplevels.values) {
                const k = keyFor(t);
                let a = byKey[k];
                if (!a) {
                    a = byKey[k] = {
                        "key": k,
                        "pinned": false,
                        "windows": []
                    };
                    out.push(a);
                }
                a.windows.push(t);
            }
            // each app's windows by workspace, lowest first (the window list, and clicking
            // its icon goes round them in this order); ones Hyprland hasn't placed yet last
            const rank = t => {
                const n = Number(workspaceOf(t));
                return workspaceOf(t) === "" || isNaN(n) ? Infinity : n;
            };
            for (const a of out)
                a.windows.sort((x, y) => rank(x) - rank(y));
            return out;
        }

        // the app a window belongs to: its desktop entry's id, else its app id
        function keyFor(t) {
            const e = DesktopEntries.heuristicLookup(t.appId);
            return e ? e.id : (t.appId || t.title);
        }
        function entryFor(key) {
            return DesktopEntries.byId(key) ?? DesktopEntries.heuristicLookup(key);
        }
        // the icon's name (or file path) from its desktop entry, else its app id;
        // AppIcon.qml finds it, or draws a letter tile when there's no such icon
        function iconFor(key) {
            const e = entryFor(key);
            return e && e.icon !== "" ? e.icon : key;
        }
        function nameFor(key) {
            const e = entryFor(key);
            return e && e.name !== "" ? e.name : key;
        }

        // ── workspaces ──
        // Hyprland's list of windows knows which workspace each is on; its `wayland` is
        // the same window as the dock's (ToplevelManager), which is how they're matched.
        // The workspace a window is on ("4"), or "" if Hyprland hasn't said yet.
        function workspaceOf(t) {
            for (const h of Hyprland.toplevels.values)
                if (h.wayland === t)
                    return h.workspace ? h.workspace.name : "";
            return "";
        }
        // the workspaces an app's windows are on, lowest first, each once: ["2", "4"]
        // (not the hidden one minimized windows are on)
        function workspacesOf(app) {
            const out = [];
            for (const w of app.windows) {
                const n = workspaceOf(w);
                if (n !== "" && !n.startsWith("special:") && !out.includes(n))
                    out.push(n);
            }
            return out.sort((a, b) => (Number(a) || 0) - (Number(b) || 0) || a.localeCompare(b));
        }
        // the apps open on a workspace (Hyprland's), each once, in the order their
        // windows were opened: [{ key, count }] (count = how many windows)
        function appsOn(ws) {
            const out = [];
            const byKey = {};
            if (!ws)
                return out;
            for (const h of ws.toplevels.values) {
                const appId = h.wayland ? h.wayland.appId : ((h.lastIpcObject && h.lastIpcObject["class"]) || "");
                const key = keyFor({
                    "appId": appId,
                    "title": h.title
                });
                if (byKey[key]) {
                    byKey[key].count++;
                } else {
                    byKey[key] = {
                        "key": key,
                        "count": 1
                    };
                    out.push(byKey[key]);
                }
            }
            return out;
        }

        // ── minimized windows ──
        // The yellow button on a window's title bar (hyprbars, in the Hyprland config)
        // "minimizes" it: Hyprland has no minimizing, so it moves the window to a hidden
        // special workspace that's never shown. Here they're listed in the dock (point at
        // the app's icon), and clicking one brings it back to the workspace you're on.
        readonly property string minimizedWorkspace: "special:minimized"
        function isMinimized(t) {
            return workspaceOf(t) === minimizedWorkspace;
        }
        function minimizedCount(app) {
            return app.windows.filter(w => isMinimized(w)).length;
        }
        // whether pointing at its icon shows its windows (previews): any open
        function showsList(app) {
            return app.windows.length > 0;
        }
        // back to the workspace you're on, focused
        function restore(t) {
            let h = null;
            for (const x of Hyprland.toplevels.values)
                if (x.wayland === t)
                    h = x;
            const ws = Hyprland.focusedWorkspace;
            if (!h || h.address === "" || !ws) {
                t.activate();
                return;
            }
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + ws.id + '", window = "address:0x' + h.address + '" })');
        }
        // go to a window, bringing it back first if it's minimized
        function show(t) {
            if (isMinimized(t))
                restore(t);
            else
                t.activate();
        }

        // ── doing things ──
        // Started through uwsm, so each app gets its own place in your session instead
        // of being Quickshell's child (restarting Quickshell would close it otherwise).
        function launch(key) {
            if (entryFor(key))
                Quickshell.execDetached(["uwsm", "app", "--", entryFor(key).id + ".desktop"]);
        }
        // Click: open it if nothing's open, go to its window if one is, and go round its
        // windows one by one on more clicks. Minimized ones are skipped, unless they're
        // all minimized: then the first comes back.
        function focus(app) {
            if (app.windows.length === 0) {
                launch(app.key);
                return;
            }
            const open = app.windows.filter(w => !isMinimized(w));
            if (open.length === 0) {
                restore(app.windows[0]);
                return;
            }
            const i = open.findIndex(w => w.activated);
            open[(i + 1) % open.length].activate();
        }
        function closeAll(app) {
            for (const w of app.windows)
                w.close();
        }

        // ── pins ──
        function isPinned(key) {
            return pins.indexOf(key) >= 0;
        }
        function pin(key) {
            if (!isPinned(key)) {
                pins = pins.concat([key]);
                save();
            }
        }
        function unpin(key) {
            pins = pins.filter(k => k !== key);
            save();
        }
        function togglePin(key) {
            isPinned(key) ? unpin(key) : pin(key);
        }
        // put an app at place `index` among the pins (pinning it if it wasn't)
        function placePin(key, index) {
            const p = pins.filter(k => k !== key);
            p.splice(Math.max(0, Math.min(p.length, index)), 0, key);
            pins = p;
            save();
        }
        // move a pin left (-1) or right (+1)
        function movePin(key, by) {
            const i = pins.indexOf(key), j = i + by;
            if (i < 0 || j < 0 || j >= pins.length)
                return;
            const p = pins.slice();
            p.splice(j, 0, p.splice(i, 1)[0]);
            pins = p;
            save();
        }

        // ── saving ──
        FileView {
            id: file
            path: d.stateDir + "/dock.json"
            blockLoading: true
            printErrors: false
        }
        Component.onCompleted: {
            try {
                pins = JSON.parse(file.text() || "{}").pins || [];
            } catch (e) {}
        }
        function save() {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/dock.json.$$\" && mv -f \"$1/dock.json.$$\" \"$1/dock.json\"", "sh", stateDir, JSON.stringify({
                    "pins": pins
                })]);
        }
    }
  '';

  # The dock along the bottom of the screen (shell.qml makes one per monitor).
  xdg.configFile."quickshell/Dock.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic   // ScrollBar (the window previews' scrollbar)
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Services.SystemTray

    // ── The dock ──
    // App icons on the bottom edge of the screen, hidden until you push the mouse
    // against that edge. It grows up out of the edge the way the bar's widgets drop out
    // of the bar (DockPanel.qml: same curves, corners and animation), and sinks back
    // half a second after the mouse leaves it. It doesn't take any space from your
    // windows: it sits over them while it's up. (Hidden under fullscreen windows.)
    //
    //   Apps (left): your pins (the dock button in the top bar), then the other open
    //   apps. A dot under an app means it has a window open (a longer one for several);
    //   accent colored = the one you're in.
    //     click         open it; if it's open, go to its window (again: the next one)
    //     middle click  a new window
    //     right click   pin / unpin, new window, close
    //     drag it       left or right to rearrange (an unpinned one gets pinned there)
    //     point at it   with a window open: after half a second the dock grows previews
    //                   of its windows above the icons (click one to go to it, or bring a
    //                   minimized one back; x to close it; past two rows they scroll);
    //                   it shrinks back when the mouse leaves
    //   Tray (right): the icons apps put up.
    //     click = the app's action, middle click = its second action,
    //     right click = its menu (the dock grows to show it, like the window list).
    PanelWindow {
        id: dock

        anchors {
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "dock"
        color: "transparent"
        // room for the dock to grow into (window previews or a menu above the icons)
        implicitHeight: 520

        readonly property int iconSize: 36
        readonly property int cell: 48           // an icon's slot

        // ── showing and hiding ──
        property bool shown: false
        // the mouse is on the dock or the bottom edge
        readonly property bool held: edgeHover.hovered || panelHover.hovered
        onHeldChanged: {
            if (held) {
                hideDelay.stop();
                shown = true;
            } else {
                hideDelay.restart();
            }
        }
        Timer {
            id: hideDelay
            interval: 500
            onTriggered: {
                dock.shown = false;
                dock.closeExtras();
            }
        }

        // Only these take the mouse; the rest of the window lets clicks through to what's
        // under it. While hidden that's just the bottom 2 px of the screen. (The edge
        // stays in while it's up, so resting the mouse there keeps it up.)
        mask: Region {
            item: edge
            Region {
                item: panel.visible ? panel : null
            }
        }

        // the bottom edge: push the mouse here to bring the dock up
        Item {
            id: edge
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            HoverHandler {
                id: edgeHover
            }
        }

        // ── what shows above the icons: one at a time ──
        // "list" (an app's windows), "menu" (an app's right-click menu), "tray" (a tray
        // icon's menu), or "" for just the icons
        property string extra: ""
        property var listApp: null      // the app whose windows are listed
        property var listMouse: null    // its icon's mouse area: pointing there keeps the list
        property var menuApp: null      // the app whose menu is open
        property var trayItem: null     // the tray icon whose menu is open
        property var trayStack: []      // the menu, and submenus opened inside it
        function closeExtras() {
            extra = "";
            listApp = null;
            listMouse = null;
            menuApp = null;
            trayItem = null;
        }
        function openList(a, mouse) {
            closeExtras();
            listApp = a;
            listMouse = mouse;
            extra = "list";
        }
        function openAppMenu(a) {
            const same = extra === "menu" && menuApp && menuApp.key === a.key;
            closeExtras();
            if (same)
                return;
            menuApp = a;
            extra = "menu";
        }
        function openTrayMenu(item) {
            const same = extra === "tray" && trayItem === item;
            closeExtras();
            if (same)
                return;
            trayItem = item;
            trayStack = [item.menu];
            extra = "tray";
        }
        // the listed app as it is now (windows come and go while the list is open)
        readonly property var listLive: listApp ? (DockData.apps.find(a => a.key === listApp.key) ?? null) : null
        onListLiveChanged: if (extra === "list" && (!listLive || !DockData.showsList(listLive)))
            closeExtras()
        // The window list goes a moment after the mouse leaves both the icon and the
        // list. (Menus stay until you pick something, click their icon again, or the
        // dock hides.)
        readonly property bool listHeld: extra === "list" && (listHover.hovered || (listMouse !== null && listMouse.containsMouse))
        onListHeldChanged: if (!listHeld && extra === "list")
            listClose.restart()
        else
            listClose.stop()
        Timer {
            id: listClose
            interval: 350
            onTriggered: if (dock.extra === "list")
                dock.closeExtras()
        }

        // ── dragging apps to rearrange them ──
        // Drag an app left or right and drop it. Your pins take the new order; an open app
        // that isn't pinned gets pinned where you drop it among the pins; a pin dragged
        // past the last pin goes to the end of the pins. (The order is saved, DockData.)
        property int dragFrom: -1        // the app being dragged (its place), -1 = none
        property int dragTo: -1          // where it would land now
        property real dragDx: 0          // how far the mouse has moved it
        readonly property real slotStep: cell + 2      // an icon slot plus the gap
        readonly property int pinCount: DockData.pins.length
        function updateDrag(pinned) {
            const t = Math.round(dragFrom + dragDx / slotStep);
            // pins move among the pins; others can go in among them, or stay put
            dragTo = Math.max(0, Math.min(pinned ? pinCount - 1 : Math.max(pinCount, dragFrom), t));
        }
        function dropDrag() {
            const from = dragFrom, to = dragTo;
            const a = from >= 0 ? DockData.apps[from] : null;
            endDrag();
            if (!a || from === to)
                return;
            if (a.pinned || to <= pinCount)
                DockData.placePin(a.key, Math.min(to, a.pinned ? pinCount - 1 : pinCount));
        }
        function endDrag() {
            dragFrom = -1;
            dragTo = -1;
            dragDx = 0;
        }

        // ── the dock ──
        DockPanel {
            id: panel
            open: dock.shown
            anchorX: dock.width / 2
            baseY: dock.height
            HoverHandler {
                id: panelHover
            }

            Column {
                id: stack
                spacing: 6

                // ════ an app's windows ════
                // A card for each: a preview of the window (a picture taken when the list
                // opens; the one under the mouse plays live), its title and its workspace,
                // up to three across. Click one to go to it (a minimized one comes back to
                // the workspace you're on); x (on hover) closes it. Past two rows it
                // scrolls: mouse wheel, or the thin scrollbar on the right.
                Column {
                    id: listCol
                    visible: dock.extra === "list"
                    spacing: 4

                    readonly property int cardW: 200
                    readonly property int previewH: 112
                    readonly property int cardH: previewH + 44
                    readonly property int gap: 6
                    readonly property int count: dock.listLive ? dock.listLive.windows.length : 0
                    readonly property int cols: Math.max(1, Math.min(3, count))
                    readonly property int rows: Math.ceil(count / cols)
                    readonly property real gridW: cols * cardW + (cols - 1) * gap
                    readonly property real gridH: rows * cardH + (rows - 1) * gap
                    // two rows and a peek at the third, so it shows there's more
                    readonly property real maxGridH: 2 * cardH + gap + 40
                    readonly property bool scrolls: gridH > maxGridH
                    width: Math.max(row.width, gridW + (scrolls ? 12 : 0))

                    HoverHandler {
                        id: listHover
                    }

                    Text {
                        width: parent.width
                        leftPadding: 8
                        elide: Text.ElideRight
                        // "Kitty  ·  3 windows  ·  1 minimized"
                        text: {
                            const a = dock.listLive;
                            if (!a)
                                return "";
                            const n = a.windows.length;
                            const m = DockData.minimizedCount(a);
                            return DockData.nameFor(a.key) + "  ·  " + n + (n === 1 ? " window" : " windows") + (m > 0 ? "  ·  " + m + " minimized" : "");
                        }
                        color: Theme.text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.85
                        font.weight: 600
                    }

                    Flickable {
                        id: listFlick
                        width: listCol.width
                        height: Math.min(listCol.gridH, listCol.maxGridH)
                        contentWidth: width
                        contentHeight: cards.height
                        clip: true
                        interactive: listCol.scrolls
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ThinScrollBar {}

                        Grid {
                            id: cards
                            // centered in the room left of the scrollbar
                            x: Math.max(0, (listFlick.width - (listCol.scrolls ? 12 : 0) - width) / 2)
                            columns: listCol.cols
                            spacing: listCol.gap

                            Repeater {
                                model: dock.extra === "list" && dock.listLive ? dock.listLive.windows : []

                                Rectangle {
                                    id: card
                                    required property var modelData
                                    readonly property bool minimized: DockData.isMinimized(modelData)
                                    readonly property bool hovered: cardHover.hovered
                                    width: listCol.cardW
                                    height: listCol.cardH
                                    radius: Theme.radius + 2
                                    color: card.hovered ? Theme.pill : "transparent"
                                    // the window you're in
                                    border.width: card.modelData.activated ? 2 : 0
                                    border.color: Theme.accent
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    HoverHandler {
                                        id: cardHover
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            DockData.show(card.modelData);
                                            dock.closeExtras();
                                        }
                                    }

                                    // the preview, fitted into its box
                                    Rectangle {
                                        id: shotBox
                                        x: 8
                                        y: 8
                                        width: card.width - 16
                                        height: listCol.previewH
                                        radius: Theme.radius
                                        color: Qt.rgba(0, 0, 0, 0.25)
                                        clip: true

                                        ScreencopyView {
                                            id: shot
                                            anchors.centerIn: parent
                                            captureSource: card.modelData
                                            // live while the mouse is on it; a still picture otherwise
                                            live: card.hovered
                                            constraintSize: Qt.size(shotBox.width, shotBox.height)
                                            visible: hasContent
                                            opacity: card.minimized ? 0.55 : 1
                                        }
                                        // until there's a picture (or if there can't be one): the app's icon
                                        AppIcon {
                                            anchors.centerIn: parent
                                            visible: !shot.hasContent
                                            width: 40
                                            height: 40
                                            icon: DockData.iconFor(dock.listLive ? dock.listLive.key : "")
                                            name: DockData.nameFor(dock.listLive ? dock.listLive.key : "")
                                            opacity: 0.8
                                        }
                                    }

                                    // its title, and its workspace in a little pill ("minimized")
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: cardWs.visible ? cardWs.left : parent.right
                                        anchors.rightMargin: 6
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        text: card.modelData.title || DockData.nameFor(dock.listLive ? dock.listLive.key : "")
                                        elide: Text.ElideRight
                                        color: card.modelData.activated ? Theme.accent : Theme.text
                                        opacity: card.minimized ? 0.6 : 1
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSize * 0.9
                                        font.weight: card.modelData.activated ? 700 : 500
                                    }
                                    Rectangle {
                                        id: cardWs
                                        readonly property string name: card.minimized ? "minimized" : DockData.workspaceOf(card.modelData)
                                        visible: name !== ""
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        width: Math.max(height, cardWsText.implicitWidth + 12)
                                        height: 20
                                        radius: height / 2
                                        color: Theme.pill
                                        Text {
                                            id: cardWsText
                                            anchors.centerIn: parent
                                            text: cardWs.name
                                            color: card.modelData.activated ? Theme.accent : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSize * 0.8
                                            font.weight: 700
                                        }
                                    }
                                    // x: close it (shows on hover), over the preview's corner
                                    IconButton {
                                        anchors.right: shotBox.right
                                        anchors.top: shotBox.top
                                        anchors.margins: 4
                                        visible: card.hovered
                                        icon: "close"
                                        iconColor: Theme.red
                                        onClicked: card.modelData.close()
                                    }
                                }
                            }
                        }
                    }
                }

                // ════ an app's menu (right click) ════
                Column {
                    id: appMenuCol
                    visible: dock.extra === "menu"
                    width: Math.max(row.width, 220)

                    Text {
                        width: parent.width
                        leftPadding: 8
                        bottomPadding: 4
                        elide: Text.ElideRight
                        text: dock.menuApp ? DockData.nameFor(dock.menuApp.key) : ""
                        color: Theme.text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.85
                        font.weight: 600
                    }
                    Repeater {
                        model: {
                            const a = dock.extra === "menu" ? dock.menuApp : null;
                            if (!a)
                                return [];
                            const items = [{
                                    "id": "pin",
                                    "icon": "push_pin",
                                    "text": DockData.isPinned(a.key) ? "Unpin from dock" : "Pin to dock"
                                }];
                            if (DockData.entryFor(a.key))
                                items.push({
                                    "id": "new",
                                    "icon": "add",
                                    "text": "New window"
                                });
                            if (a.windows.length > 0)
                                items.push({
                                    "id": "close",
                                    "icon": "close",
                                    "text": a.windows.length > 1 ? "Close " + a.windows.length + " windows" : "Close window"
                                });
                            return items;
                        }

                        Rectangle {
                            id: menuRow
                            required property var modelData
                            width: appMenuCol.width
                            height: 30
                            radius: Theme.radius
                            color: menuRowMouse.containsMouse ? Theme.pill : "transparent"
                            Text {
                                id: menuRowIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.icon
                                color: menuRow.modelData.id === "close" ? Theme.red : Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                                font.variableAxes: Theme.iconAxes
                            }
                            Text {
                                anchors.left: menuRowIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRow.modelData.text
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.95
                            }
                            MouseArea {
                                id: menuRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = dock.menuApp;
                                    const what = menuRow.modelData.id;
                                    dock.closeExtras();
                                    if (what === "pin")
                                        DockData.togglePin(a.key);
                                    else if (what === "new")
                                        DockData.launch(a.key);
                                    else
                                        DockData.closeAll(a);
                                }
                            }
                        }
                    }
                }

                // ════ a tray icon's menu ════
                QsMenuOpener {
                    id: trayOpener
                    menu: dock.extra === "tray" && dock.trayStack.length > 0 ? dock.trayStack[dock.trayStack.length - 1] : null
                }
                Column {
                    id: menuCol
                    visible: dock.extra === "tray"
                    width: Math.max(row.width, 240)

                    // title, with a back arrow inside a submenu
                    Item {
                        width: parent.width
                        height: 28
                        IconButton {
                            id: menuBack
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: dock.trayStack.length > 1
                            width: visible ? implicitWidth : 0
                            icon: "arrow_back"
                            onClicked: dock.trayStack = dock.trayStack.slice(0, -1)
                        }
                        Text {
                            anchors.left: menuBack.right
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: dock.trayItem ? (dock.trayItem.tooltipTitle || dock.trayItem.title || dock.trayItem.id) : ""
                            elide: Text.ElideRight
                            color: Theme.text
                            opacity: 0.7
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.85
                            font.weight: 600
                        }
                    }

                    Repeater {
                        model: trayOpener.children

                        Item {
                            id: entry
                            required property var modelData
                            width: menuCol.width
                            height: modelData.isSeparator ? 9 : 28

                            Rectangle {
                                visible: entry.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 16
                                height: 1
                                color: Theme.pillIcon
                            }
                            Rectangle {
                                visible: !entry.modelData.isSeparator
                                anchors.fill: parent
                                radius: Theme.radius
                                color: entryMouse.containsMouse && entry.modelData.enabled ? Theme.pill : "transparent"
                                opacity: entry.modelData.enabled ? 1 : 0.4

                                // check box / radio button entries
                                Text {
                                    id: entryCheck
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                    width: visible ? implicitWidth : 0
                                    text: entry.modelData.checkState === Qt.Checked ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_checked" : "check_box") : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_unchecked" : "check_box_outline_blank")
                                    color: Theme.accent
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                                Text {
                                    anchors.left: entryCheck.right
                                    anchors.leftMargin: 8
                                    anchors.right: entryMore.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.modelData.text.replace(/_(?!_)/g, "")   // drop the underline-the-next-letter marks
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.95
                                }
                                Text {
                                    id: entryMore
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: entry.modelData.hasChildren
                                    text: "chevron_right"
                                    color: Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    font.variableAxes: Theme.iconAxes
                                }
                                MouseArea {
                                    id: entryMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        const m = entry.modelData;
                                        if (!m.enabled)
                                            return;
                                        if (m.hasChildren) {
                                            dock.trayStack = dock.trayStack.concat([m]);
                                        } else {
                                            m.triggered();
                                            dock.closeExtras();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // a line between whatever's above and the icons
                Rectangle {
                    visible: dock.extra !== ""
                    width: Math.max(row.width, listCol.visible ? listCol.width : appMenuCol.visible ? appMenuCol.width : menuCol.width)
                    height: 1
                    color: Theme.pill
                }

                // ════ the icons ════
                Row {
                    id: row
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    // nothing pinned or open
                    Text {
                        visible: DockData.apps.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8
                        rightPadding: 8
                        text: "Nothing open. Pin apps from the dock button in the bar."
                        color: Theme.text
                        opacity: 0.6
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                    }

                    Repeater {
                        model: DockData.apps

                        Item {
                            id: app
                            required property var modelData
                            required property int index
                            readonly property bool active: modelData.windows.some(w => w.activated)
                            // a line between the pins and the other open apps
                            readonly property bool firstUnpinned: !modelData.pinned && index > 0 && DockData.apps[index - 1].pinned

                            width: dock.cell + (firstUnpinned ? 11 : 0)
                            height: dock.cell

                            // while one is dragged: it follows the mouse, the ones it passes
                            // step aside by a slot to make room
                            readonly property bool dragged: dock.dragFrom === index
                            readonly property real shift: {
                                const f = dock.dragFrom, t = dock.dragTo;
                                if (f < 0 || dragged)
                                    return 0;
                                if (f < t && index > f && index <= t)
                                    return -dock.slotStep;
                                if (f > t && index >= t && index < f)
                                    return dock.slotStep;
                                return 0;
                            }
                            z: dragged ? 10 : 0
                            transform: Translate {
                                x: app.dragged ? dock.dragDx : app.shift
                                Behavior on x {
                                    enabled: !app.dragged && dock.dragFrom >= 0
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Rectangle {
                                visible: app.firstUnpinned
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: dock.cell - 16
                                color: Theme.pill
                            }

                            Item {
                                id: slot
                                anchors.right: parent.right
                                width: dock.cell
                                height: dock.cell

                                // picked out while its list or menu is open
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: Theme.radius
                                    color: Theme.pill
                                    opacity: (dock.extra === "list" && dock.listApp && dock.listApp.key === app.modelData.key) || (dock.extra === "menu" && dock.menuApp && dock.menuApp.key === app.modelData.key) ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -2
                                    width: dock.iconSize
                                    height: dock.iconSize
                                    icon: DockData.iconFor(app.modelData.key)
                                    name: DockData.nameFor(app.modelData.key)
                                    // pinned but closed: a little faded
                                    opacity: app.modelData.windows.length > 0 || appMouse.containsMouse ? 1 : 0.7
                                    scale: appMouse.pressed ? 0.9 : appMouse.containsMouse ? 1.12 : 1
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                                // open windows: a dot, longer for more than one
                                Rectangle {
                                    visible: app.modelData.windows.length > 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1
                                    width: app.modelData.windows.length > 1 ? 14 : 5
                                    height: 3
                                    radius: 1.5
                                    color: app.active ? Theme.accent : Theme.text
                                    opacity: app.active ? 1 : 0.5
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: app.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                    preventStealing: true

                                    // drag (left button) to move it along the dock
                                    property real pressX: 0
                                    property bool moved: false
                                    onPressed: mouse => {
                                        pressX = mapToItem(row, mouse.x, 0).x;
                                        moved = false;
                                    }
                                    onPositionChanged: mouse => {
                                        if (!(pressedButtons & Qt.LeftButton))
                                            return;
                                        const dx = mapToItem(row, mouse.x, 0).x - pressX;
                                        if (!moved && Math.abs(dx) < 8)
                                            return;
                                        if (!moved) {
                                            moved = true;
                                            dock.closeExtras();
                                            dock.dragFrom = app.index;
                                            dock.dragTo = app.index;
                                        }
                                        dock.dragDx = dx;
                                        dock.updateDrag(app.modelData.pinned);
                                    }
                                    onReleased: if (moved)
                                        dock.dropDrag()
                                    onCanceled: dock.endDrag()
                                    onClicked: mouse => {
                                        if (moved)
                                            return;      // that was a drag, not a click
                                        if (mouse.button === Qt.RightButton) {
                                            dock.openAppMenu(app.modelData);
                                            return;
                                        }
                                        dock.closeExtras();
                                        if (mouse.button === Qt.MiddleButton)
                                            DockData.launch(app.modelData.key);
                                        else
                                            DockData.focus(app.modelData);
                                    }
                                }
                                // a window open: point at it for half a second for the previews
                                // (pointing at another open app while they're up switches to it)
                                Timer {
                                    interval: 500
                                    running: appMouse.containsMouse && !appMouse.pressed && dock.dragFrom < 0 && DockData.showsList(app.modelData) && (dock.extra === "" || (dock.extra === "list" && dock.listApp && dock.listApp.key !== app.modelData.key))
                                    onTriggered: dock.openList(app.modelData, appMouse)
                                }
                            }

                            // its name, above the dock, while you point at it (when nothing
                            // else is showing above the icons)
                            Rectangle {
                                parent: dock.contentItem
                                visible: appMouse.containsMouse && dock.extra === "" && dock.dragFrom < 0 && panel.openness === 1
                                // worked out again whenever the dock moves or changes size
                                readonly property real atX: (panel.width, appMouse.containsMouse, slot.mapToItem(dock.contentItem, slot.width / 2, 0).x)
                                x: Math.max(4, Math.min(dock.width - width - 4, atX - width / 2))
                                y: panel.y - height - 8
                                width: nameLabel.implicitWidth + 16
                                height: 24
                                radius: height / 2
                                color: Theme.glass     // like the dock under it
                                Text {
                                    id: nameLabel
                                    anchors.centerIn: parent
                                    // "Kitty  ·  workspace 4", "Kitty  ·  3 windows  ·  workspaces 2, 4"
                                    text: {
                                        const a = app.modelData;
                                        const ws = DockData.workspacesOf(a);
                                        let t = DockData.nameFor(a.key);
                                        if (a.windows.length > 1)
                                            t += "  ·  " + a.windows.length + " windows";
                                        const m = DockData.minimizedCount(a);
                                        if (m > 0)
                                            t += "  ·  " + m + " minimized";
                                        if (ws.length > 0)
                                            t += "  ·  " + (ws.length === 1 ? "workspace " : "workspaces ") + ws.join(", ");
                                        return t;
                                    }
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSize * 0.9
                                    font.weight: 600
                                }
                            }
                        }
                    }

                    // ── the tray ──
                    Item {
                        visible: SystemTray.items.values.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: dock.cell - 16
                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: parent.height
                            color: Theme.pill
                        }
                    }
                    Repeater {
                        model: SystemTray.items

                        Rectangle {
                            id: trayBtn
                            required property var modelData
                            readonly property bool menuOpen: dock.extra === "tray" && dock.trayItem === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: Theme.radius
                            color: menuOpen ? Theme.pill : trayMouse.containsMouse ? Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.6) : "transparent"
                            scale: trayMouse.pressed ? 0.85 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                sourceSize: Qt.size(36, 36)
                                source: trayBtn.modelData.icon
                            }
                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    const item = trayBtn.modelData;
                                    if (mouse.button === Qt.MiddleButton)
                                        item.secondaryActivate();
                                    else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu))
                                        dock.openTrayMenu(item);
                                    else
                                        item.activate();
                                }
                                onWheel: wheel => trayBtn.modelData.scroll(wheel.angleDelta.y, false)
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  # The dock's shape: grows up out of the bottom edge like the bar's widgets drop out of the bar.
  xdg.configFile."quickshell/DockPanel.qml".text = ''
    import QtQuick
    import QtQuick.Shapes

    // The dock's body (Dock.qml). It sits flush on the bottom edge of the screen and
    // grows up out of it the way the bar's widgets drop out of the bar (Widget.qml),
    // just upside down: the same flared curves where it meets the edge, the same
    // rounded corners, color, opening and closing curves and timing.
    //
    //   ╭───────────────────╮
    //   │   (the content)   │
    //  ─╯                   ╰─   bottom edge of the screen
    //
    // While it's open, a change in the content's size (a window list appearing above
    // the icons) makes it grow or shrink on the same soft curve, with the icons staying
    // where they are; only the edges move.
    Item {
        id: pop

        property bool open: false
        property real anchorX: 0        // the middle (in the parent's coordinates)
        property real baseY: 0          // the edge it grows out of

        property int padding: 8
        property int curve: 14          // the curves into the edge (Widget.qml: curve)
        property int cornerRadius: 14   // the two top corners (Widget.qml: cornerRadius)
        property int duration: 320
        property int closeDuration: 260
        property var openCurve: [0.3, 0.6, 0.35, 1]
        property var closeCurve: [0.45, 0, 0.55, 1]

        default property alias content: area.data

        // 0 = closed (flat in the edge), 1 = all the way up
        property real openness: 0
        visible: openness > 0

        readonly property real bodyWidth: Math.ceil(area.childrenRect.width + padding * 2)
        readonly property real bodyHeight: Math.ceil(area.childrenRect.height + padding * 2)
        // the size it's showing: glides to a new one when the content changes while open
        property real shownWidth: bodyWidth
        property real shownHeight: bodyHeight
        Behavior on shownWidth {
            enabled: pop.open && pop.openness === 1
            NumberAnimation {
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pop.openCurve.concat([1, 1])
            }
        }
        Behavior on shownHeight {
            enabled: pop.open && pop.openness === 1
            NumberAnimation {
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pop.openCurve.concat([1, 1])
            }
        }

        x: anchorX - shownWidth / 2 - curve
        y: baseY - height
        width: shownWidth + curve * 2
        height: openness * shownHeight

        // a bigger one gets a little longer, like Widget.qml
        function timeFor(base) {
            return Math.round(base * (0.9 + 0.3 * Math.min(1, bodyHeight / 900)));
        }
        onOpenChanged: {
            if (open) {
                closeAnim.stop();
                openAnim.duration = timeFor(duration);
                openAnim.restart();
            } else {
                openAnim.stop();
                closeAnim.duration = timeFor(closeDuration);
                closeAnim.restart();
            }
        }
        NumberAnimation {
            id: openAnim
            target: pop
            property: "openness"
            to: 1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: pop.openCurve.concat([1, 1])
        }
        NumberAnimation {
            id: closeAnim
            target: pop
            property: "openness"
            to: 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: pop.closeCurve.concat([1, 1])
        }

        Shape {
            id: shape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // the curves can't be bigger than half the height, so they grow in while opening
            readonly property real c: Math.min(pop.curve, height / 2)
            readonly property real r: Math.min(pop.cornerRadius, height / 2)
            readonly property real boxLeft: pop.curve
            readonly property real boxRight: width - pop.curve

            ShapePath {
                fillColor: Theme.glass      // see-through and blurred, like the bar
                strokeColor: "transparent"

                // on the edge, left of the box; around clockwise
                startX: shape.boxLeft - shape.c
                startY: shape.height
                // bottom-left curve, up into the box's left side
                PathArc {
                    x: shape.boxLeft
                    y: shape.height - shape.c
                    radiusX: shape.c
                    radiusY: shape.c
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: shape.boxLeft
                    y: shape.r
                }
                // top-left corner
                PathArc {
                    x: shape.boxLeft + shape.r
                    y: 0
                    radiusX: shape.r
                    radiusY: shape.r
                }
                PathLine {
                    x: shape.boxRight - shape.r
                    y: 0
                }
                // top-right corner
                PathArc {
                    x: shape.boxRight
                    y: shape.r
                    radiusX: shape.r
                    radiusY: shape.r
                }
                PathLine {
                    x: shape.boxRight
                    y: shape.height - shape.c
                }
                // bottom-right curve, back out onto the edge
                PathArc {
                    x: shape.boxRight + shape.c
                    y: shape.height
                    radiusX: shape.c
                    radiusY: shape.c
                    direction: PathArc.Counterclockwise
                }
            }
        }

        // The content. Opening and closing, it rides the top edge, so it comes up out
        // of the screen's edge; growing or shrinking while open, it stays put at the
        // bottom and the top edge moves. Anything outside the shape is cut off (clip).
        Item {
            x: pop.curve
            width: pop.shownWidth
            height: parent.height
            clip: true

            Item {
                id: area
                x: (pop.shownWidth - pop.bodyWidth) / 2 + pop.padding
                y: pop.openness * (pop.shownHeight - pop.bodyHeight) + pop.padding
                width: pop.bodyWidth - pop.padding * 2
                height: pop.bodyHeight - pop.padding * 2
                opacity: pop.openness
            }
        }
    }
  '';

  # The dock's body turned on its side, for the left edge (the workspaces dock).
  xdg.configFile."quickshell/SidePanel.qml".text = ''
    import QtQuick
    import QtQuick.Shapes

    // DockPanel.qml on its side: it sits flush on the left edge of the screen and grows
    // out of it to the right, with the same flared curves where it meets the edge, the
    // same rounded corners, glass, opening and closing curves and timing.
    //
    //   │╮
    //   │╰──────────────╮
    //   │ (the content)  │
    //   │╭──────────────╯
    //   │╯
    //   left edge of the screen
    Item {
        id: pop

        property bool open: false
        property real anchorY: 0        // the middle (in the parent's coordinates)
        property real baseX: 0          // the edge it grows out of

        property int padding: 10
        property int curve: 14          // the curves into the edge (Widget.qml: curve)
        property int cornerRadius: 14   // the two right corners (Widget.qml: cornerRadius)
        property int duration: 320
        property int closeDuration: 260
        property var openCurve: [0.3, 0.6, 0.35, 1]
        property var closeCurve: [0.45, 0, 0.55, 1]

        default property alias content: area.data

        // 0 = closed (flat in the edge), 1 = all the way out
        property real openness: 0
        visible: openness > 0

        readonly property real bodyWidth: Math.ceil(area.childrenRect.width + padding * 2)
        readonly property real bodyHeight: Math.ceil(area.childrenRect.height + padding * 2)
        // the size it's showing: glides to a new one when the content changes while open
        // (a workspace appearing or going away)
        property real shownWidth: bodyWidth
        property real shownHeight: bodyHeight
        Behavior on shownWidth {
            enabled: pop.open && pop.openness === 1
            NumberAnimation {
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pop.openCurve.concat([1, 1])
            }
        }
        Behavior on shownHeight {
            enabled: pop.open && pop.openness === 1
            NumberAnimation {
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: pop.openCurve.concat([1, 1])
            }
        }

        x: baseX
        y: anchorY - shownHeight / 2 - curve
        width: openness * shownWidth
        height: shownHeight + curve * 2

        // a bigger one gets a little longer, like Widget.qml
        function timeFor(base) {
            return Math.round(base * (0.9 + 0.3 * Math.min(1, bodyWidth / 900)));
        }
        onOpenChanged: {
            if (open) {
                closeAnim.stop();
                openAnim.duration = timeFor(duration);
                openAnim.restart();
            } else {
                openAnim.stop();
                closeAnim.duration = timeFor(closeDuration);
                closeAnim.restart();
            }
        }
        NumberAnimation {
            id: openAnim
            target: pop
            property: "openness"
            to: 1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: pop.openCurve.concat([1, 1])
        }
        NumberAnimation {
            id: closeAnim
            target: pop
            property: "openness"
            to: 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: pop.closeCurve.concat([1, 1])
        }

        Shape {
            id: shape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // the curves can't be bigger than half the width, so they grow in while opening
            readonly property real c: Math.min(pop.curve, width / 2)
            readonly property real r: Math.min(pop.cornerRadius, width / 2)
            readonly property real boxTop: pop.curve
            readonly property real boxBottom: height - pop.curve

            ShapePath {
                fillColor: Theme.glass      // see-through and blurred, like the bar
                strokeColor: "transparent"

                // on the edge, above the box; around clockwise
                startX: 0
                startY: shape.boxTop - shape.c
                // top curve, out of the edge into the box's top side
                PathArc {
                    x: shape.c
                    y: shape.boxTop
                    radiusX: shape.c
                    radiusY: shape.c
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: shape.width - shape.r
                    y: shape.boxTop
                }
                // top-right corner
                PathArc {
                    x: shape.width
                    y: shape.boxTop + shape.r
                    radiusX: shape.r
                    radiusY: shape.r
                }
                PathLine {
                    x: shape.width
                    y: shape.boxBottom - shape.r
                }
                // bottom-right corner
                PathArc {
                    x: shape.width - shape.r
                    y: shape.boxBottom
                    radiusX: shape.r
                    radiusY: shape.r
                }
                PathLine {
                    x: shape.c
                    y: shape.boxBottom
                }
                // bottom curve, back out onto the edge
                PathArc {
                    x: 0
                    y: shape.boxBottom + shape.c
                    radiusX: shape.c
                    radiusY: shape.c
                    direction: PathArc.Counterclockwise
                }
            }
        }

        // The content rides the right edge as it opens and closes, so it comes out of
        // the screen's edge. Anything outside the shape is cut off (clip).
        Item {
            y: pop.curve
            width: parent.width
            height: pop.shownHeight
            clip: true

            Item {
                id: area
                x: pop.width - pop.bodyWidth + pop.padding
                y: (pop.shownHeight - pop.bodyHeight) / 2 + pop.padding
                width: pop.bodyWidth - pop.padding * 2
                height: pop.bodyHeight - pop.padding * 2
                opacity: pop.openness
            }
        }
    }
  '';

  # The workspaces dock: the workspace switcher on the left edge, hidden until you push
  # the mouse against that edge (like the dock at the bottom).
  # The music list's hover tip: a song's whole title when the list cuts it short.
  xdg.configFile."quickshell/HoverTip.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic

    // A hover tip, in the bar's colors, just above what it's about. It shows once the
    // mouse has rested there for half a second, and goes when the mouse leaves. Long
    // text wraps. Used for:
    //   - the whole of a title the music list had to cut short ("…"): a song's, an
    //     artist's or an album's, with the line under it in full too (only when
    //     something was cut: `cut`)
    //   - album covers: the album and artist
    //   - icon buttons: what they do (IconButton.qml's `tip`)
    ToolTip {
        id: tip

        property bool show: false           // the mouse is on the row
        property bool cut: false            // the title or the line under it doesn't fit
        property string title: ""
        property string detail: ""          // the line under it, or ""
        property bool below: false          // under it instead (for things in the top bar)
        readonly property real maxTextWidth: 360

        visible: show && cut && title !== ""
        delay: 500
        timeout: -1
        closePolicy: Popup.NoAutoClose      // it goes when the mouse leaves, nothing else
        x: 0
        y: below ? parent.height + 4 : -height - 4
        padding: 8

        contentItem: Column {
            spacing: 2
            Text {
                width: Math.min(implicitWidth, tip.maxTextWidth)
                text: tip.title
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                font.weight: 700
                font.letterSpacing: Theme.letterSpacing
            }
            Text {
                visible: tip.detail !== ""
                width: Math.min(implicitWidth, tip.maxTextWidth)
                text: tip.detail
                wrapMode: Text.Wrap
                color: Theme.text
                opacity: 0.7
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.85
            }
        }
        background: Rectangle {
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
            radius: Theme.radius
            border.width: 1
            border.color: Theme.pill
        }
    }
  '';

  # The title bar over a fullscreen window (see FullscreenBar.qml's comment).
  xdg.configFile."quickshell/FullscreenBar.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Hyprland

    // ── The title bar over a fullscreen window ──
    // Hyprland doesn't draw window decorations (the hyprbars title bar) on a fullscreen
    // window, and the window fills the screen, so there's no room for one anyway. So on
    // a screen whose focused window is fullscreen, pushing the mouse against the top
    // edge slides this down over it: the same bar, drawn by Quickshell (same height,
    // glass, font, colors and circles; symbols on the circles while the mouse is on
    // them). It slides back up half a second after the mouse leaves it.
    //   red: close   yellow: minimize   green: leave fullscreen
    //   double-click the title: maximized instead (like double-clicking a title bar)
    // It's on the overlay layer, the only one above fullscreen windows. While it's in,
    // only the top 2 px of the screen take the mouse (from the fullscreen window).
    PanelWindow {
        id: fsBar

        anchors {
            top: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fullscreen-titlebar"   // its blur rule in the Hyprland config
        color: "transparent"
        implicitHeight: barHeight

        readonly property int barHeight: 28           // hyprbars' bar_height

        // the focused window, if it's fullscreen (not just maximized) on this screen
        readonly property var win: {
            const t = ToplevelManager.activeToplevel;
            if (!t || !t.fullscreen)
                return null;
            for (const s of t.screens)
                if (fsBar.screen && s && s.name === fsBar.screen.name)
                    return t;
            return null;
        }
        visible: win !== null

        // its Hyprland address, for the commands below ("" until Hyprland has said)
        function address() {
            for (const h of Hyprland.toplevels.values)
                if (h.wayland === fsBar.win && h.address !== "")
                    return "address:0x" + h.address;
            return "";
        }
        function dispatchFor(make) {
            const a = fsBar.address();
            if (a !== "")
                Hyprland.dispatch(make(a));
            fsBar.shown = false;
        }
        function close() {
            if (fsBar.win)
                fsBar.win.close();
            fsBar.shown = false;
        }
        function minimize() {
            // like the yellow button on the title bar (and the dock's minimized windows)
            dispatchFor(a => 'hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "' + a + '" })');
        }
        function maximize() {
            dispatchFor(a => 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = "' + a + '" })');
        }
        function leaveFullscreen() {
            dispatchFor(a => 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", window = "' + a + '" })');
        }

        // ── showing and hiding ──
        property bool shown: false
        readonly property bool held: edgeHover.hovered || barHover.hovered
        onHeldChanged: {
            if (held) {
                hideDelay.stop();
                shown = true;
            } else {
                hideDelay.restart();
            }
        }
        onWinChanged: if (!win) {
            hideDelay.stop();
            shown = false;
        }
        Timer {
            id: hideDelay
            interval: 500
            onTriggered: fsBar.shown = false
        }
        // 0 = up out of sight, 1 = all the way down
        property real openness: shown ? 1 : 0
        Behavior on openness {
            NumberAnimation {
                duration: fsBar.shown ? 200 : 160
                easing.type: fsBar.shown ? Easing.OutCubic : Easing.InCubic
            }
        }

        mask: Region {
            item: edge
            Region {
                item: fsBar.openness > 0 ? slide : null
            }
        }

        // the top edge: push the mouse here
        Item {
            id: edge
            width: parent.width
            height: 2
            HoverHandler {
                id: edgeHover
            }
        }

        Rectangle {
            id: slide
            width: parent.width
            height: fsBar.barHeight
            y: -height * (1 - fsBar.openness)
            visible: fsBar.openness > 0
            color: Theme.glass       // hyprbars' bar_color: the bar's glass, blurred
            HoverHandler {
                id: barHover
            }

            // double-click the title: maximized instead (like on the title bar)
            MouseArea {
                anchors.fill: parent
                onDoubleClicked: fsBar.maximize()
            }

            // the three circles, at hyprbars' sizes and spacing
            Row {
                id: buttons
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                HoverHandler {
                    id: buttonsHover
                }

                Repeater {
                    model: [
                        { "color": Theme.red, "icon": "×", "act": () => fsBar.close() },
                        { "color": Theme.yellow, "icon": "−", "act": () => fsBar.minimize() },
                        { "color": Theme.green, "icon": "+", "act": () => fsBar.leaveFullscreen() }
                    ]

                    Rectangle {
                        required property var modelData
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData.color
                        Text {
                            anchors.centerIn: parent
                            visible: buttonsHover.hovered
                            text: parent.modelData.icon
                            color: Theme.bg
                            font.pixelSize: 9
                            font.weight: 700
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4          // a little easier to hit
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.act()
                        }
                    }
                }
            }

            // the title, in the middle (the bar's font, like the title bars)
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 2 * (buttons.x + buttons.width + 12))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: fsBar.win ? fsBar.win.title : ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                font.weight: 600
                font.letterSpacing: Theme.letterSpacing
            }
        }
    }
  '';

  # Dragging a window onto the workspaces dock (see WindowDrag.qml's comment).
  xdg.configFile."quickshell/WindowDrag.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io
    import Quickshell.Hyprland

    // ── Dragging a window onto the workspaces dock ──
    // Super + left drag moves a window (its bind in the Hyprland config), and two more
    // binds there say here when a drag starts and ends (`quickshell ipc call windowdrag
    // ...`, the IpcHandler in shell.qml). While you drag, this follows the mouse, since
    // Hyprland keeps the mouse to the window you're dragging and tells nothing else
    // where it is. Push the window against the left edge and the workspaces dock comes
    // out (WorkspaceDock.qml); the workspace under the mouse lights up (Workspaces.qml);
    // let go there and the window goes to that workspace, and you go with it.
    //
    // Dragging a window by its title bar does the same: hyprbars handles those clicks
    // itself, before Hyprland's binds see them, so it's patched to send the same two
    // messages (its on_drag setting; hyprbarsPatched in home.nix).
    Singleton {
        id: drag

        property bool active: false
        // where the mouse is, on the whole desktop (Hyprland's coordinates, the same as
        // the screens' x and y)
        property real x: -100000
        property real y: -100000
        // the workspace the mouse is over in a workspaces dock, and that dock's screen
        // (WorkspaceDock.qml sets them)
        property var target: null
        property var targetScreen: null

        // Each drag has a name (the time and a count, from the bind). The two messages
        // are two separate commands, so a quick drag's "finish" can get here before its
        // "start": a start for a drag that's already over is ignored.
        property var finished: []      // the last few drags' names

        function start(name) {
            console.info("windowdrag: start", name);
            if (drag.finished.includes(name))
                return;
            drag.x = -100000;
            drag.y = -100000;
            drag.target = null;
            drag.targetScreen = null;
            drag.active = true;
            giveUp.restart();
        }

        // address: the window's ("0x..."); floating: whether it was; at: where it was
        // when you picked it up, "x,y" (an "at=" in front, so a negative x isn't
        // read as an option by `quickshell ipc call`)
        function finish(name, address, floating, at) {
            drag.finished = drag.finished.concat([name]).slice(-16);
            const ws = drag.target;
            const screen = drag.targetScreen;
            console.info("windowdrag: finish", name, address, "onto", ws ? ws.name : "nothing");
            drag.active = false;
            drag.target = null;
            drag.targetScreen = null;
            giveUp.stop();
            // nowhere, or the workspace it's already on (the one showing on that screen)
            if (!ws || ws.active || !/^0x[0-9a-f]+$/.test(address))
                return;
            const win = "address:" + address;
            // the window goes there, and you go with it
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + ws.id + '", window = "' + win + '" })');
            // A floating window would stay where you let go of it, against the left edge
            // under the dock: put it back where it was, if that's on the same screen.
            const m = at.match(/^at=(-?\d+),(-?\d+)$/);
            if (floating && m && screen) {
                const px = Number(m[1]);
                const py = Number(m[2]);
                if (px >= screen.x && px < screen.x + screen.width && py >= screen.y && py < screen.y + screen.height)
                    Hyprland.dispatch('hl.dsp.window.move({ x = ' + px + ', y = ' + py + ', window = "' + win + '" })');
            }
        }

        // the mouse position, about 30 times a second, only while dragging
        Process {
            id: cursor
            command: ["hyprctl", "cursorpos"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/(-?\d+),\s*(-?\d+)/);
                    if (m && drag.active) {
                        drag.x = Number(m[1]);
                        drag.y = Number(m[2]);
                    }
                }
            }
        }
        Timer {
            interval: 33
            repeat: true
            running: drag.active
            onTriggered: if (!cursor.running)
                cursor.running = true
        }
        // if the "finish" never comes (Quickshell or Hyprland restarted mid-drag),
        // stop following the mouse after a minute
        Timer {
            id: giveUp
            interval: 60000
            onTriggered: drag.active = false
        }
    }
  '';

  xdg.configFile."quickshell/WorkspaceDock.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Wayland

    // ── The workspaces dock ──
    // This screen's workspaces (Workspaces.qml), down the left edge of the screen,
    // hidden until you push the mouse against that edge. It grows out of the edge
    // sideways, the way the dock grows up out of the bottom (SidePanel.qml: same
    // curves, corners, glass and animation), and slides back in half a second after the
    // mouse leaves it. It sits over your windows while it's out and doesn't take any
    // space from them. Click a workspace to go there. (Super + Shift + Up / Down go to
    // the one above / below from the keyboard.) Drag a window (Super + drag) against the
    // left edge and it comes out too: let go of the window on a workspace to send it there
    // (WindowDrag.qml).
    PanelWindow {
        id: side

        anchors {
            left: true
            top: true
            bottom: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "workspace-dock"   // its blur rule in the Hyprland config
        color: "transparent"
        // room for the panel to grow into: as wide as it gets (its rows with the app icons,
        // padding and the scrollbar), plus a margin, so it's never cut off
        implicitWidth: Math.max(120, panel.bodyWidth + 24)

        // ── a window being dragged here (WindowDrag.qml) ──
        // The mouse, in this window's coordinates (it starts at the screen's top left).
        // Hovering doesn't see it while a window is being dragged, so it comes from there.
        readonly property real dragX: side.screen ? WindowDrag.x - side.screen.x : -1
        readonly property real dragY: side.screen ? WindowDrag.y - side.screen.y : -1
        readonly property bool dragOnScreen: WindowDrag.active && !!side.screen && side.dragX >= 0 && side.dragX < side.screen.width && side.dragY >= 0 && side.dragY < side.screen.height
        // against the left edge (below the bar, like the mouse), or on the panel once it's out
        readonly property bool dragHere: side.dragOnScreen && ((side.dragX <= 4 && side.dragY >= edge.y) || (panel.visible && panel.contains(panel.mapFromItem(null, side.dragX, side.dragY))))
        // the workspace it would go to: tell WindowDrag.qml
        readonly property var dropTarget: wsList.dropTarget
        onDropTargetChanged: {
            if (side.dropTarget) {
                WindowDrag.target = side.dropTarget;
                WindowDrag.targetScreen = side.screen;
            } else if (WindowDrag.targetScreen === side.screen) {
                WindowDrag.target = null;
                WindowDrag.targetScreen = null;
            }
        }

        // ── showing and hiding ──
        property bool shown: false
        // the mouse (or a window you're dragging) is on the panel or the left edge
        readonly property bool held: edgeHover.hovered || panelHover.hovered || side.dragHere
        onHeldChanged: {
            if (held) {
                hideDelay.stop();
                shown = true;
            } else {
                hideDelay.restart();
            }
        }
        Timer {
            id: hideDelay
            interval: 500
            onTriggered: side.shown = false
        }

        // Only these take the mouse; the rest of the window lets clicks through. While
        // it's in, that's just the left 2 px of the screen, below the bar (so going for
        // the bar's first button doesn't bring it out).
        mask: Region {
            item: edge
            Region {
                item: panel.visible ? panel : null
            }
        }

        // the left edge: push the mouse here to bring it out
        Item {
            id: edge
            x: 0
            y: Theme.barHeight + Theme.radius
            width: 2
            height: parent.height - y
            HoverHandler {
                id: edgeHover
            }
        }

        SidePanel {
            id: panel
            open: side.shown
            baseX: 0
            anchorY: side.height / 2
            HoverHandler {
                id: panelHover
            }

            Workspaces {
                id: wsList
                screen: side.screen
                dragging: side.dragHere
                dragPoint: Qt.point(side.dragX, side.dragY)
                // fits between the bar and the bottom of the screen (centered, so the
                // same room above and below), past that it scrolls
                maxHeight: side.height - 2 * (Theme.barHeight + 8) - 2 * (panel.curve + panel.padding)
            }
        }
    }
  '';

  # The dock's button in the top bar: pin, unpin and order the dock's apps.
  xdg.configFile."quickshell/DockControl.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic
    import Quickshell

    // ── Dock ── (in the top bar, where the open-apps/tray widget used to be)
    // The dock itself lives at the bottom of the screen (Dock.qml): push the mouse
    // against the bottom edge to bring it up. This is where you pick what's on it.
    //   Pinned   your pins, in dock order: arrows move one left / right, x unpins it.
    //   Add      search your apps (name, description, keywords) and click the pin.
    // Right-clicking an app in the dock pins or unpins it too.
    Widget {
        id: root
        icon: "dock_to_bottom"

        Column {
            id: card
            width: 320
            spacing: 8

            // clear the search each time it opens
            readonly property bool open: root.popupShown
            onOpenChanged: if (!open)
                search.text = ""

            // ── header ──
            Item {
                width: parent.width
                height: 26
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dock"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 1.2
                    font.weight: 700
                    font.letterSpacing: Theme.letterSpacing
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: DockData.pins.length + " pinned"
                    color: Theme.text
                    opacity: 0.6
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 0.85
                }
            }

            // ── pinned ──
            Text {
                visible: DockData.pins.length === 0
                width: parent.width
                wrapMode: Text.Wrap
                text: "Nothing pinned yet. Find an app below and click its pin."
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.9
            }
            ListView {
                id: pinList
                visible: count > 0
                width: parent.width
                height: Math.min(contentHeight, 200)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: DockData.pins
                ScrollBar.vertical: ThinScrollBar {}

                delegate: Rectangle {
                    id: pinRow
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    height: 36
                    radius: Theme.radius
                    color: pinMouse.containsMouse ? Theme.pill : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        AppIcon {
                            id: pinIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            icon: DockData.iconFor(pinRow.modelData)
                            name: DockData.nameFor(pinRow.modelData)
                        }
                        Text {
                            anchors.left: pinIcon.right
                            anchors.leftMargin: 10
                            anchors.right: pinButtons.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: DockData.nameFor(pinRow.modelData)
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 600
                        }
                        Row {
                            id: pinButtons
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: pinMouse.containsMouse ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                            IconButton {
                                icon: "chevron_left"
                                opacity: pinRow.index > 0 ? 1 : 0.3
                                onClicked: DockData.movePin(pinRow.modelData, -1)
                            }
                            IconButton {
                                icon: "chevron_right"
                                opacity: pinRow.index < DockData.pins.length - 1 ? 1 : 0.3
                                onClicked: DockData.movePin(pinRow.modelData, 1)
                            }
                            IconButton {
                                icon: "close"
                                iconColor: Theme.red
                                onClicked: DockData.unpin(pinRow.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── add: search your apps ──
            TextField {
                id: search
                width: parent.width
                placeholderText: "Search apps to pin"
                placeholderTextColor: Theme.pillIcon
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                leftPadding: 12
                rightPadding: 12
                Keys.onEscapePressed: text = ""
                background: Rectangle {
                    radius: height / 2
                    color: Theme.glass
                    border.width: 1
                    border.color: search.activeFocus ? Theme.accent : Theme.pillIcon
                }
            }
            ListView {
                id: appList
                width: parent.width
                height: Math.min(contentHeight, 240)
                visible: count > 0
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ThinScrollBar {}
                // every app with a launcher entry, A to Z, narrowed down by the search
                model: {
                    const q = search.text.trim().toLowerCase();
                    return [...DesktopEntries.applications.values].filter(e => !e.noDisplay && (q === "" || (e.name + " " + e.genericName + " " + e.comment + " " + [...e.keywords].join(" ")).toLowerCase().includes(q))).sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
                }

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    readonly property bool pinned: DockData.pins.indexOf(modelData.id) >= 0
                    width: ListView.view.width
                    height: 36
                    radius: Theme.radius
                    color: appMouse.containsMouse ? Theme.pill : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DockData.togglePin(appRow.modelData.id)

                        AppIcon {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            icon: appRow.modelData.icon
                            name: appRow.modelData.name
                        }
                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 10
                            anchors.right: pinMark.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                text: appRow.modelData.name
                                elide: Text.ElideRight
                                color: appRow.pinned ? Theme.accent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 600
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: appRow.modelData.genericName || appRow.modelData.comment
                                elide: Text.ElideRight
                                color: Theme.text
                                opacity: 0.55
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.8
                            }
                        }
                        // the pin: filled when it's on the dock
                        Text {
                            id: pinMark
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "push_pin"
                            color: appRow.pinned ? Theme.accent : Theme.text
                            opacity: appRow.pinned || appMouse.containsMouse ? 1 : 0.3
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: ({
                                    "FILL": appRow.pinned ? 1 : 0,
                                    "wght": 700,
                                    "opsz": 20,
                                    "GRAD": 0
                                })
                        }
                    }
                }
            }
            Text {
                visible: appList.count === 0
                text: "No apps match."
                color: Theme.text
                opacity: 0.5
                font.family: Theme.font
                font.pixelSize: Theme.textSize * 0.9
            }
        }
    }
  '';

  # The shell's sounds (KDE's Ocean sound theme): played by Sounds.qml.
  xdg.configFile."quickshell/Sounds.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell

    // The shell's sounds, from KDE's Ocean sound theme (uiSounds in home.nix; a few
    // names play a stand-in from Ocean, see oceanStandIns there):
    //   message-new-instant     a notification
    //   software-update-urgent  a critical notification
    //   device-added / -removed a USB device or an audio output (DeviceWatch.qml)
    //   system-ready            logging in, on the black screen before the desktop (fade.qml)
    //   system-shutdown         log out / restart / power off (shell.qml)
    //   alarm-clock-elapsed     a timer running out, an event's reminder (Planner.qml)
    //   bell                    a reminder (Planner.qml)
    //   battery-low / -caution  a battery down to 15% / 5% (BatteryWatch.qml)
    //   battery-full            the laptop's battery charged (BatteryWatch.qml)
    //   power-plug / -unplug    the laptop's charger in / out (BatteryWatch.qml)
    // The lock screen plays its own lock sound (Ocean's service-logout; configuration.nix).
    Singleton {
        id: sounds

        readonly property string dir: "${uiSounds}"
        property bool enabled: true

        function path(name) {
            return dir + "/" + name + ".oga";
        }
        // the same sound twice within a moment (a burst of notifications) plays once
        property var lastPlayed: ({})
        function play(name) {
            if (!enabled)
                return;
            const now = Date.now();
            if (now - (lastPlayed[name] || 0) < 250)
                return;
            lastPlayed[name] = now;
            Quickshell.execDetached(["${pkgs.pipewire}/bin/pw-play", path(name)]);
        }
    }
  '';

  # USB devices and audio outputs coming and going: a notification and a sound.
  xdg.configFile."quickshell/DeviceWatch.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import Quickshell.Services.Pipewire

    // Plug in or pull out a USB device, or an audio output appears or goes away (USB or
    // Bluetooth headphones, a DAC, HDMI audio...): a notification saying which, with the
    // device-added / device-removed sound. shell.qml makes one of these.
    //
    // A USB audio device would count twice (it's a USB device and an audio output), so
    // a USB event waits a moment and is dropped if an audio output changed around then:
    // the audio one says more.
    //
    // Quiet for a few seconds after Quickshell starts and after the computer wakes up,
    // while things are found (or come back) by themselves.
    Scope {
        id: watch

        // ── quiet while starting and waking ──
        property bool settled: false
        Timer {
            id: settle
            interval: 4000
            running: true
            onTriggered: watch.settled = true
        }
        // timers don't count time asleep: a big gap between ticks means it just woke up
        property double lastTick: Date.now()
        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: {
                const now = Date.now();
                if (now - watch.lastTick > 8000) {
                    watch.settled = false;
                    settle.restart();
                }
                watch.lastTick = now;
            }
        }

        function tell(added, title, name, icon) {
            Quickshell.execDetached(["${pkgs.libnotify}/bin/notify-send", "-a", "Devices", "-i", icon, "-h", "boolean:suppress-sound:true", title, name]);
            Sounds.play(added ? "device-added" : "device-removed");
        }

        // ── audio outputs ──
        property var outputs: ({})       // node id -> name, of the outputs there are now
        property double lastAudio: 0     // when one last came or went
        function syncOutputs() {
            const now = {};
            for (const n of Pipewire.nodes.values)
                if (n.isSink && !n.isStream && n.audio)
                    now[n.id] = n.description || n.nickname || n.name;
            if (settled) {
                for (const id in now)
                    if (!(id in outputs))
                        audioChanged(true, now[id]);
                for (const id in outputs)
                    if (!(id in now))
                        audioChanged(false, outputs[id]);
            }
            outputs = now;
        }
        function audioChanged(added, name) {
            lastAudio = Date.now();
            tell(added, added ? "Audio output connected" : "Audio output disconnected", name, added ? "audio-speakers" : "audio-volume-muted");
        }
        Connections {
            target: Pipewire.nodes
            function onValuesChanged() {
                watch.syncOutputs();
            }
        }
        Component.onCompleted: syncOutputs()

        // ── USB devices ──
        // udev reports each event as KEY=value lines ending with a blank line.
        property var event: ({})
        property var waiting: []         // USB events held back a moment: [{ added, name, at }]
        Process {
            running: true
            command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--property"]
            stdout: SplitParser {
                onRead: line => {
                    if (line.trim() === "") {
                        watch.usbEvent(watch.event);
                        watch.event = {};
                        return;
                    }
                    const i = line.indexOf("=");
                    if (i > 0)
                        watch.event[line.slice(0, i)] = line.slice(i + 1);
                }
            }
        }
        function usbEvent(e) {
            if (!settled || e.DEVTYPE !== "usb_device" || (e.ACTION !== "add" && e.ACTION !== "remove"))
                return;
            if ((e.TYPE || "").startsWith("9/"))    // a hub (USB class 9): not interesting
                return;
            const tidy = s => (s || "").replace(/_/g, " ").trim();
            const vendor = tidy(e.ID_VENDOR_FROM_DATABASE || e.ID_VENDOR);
            const model = tidy(e.ID_MODEL_FROM_DATABASE || e.ID_MODEL);
            let name = model === "" ? vendor : model.toLowerCase().startsWith(vendor.toLowerCase()) ? model : (vendor + " " + model).trim();
            waiting = waiting.concat([{
                    "added": e.ACTION === "add",
                    "name": name || "USB device",
                    "at": Date.now()
                }]);
            usbDelay.restart();
        }
        Timer {
            id: usbDelay
            interval: 2500
            onTriggered: {
                for (const u of watch.waiting)
                    if (Math.abs(watch.lastAudio - u.at) > 4000)
                        watch.tell(u.added, u.added ? "USB device connected" : "USB device disconnected", u.name, "drive-removable-media-usb");
                watch.waiting = [];
            }
        }
    }
  '';

  # Battery warnings: the laptop battery (if there is one) and Bluetooth devices.
  xdg.configFile."quickshell/BatteryWatch.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Bluetooth
    import Quickshell.Services.UPower

    // Battery notifications and sounds. shell.qml makes one of these.
    //
    // The laptop battery (UPower's combined battery; nothing happens on a desktop):
    //   plugged in       "Charging"        power-plug
    //   unplugged        "On battery"      power-unplug (power-unplug-battery-low if it's low)
    //   down to 15%      "Battery low"     battery-low
    //   down to 5%       critical          battery-caution
    //   full (plugged)   "Fully charged"   battery-full
    //
    // Bluetooth devices that report a battery (headphones, controllers, mice...):
    //   down to 15% / 5%, the same as the laptop's.
    //
    // Each warning comes once per discharge: it's armed again when the battery is
    // charging, or has climbed a few percent back above the line.
    // Quiet for a few seconds after Quickshell starts and after the computer wakes up.
    Scope {
        id: watch

        readonly property int low: 15
        readonly property int critical: 5

        // ── quiet while starting and waking (same as DeviceWatch.qml) ──
        property bool settled: false
        Timer {
            id: settle
            interval: 4000
            running: true
            onTriggered: {
                watch.settled = true;
                watch.checkLevels();
            }
        }
        property double lastTick: Date.now()
        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: {
                const now = Date.now();
                if (now - watch.lastTick > 8000) {
                    watch.settled = false;
                    settle.restart();
                }
                watch.lastTick = now;
            }
        }

        function tell(title, body, icon, sound, urgent) {
            Quickshell.execDetached(["${pkgs.libnotify}/bin/notify-send", "-a", "Battery", "-i", icon, "-u", urgent ? "critical" : "normal", "-h", "boolean:suppress-sound:true", title, body]);
            Sounds.play(sound);
        }

        // ── the laptop battery ──
        readonly property var battery: UPower.displayDevice
        readonly property bool hasBattery: !!battery && battery.ready && battery.isLaptopBattery
        readonly property int percent: hasBattery ? Math.round(battery.percentage * 100) : 100
        readonly property bool charging: !UPower.onBattery

        Connections {
            target: UPower
            function onOnBatteryChanged() {
                if (!watch.settled || !watch.hasBattery)
                    return;
                watch.toldFull = false;
                const next = Object.assign({}, watch.warned);
                if (watch.charging) {
                    delete next.laptop;    // re-arm the laptop's warnings
                    watch.warned = next;
                    watch.tell("Charging", watch.percent + "%", "battery-good-charging", "power-plug", false);
                } else if (watch.percent <= watch.low) {
                    // unplugged while it's already low: this one notice is the warning
                    const isCritical = watch.percent <= watch.critical;
                    next.laptop = isCritical ? "critical" : "low";
                    watch.warned = next;
                    watch.tell(isCritical ? "On battery, very low" : "On battery, low", watch.percent + "%", isCritical ? "battery-caution" : "battery-low", "power-unplug-battery-low", isCritical);
                } else
                    watch.tell("On battery", watch.percent + "%", "battery-good", "power-unplug", false);
            }
        }
        // once per plug-in: some laptops hop between "charging" and "full" near the top
        property bool toldFull: false
        Connections {
            target: watch.battery
            function onStateChanged() {
                if (watch.toldFull || !watch.settled || !watch.hasBattery || !watch.charging || watch.battery.state !== UPowerDeviceState.FullyCharged)
                    return;
                watch.toldFull = true;
                watch.tell("Fully charged", "You can unplug", "battery-full-charged", "battery-full", false);
            }
        }

        // ── the levels ──
        // key -> the worst warning given so far this discharge: "low" or "critical"
        property var warned: ({})
        function level(key, name, pct, draining, isLaptop) {
            const was = warned[key] || "";
            const next = Object.assign({}, warned);
            if (!draining || pct > low + 3)
                delete next[key];
            else if (pct <= critical && was !== "critical") {
                next[key] = "critical";
                tell(isLaptop ? "Battery very low" : name + " battery very low", pct + "%" + (isLaptop ? ", plug in now" : ""), "battery-caution", "battery-caution", true);
            } else if (pct <= low && pct > critical && was === "") {
                next[key] = "low";
                tell(isLaptop ? "Battery low" : name + " battery low", pct + "%", "battery-low", "battery-low", false);
            } else if (pct > critical + 3 && was === "critical")
                next[key] = "low";    // charged back up a bit: the critical one can come again
            warned = next;
        }
        function checkLevels() {
            if (!settled)
                return;
            if (hasBattery)
                level("laptop", "", percent, !charging, true);
            for (const d of Bluetooth.devices.values) {
                if (d.connected && d.batteryAvailable)
                    level(d.dbusPath, d.name || d.deviceName || "Bluetooth device", Math.round(d.battery * 100), true, false);
                else if (d.dbusPath in warned) {
                    const next = Object.assign({}, warned);
                    delete next[d.dbusPath];    // disconnected: start over next time
                    warned = next;
                }
            }
        }
        // the laptop's level as it changes; Bluetooth batteries every half minute
        // (they only change every few minutes anyway)
        onPercentChanged: checkLevels()
        Timer {
            interval: 30000
            running: true
            repeat: true
            onTriggered: watch.checkLevels()
        }
    }
  '';

  xdg.configFile."quickshell/WeatherData.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io

    // Weather for the bar, from Open-Meteo (open-meteo.com: free, no account or key).
    // One copy shared by every monitor's bar. The place you pick and °F/°C are saved in
    // ~/.local/state/quickshell/weather.json. Refreshes every 15 minutes.
    // Temperatures are always fetched in °C and converted for display (show()), so
    // switching °F / °C is instant and doesn't need the internet. The same switch picks
    // the other units: °F shows mph, inches, miles and inHg; °C shows km/h, mm, km and
    // hPa (fetched in km/h, mm, m and hPa, converted the same way).
    // Air quality and the UV index come from Open-Meteo's air quality service
    // (air-quality-api.open-meteo.com), fetched alongside.
    Singleton {
        id: w

        readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

        // ── settings ──
        property var place: null      // { name, region, lat, lon }; null until you pick one
        property bool fahrenheit: Qt.locale().measurementSystem === Locale.ImperialUSSystem
        // 12-hour clock ("7PM") if your locale uses one, else 24-hour ("19:00")
        readonly property bool clock12: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0

        // a temperature (°C, as stored) in the unit you picked
        function show(c) {
            return fahrenheit ? c * 9 / 5 + 32 : c;
        }
        // ...rounded, with a degree sign: "72°" ("--" when there's none)
        function degText(c) {
            return c === undefined || c === null || isNaN(c) ? "--" : Math.round(show(c)) + "°";
        }

        // ── what Open-Meteo sent ──
        property var data: null
        property bool loading: false
        property string error: ""
        property double fetchedAt: 0
        readonly property bool hasData: data !== null && !!data.current

        // ── place search ──
        property var results: []      // [{ name, region, lat, lon }]
        property bool searching: false

        // ── handy values (all in °C) ──
        readonly property real temp: hasData ? data.current.temperature_2m : 0
        readonly property int code: hasData ? data.current.weather_code : -1
        readonly property bool isDay: hasData ? data.current.is_day === 1 : true
        readonly property real todayHigh: hasData ? data.daily.temperature_2m_max[0] : 0
        readonly property real todayLow: hasData ? data.daily.temperature_2m_min[0] : 0
        readonly property real feelsLike: hasData ? data.current.apparent_temperature : NaN

        // air quality and UV right now: { us_aqi, pm2_5, pm10, uv_index }, or null
        property var air: null

        // ── units (°F means US units throughout) ──
        function windText(kmh) {
            if (kmh === undefined || kmh === null || isNaN(kmh))
                return "--";
            return fahrenheit ? Math.round(kmh / 1.609344) + " mph" : Math.round(kmh) + " km/h";
        }
        function rainText(mm) {
            if (mm === undefined || mm === null || isNaN(mm))
                return "--";
            return fahrenheit ? (mm / 25.4).toFixed(2) + " in" : mm.toFixed(1) + " mm";
        }
        function distText(m) {
            if (m === undefined || m === null || isNaN(m))
                return "--";
            if (fahrenheit) {
                const mi = m / 1609.344;
                return (mi >= 10 ? Math.round(mi) : mi.toFixed(1)) + " mi";
            }
            return (m >= 10000 ? Math.round(m / 1000) : (m / 1000).toFixed(1)) + " km";
        }
        function pressureText(hpa) {
            if (hpa === undefined || hpa === null || isNaN(hpa))
                return "--";
            return fahrenheit ? (hpa * 0.0295300).toFixed(2) + " inHg" : Math.round(hpa) + " hPa";
        }
        // wind direction in degrees (where it comes from) -> "NW"
        function compass(deg) {
            if (deg === undefined || deg === null || isNaN(deg))
                return "";
            return ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"][Math.round(deg / 22.5) % 16];
        }
        // seconds -> "11h 23m"
        function spanText(sec) {
            if (sec === undefined || sec === null || isNaN(sec))
                return "--";
            const m = Math.round(sec / 60);
            return Math.floor(m / 60) + "h " + (m % 60) + "m";
        }
        // (short: with a plain space, for the small tiles)
        function uvText(uv, short) {
            if (uv === undefined || uv === null || isNaN(uv))
                return "--";
            const r = Math.round(uv);
            return r + (short ? " " : "  ·  ") + (r <= 2 ? "Low" : r <= 5 ? "Moderate" : r <= 7 ? "High" : r <= 10 ? "Very high" : "Extreme");
        }
        // US AQI -> its EPA category
        function aqiText(aqi, short) {
            if (aqi === undefined || aqi === null || isNaN(aqi))
                return "--";
            const r = Math.round(aqi);
            return r + (short ? " " : "  ·  ") + (r <= 50 ? "Good" : r <= 100 ? "Moderate" : r <= 150 ? "Unhealthy for some" : r <= 200 ? "Unhealthy" : r <= 300 ? "Very unhealthy" : "Hazardous");
        }
        function aqiColor(aqi) {
            if (aqi === undefined || aqi === null || isNaN(aqi))
                return Theme.text;
            return aqi <= 50 ? Theme.green : aqi <= 100 ? Theme.yellow : aqi <= 150 ? Theme.orange : Theme.red;
        }

        // ── loading and saving the settings ──
        FileView {
            id: settingsFile
            path: w.stateDir + "/weather.json"
            blockLoading: true
            printErrors: false
        }
        Component.onCompleted: {
            try {
                const s = JSON.parse(settingsFile.text() || "{}");
                if (s.place)
                    place = s.place;
                if (s.fahrenheit !== undefined)
                    fahrenheit = s.fahrenheit;
            } catch (e) {}
            refresh();
        }
        function save() {
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/weather.json\"", "sh", stateDir, JSON.stringify({
                    "place": place,
                    "fahrenheit": fahrenheit
                })]);
        }
        function setPlace(p) {
            place = p;
            data = null;
            results = [];
            save();
            refresh();
        }
        function setFahrenheit(f) {
            if (f === fahrenheit)
                return;
            fahrenheit = f;
            save();
        }

        // ── talking to Open-Meteo ──
        function get(url, ok, fail) {
            const x = new XMLHttpRequest();
            x.onreadystatechange = () => {
                if (x.readyState !== XMLHttpRequest.DONE)
                    return;
                if (x.status === 200) {
                    try {
                        ok(JSON.parse(x.responseText));
                    } catch (e) {
                        fail("Bad answer from the weather service");
                    }
                } else {
                    fail(x.status ? "Weather service error " + x.status : "No connection");
                }
            };
            x.open("GET", url);
            x.send();
        }
        function refresh() {
            if (!place)
                return;
            loading = true;
            error = "";
            get("https://api.open-meteo.com/v1/forecast?latitude=" + place.lat + "&longitude=" + place.lon
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,precipitation,weather_code,is_day,cloud_cover,pressure_msl,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
                + "&hourly=temperature_2m,apparent_temperature,weather_code,is_day,precipitation_probability"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant"
                + "&timezone=auto&forecast_days=7", r => {
                data = r;
                fetchedAt = Date.now();
                loading = false;
            }, e => {
                error = e;
                loading = false;
            });
            // air quality and UV (a separate service; the card just leaves them out if it fails)
            get("https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + place.lat + "&longitude=" + place.lon
                + "&current=us_aqi,pm2_5,pm10,uv_index&timezone=auto", r => {
                air = r.current || null;
            }, e => {
                air = null;
            });
        }
        function search(q) {
            q = q.trim();
            if (q.length < 2) {
                results = [];
                return;
            }
            searching = true;
            get("https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=" + encodeURIComponent(q), r => {
                results = (r.results || []).map(x => ({
                            "name": x.name,
                            "region": [x.admin1, x.country].filter(s => !!s).join(", "),
                            "lat": x.latitude,
                            "lon": x.longitude
                        }));
                searching = false;
            }, e => {
                results = [];
                searching = false;
            });
        }
        Timer {
            interval: 15 * 60 * 1000
            running: true
            repeat: true
            onTriggered: w.refresh()
        }
        // when the popup opens and the data is older than 10 minutes
        function refreshIfOld() {
            if (Date.now() - fetchedAt > 10 * 60 * 1000)
                refresh();
        }

        // ── turning numbers into words, icons and colors ──
        // Weather codes are the WMO ones Open-Meteo uses.
        function describe(c) {
            if (c === 0)
                return "Clear";
            if (c === 1)
                return "Mostly clear";
            if (c === 2)
                return "Partly cloudy";
            if (c === 3)
                return "Cloudy";
            if (c === 45 || c === 48)
                return "Fog";
            if (c >= 51 && c <= 55)
                return "Drizzle";
            if (c === 56 || c === 57)
                return "Freezing drizzle";
            if (c === 61 || c === 80)
                return "Light rain";
            if (c === 63 || c === 81)
                return "Rain";
            if (c === 65 || c === 82)
                return "Heavy rain";
            if (c === 66 || c === 67)
                return "Freezing rain";
            if (c >= 71 && c <= 77 || c === 85 || c === 86)
                return "Snow";
            if (c === 95)
                return "Thunderstorms";
            if (c === 96 || c === 99)
                return "Thunderstorms, hail";
            return "—";
        }
        // Material Symbols icon name
        function icon(c, day) {
            if (c === 0 || c === 1)
                return day ? "clear_day" : "clear_night";
            if (c === 2)
                return day ? "partly_cloudy_day" : "partly_cloudy_night";
            if (c === 3)
                return "cloud";
            if (c === 45 || c === 48)
                return "foggy";
            if (c >= 51 && c <= 55 || c === 61)
                return "rainy_light";
            if (c === 63 || c === 80 || c === 81)
                return "rainy";
            if (c === 65 || c === 82)
                return "rainy_heavy";
            if (c === 56 || c === 57 || c === 66 || c === 67)
                return "weather_mix";
            if (c >= 71 && c <= 77 || c === 85 || c === 86)
                return "weather_snowy";
            if (c === 95)
                return "thunderstorm";
            if (c === 96 || c === 99)
                return "weather_hail";
            return "cloud";
        }
        function iconColor(c, day) {
            if (c <= 2)
                return day ? Theme.yellow : Theme.blue;
            if (c >= 51 && c <= 67 || c >= 80 && c <= 82)
                return Theme.blue;
            if (c >= 95)
                return Theme.yellow;
            return Theme.text;
        }
        // Color for a temperature in °C (for the range bars): cold blue -> aqua -> green -> yellow -> orange
        function tempColor(c) {
            const f = c * 9 / 5 + 32;
            if (f < 40)
                return Theme.blue;
            if (f < 55)
                return Theme.cyan;
            if (f < 70)
                return Theme.green;
            if (f < 85)
                return Theme.yellow;
            return Theme.orange;
        }

        // "2026-10-17T19:00" -> "7PM" (or "19:00" with a 24-hour locale); minutes shown when not on the hour
        function clockLabel(iso) {
            const h = parseInt(iso.substr(11, 2));
            const m = iso.substr(14, 2);
            if (!clock12)
                return iso.substr(11, 5);
            const h12 = h % 12 === 0 ? 12 : h % 12;
            return h12 + (m === "00" ? "" : ":" + m) + (h < 12 ? "AM" : "PM");
        }

        // The next 24 hours (now first), with sunrise / sunset slotted in where they happen.
        // [{ time, label, icon, color, temp, rain }] (rain: % chance, or -1)
        readonly property var hours: {
            if (!hasData)
                return [];
            const H = data.hourly, D = data.daily;
            const nowHour = data.current.time.substr(0, 13);
            let i = H.time.findIndex(t => t.substr(0, 13) === nowHour);
            if (i < 0)
                i = 0;
            const list = [];
            for (let k = i; k < Math.min(i + 24, H.time.length); k++)
                list.push({
                    "time": H.time[k],
                    "label": k === i ? "Now" : clockLabel(H.time[k]),
                    "icon": icon(H.weather_code[k], H.is_day[k] === 1),
                    "color": iconColor(H.weather_code[k], H.is_day[k] === 1),
                    "temp": k === i ? data.current.temperature_2m : H.temperature_2m[k],
                    "rain": H.precipitation_probability ? H.precipitation_probability[k] : -1
                });
            const end = list.length ? list[list.length - 1].time : "";
            for (let d = 0; d < D.time.length; d++) {
                for (const [key, name] of [["sunrise", "Sunrise"], ["sunset", "Sunset"]]) {
                    const t = D[key][d];
                    if (t > data.current.time && t < end) {
                        // temperature of the hour it falls in
                        const j = H.time.findIndex(x => x.substr(0, 13) === t.substr(0, 13));
                        list.push({
                            "time": t,
                            "label": clockLabel(t),
                            "icon": "wb_twilight",
                            "color": Theme.orange,
                            "temp": j >= 0 ? H.temperature_2m[j] : NaN,
                            "rain": -1,
                            "event": name
                        });
                    }
                }
            }
            list.sort((a, b) => a.time < b.time ? -1 : a.time > b.time ? 1 : 0);
            return list;
        }

        // One day's 24 hours (d = 0 for today), for the day's page:
        // [{ time, label, icon, color, temp, rain }]
        function hoursOf(d) {
            if (!hasData || d < 0 || d >= data.daily.time.length)
                return [];
            const H = data.hourly, day = data.daily.time[d];
            const out = [];
            for (let k = 0; k < H.time.length; k++) {
                if (H.time[k].substr(0, 10) !== day)
                    continue;
                out.push({
                    "time": H.time[k],
                    "label": clockLabel(H.time[k]),
                    "icon": icon(H.weather_code[k], H.is_day[k] === 1),
                    "color": iconColor(H.weather_code[k], H.is_day[k] === 1),
                    "temp": H.temperature_2m[k],
                    "rain": H.precipitation_probability ? H.precipitation_probability[k] : -1
                });
            }
            return out;
        }

        // The next 7 days, plus the week's range: [{ index, label, longLabel, code,
        // icon, color, low, high, feelsLow, feelsHigh, rainChance, rainSum, windMax,
        // gustMax, windDir, uvMax, sunrise, sunset, daylight, sunshine }]
        // (temperatures °C, wind km/h, rain mm, times "2026-10-28T07:31", spans seconds)
        readonly property var days: {
            if (!hasData)
                return [];
            const D = data.daily;
            const v = (key, d) => D[key] ? D[key][d] : NaN;
            const out = [];
            for (let d = 0; d < Math.min(7, D.time.length); d++) {
                const p = D.time[d].split("-");
                const date = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]));
                out.push({
                    "index": d,
                    "label": d === 0 ? "Today" : Qt.formatDate(date, "ddd"),
                    "longLabel": (d === 0 ? "Today, " : d === 1 ? "Tomorrow, " : Qt.formatDate(date, "dddd") + ", ") + Qt.formatDate(date, "MMM d"),
                    "code": D.weather_code[d],
                    "icon": icon(D.weather_code[d], true),
                    "color": iconColor(D.weather_code[d], true),
                    "low": D.temperature_2m_min[d],
                    "high": D.temperature_2m_max[d],
                    "feelsLow": v("apparent_temperature_min", d),
                    "feelsHigh": v("apparent_temperature_max", d),
                    "rainChance": v("precipitation_probability_max", d),
                    "rainSum": v("precipitation_sum", d),
                    "windMax": v("wind_speed_10m_max", d),
                    "gustMax": v("wind_gusts_10m_max", d),
                    "windDir": v("wind_direction_10m_dominant", d),
                    "uvMax": v("uv_index_max", d),
                    "sunrise": D.sunrise[d],
                    "sunset": D.sunset[d],
                    "daylight": v("daylight_duration", d),
                    "sunshine": v("sunshine_duration", d)
                });
            }
            return out;
        }
        // the next sunrise or sunset from now: { name, time } or null
        readonly property var nextSun: {
            if (!hasData)
                return null;
            const now = data.current.time;
            for (const day of days)
                for (const [name, t] of [["Sunrise", day.sunrise], ["Sunset", day.sunset]])
                    if (t > now)
                        return {
                            "name": name,
                            "time": t
                        };
            return null;
        }
        readonly property real weekLow: days.length ? Math.min(...days.map(d => d.low)) : 0
        readonly property real weekHigh: days.length ? Math.max(...days.map(d => d.high)) : 1
    }
  '';

  xdg.configFile."quickshell/Weather.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic
    import Quickshell

    // ── Weather ──
    // In the bar: the current conditions icon and temperature. Click for the card:
    //   place + now   the temperature, conditions, high / low and what it feels like
    //   tiles         humidity, wind, UV, rain, air quality, the next sunrise / sunset;
    //                 click one for everything about right now (the details page)
    //   hours         the next 24 (scroll sideways: wheel, drag, or the thin scrollbar),
    //                 with sunrise / sunset and the chance of rain
    //   days          the next 7, with temperature range bars; click one for its page:
    //                 feels like, rain, wind, UV, sunrise / sunset, daylight, its hours
    // A page's back arrow (or closing the card) goes back. Click the place name to
    // search for another one; °F / °C switches in the top-right corner of the card
    // (°F also means mph, inches, miles).
    // Data: WeatherData.qml (Open-Meteo).
    Widget {
        id: root

        property bool picking: false        // the place search is open
        readonly property bool shown: picking || !WeatherData.place

        // t is in °C (that's how WeatherData keeps it); shown in the unit you picked
        function deg(t) {
            return isNaN(t) ? "--" : Math.round(WeatherData.show(t)) + "°";
        }

        button: Pill {
            icon: !WeatherData.place ? "location_on" : WeatherData.hasData ? WeatherData.icon(WeatherData.code, WeatherData.isDay) : "cloud"
            iconColor: WeatherData.hasData ? WeatherData.iconColor(WeatherData.code, WeatherData.isDay) : Theme.text
            text: !WeatherData.place ? "Weather" : WeatherData.hasData ? root.deg(WeatherData.temp) : "--"
        }

        Column {
            id: card
            width: 360
            spacing: 12

            // which page: "main", "day" (the day at dayIndex) or "details" (right now)
            property string page: "main"
            property int dayIndex: 0
            readonly property var day: WeatherData.days[dayIndex] ?? null
            readonly property bool onMain: !root.shown && page === "main"

            // fresh data each time it opens (if it's more than 10 minutes old); back to the
            // main page when it closes
            readonly property bool open: root.popupShown
            onOpenChanged: if (open) {
                WeatherData.refreshIfOld();
            } else {
                root.picking = false;
                page = "main";
            }

            // ── pieces used below ──
            // (Inline components can't see this file's ids, so what they need comes in
            // through their own properties: a page header's back is a signal, temperatures
            // go through WeatherData.degText.)
            // a tile: an icon and a name, the value under them
            component Tile: Rectangle {
                id: tile
                property string icon: ""
                property color iconColor: Theme.accent
                property string label: ""
                property string value: ""
                property color valueColor: Theme.text
                property bool clickable: false
                signal clicked
                width: 116            // three to the card's 360, with the grid's gaps
                height: 56
                radius: Theme.radius
                color: tileMouse.containsMouse && tile.clickable ? Theme.pill : Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, Theme.pill.a * 0.6)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Column {
                    x: 10
                    width: tile.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Row {
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.icon
                            color: tile.iconColor
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize * 0.9
                            font.variableAxes: Theme.iconAxes
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.label
                            color: Theme.text
                            opacity: 0.7
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.8
                            font.weight: 600
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: tile.value
                        color: tile.valueColor
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        font.weight: 700
                    }
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: tile.clickable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.clicked()
                }
            }
            // hours side by side, six to the card's width, scrolling sideways past that
            component HourStrip: Flickable {
                id: strip
                property var hours: []
                readonly property real cellW: width / 6
                width: parent ? parent.width : 360
                height: 96
                contentWidth: hours.length * cellW
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ThinScrollBar {}
                // the mouse wheel scrolls it sideways
                WheelHandler {
                    onWheel: event => {
                        const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - d));
                    }
                }
                Row {
                    Repeater {
                        model: strip.hours
                        Column {
                            required property var modelData
                            width: strip.cellW
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.text
                                opacity: 0.7
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                                font.weight: 600
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: modelData.color
                                font.family: Theme.iconFont
                                font.pixelSize: 22
                                font.variableAxes: ({
                                        "FILL": 1,
                                        "wght": 500,
                                        "opsz": 24,
                                        "GRAD": 0
                                    })
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: WeatherData.degText(modelData.temp)
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 700
                            }
                            // the chance of rain (sunrise / sunset have none)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.event ? modelData.event : modelData.rain >= 0 ? modelData.rain + "%" : ""
                                color: modelData.event ? Theme.orange : Theme.blue
                                opacity: modelData.event || modelData.rain >= 20 ? 1 : 0.5
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.75
                                font.weight: 600
                            }
                        }
                    }
                }
            }
            // a page's top: the back arrow and its title
            component PageHeader: Item {
                id: header
                property string title: ""
                signal back
                width: parent ? parent.width : 360
                height: 30
                IconButton {
                    id: backButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_back"
                    tip: "Back"
                    onClicked: header.back()
                }
                Text {
                    anchors.left: backButton.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: header.title
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 1.2
                    font.weight: 700
                    font.letterSpacing: Theme.letterSpacing
                }
            }
            // a line in the details list: icon, name, value
            component DetailRow: Item {
                id: drow
                property string icon: ""
                property string label: ""
                property string value: ""
                property color valueColor: Theme.text
                width: parent ? parent.width : 360
                height: 28
                Text {
                    id: drowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    text: drow.icon
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize
                    font.variableAxes: Theme.iconAxes
                }
                Text {
                    anchors.left: drowIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: drow.label
                    color: Theme.text
                    opacity: 0.75
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize
                    font.weight: 600
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: drow.value
                    color: drow.valueColor
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize
                    font.weight: 700
                }
            }

            // ── place + now ──
            Item {
                width: parent.width
                height: 124
                visible: card.onMain

                // place: click it to change it
                Row {
                    id: placeRow
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WeatherData.place ? WeatherData.place.name : ""
                        color: placeMouse.containsMouse ? Theme.accent : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 1.3
                        font.weight: 700
                        font.letterSpacing: Theme.letterSpacing
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "edit_location"
                        color: Theme.text
                        opacity: placeMouse.containsMouse ? 0.9 : 0.4
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        font.variableAxes: Theme.iconAxes
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
                MouseArea {
                    id: placeMouse
                    anchors.fill: placeRow
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picking = true
                }

                // big temperature
                Text {
                    anchors.left: parent.left
                    anchors.top: placeRow.bottom
                    anchors.topMargin: -2
                    text: WeatherData.hasData ? root.deg(WeatherData.temp) : "--"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 54
                    font.weight: 300
                    font.letterSpacing: -2
                }

                // °F / °C: switches right away (no new download)
                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4
                    Chip {
                        label: "°F"
                        selected: WeatherData.fahrenheit
                        onClicked: WeatherData.setFahrenheit(true)
                    }
                    Chip {
                        label: "°C"
                        selected: !WeatherData.fahrenheit
                        onClicked: WeatherData.setFahrenheit(false)
                    }
                }

                // condition, high / low, on the right
                Column {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 2
                    Text {
                        anchors.right: parent.right
                        text: WeatherData.hasData ? WeatherData.icon(WeatherData.code, WeatherData.isDay) : ""
                        color: WeatherData.iconColor(WeatherData.code, WeatherData.isDay)
                        font.family: Theme.iconFont
                        font.pixelSize: 26
                        font.variableAxes: ({
                                "FILL": 1,
                                "wght": 500,
                                "opsz": 24,
                                "GRAD": 0
                            })
                    }
                    Text {
                        anchors.right: parent.right
                        text: WeatherData.hasData ? WeatherData.describe(WeatherData.code) : WeatherData.loading ? "Loading..." : WeatherData.error
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        font.weight: 700
                    }
                    Text {
                        anchors.right: parent.right
                        visible: WeatherData.hasData
                        text: "H:" + root.deg(WeatherData.todayHigh) + "  L:" + root.deg(WeatherData.todayLow)
                        color: Theme.text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                        font.weight: 600
                    }
                    Text {
                        anchors.right: parent.right
                        visible: WeatherData.hasData
                        text: "Feels like " + root.deg(WeatherData.feelsLike)
                        color: Theme.text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.9
                        font.weight: 600
                    }
                }
            }

            Rectangle {
                visible: card.onMain && WeatherData.hasData
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── tiles: right now (click one for the details page) ──
            Grid {
                visible: card.onMain && WeatherData.hasData
                columns: 3
                spacing: 6
                Tile {
                    icon: "water_drop"
                    label: "Humidity"
                    value: WeatherData.hasData ? Math.round(WeatherData.data.current.relative_humidity_2m) + "%" : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
                Tile {
                    icon: "air"
                    label: "Wind"
                    value: WeatherData.hasData ? WeatherData.windText(WeatherData.data.current.wind_speed_10m) + " " + WeatherData.compass(WeatherData.data.current.wind_direction_10m) : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
                Tile {
                    icon: "wb_sunny"
                    iconColor: Theme.yellow
                    label: "UV index"
                    value: WeatherData.air ? WeatherData.uvText(WeatherData.air.uv_index, true) : WeatherData.days.length ? WeatherData.uvText(WeatherData.days[0].uvMax, true) : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
                Tile {
                    icon: "umbrella"
                    iconColor: Theme.blue
                    label: "Rain today"
                    value: WeatherData.days.length && !isNaN(WeatherData.days[0].rainChance) ? WeatherData.days[0].rainChance + "% chance" : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
                Tile {
                    icon: "aq"
                    iconColor: WeatherData.air ? WeatherData.aqiColor(WeatherData.air.us_aqi) : Theme.accent
                    label: "Air quality"
                    value: WeatherData.air ? WeatherData.aqiText(WeatherData.air.us_aqi, true) : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
                Tile {
                    icon: "wb_twilight"
                    iconColor: Theme.orange
                    label: WeatherData.nextSun ? WeatherData.nextSun.name : "Sun"
                    value: WeatherData.nextSun ? WeatherData.clockLabel(WeatherData.nextSun.time) : "--"
                    clickable: true
                    onClicked: card.page = "details"
                }
            }

            Rectangle {
                visible: card.onMain && WeatherData.hasData
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── the next 24 hours ──
            HourStrip {
                visible: card.onMain && WeatherData.hasData
                hours: WeatherData.hours
            }

            Rectangle {
                visible: card.onMain && WeatherData.hasData
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── the next 7 days (click one for its page) ──
            Column {
                visible: card.onMain && WeatherData.hasData
                width: parent.width
                spacing: 4
                Repeater {
                    model: WeatherData.days
                    Item {
                        id: dayRow
                        required property var modelData
                        required property int index
                        width: card.width
                        height: 30

                        // click a day for its page
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -6
                            anchors.rightMargin: -6
                            radius: Theme.radius
                            color: Theme.pill
                            opacity: dayMouse.containsMouse ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.dayIndex = dayRow.index;
                                card.page = "day";
                            }
                        }

                        Text {
                            id: dayName
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            text: dayRow.modelData.label
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 700
                        }
                        Text {
                            id: dayIcon
                            anchors.left: dayName.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignHCenter
                            text: dayRow.modelData.icon
                            color: dayRow.modelData.color
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            font.variableAxes: ({
                                    "FILL": 1,
                                    "wght": 500,
                                    "opsz": 24,
                                    "GRAD": 0
                                })
                        }
                        Text {
                            id: lowText
                            anchors.left: dayIcon.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            text: root.deg(dayRow.modelData.low)
                            color: Theme.text
                            opacity: 0.55
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 600
                        }
                        Text {
                            id: highText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: root.deg(dayRow.modelData.high)
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 700
                        }

                        // the range bar: the whole track is the week's lowest to highest;
                        // the colored part is this day's low to high
                        Rectangle {
                            id: track
                            anchors.left: lowText.right
                            anchors.right: highText.left
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 5
                            radius: 2.5
                            color: Theme.pill

                            readonly property real span: Math.max(1, WeatherData.weekHigh - WeatherData.weekLow)
                            function at(t) {
                                return (t - WeatherData.weekLow) / span * width;
                            }

                            Rectangle {
                                x: track.at(dayRow.modelData.low)
                                width: Math.max(height, track.at(dayRow.modelData.high) - x)
                                height: parent.height
                                radius: parent.radius
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: WeatherData.tempColor(dayRow.modelData.low)
                                    }
                                    GradientStop {
                                        position: 1
                                        color: WeatherData.tempColor(dayRow.modelData.high)
                                    }
                                }
                            }
                            // today: a dot where the temperature is right now
                            Rectangle {
                                visible: dayRow.index === 0
                                width: 9
                                height: 9
                                radius: 4.5
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(track.width, track.at(WeatherData.temp))) - width / 2
                                color: Theme.text
                                border.width: 2
                                border.color: Theme.bg
                            }
                        }
                    }
                }
            }

            // nothing yet (no place, offline, loading)
            Text {
                visible: !root.shown && !WeatherData.hasData
                width: parent.width
                wrapMode: Text.Wrap
                text: WeatherData.loading ? "Loading..." : WeatherData.error !== "" ? WeatherData.error : ""
                color: Theme.text
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: Theme.textSize
            }

            // ════ a day's page ════
            Column {
                visible: !root.shown && card.page === "day" && card.day !== null
                width: card.width
                spacing: 12

                PageHeader {
                    title: card.day ? card.day.longLabel : ""
                    onBack: card.page = "main"
                }
                // its weather, high / low, what it feels like
                Item {
                    width: card.width
                    height: 54
                    Text {
                        id: dayBigIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.day ? card.day.icon : ""
                        color: card.day ? card.day.color : Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 44
                        font.variableAxes: ({
                                "FILL": 1,
                                "wght": 500,
                                "opsz": 48,
                                "GRAD": 0
                            })
                    }
                    Column {
                        anchors.left: dayBigIcon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: card.day ? WeatherData.describe(card.day.code) : ""
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 1.15
                            font.weight: 700
                        }
                        Text {
                            text: card.day ? "Feels like " + root.deg(card.day.feelsHigh) + " / " + root.deg(card.day.feelsLow) : ""
                            color: Theme.text
                            opacity: 0.7
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 0.9
                            font.weight: 600
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.day ? "H:" + root.deg(card.day.high) + "  L:" + root.deg(card.day.low) : ""
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 1.1
                        font.weight: 700
                    }
                }
                Grid {
                    columns: 3
                    spacing: 6
                    Tile {
                        icon: "umbrella"
                        iconColor: Theme.blue
                        label: "Rain chance"
                        value: card.day && !isNaN(card.day.rainChance) ? card.day.rainChance + "%" : "--"
                    }
                    Tile {
                        icon: "rainy"
                        iconColor: Theme.blue
                        label: "Rain"
                        value: card.day ? WeatherData.rainText(card.day.rainSum) : "--"
                    }
                    Tile {
                        icon: "wb_sunny"
                        iconColor: Theme.yellow
                        label: "UV (highest)"
                        value: card.day ? WeatherData.uvText(card.day.uvMax, true) : "--"
                    }
                    Tile {
                        icon: "air"
                        label: "Wind (most)"
                        value: card.day ? WeatherData.windText(card.day.windMax) + " " + WeatherData.compass(card.day.windDir) : "--"
                    }
                    Tile {
                        icon: "storm"
                        label: "Gusts"
                        value: card.day ? WeatherData.windText(card.day.gustMax) : "--"
                    }
                    Tile {
                        icon: "light_mode"
                        iconColor: Theme.yellow
                        label: "Sunshine"
                        value: card.day ? WeatherData.spanText(card.day.sunshine) : "--"
                    }
                    Tile {
                        icon: "wb_twilight"
                        iconColor: Theme.orange
                        label: "Sunrise"
                        value: card.day ? WeatherData.clockLabel(card.day.sunrise) : "--"
                    }
                    Tile {
                        icon: "wb_twilight"
                        iconColor: Theme.orange
                        label: "Sunset"
                        value: card.day ? WeatherData.clockLabel(card.day.sunset) : "--"
                    }
                    Tile {
                        icon: "schedule"
                        label: "Daylight"
                        value: card.day ? WeatherData.spanText(card.day.daylight) : "--"
                    }
                }
                Rectangle {
                    width: card.width
                    height: 1
                    color: Theme.pill
                }
                // its hours
                HourStrip {
                    hours: card.page === "day" ? WeatherData.hoursOf(card.dayIndex) : []
                }
            }

            // ════ the details page: everything about right now ════
            Column {
                visible: !root.shown && card.page === "details" && WeatherData.hasData
                width: card.width
                spacing: 2

                readonly property var cur: WeatherData.hasData ? WeatherData.data.current : ({})

                PageHeader {
                    title: "Right now"
                    onBack: card.page = "main"
                }
                Item {
                    width: 1
                    height: 6
                }
                DetailRow {
                    icon: "thermostat"
                    label: "Temperature"
                    value: root.deg(parent.cur.temperature_2m)
                }
                DetailRow {
                    icon: "accessibility_new"
                    label: "Feels like"
                    value: root.deg(parent.cur.apparent_temperature)
                }
                DetailRow {
                    icon: "water_drop"
                    label: "Humidity"
                    value: parent.cur.relative_humidity_2m !== undefined ? Math.round(parent.cur.relative_humidity_2m) + "%" : "--"
                }
                DetailRow {
                    icon: "dew_point"
                    label: "Dew point"
                    value: root.deg(parent.cur.dew_point_2m)
                }
                DetailRow {
                    icon: "rainy"
                    label: "Rain (last hour)"
                    value: WeatherData.rainText(parent.cur.precipitation)
                }
                DetailRow {
                    icon: "cloud"
                    label: "Cloud cover"
                    value: parent.cur.cloud_cover !== undefined ? Math.round(parent.cur.cloud_cover) + "%" : "--"
                }
                DetailRow {
                    icon: "air"
                    label: "Wind"
                    value: WeatherData.windText(parent.cur.wind_speed_10m) + " " + WeatherData.compass(parent.cur.wind_direction_10m)
                }
                DetailRow {
                    icon: "storm"
                    label: "Gusts"
                    value: WeatherData.windText(parent.cur.wind_gusts_10m)
                }
                DetailRow {
                    icon: "compress"
                    label: "Pressure"
                    value: WeatherData.pressureText(parent.cur.pressure_msl)
                }
                DetailRow {
                    icon: "visibility"
                    label: "Visibility"
                    value: WeatherData.distText(parent.cur.visibility)
                }
                DetailRow {
                    icon: "wb_sunny"
                    label: "UV index"
                    value: WeatherData.air ? WeatherData.uvText(WeatherData.air.uv_index) : "--"
                }
                DetailRow {
                    icon: "aq"
                    label: "Air quality (US AQI)"
                    value: WeatherData.air ? WeatherData.aqiText(WeatherData.air.us_aqi) : "--"
                    valueColor: WeatherData.air ? WeatherData.aqiColor(WeatherData.air.us_aqi) : Theme.text
                }
                DetailRow {
                    icon: "grain"
                    label: "PM2.5"
                    value: WeatherData.air && WeatherData.air.pm2_5 !== undefined ? Math.round(WeatherData.air.pm2_5) + " µg/m³" : "--"
                }
                DetailRow {
                    icon: "grain"
                    label: "PM10"
                    value: WeatherData.air && WeatherData.air.pm10 !== undefined ? Math.round(WeatherData.air.pm10) + " µg/m³" : "--"
                }
                DetailRow {
                    icon: "wb_twilight"
                    label: WeatherData.nextSun ? "Next " + WeatherData.nextSun.name.toLowerCase() : "Sun"
                    value: WeatherData.nextSun ? WeatherData.clockLabel(WeatherData.nextSun.time) : "--"
                }
            }

            // ── picking a place ──
            Column {
                visible: root.shown
                width: parent.width
                spacing: 8

                // title, and a close button (once there's a place to go back to)
                Item {
                    width: parent.width
                    height: 26
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Weather location"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 1.2
                        font.weight: 700
                        font.letterSpacing: Theme.letterSpacing
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        IconButton {
                            visible: !!WeatherData.place
                            icon: "close"
                            onClicked: root.picking = false
                        }
                    }
                }

                // search box
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: height / 2
                    color: Theme.pill
                    border.width: 1
                    border.color: searchField.activeFocus ? Theme.accent : Theme.pill

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        font.variableAxes: Theme.iconAxes
                    }
                    TextField {
                        id: searchField
                        anchors.left: searchIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        color: Theme.text
                        placeholderText: "Search for a city"
                        placeholderTextColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize
                        selectionColor: Theme.accent
                        // search as you type (after a short pause)
                        onTextEdited: searchDelay.restart()
                        onAccepted: {
                            searchDelay.stop();
                            WeatherData.search(text);
                        }
                        Keys.onEscapePressed: root.picking = false
                    }
                    Timer {
                        id: searchDelay
                        interval: 350
                        onTriggered: WeatherData.search(searchField.text)
                    }
                }
                // focus the box as soon as the search shows
                onVisibleChanged: if (visible)
                    searchField.forceActiveFocus()

                // results
                Repeater {
                    model: WeatherData.results
                    Rectangle {
                        id: result
                        required property var modelData
                        width: parent.width
                        height: 40
                        radius: Theme.radius
                        color: resultMouse.containsMouse ? Theme.pill : "transparent"
                        scale: resultMouse.pressed ? 0.97 : 1
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
                            id: pin
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "location_on"
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            font.variableAxes: Theme.iconAxes
                        }
                        Column {
                            anchors.left: pin.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: result.modelData.name
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize
                                font.weight: 700
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: text !== ""
                                text: result.modelData.region
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                            }
                        }
                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // setPlace clears the results, which deletes this row,
                                // so everything else has to happen before it.
                                const p = result.modelData;
                                searchField.text = "";
                                root.picking = false;
                                WeatherData.setPlace(p);
                            }
                        }
                    }
                }
                Text {
                    visible: WeatherData.results.length === 0
                    text: WeatherData.searching ? "Searching..." : searchField.text.trim().length >= 2 ? "No places found" : "Type a city name"
                    color: Theme.text
                    opacity: 0.5
                    font.family: Theme.font
                    font.pixelSize: Theme.textSize * 0.9
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell/Workspaces.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic
    import Quickshell
    import Quickshell.Hyprland

    // This screen's workspaces, top to bottom, for the workspaces dock on the left edge
    // (WorkspaceDock.qml). Each row: the workspace's number, then the icons of the apps
    // open on it (one per app, the dock's icons; past four, three and a "+N"). Big
    // targets: click a row to go there. The highlight slides to the one you're on; the
    // number under the mouse shrinks a little, like the bar's buttons.
    //
    // No taller than maxHeight (WorkspaceDock.qml sets it so the dock fits between the
    // bar and the bottom of the screen). With more workspaces than fit, the list
    // scrolls (mouse wheel, or drag the thin scrollbar on its right), and it always
    // scrolls to show the one you're on.
    //
    // While you drag a window over it (WindowDrag.qml, WorkspaceDock.qml), the workspace
    // under the window gets an accent ring: let go and the window goes there. Hold it
    // near the top or bottom of a list that scrolls and the list scrolls.
    //
    // At the bottom, "+": a new workspace, numbered one past the highest there is (on
    // any screen). Click it to go there; drop a window on it to send the window there.
    // (Hyprland lets an empty workspace go once you leave it.)
    Item {
        id: root

        required property var screen
        property real maxHeight: 100000

        property int cell: 44           // a workspace's row height, and its number's square
        property int gap: 4
        property int slideTime: 300
        property int iconSize: 22       // the app icons
        property int maxIcons: 4

        // room for the icons, if any workspace has an app open
        readonly property bool anyApps: root.list.some(w => w.toplevels.values.length > 0)
        readonly property real iconsWidth: root.anyApps ? 6 + root.maxIcons * root.iconSize + (root.maxIcons - 1) * 4 + 10 : 0
        readonly property real rowWidth: root.cell + root.iconsWidth

        property var monitor: Hyprland.monitorFor(root.screen)
        property var list: !root.monitor ? [] : Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)
        // the "+" row's workspace: one past the highest numbered one anywhere
        readonly property int newId: Hyprland.workspaces.values.reduce((m, w) => Math.max(m, w.id), 0) + 1
        readonly property int rows: root.list.length + 1         // the workspaces, then "+"
        function goToNew() {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.newId + '" })');
        }
        property int activeIndex: root.list.findIndex(w => w.active)

        // Which one the mouse is over: -1 = none.
        property int hoveredIndex: -1
        property real hoverShrink: 0.85
        property int hoverTime: 150

        // ── a window dragged over it ──
        property bool dragging: false
        property point dragPoint: Qt.point(-1, -1)  // the mouse, in the window's coordinates
        // the one under the mouse: -1 = none
        readonly property int dropIndex: root.dragging ? root.indexAt(root.dragPoint) : -1
        // the "+" row stands for a workspace that doesn't exist yet (WindowDrag.qml only
        // needs its id, name and whether it's the one showing)
        readonly property var dropTarget: root.dropIndex < 0 ? null : root.dropIndex < root.list.length ? root.list[root.dropIndex] : ({
                "id": root.newId,
                "name": String(root.newId),
                "active": false
            })
        function indexAt(p) {
            const q = flick.mapFromItem(null, p.x, p.y);
            if (q.x < 0 || q.x >= root.rowWidth || q.y < 0 || q.y >= flick.height)
                return -1;
            // the gaps between rows count as the nearest row, so it doesn't flicker
            const i = Math.floor((q.y + flick.contentY + root.gap / 2) / root.step);
            return Math.max(0, Math.min(root.rows - 1, i));
        }
        // held near the top (-1) or bottom (1) of a list that scrolls
        readonly property int dragScroll: {
            if (!root.dragging || !root.scrolls)
                return 0;
            const q = flick.mapFromItem(null, root.dragPoint.x, root.dragPoint.y);
            if (q.x < 0 || q.x >= flick.width)
                return 0;
            return q.y < root.cell / 2 ? -1 : q.y > flick.height - root.cell / 2 ? 1 : 0;
        }
        Timer {
            interval: 16
            repeat: true
            running: root.dragScroll !== 0
            onTriggered: flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + root.dragScroll * 6))
        }

        readonly property real step: root.cell + root.gap
        readonly property real fullHeight: Math.max(0, root.rows * root.step - root.gap)
        readonly property bool scrolls: root.fullHeight > root.maxHeight

        implicitWidth: root.rowWidth + (root.scrolls ? 10 : 0)    // and room for the scrollbar
        implicitHeight: Math.min(root.fullHeight, root.maxHeight)
        visible: root.list.length > 0

        // Scroll just enough to show the one you're on (when it changes, and when the
        // dock comes out).
        function showActive() {
            if (!root.scrolls || root.activeIndex < 0)
                return;
            const top = root.activeIndex * root.step;
            const bottom = top + root.cell;
            let to = flick.contentY;
            if (top < flick.contentY)
                to = top;
            else if (bottom > flick.contentY + flick.height)
                to = bottom - flick.height;
            if (to !== flick.contentY) {
                follow.to = to;
                follow.restart();
            }
        }
        onActiveIndexChanged: showActive()
        onVisibleChanged: if (visible)
            Qt.callLater(showActive)
        onScrollsChanged: Qt.callLater(showActive)

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: root.fullHeight
            clip: true
            interactive: root.scrolls
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThinScrollBar {}

            NumberAnimation {
                id: follow
                target: flick
                property: "contentY"
                duration: root.slideTime
                easing.type: Easing.OutCubic
            }

            // the highlight under the one you're on
            Rectangle {
                y: root.activeIndex * root.step
                width: root.rowWidth
                height: root.cell
                visible: root.activeIndex >= 0
                radius: Theme.radius + 2
                color: Qt.darker(Theme.accent, 3)
                opacity: 0.75

                Behavior on y {
                    NumberAnimation {
                        duration: root.slideTime
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Column {
                spacing: root.gap

                Repeater {
                    model: root.list

                    Item {
                        id: wsCell
                        required property var modelData
                        required property int index     // 0, 1, 2... its place, top to bottom

                        width: root.rowWidth
                        height: root.cell

                        // the apps open on it (DockData.qml), for the icons
                        readonly property var apps: DockData.appsOn(wsCell.modelData)

                        // a faint background behind each one, so they read as buttons
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius + 2
                            color: Theme.pill
                            opacity: wsCell.modelData.active ? 0 : 0.6
                        }
                        // the ring when a window you're dragging is over it
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius + 2
                            color: "transparent"
                            border.color: Theme.accent
                            border.width: 2
                            opacity: root.dropIndex === wsCell.index ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.hoverTime
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        Text {
                            x: (root.cell - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: wsCell.modelData.name
                            color: wsCell.modelData.active || root.dropIndex === wsCell.index ? Theme.accent : Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize * 1.45
                            font.weight: 700

                            // only the hovered one shrinks (or the one a dragged window is
                            // over); the rest stay as they are
                            scale: root.hoveredIndex === wsCell.index || root.dropIndex === wsCell.index ? root.hoverShrink : 1

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
                        }
                        // its apps' icons
                        Row {
                            x: root.cell + 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: root.anyApps

                            readonly property bool more: wsCell.apps.length > root.maxIcons
                            Repeater {
                                model: parent.more ? wsCell.apps.slice(0, root.maxIcons - 1) : wsCell.apps
                                AppIcon {
                                    required property var modelData
                                    width: root.iconSize
                                    height: root.iconSize
                                    icon: DockData.iconFor(modelData.key)
                                    name: DockData.nameFor(modelData.key)
                                    opacity: wsCell.modelData.active ? 1 : 0.85
                                }
                            }
                            Text {
                                visible: parent.more
                                width: root.iconSize
                                height: root.iconSize
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "+" + (wsCell.apps.length - (root.maxIcons - 1))
                                color: Theme.text
                                opacity: 0.7
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
                                font.weight: 700
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoveredIndex = wsCell.index
                            // only clear it if it's still ours: moving to the next one can
                            // run that one's onEntered before this onExited
                            onExited: if (root.hoveredIndex === wsCell.index)
                                root.hoveredIndex = -1
                            onClicked: wsCell.modelData.activate()
                        }
                    }
                }

                // "+": a new workspace (click to go there; drop a window on it)
                Item {
                    id: plusCell
                    readonly property int index: root.list.length
                    width: root.rowWidth
                    height: root.cell

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius + 2
                        color: Theme.pill
                        opacity: 0.6
                    }
                    Rectangle {          // the ring when a window you're dragging is over it
                        anchors.fill: parent
                        radius: Theme.radius + 2
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 2
                        opacity: root.dropIndex === plusCell.index ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.hoverTime
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Text {
                        x: (root.cell - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add"
                        color: root.dropIndex === plusCell.index ? Theme.accent : Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize * 1.2
                        font.variableAxes: Theme.iconAxes
                        scale: root.hoveredIndex === plusCell.index || root.dropIndex === plusCell.index ? root.hoverShrink : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.hoverTime
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Text {
                        x: root.cell + 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.anyApps
                        text: "New workspace"
                        color: Theme.text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.textSize * 0.85
                        font.weight: 600
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredIndex = plusCell.index
                        onExited: if (root.hoveredIndex === plusCell.index)
                            root.hoveredIndex = -1
                        onClicked: root.goToNew()
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
  # One inward curve under an end of the bar (see Theme.barCurve): a square of the bar's
  # color with a quarter circle cut out of it. mirrored: true mirrors it for the right end.
  xdg.configFile."quickshell/BarCorner.qml".text = ''
    import QtQuick
    import QtQuick.Shapes

    Shape {
        id: corner

        property bool mirrored: false
        property real size: Theme.radius
        property color color: Theme.glass       // the bar's color, see-through like it

        width: size
        height: size
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            xScale: corner.mirrored ? -1 : 1
            origin.x: corner.size / 2
        }

        ShapePath {
            fillColor: corner.color
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: corner.size; y: 0 }
            // the curve, from the bar's edge down to the side of the screen
            PathArc {
                x: 0
                y: corner.size
                radiusX: corner.size
                radiusY: corner.size
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }
  '';

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

  # The scroll bar for long lists in the popups (Bluetooth, Wi-Fi, notifications):
  # a thin pill on the right, hidden when everything fits, faint until you scroll or
  # point at it. Drag it, or scroll with the wheel anywhere over the list.
  xdg.configFile."quickshell/ThinScrollBar.qml".text = ''
    import QtQuick
    import QtQuick.Controls.Basic

    ScrollBar {
        id: bar
        contentItem: Rectangle {
            implicitWidth: 4
            implicitHeight: 4         // for a horizontal one
            radius: 2
            color: Theme.pillIcon
            opacity: bar.size < 1 ? (bar.active || bar.hovered ? 1 : 0.4) : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
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
        // what it does, shown after the mouse rests on it for half a second (HoverTip.qml);
        // "" for none
        property string tip: ""
        property bool tipBelow: false       // the tip under it (for buttons in the top bar)

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
        HoverTip {
            show: mouse.containsMouse
            cut: root.tip !== ""
            title: root.tip
            below: root.tipBelow
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
    # the wallpaper animation (awwwTransition at the top of this file)
    inherit (awwwTransition)
      AWWW_TRANSITION
      AWWW_TRANSITION_POS
      AWWW_TRANSITION_DURATION
      AWWW_TRANSITION_FPS
      ;
  };
  # The bar is a systemd service, so give it TZDIR directly too.
  systemd.user.services.quickshell.Service.Environment = [
    "TZDIR=/etc/zoneinfo"
    # Bar animations stepping at 60 on a high-refresh screen? Removing the # below makes
    # Qt move animations forward once per frame drawn, at whatever rate the screen runs.
    # Quickshell leaves it off on purpose: it can keep the GPU redrawing much more
    # (Qt bug QTBUG-126099). Try it live first (see the notes from Claude).
    # "QSG_USE_SIMPLE_ANIMATION_DRIVER=1"
  ];
  # Wait (up to 2 s) until the login fade has covered the screen, so the bar doesn't
  # pop in before the fade (see fade.qml). Same for the wallpaper below.
  systemd.user.services.quickshell.Service.ExecStartPre = "${waitForFade}";
  # uwsm sources this before starting Hyprland: home-manager's session variables, then
  # the theme's (XCURSOR_THEME), so the session starts with the theme's cursor.
  xdg.configFile."uwsm/env".text = ''
    . "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh"
    if [ -r "${themeState}/current/session.env" ]; then . "${themeState}/current/session.env"; fi
  '';

  # Start PipeWire the moment you log in, instead of when the first program asks for
  # sound. Otherwise the login sound (fade.qml) would also be what wakes PipeWire up,
  # and it would come late while PipeWire and WirePlumber get going. Only for you: the
  # login screen's user doesn't get this. (NixOS starts PipeWire on first use: its
  # socket, services.pipewire.socketActivation.)
  systemd.user.services.audio-at-login = {
    Unit = {
      Description = "Start PipeWire at login (for the login sound)";
      Wants = [
        "pipewire.service"
        "wireplumber.service"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "default.target" ];
  };

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
    Service.ExecStartPre = "${waitForFade}";
    # the wallpaper animation (awwwTransition at the top of this file)
    Service.Environment = lib.mapAttrsToList (n: v: "${n}=${v}") awwwTransition;
    # Set the picture every time the daemon (re)starts. awww answers a moment after it
    # starts, so keep trying for up to ~10 s.
    Service.ExecStartPost = toString (
      pkgs.writeShellScript "awww-wallpaper" ''
        for _ in $(${pkgs.coreutils}/bin/seq 50); do
          # the theme's wallpaper (a link the theme command keeps up to date)
          ${pkgs.awww}/bin/awww img ${themeState}/wallpaper && exit 0
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

  # ── Wallpapers for the login screen ──
  # The login screen can't read your home folder, so this copies the pictures in
  # ~/Pictures/Wallpapers to /var/lib/greeter-wallpapers (made in configuration.nix)
  # when you log in and whenever something in that folder changes. Pick one with the
  # wallpaper button in the login screen's top bar.
  systemd.user.services.greeter-wallpapers = {
    Unit.Description = "Copy ~/Pictures/Wallpapers for the login screen";
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "greeter-wallpapers" ''
          src="$HOME/Pictures/Wallpapers"
          dst=/var/lib/greeter-wallpapers
          [ -d "$src" ] && [ -w "$dst" ] || exit 0
          # pictures only, no subfolders; files you delete get removed there too
          exec ${pkgs.rsync}/bin/rsync -rt --delete --delete-excluded --chmod=D755,F644 \
            --include='*.png' --include='*.PNG' --include='*.jpg' --include='*.JPG' \
            --include='*.jpeg' --include='*.JPEG' --include='*.webp' --include='*.WEBP' \
            --exclude='*' "$src/" "$dst/"
        ''
      );
    };
    Install.WantedBy = [ "default.target" ];
  };
  # Re-run it when you add, change or delete a picture in the folder.
  systemd.user.paths.greeter-wallpapers = {
    Unit.Description = "Watch ~/Pictures/Wallpapers for the login screen";
    Path.PathChanged = "%h/Pictures/Wallpapers";
    Install.WantedBy = [ "default.target" ];
  };
  # Bluetooth pairing agent (with services.blueman in configuration.nix): when a device
  # wants a code confirmed, blueman shows the dialog. The bar's widget does the rest.
  services.blueman-applet.enable = true;

  # hyprtoolkit's colors (and fonts) come from the theme: see "hyprtoolkit.conf" in
  # mkThemeDir at the top of this file. The polkit agent is a hyprtoolkit app, and
  # `theme` makes it reload this file on a switch (see tell_session).
  xdg.configFile."hypr/hyprtoolkit.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink "${themeState}/current/hyprtoolkit.conf";
    force = true;
  };

  # ── Qt theming (pavucontrol-qt, Quickshell, any Qt app) ──
  # qt6ct supplies Qt's palette. This module also exports QT_QPA_PLATFORMTHEME to
  # systemd user services. (hyprpolkitagent used to be a Qt app; since 0.2 it's
  # hyprtoolkit, themed by hyprtoolkit.conf above.)
  qt = {
    enable = true;
    platformTheme.name = "qtct"; # installs qt5ct + qt6ct
    qt5ctSettings = {
      Appearance = {
        style = "Fusion";
        custom_palette = true;
        color_scheme_path = "${themeState}/current/qt6ct.conf"; # the theme's colors
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
        color_scheme_path = "${themeState}/current/qt6ct.conf"; # the theme's colors
      };
      Fonts = {
        general = ''"SFProText Nerd Font,11"'';
        fixed = ''"SFMono Nerd Font,11"'';
      };
    };
  };
  xdg.configFile."qt5ct/qt5ct.conf".force = true;
  xdg.configFile."qt6ct/qt6ct.conf".force = true;

  # The Qt colors themselves are made per theme ("qt6ct.conf" in mkThemeDir). Qt apps
  # read them when they start.

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

      -- Colors from the theme you picked (see "Themes" in home.nix). Anything that file
      -- doesn't have (or the whole file, if it's missing) comes from the default theme:
      -- an older copy of it, from before a color was added, still works.
      local theme = {
      ${hyprlandThemeColors themes.themes.${themes.default}.colors}}
      local okTheme, picked = pcall(dofile, os.getenv("HOME") .. "/.local/state/theme/current/hyprland.lua")
      if okTheme and type(picked) == "table" then
          for k, v in pairs(picked) do
              theme[k] = v
          end
      end

      hl.monitor({
          output   = "", -- for laptops generally eDP-0 or eDP-1, and desktops usually DP-1.
          mode     = "highrr",
          position = "auto",
          scale    = "auto",
      })

      -- Environment variables live in home.nix (home.sessionVariables), which uwsm
      -- loads from ~/.config/uwsm/env before Hyprland starts. uwsm sets the XDG_* ones itself.
      --hyprmod settings
      -- Super + Shift + Up / Down: the workspace above / below. Up and down to match
      -- the workspace animation (slidevert) and the workspaces dock on the left edge,
      -- which lists them top to bottom.
      hl.unbind("SUPER + SHIFT + Left")
      hl.unbind("SUPER + SHIFT + Right")
      hl.unbind("SUPER + SHIFT + Up")
      hl.bind("SUPER + SHIFT + Up", hl.dsp.focus({ workspace = -1 }))
      hl.unbind("SUPER + SHIFT + Down")
      hl.bind("SUPER + SHIFT + Down", hl.dsp.focus({ workspace = "+1" }))
      hl.bind("Print", hl.dsp.exec_cmd("uwsm app -- hyprshot -m region --output-folder ~/Pictures/Screenshots"))
      -- Laptop brightness keys: hold to keep going, and they work on the lock screen too.
      -- --min-value=1 stops it at 1 instead of going fully black.
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q -c backlight set 5%+"), { repeating = true, locked = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q -c backlight --min-value=1 set 5%-"), { repeating = true, locked = true })
      -- Media keys: keyboard media keys, and headphone buttons / AirPods taps (BlueZ turns
      -- those into the same keys). playerctl sends them to the player you used last
      -- (playerctld). Pause is its own key so a "pause" tap never starts playback.
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"), { locked = true })
      hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
      hl.bind("SUPER + CTRL + Right", hl.dsp.window.move({ workspace = "+1" }))
      hl.bind("SUPER + CTRL + Left", hl.dsp.window.move({ workspace = -1 }))
      -- Super + Ctrl + Up / Down: take the focused window to the workspace above /
      -- below, and go with it (up and down like Super + Shift + Up / Down and the
      -- workspaces dock)
      hl.bind("SUPER + CTRL + Up", hl.dsp.window.move({ workspace = -1 }))
      hl.bind("SUPER + CTRL + Down", hl.dsp.window.move({ workspace = "+1" }))

      -- The bar (and the widgets that drop out of it), the docks and the notification
      -- popups are see-through (Theme.glassOpacity in Quickshell's
      -- Theme.qml): blur what's behind them. ignore_alpha: leave the clear parts of their
      -- windows alone (only blur under what's at least 10% solid; keep it under
      -- Theme.glassOpacity), so the blur follows their shapes.
      --
      -- xray: which blur. On, a surface shows the blurred wallpaper (worked out once for
      -- the whole screen); off, it blurs whatever is drawn under it right then, windows
      -- included. All of these use it off, so what's behind them shows through blurred:
      -- a window under an open widget or the dock, not just the wallpaper. The bar and
      -- its widgets are one surface (the widgets are drawn inside the bar's own window,
      -- Widget.qml), so they're blurred in one go and there's no edge between them.
      hl.layer_rule({ name = "bar-blur", match = { namespace = "bar" }, blur = true, ignore_alpha = 0.1, xray = false })
      hl.layer_rule({ name = "dock-blur", match = { namespace = "dock" }, blur = true, ignore_alpha = 0.1, xray = false })
      hl.layer_rule({ name = "workspace-dock-blur", match = { namespace = "workspace-dock" }, blur = true, ignore_alpha = 0.1, xray = false })
      hl.layer_rule({ name = "notification-blur", match = { namespace = "notification-popups" }, blur = true, ignore_alpha = 0.1, xray = false })
      hl.layer_rule({ name = "fullscreen-titlebar-blur", match = { namespace = "fullscreen-titlebar" }, blur = true, ignore_alpha = 0.1, xray = false })


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

      -- What shows before the wallpaper and bar are up: plain black, so logging in
      -- fades smoothly from the login screen (which fades out to black) into the desktop.
      -- At login: the screen stays black and the desktop fades in from the middle
      -- (~/.config/quickshell/fade.qml, started here before anything else). The mouse
      -- pointer is hidden until then; the timer is a safety net if the fade doesn't run.
      hl.on("hyprland.start", function()
          hl.config({ cursor = { invisible = true } })
          hl.timer(function() hl.config({ cursor = { invisible = false } }) end, { timeout = 6000, type = "oneshot" })
          hl.exec_cmd("${config.programs.quickshell.package}/bin/quickshell -p ~/.config/quickshell/fade.qml")
      end)

      hl.config({
          misc = {
              background_color = "rgb(000000)",
              -- if the lock screen ever crashed, the screen stays locked (red); this lets
              -- you start it again: on a text console (Ctrl+Alt+F3) log in and run
              -- WAYLAND_DISPLAY=wayland-1 lock   (ls /run/user/$UID shows the wayland-N name)
              allow_session_lock_restore = true,
              -- a key or the mouse turns the screens back on if they're off (after waking
              -- from suspend, say), so the first thing you type isn't lost to that
              key_press_enables_dpms = true,
              mouse_move_enables_dpms = true,
              disable_hyprland_logo = true,
              disable_splash_rendering = true,
              force_default_wallpaper = 0,
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
              -- from the theme (~/.local/state/theme/current/hyprland.lua); only drawn if border_size > 0
              ["col.active_border"]   = theme.active_border,
              ["col.inactive_border"] = theme.inactive_border,
              resize_on_border = true,
              extend_border_grab_area = 20,  -- pixels of grab area beyond the visible border
              hover_icon_on_border = true,
          },
      })
      hl.config({
          cursor = {
              inactive_timeout = 0,
              -- don't move the mouse to the middle of a window when it gets focus (from
              -- the dock, an app asking for attention...). Super + arrows bring it along
              -- on purpose (focusAndBringMouse above).
              no_warps = true,
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
      -- slidevert: workspaces slide up and down (the next one comes up from below), to
      -- match Super + Shift + Up / Down and the workspaces dock
      hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "snappy", style = "slidevert" })
      hl.animation({ leaf = "layers", enabled = true, speed = 1.6, bezier = "sharp" })
      hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.1 && ~/.config/hypr/scripts/capslock.sh"))

      -- Try using the shorthand variant if the full word is being ignored

      hl.bind("SUPER + J", hl.dsp.focus({ workspace = "-1" }))
      hl.bind("SUPER + K", hl.dsp.focus({ workspace = "+1" }))

      -- Super + arrows: focus the window that way, and bring the mouse along to its
      -- middle. cursor.no_warps (below) keeps focus changes from moving the mouse (so
      -- the dock doesn't yank it), but with follow_mouse the window under a mouse left
      -- behind would take focus back the moment you nudged it. So these four move the
      -- mouse themselves. (no_warps only stops the move a focus change would make;
      -- cursor.move is a move of its own.)
      local function focusAndBringMouse(dir)
          return function()
              hl.dispatch(hl.dsp.focus({ direction = dir }))
              local w = hl.get_active_window()
              if w then
                  hl.dispatch(hl.dsp.cursor.move({
                      x = w.at.x + math.floor(w.size.x / 2),
                      y = w.at.y + math.floor(w.size.y / 2),
                  }))
              end
          end
      end
      hl.bind("SUPER + left", focusAndBringMouse("left"))
      hl.bind("SUPER + right", focusAndBringMouse("right"))
      hl.bind("SUPER + up", focusAndBringMouse("up"))
      hl.bind("SUPER + down", focusAndBringMouse("down"))


      -- Trigger the rofi power menu

      hl.bind("SUPER + Return", hl.dsp.exec_cmd("uwsm app -- kitty"))

      hl.bind("SUPER + Q", hl.dsp.window.close())

      -- log out with the fade to black (falls back to a plain log out if the bar isn't running)
      hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("quickshell ipc call session logout || uwsm stop"))


      -- Captures the entire screen and copies it directly to your clipboard
      -- Pressing Print captures the entire screen straight to your clipboard


      -- True fullscreen (Hides waybar and gaps)

      hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind("SUPER + V", hl.dsp.window.float())

      -- Super + Shift + V: every window on this workspace floating at once; again: all
      -- back to tiling. If some float and some don't, the first press floats them all
      -- (rather than flipping each one, which would just swap which ones float).
      hl.bind("SUPER + SHIFT + V", function()
          local ws = hl.get_active_workspace()
          if not ws then
              return
          end
          local windows = hl.get_workspace_windows(ws)
          local allFloating = #windows > 0
          for _, w in ipairs(windows) do
              if not w.floating then
                  allFloating = false
              end
          end
          for _, w in ipairs(windows) do
              hl.dispatch(hl.dsp.window.float({ action = allFloating and "disable" or "enable", window = w }))
          end
      end)

      -- Toggle Rofi App Launcher using Super and Tab

      hl.bind("SUPER + TAB", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -run-command 'uwsm app -- {cmd}' -theme-str 'window { close-on-click:true; } '"))

      -- Delete or replace the bottom section with ONLY this line:

      -- Super + left drag: move a window. Let go of it on a workspace in the workspaces
      -- dock (push it against the left edge to bring the dock out) and it goes to that
      -- workspace, and so do you. Two binds tell Quickshell (WindowDrag.qml in home.nix)
      -- what happened; it does the rest:
      --   1. Super + left press: the drag, and "a drag started", with the window under
      --      the mouse;
      --   2. any left-button release: "it ended" (if a drag was going).
      -- Number 2 is its own bind because Hyprland 0.56.2 only runs bind 1 again on
      -- release if Super is still held then, and letting go of Super first is normal.
      -- When it does run bind 1 again, a drag is still marked as going (number 2 comes
      -- after it), so it does nothing. Number 2 ignores which modifiers are held and is
      -- non-consuming, so it never takes clicks away from your apps (it runs, and the
      -- click still goes to the app). Each drag gets its own name (the time and a count),
      -- so if a quick drag's "ended" gets to Quickshell before its "started", Quickshell
      -- can tell, even after Hyprland reloads its config.
      local dragging = nil     -- the window picked up, while dragging; nil otherwise
      local dragCount = 0

      -- the window under the mouse, the one a drag picks up (Hyprland doesn't say which
      -- it took): the focused one if it's there, else a floating one (they're on top of
      -- the tiled ones), else the tiled one
      local function windowUnderCursor()
          local c = hl.get_cursor_pos()
          if not c then
              return nil
          end
          local function under(w)
              return w ~= nil and w.mapped and not w.hidden and w.workspace ~= nil and w.workspace.visible
                  and c.x >= w.at.x and c.x < w.at.x + w.size.x
                  and c.y >= w.at.y and c.y < w.at.y + w.size.y
          end
          local active = hl.get_active_window()
          if under(active) then
              return active
          end
          local tiled = nil
          for _, w in ipairs(hl.get_windows()) do
              if under(w) then
                  if w.floating then
                      return w
                  end
                  tiled = tiled or w
              end
          end
          return tiled
      end

      -- 1. the drag, and it started
      hl.bind("SUPER + mouse:272", function()
          hl.dispatch(hl.dsp.window.drag())
          if dragging then
              return       -- run again on release (Super still held): number 2 handles it
          end
          local w = windowUnderCursor()
          if not w then
              dragging = nil
              return
          end
          dragCount = dragCount + 1
          dragging = {
              name = string.format("%d-%d", os.time(), dragCount),
              address = w.address,
              floating = w.floating and "true" or "false",
              at = string.format("at=%d,%d", math.floor(w.at.x), math.floor(w.at.y)),
          }
          hl.exec_cmd("quickshell ipc call windowdrag start " .. dragging.name)
      end, { mouse = true })

      -- 2. it ended: any left-button release, whatever is held (does nothing when
      -- there's no drag)
      hl.bind("mouse:272", function()
          if dragging then
              hl.exec_cmd(string.format("quickshell ipc call windowdrag finish %s %s %s %s",
                  dragging.name, dragging.address, dragging.floating, dragging.at))
          end
          dragging = nil
      end, { release = true, ignore_mods = true, non_consuming = true })

      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- TODO: manual review: blurls = "waybar"

      -- Autostart: nothing here anymore. Everything that used to start here is a
      -- systemd user service in home.nix (awww, playerctld,
      -- hyprpolkitagent, quickshell, music-player), started by uwsm's graphical-session.target.

      -- ── Title bars (hyprbars) ──
      -- A thin bar on top of each window, macOS style: three small circles on the left
      -- (their symbols show when the mouse is on them), the title in the middle. Drag a
      -- window by it; double-click it to maximize (or back). (On a fullscreen window
      -- Hyprland doesn't draw it: push the mouse against the top of the screen and
      -- Quickshell slides down a copy instead, FullscreenBar.qml.) Colors from the theme (bar_* in
      -- ~/.local/state/theme/current/hyprland.lua, "hyprland.lua" in home.nix), so they
      -- change with it: `theme` reloads this config. The bar is the top bar's glass:
      -- see-through and blurred.
      --   red: close
      --   yellow: minimize. Hyprland has no minimizing, so the window goes to a hidden
      --     special workspace, "special:minimized", that's never shown. The dock lists
      --     it (point at the app's icon); click it there to bring it back to the
      --     workspace you're on (DockData.qml in home.nix).
      --   green: true fullscreen, like Super + Shift + F. The bar isn't drawn on a
      --     fullscreen window: push the mouse against the top of the screen for its
      --     stand-in (FullscreenBar.qml), whose green button leaves fullscreen.
      --   double-click the title: maximize (or back), like Super + F.
      -- The plugin is built for this Hyprland (nixpkgs' hyprlandPlugins, the same
      -- version); Hyprland loads it once this file has been read, then reads it again,
      -- so hl.plugin.hyprbars only exists that second time (the `if`).
      -- It's loaded from a path that stays the same from one rebuild to the next
      -- (~/.local/share/hypr/plugins, a link to the build: see hyprbarsPatched in
      -- home.nix). A rebuild gives the plugin a new store path, and when the path in
      -- this file changes, Hyprland swaps the plugin out while it's running, which can
      -- crash it. With the same path it keeps the one it has, and a new build is
      -- picked up the next time you log in.
      hl.plugin.load(os.getenv("HOME") .. "/.local/share/hypr/plugins/libhyprbars.so")
      if hl.plugin.hyprbars then
          hl.config({
              plugin = {
                  hyprbars = {
                      bar_height = 28,
                      bar_color = theme.bar_color,
                      ["col.text"] = theme.bar_text,
                      bar_blur = true,
                      -- the title in the bar's font, size and weight (Theme.font,
                      -- Theme.textSize and the bar's 600 in Quickshell). The size is
                      -- in pixels, whole ones only: Quickshell's 12.5 is drawn at 12
                      -- too (Qt rounds pixel sizes down). Quickshell's tighter letter
                      -- spacing (-0.5) has no setting here.
                      bar_text_font = "SFMono Nerd Font",
                      bar_text_size = 12,
                      bar_text_weight = 600,
                      bar_text_align = "center",
                      bar_buttons_alignment = "left",
                      bar_padding = 12,          -- the left edge to the first circle
                      bar_button_padding = 8,    -- between the circles
                      icon_on_hover = true,      -- symbols only while the mouse is on them
                      inactive_button_color = theme.bar_button_inactive,
                      bar_part_of_window = true, -- the window's space includes it
                      bar_precedence_over_border = true,
                      on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
                      -- dragging a window by its bar: tell Quickshell, so it can be
                      -- dropped on a workspace in the workspaces dock (hyprbarsPatched
                      -- and WindowDrag.qml in home.nix)
                      on_drag = "quickshell ipc call windowdrag",
                  },
              },
          })
          -- Left to right, in this order. A click focuses the window first, so each acts
          -- on the window you clicked.
          local function button(color, icon, action)
              hl.plugin.hyprbars.add_button({
                  bg_color = color,
                  fg_color = theme.bar_icon,
                  size = 12,
                  icon = icon,
                  action = action,
              })
          end
          button(theme.bar_close, "×", [[hyprctl dispatch 'hl.dsp.window.close()']])
          button(theme.bar_float, "−", [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']])
          button(theme.bar_fullscreen, "+", [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })']])
      end

      -- HyprMod (the Hyprland settings app): what you save in it goes in
      -- ~/.config/hypr/hyprland-gui.lua, loaded here, at the end, so it wins over
      -- everything above. HyprMod would add this line itself, but home-manager makes
      -- this file and it can't be written to; HyprMod sees the line is already here and
      -- only writes its own file.
      -- If that file isn't there (you haven't saved anything in HyprMod yet, or you
      -- deleted it), nothing happens and the config above is all there is: Hyprland's
      -- require reports a missing file as a plain Lua error, which pcall catches. A
      -- file that's there but broken still shows in Hyprland's config errors, so you'd
      -- know; the config above still applies.
      pcall(function() require("hyprland-gui") end)
    '';
  };

  # The title bar plugin, at a path that stays the same between rebuilds (the Hyprland
  # config loads it from here; see hyprbarsPatched at the top of this file).
  xdg.dataFile."hypr/plugins/libhyprbars.so".source = "${hyprbarsPatched}/lib/libhyprbars.so";

  # Reload Hyprland when its config changes, so a rebuild shows up right away.
  # home-manager's Hyprland module does this itself, but only when it's given Hyprland's
  # package, and it isn't here (package = null above: Hyprland comes from
  # configuration.nix). Hyprland doesn't notice by itself either: it watches for its
  # config file being written, and a switch swaps the link to a new file instead. This
  # is the same command home-manager would run, with configuration.nix's Hyprland.
  xdg.configFile."hypr/hyprland.lua".onChange =
    let
      hyprctl = "${
        if osConfig != null then osConfig.programs.hyprland.package else pkgs.hyprland
      }/bin/hyprctl";
    in
    ''
      (
        XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
        if [[ -d "$XDG_RUNTIME_DIR/hypr" ]]; then
          for i in $(${hyprctl} instances -j | ${pkgs.jq}/bin/jq -r ".[].instance"); do
            ${hyprctl} -i "$i" reload config-only || true
          done
        fi
      )
    '';

  # App launcher (Super+Tab): apps only, a search bar, and your wallpaper as a square
  # on the left. To get the old tall launcher on the left edge back, set the window's
  # location/anchor to "west" and its height to "96%".
  programs.rofi = {
    enable = true;
    settings = {
      modi = "drun"; # apps only (no run / files switcher)
      show-icons = true;
      display-drun = "";
      drun-display-format = "{name}";
    };
    theme = lib.mkForce (
      let
        inherit (config.lib.formats.rasi) mkLiteral;
        # a small square copy of the theme's wallpaper, made by the rofi-wallpaper service below
        wallpaper = "${config.home.homeDirectory}/.cache/rofi/wallpaper.png";
      in
      {
        # The colors (@background, @foreground, @selected, ...) come from the theme
        # ("rofi.rasi" in mkThemeDir). rofi reads them every time it opens.
        "@import" = "${themeState}/current/rofi.rasi";
        "*" = {
          font = "SFMono Nerd Font Semi-Bold 11";
          border-radius = mkLiteral "8px";
        };
        "window" = {
          transparency = "real";
          location = mkLiteral "center";
          anchor = mkLiteral "center";
          fullscreen = false;
          width = mkLiteral "720px";
          height = mkLiteral "420px";
          padding = mkLiteral "0px";
          border = mkLiteral "3px solid";
          border-color = mkLiteral "@background-alt";
          border-radius = mkLiteral "14px";
          cursor = "default";
          background-color = mkLiteral "@background";
        };
        # picture on the left, search + apps on the right
        "mainbox" = {
          orientation = mkLiteral "horizontal";
          spacing = mkLiteral "0px";
          padding = mkLiteral "0px";
          background-color = mkLiteral "transparent";
          children = [
            "imagebox"
            "listbox"
          ];
        };
        # The wallpaper square. (Width = the window's height minus its 2 x 3 px border.)
        "imagebox" = {
          expand = false;
          width = mkLiteral "414px";
          border-radius = mkLiteral "11px 0px 0px 11px";
          background-color = mkLiteral "@background-alt";
          background-image = mkLiteral ''url("${wallpaper}", both)'';
        };
        "listbox" = {
          orientation = mkLiteral "vertical";
          spacing = mkLiteral "12px";
          padding = mkLiteral "16px";
          background-color = mkLiteral "transparent";
          children = [
            "inputbar"
            "listview"
          ];
        };
        # the minimal search bar
        "inputbar" = {
          spacing = mkLiteral "10px";
          padding = mkLiteral "10px 12px";
          border-radius = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
          children = [
            "textbox-prompt-colon"
            "entry"
          ];
        };
        "textbox-prompt-colon" = {
          expand = false;
          str = ""; # magnifying glass (Nerd Font icon)
          vertical-align = mkLiteral "0.5";
          padding = mkLiteral "0px 2px 0px 0px";
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "@selected";
        };
        "entry" = {
          background-color = mkLiteral "inherit";
          text-color = mkLiteral "inherit";
          cursor = mkLiteral "text";
          placeholder = "Search apps";
          placeholder-color = mkLiteral "@placeholder-fg";
        };
        "listview" = {
          columns = 1;
          lines = 8;
          cycle = true;
          dynamic = true;
          scrollbar = false;
          layout = mkLiteral "vertical";
          fixed-height = true;
          spacing = mkLiteral "4px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = "default";
        };
        "element" = {
          spacing = mkLiteral "10px";
          padding = mkLiteral "7px 10px";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@foreground";
          cursor = mkLiteral "pointer";
        };
        "element normal.normal, element alternate.normal" = {
          background-color = mkLiteral "transparent";
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
          size = mkLiteral "22px";
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
        "error-message" = {
          padding = mkLiteral "20px";
          background-color = mkLiteral "@background";
          text-color = mkLiteral "@foreground";
        };
      }
    );
  };

  # ── The picture for rofi, made ahead of time ──
  # rofi has no background daemon: it starts fresh each time you open it, and decoding
  # the full-size wallpaper (hk.png is 4288 x 2848, 12 MB) took long enough to see the square pop in.
  # So this keeps a small 828 x 828 copy (2x the 414 px square, sharp on HiDPI) in
  # ~/.cache/rofi, cut from the middle of the picture. It's about 20x faster to load.
  # Made at login, when you switch themes, and whenever the theme's wallpaper changes.
  systemd.user.services.rofi-wallpaper = {
    Unit.Description = "Square copy of the wallpaper for rofi";
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "rofi-wallpaper" ''
          src=$(${pkgs.coreutils}/bin/readlink -f "$HOME/.local/state/theme/wallpaper")
          out="$HOME/.cache/rofi/wallpaper.png"
          [ -f "$src" ] || exit 0
          ${pkgs.coreutils}/bin/mkdir -p "$HOME/.cache/rofi"
          # [0]: just the first frame, in case it's a GIF
          ${pkgs.imagemagick}/bin/magick "$src[0]" -resize 828x828^ -gravity center -extent 828x828 -strip "$out.new.png" \
            && ${pkgs.coreutils}/bin/mv "$out.new.png" "$out"
        ''
      );
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.paths.rofi-wallpaper = {
    Unit.Description = "Watch the theme's wallpaper for rofi";
    Path.PathChanged = "%h/.local/state/theme/wallpaper";
    Install.WantedBy = [ "default.target" ];
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
      wayland_titlebar_color = "system";
    };
    # The colors come from the theme ("kitty.conf" in mkThemeDir). `theme` sends kitty
    # SIGUSR1 after switching, which makes open windows reread this and recolor.
    extraConfig = ''
      include ${themeState}/current/kitty.conf
    '';
  };
  # kitty rewrites kitty.conf itself (e.g. the font/theme kittens), turning HM's
  # symlink into a regular file; force lets HM replace it
  xdg.configFile."kitty/kitty.conf".force = true;

  # ── Themes ──
  # Five themes (the themes block at the top), all built ahead of time. Pick one with the palette
  # button on the bar, or in a terminal:  theme  (lists them)  /  theme rose-pine
  #
  # How it fits together, since NixOS itself can't change after it's built:
  #  - every theme's files (kitty colors, rofi colors, qt6ct.conf, ...) are made by
  #    mkThemeDir and kept in the Nix store, one folder per theme
  #  - the apps' config files point at ~/.local/state/theme/current/<file>
  #  - ~/.local/state/theme/current is a link to one theme's folder. That link (and
  #    ~/.local/state/theme/name) is the only thing that changes when you switch.
  #  - the theme's wallpaper: ~/.local/state/theme/wallpaper links to the first picture
  #    in ~/Pictures/Wallpapers/<theme id>/ (hk.png if that folder's empty)
  # Nothing to set up: the link gets made on the next rebuild, pointing at the
  # default theme (`default` in the themes block).
  # Hands the themes to configuration.nix, for the login screen. It reads them as
  # config.home-manager.users.<you>.my.themes. Your home-manager settings can be read
  # from configuration.nix like any other option, so the themes are made into one:
  # `my.themes`, declared right here (the imports line) and set to the themes block.
  imports = [
    {
      options.my.themes = lib.mkOption {
        type = lib.types.raw;
        readOnly = true;
        description = "The color themes (the themes block in home.nix), for configuration.nix.";
      };
    }
  ];
  my.themes = themes;

  home.packages = [
    themeSwitch
    lockCmd
    # HyprMod, the Hyprland settings app (the hyprmod flake input; the end of the
    # Hyprland config says how its settings get loaded)
    inputs.hyprmod.packages.${pkgs.stdenv.hostPlatform.system}.default
  ]
  # every theme's GTK theme, icons and cursor, so they're there when you switch
  ++ lib.unique (
    lib.concatMap (t: [
      t.gtk.package
      t.icons.package
      t.cursor.package
    ]) (lib.attrValues themes.themes)
  );
  # ── Locking when the computer sleeps ──
  # hypridle watches for suspend (and `loginctl lock-session`) and starts the lock
  # screen. inhibit_sleep = 3 holds the suspend back until Hyprland reports the screen
  # is actually locked, so waking up never shows your desktop for a moment first.
  # After waking it turns the screens back on, and the lock screen is already there,
  # taking keys (see LoginCard.qml in configuration.nix).
  # No idle timeouts (lock / screen off after N minutes); add `listener` entries
  # here if you want them (man: github.com/hyprwm/hypridle).
  services.hypridle = {
    enable = true;
    settings.general = {
      lock_cmd = "${lockCmd}/bin/lock"; # what `loginctl lock-session` runs
      before_sleep_cmd = "${lockCmd}/bin/lock"; # lock before suspending
      after_sleep_cmd = "${wakeCmd}/bin/after-wake";
      inhibit_sleep = 3; # wait until it's locked
    };
  };

  # Each rebuild makes new copies of the theme folders, so point the link at this
  # build's copy of the theme you're using (and make it the first time).
  # Before onFilesChange, which reloads Hyprland when its config changed (onChange on
  # hypr/hyprland.lua), so that reload already reads this build's theme colors.
  home.activation.theme = lib.hm.dag.entryBetween [ "onFilesChange" ] [ "linkGeneration" ] ''
    run ${themeCmd} --refresh
  '';
  # At login: tell GTK (dconf) and the login screen which theme is on, and pick up
  # pictures you've added to the theme's wallpaper folder.
  systemd.user.services.theme-session = {
    Unit = {
      Description = "Apply the current theme for this session";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      Before = [ "awww.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${themeCmd} --login";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # GTK: home-manager still does the fonts. The theme, icons and cursor come from
  # the theme you picked: settings.ini (GTK 3 and 4) and GTK 4's gtk.css are links to
  # that theme's files, and `theme` also sets them in dconf so open GTK 3 apps switch.
  gtk = {
    enable = true;
    font = {
      name = "SFProText Nerd Font";
      size = 11;
    };
  };
  xdg.configFile."gtk-3.0/settings.ini" = {
    source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${themeState}/current/gtk-3.0.ini");
    force = true;
  };
  xdg.configFile."gtk-4.0/settings.ini" = {
    source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${themeState}/current/gtk-4.0.ini");
    force = true;
  };
  xdg.configFile."gtk-4.0/gtk.css" = {
    source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${themeState}/current/gtk-4.0.css");
    force = true;
  };

  # Mouse cursor: the theme's. At login uwsm reads XCURSOR_THEME from the theme
  # (see uwsm/env), apps that look for the "default" cursor get it from
  # ~/.icons/default, and `theme` changes Hyprland's right away (hyprctl setcursor).
  home.sessionVariables.XCURSOR_SIZE = "24";
  home.file.".icons/default/index.theme" = {
    source = config.lib.file.mkOutOfStoreSymlink "${themeState}/current/cursor.theme";
    force = true;
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

}
