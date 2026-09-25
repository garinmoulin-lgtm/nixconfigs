{ config, pkgs, lib, ... }:

{
  home.username = "garinh";
  home.homeDirectory = "/home/garinh";


  programs.home-manager.enable = true;

  programs.waybar = {
    enable = true;
    # Same override as configuration.nix, so the waybar HM installs is the identical build
    package = pkgs.waybar.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.modemmanager ];
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Dcava=disabled"
        "-Dsystemd=disabled"
      ];
      env.NIX_CFLAGS_COMPILE = "-march=native -O3";
      doInstallCheck = false;
    });
    settings = {
      mainBar = {
      layer = "top";
      position = "top";
      margin-top = 8;
      margin-left = 10;
      margin-right = 10;
      spacing = 1;
      height = 30;
      modules-left = [ "group/hardware" "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "group/media-player" "custom/media-time" "tray" ];
      modules-right = [ "clock" "wireplumber#sink" "network" "group/session" ];
      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
      };
      "hyprland/window" = {
        format = "<span color='#cdd6f4'>  {title}  </span>";
        max-length = 35;
        rewrite = {
          "(.*) - Mozilla Firefox" = "🌎 $1";
          "(.*) - zsh" = "> [$1]";
        };
      };
      "group/hardware" = {
        orientation = "horizontal";
        modules = [ "power-profiles-daemon" "memory" "cpu" "disk" ];
      };
      "group/session" = {
        orientation = "horizontal";
        modules = [
          "custom/lock"
          "custom/reboot"
          "custom/sleep"
          "custom/power"
          "custom/logout"
        ];
      };
      "custom/lock" = {
        format = "<span color='#f5e0dc'> 󰌾  </span>";
        on-click = "env TZ='America/Chicago' hyprlock";
        tooltip = true;
        tooltip-format = "Lock screen";
      };
      "custom/reboot" = {
        format = "<span color='#f5e0dc'>  󰜉  </span>";
        on-click = "systemctl reboot";
        tooltip = true;
        tooltip-format = "Reboot";
      };
      "custom/sleep" = {
        format = "<span color='#f5e0dc'>  󰤄  </span>";
        on-click = "systemctl suspend";
        tooltip = true;
        tooltip-format = "Sleep";
      };
      "custom/power" = {
        format = "<span color='#f5e0dc'>  󰐥  </span>";
        on-click = "systemctl poweroff";
        tooltip = true;
        tooltip-format = "Power Off";
      };
      "custom/logout" = {
        format = "<span color='#f5e0dc'>  󰈆 </span>";
        on-click = "pkill Hyprland";
        tooltip = true;
        tooltip-format = "Log Out";
      };
      clock = {
        format = "<span color='#f5e0dc'> 󰥔 </span><span color='#cdd6f4'>{:%I:%M %p 󰃮 %B %d, %Y}</span>";
        format-alt = "<span color='#f5e0dc'> 󰥔 </span><span color='#cdd6f4'>{:%I:%M %p}</span>";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        timezone = "America/Chicago";
        calendar = {
          mode = "month";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#f5e0dc'><b>{}</b></span>";
            days = "<span color='#f5e0dc'>{}</span>";
            weeks = "<span color='#f5e0dc'><b>W{}</b></span>";
            weekdays = "<span color='#f5e0dc'><b>{}</b></span>";
            today = "<span color='#f5e0dc'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-click-forward = "tz_up";
          on-click-backward = "tz_down";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };
      cpu = {
        format = ''<span color="#f5e0dc">󰘚</span> <span color="#cdd6f4">{usage}%</span>'';
        on-click = "kitty -e btop";
        interval = 1;
      };
      memory = {
        format = ''<span color="#f5e0dc">󰍛</span> <span color="#cdd6f4">{used:0.1f}GiB</span>'';
        interval = 1;
        on-click = "kitty -e btop";
      };
      "custom/media-time" = {
        exec = "~/.config/waybar/scripts/media-time.sh";
        format = ''<span color="#cdd6f4">  {} </span>'';
        interval = 1;
        tooltip = false;
      };
      network = {
        format-wifi = ''<span color="#f5e0dc">󰖩</span> <span color="#cdd6f4">{essid} ({signalStrength}%) </span>'';
        format-ethernet = ''<span color="#f5e0dc">󰈀</span> <span color="#cdd6f4">{ifname}</span>'';
        format-linked = ''<span color="#f5e0dc">󰈀</span> <span color="#cdd6f4">{ifname} (No IP)</span>'';
        format-disconnected = ''<span color="#f38ba8">󰖪</span> <span color="#cdd6f4">Disconnected</span>'';
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        tooltip-format = "{ifname}: {ipaddr}";
        on-click-right = "kitty -e nmtui";
      };
      "group/media-player" = {
        orientation = "horizontal";
        modules = [ "custom/media" "custom/media-prev" "custom/media-next" ];
      };
      "custom/media" = {
        format = '' {icon} <span color="#cdd6f4">{text} </span>'';
        return-type = "json";
        max-length = 25;
        restart-interval = 1;
        format-icons = {
          Playing = ''<span color="#a6e3a1" font_size="large"> 󰏦 </span>'';
          Paused = ''<span color="#f9e2af" font_size="large"> 󰐍 </span>'';
          Stopped = ''<span color="#f38ba8" font_size="large"> 󰝛 </span>'';
        };
        exec = "playerctl metadata --follow --format '{\"text\": \"{{markup_escape(title)}}\", \"tooltip\": \"{{playerName}} : {{markup_escape(title)}}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' 2>/dev/null || echo '{\"text\": \"Nothing playing\", \"alt\": \"Stopped\", \"class\": \"Stopped\", \"tooltip\": \"No media\"}'";
        exec-if = "true";
        on-click = "playerctl play-pause";
        on-scroll-up = "playerctl next";
        on-scroll-down = "playerctl previous";
      };
      "custom/media-prev" = {
        interval = 1;
        exec = "playerctl status 2>/dev/null | grep -q 'Playing\\|Paused' && echo '{\"text\": \"  󰼥  \", \"class\": \"active\"}' || echo '{\"text\": \"\", \"class\": \"inactive\"}'";
        return-type = "json";
        on-click = "playerctl previous";
        tooltip = false;
      };
      "custom/media-next" = {
        interval = 1;
        exec = "playerctl status 2>/dev/null | grep -q 'Playing\\|Paused' && echo '{\"text\": \"  󰼦  \", \"class\": \"active\"}' || echo '{\"text\": \"\", \"class\": \"inactive\"}'";
        return-type = "json";
        on-click = "playerctl next";
        tooltip = false;
      };
      "wireplumber#sink" = {
        format = ''{icon} <span color="#cdd6f4">{volume}%</span>'';
        format-muted = ''<span color="#f5e0dc">󰝟</span>'';
        format-icons = [
          ''<span color="#f5e0dc">󰕿</span>''
          ''<span color="#f5e0dc">󰖀</span>''
          ''<span color="#f5e0dc">󰕾</span>''
        ];
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-scroll-down = "wpctl set-volume @DEFAULT_SINK@ 1%-";
        on-scroll-up = "wpctl set-volume @DEFAULT_SINK@ 1%+ --limit 1.0";
      };
      disk = {
        interval = 30;
        format = ''<span color="#f5e0dc">󰋊</span> <span color="#cdd6f4">{percentage_used}%</span>'';
        path = "/";
      };
      tray = {
        icon-size = 16;
        spacing = 5;
      };
      power-profiles-daemon = {
        format = "{icon}";
        tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        tooltip = true;
        format-icons = {
          default = ''<span color="#f5e0dc">󰾞</span>'';
          performance = ''<span color="#f5e0dc">󱐋</span>'';
          balanced = ''<span color="#f5e0dc">󰗑</span>'';
          power-saver = ''<span color="#f5e0dc">󰌪</span>'';
        };
      };
    };
    };
    style = lib.mkForce ''
/* Catppuccin Mocha Colors - AptNix, by gmlgtm */
 @define-color background #1e1e2e; /* Base */
 @define-color background-light #313244; /* Surface0 */
 @define-color foreground #f5e0dc; /* Rosewater */
 @define-color black #585b70; /* Surface2 */
 @define-color crust #11111b; /* Crust */
 @define-color subtext #a6adc8; /* Subtext0 */
 @define-color white #cdd6f4; /* Text */
 
 /* Module-specific colors */
 @define-color workspaces-color @foreground;
 @define-color workspaces-focused-bg @foreground;
 @define-color workspaces-focused-fg @foreground;
 @define-color workspaces-urgent-bg @foreground;
 @define-color workspaces-urgent-fg @black;
 
 /* Text and border colors for modules */
 @define-color mode-color @foreground;
 @define-color group-hardware-color @foreground;
 @define-color group-session-color @foreground;
 @define-color clock-color @foreground;
 @define-color cpu-color @foreground;
 @define-color memory-color @foreground;
 @define-color temperature-color @foreground;
 @define-color temperature-critical-color @foreground;
 @define-color battery-color @foreground;
 @define-color battery-charging-color @foreground;
 @define-color battery-warning-color @foreground;
 @define-color battery-critical-color @foreground;
 @define-color network-color @foreground;
 @define-color network-disconnected-color @foreground;
 @define-color pulseaudio-color @foreground;
 @define-color pulseaudio-muted-color @foreground;
 @define-color wireplumber-color @foreground;
 @define-color wireplumber-muted-color @foreground;
 @define-color backlight-color @foreground;
 @define-color disk-color @foreground;
 @define-color updates-color @foreground;
 @define-color quote-color @foreground;
 @define-color idle-inhibitor-color @foreground;
 @define-color idle-inhibitor-active-color @foreground;
 @define-color power-profiles-daemon-color @foreground;
 @define-color power-profiles-daemon-performance-color @foreground;
 @define-color power-profiles-daemon-balanced-color @foreground;
 @define-color power-profiles-daemon-power-saver-color @foreground;
 
 * {
     /* Base styling for all modules */
     border: none;
     font-family: "JetBrainsMono", "Symbols Nerd Font";
     font-size: 14px;
     min-height: 0;
     font-weight: 500; 
 }
 
 /* Common module styling with uniform borders */
 #mode,
 #custom-hardware-wrap,
 #custom-session-wrap,
 #session,
 #custom-session,
 #clock,
 #cpu,
 #memory,
 #temperature,
 #battery,
 #network,
 #pulseaudio,
 #wireplumber,
 #backlight,
 #disk,
 #power-profiles-daemon,
 #idle_inhibitor,
 #tray {
     padding: 2px 10px;
     margin: 2px 4px;
     border: 2px solid @foreground;
     background-color: transparent;
 }
 
#workspaces {
    background-color: transparent;
    padding: 0 6px;
}

#workspaces button {
    min-width: 22px;
    border-radius: 0;
    min-height: 0;
    padding: 2px 7px;
    margin: 0 3px;
    border: 2px solid @foreground;
    background-color: transparent;
    color: @foreground;
    font-weight: 600;
}

#workspaces button label {
    opacity: 1;
    color: @white;
}

#workspaces button:hover {
    background-color: alpha(@foreground, 0.25);
}

#workspaces button.active,
#workspaces button.focused {
    background-color: @foreground;
    border-color: @foreground;
    color: @crust;
}

#workspaces button.active label,
#workspaces button.focused label {
    color: @crust;
}

#workspaces button.urgent {
    background-color: @foreground;
    border-color: @foreground;
    color: @crust;
}

 /* Module-specific text styling (borders globally set to @foreground) */
 #mode {
     color: @mode-color;
 }
 
 #custom-hardware-wrap {
     color: @crust;
     background-color: @foreground;
 }

 #window {
     color: @foreground;
     padding: 2px 10px;
 }
 
 #clock {
     color: @clock-color;
 }

 #cpu {
     color: @cpu-color;
 }

 #memory {
     color: @memory-color;
 }

 #temperature {
     color: @temperature-color;
 }

 #temperature.critical {
     color: @crust;
     background-color: @foreground;
 }

 #network {
     color: @network-color;
 }

 #network.disconnected {
     color: @network-disconnected-color;
 }

 #disk {
     color: @disk-color;
 }

 #power-profiles-daemon {
     color: @power-profiles-daemon-color;
 }

 #power-profiles-daemon.performance {
     color: @power-profiles-daemon-performance-color;
 }

 #power-profiles-daemon.balanced {
     color: @power-profiles-daemon-balanced-color;
 }

 #power-profiles-daemon.power-saver {
     color: @power-profiles-daemon-power-saver-color;
 }
 
 #cpu-group {
     color: @crust;
     background-color: @foreground;
     border: 2px solid @foreground;
 }
 
 #custom-gpu {
     color: @crust;
     background-color: @foreground; 
     border: 2px solid @foreground;
 }
 
 #custom-gpu-temperature {
     color: @crust;
     background-color: @foreground;
     border: 2px solid @foreground;
 }
 
 #battery {
     color: @battery-color;
 }
 
 #battery.charging,
 #battery.plugged {
     color: @battery-charging-color;
 }
 
 #battery.warning:not(.charging) {
     color: @battery-warning-color;
 }
 
 #battery.critical:not(.charging) {
     color: @battery-critical-color;
 }
 
 #pulseaudio {
     color: @pulseaudio-color;
 }
 
 #pulseaudio.muted {
     color: @pulseaudio-muted-color;
 }

 #wireplumber {
     color: @wireplumber-color;
 }

 #wireplumber.muted {
     color: @wireplumber-muted-color;
 }
 
 #backlight {
     color: @backlight-color;
 }

 decoration {
     background: transparent;
     box-shadow: none;
 }
 
 #idle_inhibitor {
     color: @idle-inhibitor-color;
 }
 
 #idle_inhibitor.activated {
     color: @idle-inhibitor-active-color;
 }
 
 tooltip {
     background: @background;
     border: 2px solid @foreground;
     border-radius: 0;
 }

 #custom-media-next.active {
     color: @foreground;
 }

 #custom-media-prev.active {
     color: @foreground;
 }

 /* Tray Menu Styling */
 #tray menu {
     background: @crust;
     border: 1px solid @foreground;
     padding: 6px;
 }
 
 #tray menu menuitem {
     color: @foreground;
     padding: 4px 12px;
     transition: all 0.2s ease;
 }
 
 #tray menu menuitem:hover {
     background: @foreground;
     color: @crust;
 }
 
 #tray {
     background-color: transparent;
     border-color: @foreground;
     padding: 0 10px;
     margin: 0 2px;
 }
 
 #tray>.passive {
     -gtk-icon-effect: dim;
 }
 
 #tray>.needs-attention {
     -gtk-icon-effect: highlight;
     color: @foreground;
 }
 
/* Base window */
window#waybar {
    background-color: transparent;
}

/* Outer Waybar Container */
window#waybar > box {
    background-color: @background;
    border: 2px solid @subtext;
    padding: 2px 6px;
}
 
 #modules-left > widget:first-child,
 #modules-right > widget:last-child {
     margin: 0 4px;
}
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;        # use programs.hyprland from configuration.nix
    portalPackage = null;  # portal already set in configuration.nix
    configType = "lua";
    settings = lib.mkForce { };
    systemd.enable = true; # your Lua already runs dbus-update-activation-environment
    extraConfig = ''
-- Generated by hyprconf2lua v1.3.2
-- https://github.com/Prateek-squadron/hyprconf2lua
-- Manual review may be needed for complex directives
-- Fixed: env vars now actually applied via hl.env(); blur config consolidated into one block

---@module 'hl'

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
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind("SUPER + CTRL + Right", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER + CTRL + Left", hl.dsp.window.move({ workspace = -1 }))
-- Nvidia env vars (previously a dangling `env = {...}` table that Hyprland never read)
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
        "blur, waybar",
        "ignorealpha 0.4, waybar", -- lets blur render through semi-transparent areas; tune threshold to your CSS alpha
    }
})


-- Consolidated decoration/blur block (previously split across 3 hl.config calls
-- that overwrote each other; only the last one was ever actually in effect)
hl.config({
    decoration = {
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
        border_size = 2,
        ["col.active_border"]   = "rgba(7f849cee)",    
        ["col.inactive_border"] = "rgba(45475a99)",  
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
   hl.exec_cmd("waybar &")
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
            bar_color = "rgb(1e1e2e)",
            ["col.text"] = "rgb(cdd6f4)",
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
    bg_color = "rgb(f38ba8)",
    fg_color = "rgb(1e1e2e)",
    size = 15,
    icon = "󱎘",
    action = "hyprctl dispatch 'hl.dsp.window.close()'",
})
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(a6e3a1)",
    fg_color = "rgb(1e1e2e)",
    size = 15,
    icon = "",
    action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
})
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(cba6f7)",
    fg_color = "rgb(1e1e2e)",
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
        "*" = {
          background = mkLiteral "#1e1e2e";
          background-alt = mkLiteral "#313244";
          foreground = mkLiteral "#cdd6f4";
          selected = mkLiteral "#b4befe";
          active = mkLiteral "#a6e3a1";
          urgent = mkLiteral "#f38ba8";
          font = "JetBrainsMono Nerd Font 11";
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
          children = [ "inputbar" "message" "listview" "mode-switcher" ];
        };
        "inputbar" = {
          enabled = true;
          spacing = mkLiteral "10px";
          margin = mkLiteral "0px";
          padding = mkLiteral "10px";
          background-color = mkLiteral "@background-alt";
          text-color = mkLiteral "@foreground";
          children = [ "textbox-prompt-colon" "entry" ];
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
      });
  };

xdg.configFile."waybar/scripts/media-time.sh" = {
    executable = true;
    force = true;
    text = ''
#!/usr/bin/env bash
pos=$(playerctl position 2>/dev/null | cut -d. -f1)
dur=$(playerctl metadata mpris:length 2>/dev/null | awk '{printf "%.0f", $1/1000000}')

if [[ -z "$pos" || -z "$dur" || "$dur" -eq 0 ]]; then
    echo ""
    exit 0
fi

printf '%d:%02d / %d:%02d\n' $((pos/60)) $((pos%60)) $((dur/60)) $((dur%60))
'';
};

  services.swaync = {
    enable = true;
    settings = {
      "$schema" = "/etc/xdg/swaync/configSchema.json";
      ignore-gtk-theme = true;
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      layer-shell-cover-screen = true;
      cssPriority = "user";
      control-center-margin-top = 0;
      control-center-margin-bottom = 0;
      control-center-margin-right = 0;
      control-center-margin-left = 0;
      notification-2fa-action = true;
      notification-inline-replies = false;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      relative-timestamps = true;
      control-center-width = 500;
      control-center-height = 600;
      notification-window-width = 500;
      keyboard-shortcuts = true;
      notification-grouping = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      text-empty = "No Notifications";
      script-fail-notify = true;
      scripts = {
        example-script = {
          app-name = "example.app.id";
          exec = "echo 'Do something...'";
          urgency = "Normal";
        };
        example-action-script = {
          app-name = "example.app.id";
          exec = "echo 'Do something actionable!'";
          urgency = "Normal";
          run-on = "action";
        };
      };
      notification-visibility = {
        example-name = {
          state = "muted";
          urgency = "Normal";
          app-name = "example.app.id";
        };
      };
      widgets = [ "inhibitors" "title" "dnd" "notifications" ];
      widget-config = {
        notifications = {
          vexpand = true;
        };
        inhibitors = {
          text = "Inhibitors";
          button-text = "Clear All";
          clear-all-button = true;
        };
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        label = {
          max-lines = 5;
          text = "Label Text";
        };
        mpris = {
          blacklist = [ ];
          autohide = false;
          show-album-art = "always";
          loop-carousel = false;
        };
        buttons-grid = {
          buttons-per-row = 7;
          actions = [
            {
              label = "直";
              type = "toggle";
              active = true;
              command = "sh -c '[[ $SWAYNC_TOGGLE_STATE == true ]] && nmcli radio wifi on || nmcli radio wifi off'";
              update-command = "sh -c '[[ $(nmcli radio wifi) == \"enabled\" ]] && echo true || echo false'";
            }
          ];
        };
      };
    };
    style = lib.mkForce ''
:root {
  --cc-bg: rgba(30, 30, 46, 0.7);
  --noti-border-color: rgba(245, 224, 220, 0.15);
  --noti-bg: 30, 30, 46;
  --noti-bg-alpha: 0.8;
  --noti-bg-darker: rgb(24, 24, 37);
  --noti-bg-hover: rgb(49, 50, 68);
  --noti-bg-focus: rgba(69, 71, 90, 0.6);
  --noti-close-bg: rgb(69, 71, 90);
  --noti-close-bg-hover: rgb(88, 91, 112);
  --text-color: rgb(245, 224, 220);
  --text-color-disabled: rgb(108, 112, 134);
  --notification-icon-size: 64px;
  --notification-app-icon-size: calc(var(--notification-icon-size) / 3);
  --notification-group-icon-size: 32px;
  --border: 1px solid var(--noti-border-color);
  --notification-shadow: 0 0 0 1px rgba(17, 17, 27, 0.3),
    0 1px 3px 1px rgba(17, 17, 27, 0.7), 0 2px 6px 2px rgba(17, 17, 27, 0.3);
  --font-size-body: 15px;
  --font-size-summary: 16px;
  /* Deprecated variables (because of their typos). Keeeping them around for backwards compatibility. */
  --hover-tranistion: background 0.15s ease-in-out;
  --group-collapse-tranistion: opacity 400ms ease-in-out;
  --hover-transition: var(--hover-tranistion);
  --group-collapse-transition: var(--group-collapse-tranistion);
}

notificationwindow, blankwindow {
  background: transparent;
}

.close-button {
  /* The notification Close Button */
  background: var(--noti-close-bg);
  color: var(--text-color);
  text-shadow: none;
  padding: 0;
  margin-top: 8px;
  margin-right: 8px;
  box-shadow: none;
  border: none;
  min-width: 24px;
  min-height: 24px;
}

.close-button:hover {
  box-shadow: none;
  background: var(--noti-close-bg-hover);
  transition: var(--hover-tranistion);
  border: none;
}

.notification-row {
  background: none;
  outline: none;
}

.notification-row:focus {
  background: var(--noti-bg-focus);
}

.notification-row .notification-background {
  padding: 6px 12px;
}

.notification-row .notification-background .notification {
  /* The actual notification */
  border: var(--border);
  padding: 0;
  transition: var(--hover-tranistion);
  background: rgba(var(--noti-bg), var(--noti-bg-alpha));
}

.notification-row .notification-background .notification.low {
  /* Low Priority Notification */
}

.notification-row .notification-background .notification.normal {
  /* Normal Priority Notification */
}

.notification-row .notification-background .notification.critical {
  /* Critical Priority Notification */
}

.notification-row .notification-background .notification .notification-default-action {
  /* The large action that also displays the notification summary and body */
  padding: 4px;
  margin: 0;
  box-shadow: none;
  background: transparent;
  border: none;
  color: var(--text-color);
  transition: var(--hover-tranistion);
}

.notification-row .notification-background .notification .notification-default-action:hover {
  -gtk-icon-filter: none;
  background: var(--noti-bg-hover);
}

.notification-row .notification-background .notification .notification-default-action:not(:only-child) {
  /* When alternative actions are visible */
}

.notification-row .notification-background .notification .notification-default-action .notification-content {
  background: transparent;
  padding: 0;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .image {
  /* Notification Primary Image */
  -gtk-icon-filter: none;
  -gtk-icon-size: var(--notification-icon-size);
  /* Size in px */
  margin: 4px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .app-icon {
  /* Notification app icon (only visible when the primary image is set) */
  -gtk-icon-filter: none;
  -gtk-icon-size: var(--notification-app-icon-size);
  -gtk-icon-shadow: 0 1px 4px rgba(17, 17, 27, 0.8);
  margin: 6px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .text-box label {
  /* Fixes base GTK 4 CSS setting a filter of opacity 50% for some odd reason */
  filter: none;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .text-box .summary {
  /* Notification summary/title */
  font-size: var(--font-size-summary);
  font-weight: bold;
  background: transparent;
  color: var(--text-color);
  text-shadow: none;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
  /* Notification time-ago */
  font-size: var(--font-size-summary);
  font-weight: bold;
  background: transparent;
  color: var(--text-color);
  text-shadow: none;
  margin-right: 30px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .text-box .body {
  /* Notification body */
  font-size: var(--font-size-body);
  font-weight: normal;
  background: transparent;
  color: var(--text-color);
  text-shadow: none;
}

.notification-row .notification-background .notification .notification-default-action .notification-content progressbar {
  /* The optional notification progress bar */
  margin-top: 4px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .body-image {
  /* The "extra" optional bottom notification image */
  margin-top: 4px;
  background-color: rgb(245, 224, 220);
  -gtk-icon-filter: none;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply {
  /* The inline reply section */
  margin-top: 4px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply .inline-reply-entry {
  background: var(--noti-bg-darker);
  color: var(--text-color);
  caret-color: var(--text-color);
  border: var(--border);
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply .inline-reply-button {
  margin-left: 4px;
  background: rgba(var(--noti-bg), var(--noti-bg-alpha));
  border: var(--border);
  color: var(--text-color);
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply .inline-reply-button:disabled {
  background: initial;
  color: var(--text-color-disabled);
  border: var(--border);
  border-color: transparent;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply .inline-reply-button:hover {
  background: var(--noti-bg-hover);
}

.notification-row .notification-background .notification .notification-alt-actions {
  background: none;
  padding: 4px;
}

.notification-row .notification-background .notification .notification-action {
  /* The alternative actions below the default action */
  margin: 4px;
  padding: 0;
}

.notification-row .notification-background .notification .notification-action > button {
  color: var(--text-color);
}

.notification-group {
  /* Styling only for Grouped Notifications */
  transition: opacity 200ms ease-in-out;
  /* The groups close button */
}

.notification-group:focus {
  background: var(--noti-bg-focus);
}

.notification-group.low {
  /* Low Priority Group */
}

.notification-group.normal {
  /* Low Priority Group */
}

.notification-group.critical {
  /* Low Priority Group */
}

.notification-group .notification-group-close-button .close-button {
  margin: 12px 20px;
}

.notification-group .notification-group-buttons, .notification-group .notification-group-headers {
  margin: 0 16px;
  color: var(--text-color);
}

.notification-group .notification-group-headers {
  /* Notification Group Headers */
}

.notification-group .notification-group-headers .notification-group-icon {
  color: var(--text-color);
  -gtk-icon-size: var(--notification-group-icon-size);
}

.notification-group .notification-group-headers .notification-group-header {
  color: var(--text-color);
}

.notification-group .notification-group-buttons {
  /* Notification Group Buttons */
}

.notification-group.collapsed {
  /* When another group is expanded, lower the opacity of the collapsed ones */
}

.notification-group.collapsed.not-expanded {
  opacity: 0.4;
}

.notification-group.collapsed .notification-row .notification {
  background-color: rgba(var(--noti-bg), 1);
}

.notification-group.collapsed .notification-row:not(:last-child) {
  /* Top notification in stack */
  /* Set lower stacked notifications opacity to 0 */
}

.notification-group.collapsed .notification-row:not(:last-child) .notification-action,
.notification-group.collapsed .notification-row:not(:last-child) .notification-default-action {
  opacity: 0;
}

.notification-group.collapsed:hover .notification-row:not(:only-child) .notification {
  background-color: var(--noti-bg-hover);
}

.control-center {
  /* The Control Center which contains the old notifications + widgets */
  background: var(--cc-bg);
  color: var(--text-color);
}

.control-center .control-center-list-placeholder {
  /* The placeholder when there are no notifications */
  opacity: 0.5;
}

.control-center .control-center-list {
  /* List of notifications */
  background: transparent;
}

.control-center .control-center-list .notification {
  box-shadow: var(--notification-shadow);
}

.control-center .control-center-list .notification .notification-default-action,
.control-center .control-center-list .notification .notification-action {
  transition: var(--group-collapse-tranistion), var(--hover-tranistion);
}

.control-center .control-center-list .notification .notification-default-action:hover,
.control-center .control-center-list .notification .notification-action:hover {
  background-color: var(--noti-bg-hover);
}

.blank-window {
  /* Window behind control center and on all other monitors */
  background: transparent;
}

.floating-notifications {
  background: transparent;
}

.floating-notifications .notification {
  box-shadow: none;
}

/*** Widgets ***/
.widget {
  margin: 8px;
  padding: 8px;
}

/* Title widget */
.widget-title > label {
  margin-right: 8px;
  font-size: 1.5rem;
}

.widget-title > button {
  margin-left: 8px;
}

/* DND widget */
.widget-dnd label {
  color: var(--text-color);
  margin-right: 8px;
  font-size: 1.1rem;
}

.widget-dnd switch {
  margin-left: 8px;
}

/* Label widget */
.widget-label > label {
  font-size: 1.1rem;
}

/* Mpris widget */
:root {
  --mpris-album-art-overlay: rgba(17, 17, 27, 0.55);
  --mpris-button-hover: rgba(17, 17, 27, 0.5);
  --mpris-album-art-icon-size: 96px;
  --mpris-album-art-shadow: 0px 0px 10px rgba(17, 17, 27, 0.75);
}

.widget-mpris {
  padding: 0;
  /* The parent to all players */
}

.widget-mpris .widget-mpris-player {
  margin: 16px 20px;
  box-shadow: var(--mpris-album-art-shadow);
}

.widget-mpris .widget-mpris-player .mpris-background {
  filter: blur(10px);
}

.widget-mpris .widget-mpris-player .mpris-overlay {
  padding: 16px;
  background-color: var(--mpris-album-art-overlay);
}

.widget-mpris .widget-mpris-player .mpris-overlay button:hover {
  /* The media player buttons (play, pause, next, etc...) */
  background: var(--noti-bg-hover);
}

.widget-mpris .widget-mpris-player .mpris-overlay .widget-mpris-album-art {
  box-shadow: var(--mpris-album-art-shadow);
  -gtk-icon-size: var(--mpris-album-art-icon-size);
}

.widget-mpris .widget-mpris-player .mpris-overlay .widget-mpris-title {
  font-weight: bold;
  font-size: 1.25rem;
}

.widget-mpris .widget-mpris-player .mpris-overlay .widget-mpris-subtitle {
  font-size: 1.1rem;
}

.widget-mpris .widget-mpris-player .mpris-overlay > box > button {
  /* Change player control buttons */
}

.widget-mpris .widget-mpris-player .mpris-overlay > box > button:hover {
  background-color: var(--mpris-button-hover);
}

.widget-mpris > box > button {
  /* Change player side buttons */
}

.widget-mpris > box > button:disabled {
  /* Change player side buttons insensitive */
}

/* Buttons widget */
.widget-buttons-grid flowboxchild > button.toggle:checked {
  /* style given to the active toggle button */
  background-color: rgb(245, 224, 220);
  color: rgb(17, 17, 27);
}

/* Menubar widget */
.widget-menubar {
  /* The revealer buttons */
}

.widget-menubar > .menu-button-bar {
  /* The left button container */
  /* The right button container */
  /* The left and right button container */
}

.widget-menubar > .menu-button-bar > .start {
  margin-left: 8px;
}

.widget-menubar > .menu-button-bar > .end {
  margin-right: 8px;
}

.widget-menubar > .menu-button-bar > .widget-menubar-container button {
  margin: 0 4px;
}

.widget-menubar > revealer * {
  margin-top: 8px;
}

.widget-menubar > revealer * button {
  margin: 8px;
  margin-top: 0;
}

.widget-menubar > revealer * button:last-child {
  margin-bottom: 0;
}

/* Volume widget */
:root {
  --widget-volume-row-icon-size: 24px;
}

/* Each row app icon */
.widget-volume row image {
  -gtk-icon-size: var(--widget-volume-row-icon-size);
}

.per-app-volume {
  background-color: rgb(49, 50, 68);
  margin: 8px;
  margin-bottom: 0;
}

/* Slider widget */
.widget-slider label {
  font-size: inherit;
}

/* Backlight widget */
/* Inhibitors widget */
.widget-inhibitors > label {
  margin-right: 8px;
  font-size: 1.5rem;
}

.widget-inhibitors > button {
  margin-left: 8px;
}
    '';
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
    font.name = "JetBrainsMono Nerd Font Mono";
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
    name = "Noto Sans";
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
    ll = "ls -la";
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
    # mkForce: catppuccin's autoEnable otherwise sources its own full hyprlock.conf
    # (corner clock, keyboard-layout label, mauve input field) on top of this one
    settings = lib.mkForce {
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
          color = "rgb(f5e0dc)"; # Rosewater
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
          outer_color = "rgb(f5e0dc)"; # Rosewater border, same as the clock
          inner_color = "rgb(313244)"; # Surface0 fill
          font_color = "rgb(f5e0dc)";  # Text
          font_family = "JetBrainsMono Nerd Font";
          placeholder_text = "<i>Input Password...</i>";
          fade_on_empty = false;
          dots_center = true;
          check_color = "rgb(f9e2af)";
          fail_color = "rgb(f38ba8)";
          dots_size = 0.33;    # 0.2–0.8, fraction of the field height
          dots_spacing = 0.15; # 0.0–1.0, gap between dots, relative to dot size
        }
      ];
    };
  };
  # replaces any hand-written ~/.config/hypr/hyprlock.conf instead of failing activation
  xdg.configFile."hypr/hyprlock.conf".force = true;
}
