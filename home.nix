{
  config,
  pkgs,
  lib,
  inputs,
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
  # (Quickshell), kitty, rofi, hyprlock, GTK and Qt apps, the mouse cursor, and the
  # login screen (configuration.nix reads this as my.themes, see "Themes" near the
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

      # hyprpolkitagent and other hyprtoolkit apps
      "hyprtoolkit.conf" = pkgs.writeText "hyprtoolkit.conf" (
        lib.hm.generators.toHyprconf {
          attrs = {
            background = "0xFF${lib.toUpper c.bg}";
            base = "0xFF${lib.toUpper c.overlay}";
            accent = "0xFF${lib.toUpper c.accent}";
            font_family = "SFProText Nerd Font";
            font_family_monospace = "SFMono Nerd Font";
          };
        }
      );

      # Lock screen. Measured from the reference screenshot and scaled to 1920x1080.
      "hyprlock.conf" = pkgs.writeText "hyprlock.conf" (
        lib.hm.generators.toHyprconf {
          importantPrefixes = [
            "$"
            "monitor"
          ];
          attrs = {
            general.hide_cursor = false; # cursor is visible in the reference

            background = [
              {
                monitor = "";
                path = "${themeState}/wallpaper"; # the theme's wallpaper
                blur_passes = 3;
              }
            ];

            # Clock: 07:44 — ink ~238x64px, centered 74px above screen center
            label = [
              {
                monitor = "";
                text = "$TIME";
                color = "rgb(${c.fg})";
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
                outer_color = "rgb(${c.accent})";
                inner_color = "rgb(${c.surface})";
                font_color = "rgb(${c.fg})";
                font_family = "SFMono Nerd Font";
                placeholder_text = "<i>Input Password...</i>";
                fade_on_empty = false;
                dots_center = true;
                check_color = "rgb(${c.yellow})";
                fail_color = "rgb(${c.red})";
                dots_size = 0.33; # 0.2–0.8, fraction of the field height
                dots_spacing = 0.15; # 0.0–1.0, gap between dots, relative to dot size
              }
            ];
          };
        }
      );

      # read by hyprland.lua when Hyprland starts or reloads its config
      "hyprland.lua" = pkgs.writeText "hyprland-theme.lua" ''
        return {
            active_border = "rgba(${c.accent}ee)",
            inactive_border = "rgba(${c.border}99)",
        }
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
      # read by uwsm at login (see uwsm/env below), so the session starts with it
      "session.env" = pkgs.writeText "session.env" ''
        export XCURSOR_THEME=${lib.escapeShellArg t.cursor.name}
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
      # The theme's wallpaper: the first picture (A to Z) in ~/Pictures/Wallpapers/<id>/,
      # or ~/Pictures/Wallpapers/hk.png if that folder is empty or missing.
      wallpaper_for() {
        local f
        f=$(find "$HOME/Pictures/Wallpapers/$1" -maxdepth 1 -type f \
          \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) \
          2>/dev/null | LC_ALL=C sort | head -n 1) || true # no folder yet is fine
        echo "''${f:-$HOME/Pictures/Wallpapers/hk.png}"
      }
      use_wallpaper() {
        local f
        f=$(wallpaper_for "$1")
        [ "$(readlink "$state/wallpaper" 2>/dev/null || true)" = "$f" ] || relink "$f" "$state/wallpaper"
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
          hyprctl setcursor "$CURSOR_THEME" 24 >/dev/null || true
          # and for apps Hyprland starts from now on
          hyprctl eval "hl.env(\"XCURSOR_THEME\", \"$CURSOR_THEME\")" >/dev/null || true
        fi
        systemctl --user set-environment XCURSOR_THEME="$CURSOR_THEME" || true
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
          ;;
        --refresh)
          # home-manager runs this on every rebuild: the theme folders get new store
          # paths, so the link is pointed at this build's copy of the same theme
          use "$(current)"
          [ -e "$state/wallpaper" ] || use_wallpaper "$(current)"
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
            // fade to black, then run `cmd`
            function leave(cmd) {
                if (leaveCmd !== null)
                    return;
                leaveCmd = cmd;
                Ui.leaving = true;   // every open widget popup slides shut (Widget.qml)
                pointer(false);
                coverAnim.start();
                leaveTimer.start();
            }
            function logout() {
                leave(["uwsm", "stop"]);
            }
            Timer {
                id: leaveTimer
                interval: 750      // just after the 700 ms fade
                onTriggered: Quickshell.execDetached(session.leaveCmd)
            }
            // so the Super+Shift+E key can use it: quickshell ipc call session logout
            IpcHandler {
                target: "session"
                function logout(): void {
                    session.logout();
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
                unsortedIds = [];
                send(["playlist-move", from, to > from ? to + 1 : to]);
            }
            // Sort the whole queue by "album", "artist" or "title" (the song that's
            // playing stays playing, it just moves with the rest). Works out the new order,
            // then moves entries into place one by one, top to bottom, with the same
            // playlist-move that drag-to-reorder uses. Songs that aren't in the library
            // (so have no tags) go to the end.
            //
            // The queue sort is a mode, like the library's: the chip stays lit while it's on,
            // songs you add get sorted in, and clicking the lit chip again turns it off and
            // puts the queue back the way it was before (songs added since go at the end).
            // Dragging a song turns it off too, keeping the order you made.
            property string queueSort: ""     // "", "album", "artist" or "title"
            property var unsortedIds: []      // mpv entry ids in the order from before the sort
            property var sortedIds: ({})      // ids the sort has seen (id -> true)
            property var expectIds: null      // the order our moves will end on; null = not busy
            function setQueueSort(by) {
                if (by === queueSort) {
                    // off: back to the old order, then anything newer as it is now
                    const ids = queue.map(e => e.id);
                    const old = unsortedIds.filter(id => ids.includes(id));
                    const order = old.concat(ids.filter(id => !old.includes(id)));
                    queueSort = "";
                    unsortedIds = [];
                    applyOrder(order.map(id => queue.find(e => e.id === id)));
                    return;
                }
                if (queueSort === "")
                    unsortedIds = queue.map(e => e.id);
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
                // songs added while sorted: remember them for "off", and sort them in
                const fresh = queue.filter(e => !sortedIds[e.id]);
                if (fresh.length > 0) {
                    unsortedIds = unsortedIds.concat(fresh.map(e => e.id));
                    sortQueue(queueSort);
                }
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
                            readonly property bool shown: !!QsWindow.window && QsWindow.window.visible
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
                        }
                    }

                    // ── Theme: the color themes (the themes block at the top of home.nix) ──
                    // Icon only, like Bluetooth. Each row shows that theme's own colors;
                    // click one to switch. The bar fades over, and the theme command does
                    // the rest (see "Themes" in home.nix). The popup stays open, so you
                    // can try a few.
                    Widget {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "palette"

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

                            // where this theme's wallpaper comes from
                            Text {
                                width: themeList.width
                                topPadding: 4
                                leftPadding: 8
                                rightPadding: 8
                                wrapMode: Text.Wrap
                                text: "Wallpaper: the first picture in\n~/Pictures/Wallpapers/" + Theme.current + "/"
                                color: Theme.text
                                opacity: 0.6
                                font.family: Theme.font
                                font.pixelSize: Theme.textSize * 0.85
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
                                        color: Theme.bg
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
                                        anchors.right: pickSort.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: "play_circle"
                                        onClicked: music.playAll(lib.results)
                                    }
                                    // an artist's songs can be sorted too (an album keeps its track order)
                                    IconButton {
                                        id: pickSort
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !!lib.pick && lib.pick.kind === "artists"
                                        width: visible ? implicitWidth : 0
                                        icon: "sort"
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
                                            // lit while the queue is kept sorted this way; click it
                                            // again to put the queue back how it was
                                            selected: music.queueSort === modelData.id
                                            onClicked: music.setQueueSort(modelData.id)
                                        }
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
                                        if (lib.view !== "songs" && !lib.pick)
                                            return lib.groups.length === 0 ? "No matches." : "";
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
                                                anchors.right: groupPlay.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
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
                                                    width: parent.width
                                                    text: (group.modelData.kind === "albums" && group.modelData.artist ? group.modelData.artist + "  ·  " : "") + group.modelData.songs.length + (group.modelData.songs.length === 1 ? " song" : " songs")
                                                    elide: Text.ElideRight
                                                    color: Theme.text
                                                    opacity: 0.6
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSize * 0.85
                                                }
                                            }
                                            IconButton {        // play everything by this artist / on this album
                                                id: groupPlay
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: groupMouse.containsMouse
                                                icon: "play_arrow"
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
                                        cmd: ["hyprlock"]
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
            onTriggered: Quickshell.execDetached(["${pkgs.coreutils}/bin/touch", root.marker])
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
        property color pill: c.overlay
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
        Behavior on pill { enabled: theme.ready; ColorAnimation { duration: theme.fade; easing.type: Easing.InOutQuad } }
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
        property int headroom: 240       // extra (empty, click-through) window height, so new rows fit

        // The popup window's height. See implicitHeight in the PopupWindow below.
        property real windowHeight: 0
        function fitWindow() {
            const bar = root.QsWindow.window;
            // never taller than the screen below the bar, or Hyprland would move it
            const room = bar && bar.screen ? bar.screen.height - bar.height : 100000;
            windowHeight = Math.max(popup.bodyHeight, Math.min(popup.bodyHeight + headroom, room));
        }

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
            // one popup at a time: close whichever widget is open now (any monitor's bar)
            if (Ui.openWidget && Ui.openWidget !== root)
                Ui.openWidget.closePopup()
            Ui.openWidget = root
            root.fitWindow()
            popup.visible = true
            root.open = true
            grabBar = false
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
            grabBar = false
            if (Ui.openWidget === root)
                Ui.openWidget = null
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

        // Click-off-to-close, through Hyprland's focus grab. While the popup is open the
        // grab covers the popup and this bar: clicks there work normally (other widgets
        // and bar buttons react on the first click), and typed keys go to the popup. A
        // click anywhere else ends the grab and Hyprland tells us (onCleared), so the
        // popup slides back into the bar. (Hyprland spends that outside click on ending
        // the grab; it doesn't reach the app you clicked.)
        //
        // The bar joins the grab in a second step, after the grab has gone out with the
        // popup alone: Hyprland hands the keyboard to one of the grabbed windows in no
        // fixed order, so the popup goes first to be sure it gets your typing.
        property bool grabBar: false
        HyprlandFocusGrab {
            id: grab
            windows: root.grabBar ? [popup, root.QsWindow.window] : [popup]
            onActiveChanged: if (active)
                root.grabBar = true
            onCleared: root.closePopup()
        }
        // e.g. a monitor unplugged while its bar had the open popup
        Component.onDestruction: if (Ui.openWidget === root)
            Ui.openWidget = null

        // Log out / Restart / Power off: close, so the whole screen fades to black.
        // (Popups are drawn above everything else, even the black fade layer.)
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
            // The window is made taller than the content (by root.headroom) and doesn't
            // shrink while it's open. Resizing a popup window makes it flash for a frame,
            // which is what happened every time Bluetooth or Wi-Fi found something and the
            // list got a row longer. Now only the shape inside grows; the window stays.
            implicitHeight: Math.max(1, root.windowHeight)
            onBodyHeightChanged: if (root.open && bodyHeight > root.windowHeight)
                root.fitWindow()
            // Clicks only land on the shape. The empty part of the window below it lets
            // them through, as if the popup weren't there.
            mask: Region {
                item: shape
            }

            // The height the shape shows. It follows bodyHeight, and glides there when
            // the content grows or shrinks while the popup is open (a row appearing).
            property real shownHeight: bodyHeight
            Behavior on shownHeight {
                enabled: root.open && root.openness === 1
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            color: "transparent"    // the shape below is what you see
            visible: false          // starts closed

            // If the compositor ever hides the popup by itself, skip the animation
            // and reset so the next click opens it again.
            onClosed: {
                slide.stop()
                grab.active = false
                root.openness = 0
                root.open = false
                if (Ui.openWidget === root)
                    Ui.openWidget = null
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

  xdg.configFile."quickshell/WeatherData.qml".text = ''
    pragma Singleton

    import QtQuick
    import Quickshell
    import Quickshell.Io

    // Weather for the bar, from Open-Meteo (open-meteo.com: free, no account or key).
    // One copy shared by every monitor's bar. The place you pick and °F/°C are saved in
    // ~/.local/state/quickshell/weather.json. Refreshes every 15 minutes.
    // Temperatures are always fetched in °C and converted for display (show()), so
    // switching °F / °C is instant and doesn't need the internet.
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
                + "&current=temperature_2m,weather_code,is_day"
                + "&hourly=temperature_2m,weather_code,is_day"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
                + "&timezone=auto&forecast_days=7", r => {
                data = r;
                fetchedAt = Date.now();
                loading = false;
            }, e => {
                error = e;
                loading = false;
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

        // The next hours (now + 5), with sunrise / sunset slotted in where they happen.
        // [{ label, icon, color, temp }]
        readonly property var hours: {
            if (!hasData)
                return [];
            const H = data.hourly, D = data.daily;
            const nowHour = data.current.time.substr(0, 13);
            let i = H.time.findIndex(t => t.substr(0, 13) === nowHour);
            if (i < 0)
                i = 0;
            const list = [];
            for (let k = i; k < Math.min(i + 6, H.time.length); k++)
                list.push({
                    "time": H.time[k],
                    "label": k === i ? "Now" : clockLabel(H.time[k]),
                    "icon": icon(H.weather_code[k], H.is_day[k] === 1),
                    "color": iconColor(H.weather_code[k], H.is_day[k] === 1),
                    "temp": k === i ? data.current.temperature_2m : H.temperature_2m[k]
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
                            "event": name
                        });
                    }
                }
            }
            list.sort((a, b) => a.time < b.time ? -1 : a.time > b.time ? 1 : 0);
            return list.slice(0, 6);
        }

        // The next 5 days: [{ label, icon, color, low, high }], plus the week's range
        readonly property var days: {
            if (!hasData)
                return [];
            const D = data.daily;
            const out = [];
            for (let d = 0; d < Math.min(5, D.time.length); d++) {
                const p = D.time[d].split("-");
                const date = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]));
                out.push({
                    "label": d === 0 ? "Today" : Qt.formatDate(date, "ddd"),
                    "icon": icon(D.weather_code[d], true),
                    "color": iconColor(D.weather_code[d], true),
                    "low": D.temperature_2m_min[d],
                    "high": D.temperature_2m_max[d]
                });
            }
            return out;
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
    // place + now, the next hours (with sunrise/sunset), and the next 5 days with
    // temperature range bars. Click the place name to search for another one;
    // °F / °C switches in the top-right corner of the card.
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
            width: 340
            spacing: 12

            // fresh data each time it opens (if it's more than 10 minutes old)
            readonly property bool open: !!QsWindow.window && QsWindow.window.visible
            onOpenChanged: if (open)
                WeatherData.refreshIfOld()
            else
                root.picking = false

            // ── place + now ──
            Item {
                width: parent.width
                height: 108
                visible: !root.shown

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
                }
            }

            Rectangle {
                visible: !root.shown && WeatherData.hasData
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── the next hours ──
            Row {
                visible: !root.shown && WeatherData.hasData
                width: parent.width
                Repeater {
                    model: WeatherData.hours
                    Column {
                        required property var modelData
                        width: card.width / 6
                        spacing: 6
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
                            text: root.deg(modelData.temp)
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.textSize
                            font.weight: 700
                        }
                    }
                }
            }

            Rectangle {
                visible: !root.shown && WeatherData.hasData
                width: parent.width
                height: 1
                color: Theme.pill
            }

            // ── the next 5 days ──
            Column {
                visible: !root.shown && WeatherData.hasData
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
  # mkThemeDir at the top of this file.
  xdg.configFile."hypr/hyprtoolkit.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink "${themeState}/current/hyprtoolkit.conf";
    force = true;
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

      -- Colors from the theme you picked (see "Themes" in home.nix). If that file is
      -- missing, the default theme's colors.
      local okTheme, theme = pcall(dofile, os.getenv("HOME") .. "/.local/state/theme/current/hyprland.lua")
      if not okTheme or type(theme) ~= "table" then
          theme = {
              active_border = "rgba(${themes.themes.${themes.default}.colors.accent}ee)",
              inactive_border = "rgba(${themes.themes.${themes.default}.colors.border}99)",
          }
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
      hl.unbind("SUPER + SHIFT + Left")
      hl.bind("SUPER + SHIFT + Left", hl.dsp.focus({ workspace = -1 }))
      hl.unbind("SUPER + SHIFT + Right")
      hl.bind("SUPER + SHIFT + Right", hl.dsp.focus({ workspace = "+1" }))
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

      -- log out with the fade to black (falls back to a plain log out if the bar isn't running)
      hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("quickshell ipc call session logout || uwsm stop"))


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
  #  - every theme's files (kitty colors, rofi colors, hyprlock.conf, ...) are made by
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
  ]
  # every theme's GTK theme, icons and cursor, so they're there when you switch
  ++ lib.unique (
    lib.concatMap (t: [
      t.gtk.package
      t.icons.package
      t.cursor.package
    ]) (lib.attrValues themes.themes)
  );
  # Each rebuild makes new copies of the theme folders, so point the link at this
  # build's copy of the theme you're using (and make it the first time).
  home.activation.theme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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

  # Lock screen (the power menu's lock button). hyprlock is installed system-wide in
  # configuration.nix (needed for PAM); its config is the theme's ("hyprlock.conf" in
  # mkThemeDir, with the layout and the theme's colors and wallpaper).
  xdg.configFile."hypr/hyprlock.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink "${themeState}/current/hyprlock.conf";
    force = true;
  };
}
