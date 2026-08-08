{ config, pkgs, ... }:

{
  home.username = "garinh";
  home.homeDirectory = "/home/garinh";

  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  xdg.configFile."waybar/config.jsonc" = {
  force = true;
  text = ''
{
    "layer": "top",
    "position": "top",
    "spacing": 1,
	"height": 35, // bump this up from whatever it currently is
	"margin": 0,
    "modules-left": [
    	"hyprland/workspaces",
    	"custom/bar1",
        "group/hardware",
        "custom/bar2",
        "clock",
        "tray"
    ],
    "modules-center": [
    	"group/media-player",
        "custom/media-time"
    ],
    "modules-right": [
		/*"custom/bar3",*/
    	"custom/settings",
    	"custom/terminal",
		"custom/bar4",
        "wireplumber#sink",
        "custom/bar5",
        "network",
        "custom/bar6",
        "group/session"
    ],
    "hyprland/workspaces": {
        "format": "",
        "on-click": "notify-send test" /*hyprctl dispatch \"hl.dsp.focus({workspace = {name}})\"*/
    },
    "custom/bar3": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar4": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar5": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar6": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar7": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar1": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    "custom/bar2": {
    	"format": "<span color='#E78284'> │ </span>",
    	"tooltip": false
    },
    /*"hyprland/window": {
        "format": "<span color='#c6d0f5'>  {title}  </span>",
        "max-length": 35,
        "rewrite": {
            "(.*) - Mozilla Firefox": "🌎 $1",
            "(.*) - zsh": "> [$1]"
        }
    },*/
	"group/hardware": {
	    "orientation": "horizontal",
	    "modules": [
	        "power-profiles-daemon",
	        "memory",
	        "cpu",
	        "disk"
	    ]
	},
	
    "group/session": {
        "orientation": "horizontal",
        "modules": [
            "custom/lock",
            "custom/reboot",
            "custom/sleep",
            "custom/power",
            "custom/logout"
        ]
    },
    "custom/lock": {
        "format": "<span color='#81C8BE'>   󰌾   </span>",
        "on-click": "env TZ='America/Chicago' hyprlock",
        "tooltip": true,
        "tooltip-format": "Lock screen"
    },
    "custom/reboot": {
        "format": "<span color='#CA9EE6'>   󰜉   </span>",
        "on-click": "systemctl reboot",
        "tooltip": true,
        "tooltip-format": "Reboot"
    },
    "custom/sleep": {
        "format": "<span color='#E5C890'>   󰤄   </span>",
        "on-click": "systemctl suspend",
        "tooltip": true,
        "tooltip-format": "Sleep"
    },
    "custom/power": {
        "format": "<span color='#E78284'>   󰐥   </span>",
        "on-click": "systemctl poweroff",
        "tooltip": true,
        "tooltip-format": "Power Off"
    },
    "custom/logout": {
        "format": "<span color='#A6D189'>   󰈆   </span>",
        "on-click": "pkill Hyprland",
        "tooltip": true,
        "tooltip-format": "Log Out"
    },
    /*"custom/wallpaper": {
      "format": "<span color='#81C8BE'>  󰸉  </span>",
      "on-click": "~/.config/eww/scripts/toggle-picker.sh",
      "tooltip": true,
      "tooltip-format": "Change wallpaper"
    },*/
    "clock": {
        "format": "<span color='#CA9EE6'> 󰥔 </span><span color='#c6d0f5'>{:%I:%M %p 󰃮 %B %d, %Y}</span>",
        "format-alt": "<span color='#CA9EE6'> 󰥔 </span><span color='#c6d0f5'>{:%I:%M %p}</span>",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "timezone": "America/Chicago",
        "calendar": {
            "mode": "month",
            "mode-mon-col": 3,
            "weeks-pos": "right",
            "on-scroll": 1,
            "on-click-right": "mode",
            "format": {
                "months": "<span color='#e5c890'><b>{}</b></span>",
                "days": "<span color='#e78284'>{}</span>",
                "weeks": "<span color='#a6d189'><b>W{}</b></span>",
                "weekdays": "<span color='#81c8be'><b>{}</b></span>",
                "today": "<span color='#ef9f76'><b><u>{}</u></b></span>"
            }
        },
        "actions": {
            "on-click-right": "mode",
            "on-click-forward": "tz_up",
            "on-click-backward": "tz_down",
            "on-scroll-up": "shift_up",
            "on-scroll-down": "shift_down"
        }
    },
    "cpu": {
        "format": "<span color=\"#E78284\">󰘚</span> <span color=\"#C6D0F5\">{usage}%</span>",
        "on-click": "kitty -e btop",
        "interval": 1,
    },
	"memory": {
	    "format": "<span color=\"#A6D189\">󰍛</span> <span color=\"#C6D0F5\">{used:0.1f}GiB</span>",
	    "interval": 1,
	    "on-click": "kitty -e btop"
	},
	
   /* "temperature": {
        "hwmon-path": "/sys/class/hwmon/hwmon3/temp1_input",
        "critical-threshold": 80,
        "interval": 1,
        "on-click": "kitty -e btop",
        "format": "{temperatureC}°C",
        "format-icons": [
            "󱃃",
            "󰔏",
            "󱃂"
        ]
    },
    "battery": {
        "states": {
            "good": 95,
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-plugged": "󰚥 {capacity}%",
        "format-alt": "{icon} {time}",
        "format-icons": [
            "󰂎",
            "󰁺",
            "󰁻",
            "󰁼",
            "󰁽",
            "󰁾",
            "󰁿",
            "󰂀",
            "󰂁",
            "󰂂",
            "󰁹"
        ]
    },*/
    "custom/media-time": {
        "exec": "~/.config/waybar/scripts/media-time.sh",
        "format": "<span color=\"#C6D0F5\">  {} </span>",
        "interval": 1,
        "tooltip": false
    },
    "network": {
        "format-wifi": "<span color=\"#99D1DB\">󰖩</span> <span color=\"#C6D0F5\">{essid} ({signalStrength}%) </span>",
        "format-ethernet": "<span color=\"#8CAAEE\">󰈀</span> <span color=\"#C6D0F5\">{ifname}</span>",
        "format-linked": "<span color=\"#EA999C\">󰈀</span> <span color=\"#C6D0F5\">{ifname} (No IP)</span>",
        "format-disconnected": "<span color=\"#EA999C\">󰖪</span> <span color=\"#C6D0F5\">Disconnected</span>",
        "format-alt": "{ifname}: {ipaddr}/{cidr}",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click-right": "kitty -e nmtui"
    },
    "custom/settings": {
        "format": "<span color='#EEBEBE'>   󰒓   </span>",
        "on-click": "kitty -e doas fresh /etc/nixos/configuration.nix",
        "tooltip": true,
        "tooltip-format": "Settings"
    },
    "group/media-player": {
        "orientation": "horizontal",
        "modules": [
            "custom/media",
            "custom/media-prev",
            "custom/media-next"
        ]
    },
	"custom/media": {
	    "format": " {icon} {text} ",
	    "return-type": "json",
	    "max-length": 25,
	    "restart-interval": 1,
	    "format-icons": {
	        "Playing": "<span color=\"#A6D189\" font_size=\"large\"> 󰏦 </span>",
	        "Paused": "<span color=\"#E5C890\" font_size=\"large\"> 󰐍 </span>",
	        "Stopped": "<span color=\"#E78284\" font_size=\"large\"> 󰝛 </span>"
	    },
	    "exec": "playerctl metadata --follow --format '{\"text\": \"{{markup_escape(title)}}\", \"tooltip\": \"{{playerName}} : {{markup_escape(title)}}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' 2>/dev/null || echo '{\"text\": \"Nothing playing\", \"alt\": \"Stopped\", \"class\": \"Stopped\", \"tooltip\": \"No media\"}'",
	    "return-type": "json",
	    "exec-if": "true",
	    "on-click": "playerctl play-pause",
	    "on-scroll-up": "playerctl next",
	    "on-scroll-down": "playerctl previous"
	},
	"custom/media-prev": {
		"interval": 1,
	    "exec": "playerctl status 2>/dev/null | grep -q 'Playing\\|Paused' && echo '{\"text\": \"  󰼥  \", \"class\": \"active\"}' || echo '{\"text\": \"\", \"class\": \"inactive\"}'",
	    "return-type": "json",
	    "on-click": "playerctl previous",
	    "tooltip": false
	},
	"custom/media-next": {
		"interval": 1,
	    "exec": "playerctl status 2>/dev/null | grep -q 'Playing\\|Paused' && echo '{\"text\": \"  󰼦  \", \"class\": \"active\"}' || echo '{\"text\": \"\", \"class\": \"inactive\"}'",
	    "return-type": "json",
	    "on-click": "playerctl next",
	    "tooltip": false
	},
    "custom/terminal": {
    	"format": "<span color='#EEBEBE'>   󱌣   </span>",
    	"on-click": "kitty -e doas fresh /etc/nixos/home.nix",
    	"tooltip": true,
		"tooltip-format": "Customize Home Manager"
    },
    "wireplumber#sink": {
        "format": "{icon} <span color=\"#C6D0F5\">{volume}%</span>",
        "format-muted": "<span color=\"#E78284\">󰝟</span>",
        "format-icons": [
            "<span color=\"#EF9F76\">󰕿</span>",
            "<span color=\"#EF9F76\">󰖀</span>",
            "<span color=\"#EF9F76\">󰕾</span>"
        ],
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "on-scroll-down": "wpctl set-volume @DEFAULT_SINK@ 1%-",
        "on-scroll-up": "wpctl set-volume @DEFAULT_SINK@ 1%+ --limit 1.0"
    },
    "disk": {
        "interval": 30,
        "format": "<span color=\"#81C8BE\">󰋊</span> <span color=\"#C6D0F5\">{percentage_used}%</span>",
        "path": "/"
    },
    "tray": {
        "icon-size": 16,
        "spacing": 5
    },
    "power-profiles-daemon": {
        "format": "{icon}",
        "tooltip-format": "Power profile: {profile}\nDriver: {driver}",
        "tooltip": true,
        "format-icons": {
            "default": "<span color=\"#EA999C\">󰾞</span>",
            "performance": "<span color=\"#E78284\">󱐋</span>",
            "balanced": "<span color=\"#EF9F76\">󰗑</span>",
            "power-saver": "<span color=\"#81C8BE\">󰌪</span>"
        }
    }
}
'';
};
  xdg.configFile."waybar/style.css" = {
  	
  force = true;
  text = ''
 /* Catppuccin Frappé TTY Colors */
 @define-color background #303446; /* Base */
 @define-color background-light #414559; /* Surface0 */
 @define-color foreground #c6d0f5; /* Text */
 @define-color black #626880; /* Surface2 */
 @define-color red #e78284; /* Red */
 @define-color green #a6d189; /* Green */
 @define-color yellow #e5c890; /* Yellow */
 @define-color blue #8caaee; /* Blue */
 @define-color magenta #f4b8e4; /* Pink */
 @define-color cyan #99d1db; /* Sky */
 @define-color white #c6d0f5; /* Text */
 @define-color orange #ef9f76; /* Peach */
 
 /* Module-specific colors */
 @define-color workspaces-color @foreground;
 @define-color workspaces-focused-bg @green;
 @define-color workspaces-focused-fg @cyan;
 @define-color workspaces-urgent-bg @red;
 @define-color workspaces-urgent-fg @black;
 
 /* Text and border colors for modules */
 @define-color mode-color @orange;
 @define-color group-hardware-color #232634;
 @define-color group-session-color @red;
 @define-color clock-color @blue;
 @define-color cpu-color @green;
 @define-color memory-color @magenta;
 @define-color temperature-color @yellow;
 @define-color temperature-critical-color @red;
 @define-color battery-color @cyan;
 @define-color battery-charging-color @green;
 @define-color battery-warning-color @yellow;
 @define-color battery-critical-color @red;
 @define-color network-color @blue;
 @define-color network-disconnected-color @red;
 @define-color pulseaudio-color @orange;
 @define-color pulseaudio-muted-color @red;
 @define-color wireplumber-color @orange;
 @define-color wireplumber-muted-color @red;
 @define-color backlight-color @yellow;
 @define-color disk-color @cyan;
 @define-color updates-color @orange;
 @define-color quote-color @green;
 @define-color idle-inhibitor-color @foreground;
 @define-color idle-inhibitor-active-color @red;
 @define-color power-profiles-daemon-color @cyan;
 @define-color power-profiles-daemon-performance-color @red;
 @define-color power-profiles-daemon-balanced-color @yellow;
 @define-color power-profiles-daemon-power-saver-color @green;
 
 * {
     /* Base styling for all modules */
     border: none;
     border-radius: 0;
     font-family: "JetBrainsMono", "Symbols Nerd Font";
     font-size: 14px;
     min-height: 0;
     font-weight: 500; 
 }
 
 /* Common module styling with border-bottom */
 #mode,
 #custom-hardware-wrap,
 #custom-session-wrap,
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
     padding: 0 10px;
     margin: 0 2px;
     border-bottom: 2px solid transparent;
     background-color: transparent;
 }
 
#workspaces {
    background-color: transparent;
    padding: 0 8px;
}

#workspaces button {
    padding: 0;
    margin: 6 6px;
    min-width: 15px;
    min-height: 15px;
    border-radius: 100%;
    background-color: transparent;
    border: 2px solid @workspaces-color; /* or swap for a specific rgba */
    color: transparent; /* hides the workspace number/name text */
    transition: all 0.2s ease-in-out;
}

#workspaces button label {
    opacity: 0; /* fully hide text so only the circle shows */
}

#workspaces button:hover {
    background-color: alpha(@workspaces-color, 0.3);
}

#workspaces button.active,
#workspaces button.focused {
    background-color: #eebebe; /* your existing Flamingo accent */
    border-color: #eebebe;
}
 
 #workspaces button.urgent {
     background-color: @workspaces-urgent-bg;
     color: @workspaces-urgent-fg;
 }
 
 
 /* Module-specific styling */
 #mode {
     color: @mode-color;
     border-bottom-color: @mode-color;
 }
 
 #custom-hardware-wrap {
     color: #232634;
     border-radius: 20px;
 	background-color: #85c1dc;
 }
 #window {
 	color: #c6d0f5;
 	border-radius: 20px;
 	/*background-color: #303446;*/
 }
 
 
 
 #cpu-group {
     color: #232634;
     border-radius: 20px;
     background-color: #f4b8e4;
 }
 
 
 #custom-gpu {
 	color: #232634;
 	border-radius: 20px;
 	background-color: #8caaee; 
 }
 
 #custom-gpu-temperature {
 	color: #232634;
 	border-radius: 20px;
 	background-color: #ca9ee6;
 }
 
 
 #temperature.critical {
     color: #232634;
     border-radius: 20px;
     background-color: #e78284;
 }
 
 
 
 
 /*#power-profiles-daemon.power-saver {
     color: #232634;
     border-radius: 20px;
     background-color: #81c8be;
 }*/
 
 #battery {
     color: @battery-color;
     border-bottom-color: @battery-color;
 }
 
 #battery.charging,
 #battery.plugged {
     color: @battery-charging-color;
     border-bottom-color: @battery-charging-color;
 }
 
 #battery.warning:not(.charging) {
     color: @battery-warning-color;
     border-bottom-color: @battery-warning-color;
 }
 
 #battery.critical:not(.charging) {
     color: @battery-critical-color;
     border-bottom-color: @battery-critical-color;
 }
 
 
 #pulseaudio {
     color: @pulseaudio-color;
     border-bottom-color: @pulseaudio-color;
     border-radius: 20px;
 }
 
 #pulseaudio.muted {
     color: @pulseaudio-muted-color;
     border-bottom-color: @pulseaudio-muted-color;
     border-radius: 20px;
 }
 
 /*#wireplumber {
     color: #232634;
     border-radius: 20px;
     background-color: #ef9f76;
 }
 
 #wireplumber.muted {
     background-color: #ea999c;
     border-radius: 20px;
     color: #232634;
 }*/
 
 #backlight {
     color: @backlight-color;
     border-bottom-color: @backlight-color;
     border-radius: 20px;
 }
 decoration {
     background: transparent;
     box-shadow: none;
     border-radius: 20px; /* Change this to match your tooltip's border-radius */
 }
 
 /* Clean up gaps when the music components are inactive */
 /* Target the buttons inside the group when the media module is invisible/empty */
 
 #idle_inhibitor {
     color: @idle-inhibitor-color;
     border-bottom-color: transparent;
 }
 
 #idle_inhibitor.activated {
     color: @idle-inhibitor-active-color;
     border-bottom-color: @idle-inhibitor-active-color;
 }
 
 tooltip {
     background: #303446;          /* Change popup background color */
     border: 2px solid #c6d0f5;    /* Give it a clean border */
     border-radius: 8px;           /* Round the corners */
     font-family: "Iosevka Mono"; /* Must be monospaced for layout alignment */
 }
 #custom-media-next.active {
     color: #81c8be;
 }
 #custom-media-prev.active {
     color: #81c8be;
 }
 /* Styling the main container of the right-click context menu */
 #tray menu {
     background: #232634;          /* Dark theme background */
     border: 1px solid #414559;
     border-radius: 6px;
     padding: 6px;
 }
 
 /* Individual lines / list items within the context menu */
 #tray menu menuitem {
     color: #c6d0f5;               /* Text color */
     padding: 4px 12px;
     transition: all 0.2s ease;   /* Smooth color transition */
 }
 
 /* Style when you hover your cursor over an option */
 #tray menu menuitem:hover {
     background: #8caaee;          /* Highlight color on hover */
     color: #232634;               /* Change text color on hover for legibility */
     border-radius: 20px;
 }
 
 
 #tray {
     background-color: transparent;
     padding: 0 10px;
     margin: 0 2px;
 }
 
 #tray>.passive {
     -gtk-icon-effect: dim;
 }
 
 #tray>.needs-attention {
     -gtk-icon-effect: highlight;
     color: @red;
     border-bottom-color: @red;
 }
 
 /* Outer GTK window: border lives here since this is the layer-shell
    surface boundary. */
 window#waybar {
     background-color: #303446;
     color: @foreground;
     /*border: 2px solid #838ba7;
     border-radius: 20px;*/
 }
 
 /* GTK Inspector confirmed the actual content node is an unnamed
    box.horizontal directly under window#waybar (not #waybar itself,
    and not a generic #waybar > box selector). Padding goes here so
    it's applied to the real node holding modules-left/center/right. */
 window#waybar > box {
     padding: 4px 4px;
 }
 
 /* Extra safety margin on the very first/last module in each group
    so nothing touches the rounded corners. */
 #modules-left > widget:first-child,
 #modules-right > widget:last-child {
     margin: 0 4px;
 }
'';
};
  xdg.configFile."hypr/hyprland.lua" = {
  force = true;
  text = ''
  -- Generated by hyprconf2lua v1.3.2
-- https://github.com/Prateek-squadron/hyprconf2lua
-- Manual review may be needed for complex directives
-- Fixed: env vars now actually applied via hl.env(); blur config consolidated into one block

---@module 'hl'

hl.monitor({
    output   = "DP-3", -- for laptops generally eDP-0 or eDP-1, and desktops usually DP-1.
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

-- exec-once=noctalia

-- Consolidated decoration/blur block (previously split across 3 hl.config calls
-- that overwrote each other; only the last one was ever actually in effect)
hl.config({
    decoration = {
        rounding = 0,
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
        sensitivity = 0,
    },
})
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        ["col.active_border"]   = "rgba(838ba7ee)",   -- Frappe Green
        ["col.inactive_border"] = "rgba(51576d99)",   -- Frappe Surface1
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
hl.config({
    input = {
        accel_profile = "flat",
        sensitivity = 0.0,   -- keep at 0 for 1:1, adjust if needed alongside flat profile
    },
})

hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.1 && ~/.config/hypr/scripts/capslock.sh"))

hl.bind("SUPER + SHIFT + Right", function()
    hl.dsp.window.move({ workspace = "+1", follow = false })
end)

hl.bind("SUPER + SHIFT + Left", function()
    hl.dsp.window.move({ workspace = "-1", follow = false })
end)
-- Try using the shorthand variant if the full word is being ignored

hl.bind("SUPER + J", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + K", hl.dsp.focus({ workspace = "+1" }))

hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))


-- Trigger the rofi power menu

hl.bind("SUPER" .. " + " .. "Return", hl.dsp.exec_cmd("kitty"))

hl.bind("SUPER" .. " + " .. "Q", hl.dsp.window.close())

hl.bind("SUPER + SHIFT" .. " + " .. "E", hl.dsp.exit())

-- True minimize without hidden workspaces (Super and Minus)

hl.bind("SUPER" .. " + " .. "minus", hl.dsp.exec_cmd("hyprctl minimize"))

-- Unminimize the last minimized window layout item (Super and Equal)

hl.bind("SUPER" .. " + " .. "equal", hl.dsp.exec_cmd("hyprctl unminimize"))

-- Captures the entire screen and copies it directly to your clipboard
-- Pressing Print captures the entire screen straight to your clipboard


-- True fullscreen (Hides waybar and gaps)

hl.bind("SUPER" .. " + " .. "F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER" .. " + " .. "V", hl.dsp.window.float())

-- Forces every window on the workspace into floating mode

hl.bind("SUPER + SHIFT" .. " + " .. "V", hl.dsp.exec_cmd("hyprctl clients -j| jq -r '.[]| select(.workspace.id=='$(hyprctl activeworkspace -j| jq '.id')')| . address'| xargs -I { } hyprctl dispatch togglefloating address:{ }"))

-- Toggle Rofi App Launcher using Super and Tab

hl.bind("SUPER" .. " + " .. "TAB", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -theme-str 'window { close-on-click:true; } '"))

hl.bind("SUPER" .. " + " .. "M", hl.dsp.exec_cmd("nautilus"))

-- Delete or replace the bottom section with ONLY this line:

hl.bind("SUPER" .. " + " .. "mouse:272", hl.dsp.window.drag(), { mouse = true })

hl.bind("SUPER" .. " + " .. "mouse:273", hl.dsp.window.resize(), { mouse = true })

-- TODO: manual review: blurls = "waybar"

-- Autostart
hl.on("hyprland.start", function()
   hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
   hl.exec_cmd("waybar &")
   -- hl.exec_cmd("eww daemon")
   hl.exec_cmd("awww-daemon")
   hl.exec_cmd("awww img ~/Pictures/Wallpapers/hk.png")
   hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
   hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
   hl.exec_cmd("eww daemon")
   hl.exec_cmd("playerctld daemon")
   --hl.exec_cmd("nwg-dock-hyprland -mb 4 -d -p bottom -i 32 -w 4 -l top -lp start -c 'rofi -show drun' -a start &")
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
  xdg.configFile."hypr/hyprlock.conf" = {
  force = true;
  text = ''
background {
    monitor =
    path = /home/garinh/Pictures/Wallpapers/hk.png
    blur_passes = 3 # Adds a nice frosted look to your wallpaper
    blur_size = 7
}
input-field {
    monitor =
    size = 200, 50
    outline_thickness = 3
    dots_size = 0.33 # Size of input-field dots
    dots_spacing = 0.15 # Spacing of input-field dots
    dots_fade_time = 200 # Milliseconds to fade dots on input
    outer_color = rgb(202, 158, 230) # Frappé Mauve
    inner_color = rgb(48, 52, 70)    # Frappé Base
    font_color = rgb(198, 208, 245)  # Frappé Text
    fade_on_empty = false
    placeholder_text = <i>Input Password...</i>
    hide_input = false
    font_family = Ioskeley Mono
    position = 0, -20
    halign = center
    valign = center
}
label {
    monitor =
    text = cmd[update:1000] echo "$TIME"
    color = rgb(198, 208, 245) # Frappé Text
    font_size = 64
    font_family = Ioskeley Mono
    
    position = 0, 80
    halign = center
    valign = center
}

'';
};
  xdg.configFile."rofi/config.rasi" = {
  force = true;
  text = ''
  
@theme "~/.config/rofi/catppuccin/launcher.rasi"

'';
};
  xdg.configFile."rofi/catppuccin/launcher.rasi" = {
  force = true;
  text = ''
  /**
 * Copyright (C) 2020-2024 Aditya Shakya <adi1090x@gmail.com>
 **/

/*****----- Configuration -----*****/
configuration {
	modi:                       "drun,run,filebrowser";
    show-icons:                 true;
    display-drun:               "";
    display-run:                "";
    display-filebrowser:        "";
	drun-display-format:        "{name}";
}

/*****----- Global Properties -----*****/
@import                          "shared/colors.rasi"
@import                          "shared/fonts.rasi"

/*****----- Main Window -----*****/
window {
    /* properties for window widget */
    transparency:                "real";
    location:                    west;
    anchor:                      west;
    fullscreen:                  false;
    width:                       500px;
    height:                      96%;
    x-offset:                    20px;
    y-offset:                    0px;

    /* properties for all widgets */
    enabled:                     true;
    margin:                      0px;
    padding:                     0px;
    border:                      4px solid;
    border-radius:               12px;
    border-color:                @background-alt;
    cursor:                      "default";
    background-color:            @background;
}

/*****----- Main Box -----*****/
mainbox {
    enabled:                     true;
    spacing:                     20px;
    margin:                      0px;
    padding:                     20px;
    background-color:            transparent;
    children:                    [ "inputbar", "message", "listview", "mode-switcher" ];
}

/*****----- Inputbar -----*****/
inputbar {
    enabled:                     true;
    spacing:                     10px;
    margin:                      0px;
    padding:                     10px;
    border-radius:               12px;
    background-color:            @background-alt;
    text-color:                  @foreground;
    children:                    [ "textbox-prompt-colon", "entry" ];
}

prompt {
    enabled:                     true;
    background-color:            inherit;
    text-color:                  inherit;
}
textbox-prompt-colon {
    enabled:                     true;
    padding:                     0px;
    expand:                      false;
    str:                         "";
    background-color:            inherit;
    text-color:                  inherit;
}
entry {
    enabled:                     true;
    padding:                     0px;
    background-color:            inherit;
    text-color:                  inherit;
    cursor:                      text;
    placeholder:                 "Search...";
    placeholder-color:           inherit;
}

/*****----- Listview -----*****/
listview {
    enabled:                     true;
    columns:                     1;
    lines:                       12;
    cycle:                       true;
    dynamic:                     true;
    scrollbar:                   true;
    layout:                      vertical;
    reverse:                     false;
    fixed-height:                true;
    fixed-columns:               true;
    
    spacing:                     5px;
    background-color:            transparent;
    text-color:                  @foreground;
    cursor:                      "default";
}
scrollbar {
    handle-width:                5px ;
    handle-color:                @selected;
    border-radius:               10px;
    background-color:            @background-alt;
}

/*****----- Elements -----*****/
element {
    enabled:                     true;
    spacing:                     10px;
    margin:                      0px;
    padding:                     6px;
    border-radius:               12px;
    background-color:            transparent;
    text-color:                  @foreground;
    cursor:                      pointer;
}
element normal.normal,
element alternate.normal {
    background-color:            var(background);
    text-color:                  var(foreground);
}
element normal.urgent,
element alternate.urgent,
element selected.active {
    background-color:            var(urgent);
    text-color:                  var(background);
}
element normal.active,
element alternate.active,
element selected.urgent {
    background-color:            var(active);
    text-color:                  var(background);
}
element selected.normal {
    background-color:            var(selected);
    text-color:                  var(background);
}
element-icon {
    background-color:            transparent;
    text-color:                  inherit;
    size:                        24px;
    cursor:                      inherit;
}
element-text {
    background-color:            transparent;
    text-color:                  inherit;
    highlight:                   inherit;
    cursor:                      inherit;
    vertical-align:              0.5;
    horizontal-align:            0.0;
}

/*****----- Mode Switcher -----*****/
mode-switcher{
    enabled:                     true;
    spacing:                     10px;
    margin:                      0px;
    padding:                     0px 0px;
    background-color:            transparent;
    text-color:                  @foreground;
}
button {
    padding:                     10px;
    border-radius:               12px;
    background-color:            @background-alt;
    text-color:                  inherit;
    cursor:                      pointer;
}
button selected {
    background-color:            var(urgent);
    text-color:                  var(background);
}

/*****----- Message -----*****/
message {
    enabled:                     true;
    margin:                      0px;
    padding:                     10px;
    border-radius:               12px;
    background-color:            @background-alt;
    text-color:                  @foreground;
}
textbox {
    background-color:            transparent;
    text-color:                  @foreground;
    vertical-align:              0.5;
    horizontal-align:            0.0;
    highlight:                   none;
    placeholder-color:           @foreground;
    blink:                       true;
    markup:                      true;
}
error-message {
    padding:                     20px;
    background-color:            @background;
    text-color:                  @foreground;
}
'';
};
xdg.configFile."rofi/catppuccin/shared/colors.rasi" = {
	force = true;
	text = ''
/* Copyright (C) 2020-2024 Aditya Shakya <adi1090x@gmail.com> */

/* Colors */

* {
    background:     #303446;
    background-alt: #414559;
    foreground:     #c6d0f5;
    selected:       #99d1db;
    active:         #ef9f76;
    urgent:         #e78284;
}
'';
};
xdg.configFile."rofi/catppuccin/shared/fonts.rasi" = {
	force = true;
	text = ''
/* Copyright (C) 2020-2024 Aditya Shakya <adi1090x@gmail.com> */

/* Text Font */

* {
    font: "Ioskeley Mono 11";
}
'';
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
xdg.configFile."swaync/config.json" = {
	force = true;
	text = ''
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "ignore-gtk-theme": true,
  "positionX": "right",
  "positionY": "top",
  "layer": "overlay",
  "control-center-layer": "top",
  "layer-shell": true,
  "layer-shell-cover-screen": true,
  "cssPriority": "user",
  "control-center-margin-top": 0,
  "control-center-margin-bottom": 0,
  "control-center-margin-right": 0,
  "control-center-margin-left": 0,
  "notification-2fa-action": true,
  "notification-inline-replies": false,
  "notification-body-image-height": 100,
  "notification-body-image-width": 200,
  "timeout": 10,
  "timeout-low": 5,
  "timeout-critical": 0,
  "fit-to-screen": true,
  "relative-timestamps": true,
  "control-center-width": 500,
  "control-center-height": 600,
  "notification-window-width": 500,
  "keyboard-shortcuts": true,
  "notification-grouping": true,
  "image-visibility": "when-available",
  "transition-time": 200,
  "hide-on-clear": false,
  "hide-on-action": true,
  "text-empty": "No Notifications",
  "script-fail-notify": true,
  "scripts": {
    "example-script": {
      "app-name": "example.app.id",
      "exec": "echo 'Do something...'",
      "urgency": "Normal"
    },
    "example-action-script": {
      "app-name": "example.app.id",
      "exec": "echo 'Do something actionable!'",
      "urgency": "Normal",
      "run-on": "action"
    }
  },
  "notification-visibility": {
    "example-name": {
      "state": "muted",
      "urgency": "Normal",
      "app-name": "example.app.id"
    }
  },
  "widgets": [
    "inhibitors",
    "title",
    "dnd",
    "notifications"
  ],
  "widget-config": {
    "notifications": {
      "vexpand": true
    },
    "inhibitors": {
      "text": "Inhibitors",
      "button-text": "Clear All",
      "clear-all-button": true
    },
    "title": {
      "text": "Notifications",
      "clear-all-button": true,
      "button-text": "Clear All"
    },
    "dnd": {
      "text": "Do Not Disturb"
    },
    "label": {
      "max-lines": 5,
      "text": "Label Text"
    },
    "mpris": {
      "blacklist": [],
      "autohide": false,
      "show-album-art": "always",
      "loop-carousel": false
    },
    "buttons-grid": {
      "buttons-per-row": 7,
      "actions": [
        {
          "label": "直",
          "type": "toggle",
          "active": true,
          "command": "sh -c '[[ $SWAYNC_TOGGLE_STATE == true ]] && nmcli radio wifi on || nmcli radio wifi off'",
          "update-command": "sh -c '[[ $(nmcli radio wifi) == \"enabled\" ]] && echo true || echo false'"
        }
      ]
    }
  }
}
'';
};
xdg.configFile."swaync/style.css" = {
	force = true;
	text = ''
:root {
  --cc-bg: rgba(48, 52, 70, 0.7);
  --noti-border-color: rgba(198, 208, 245, 0.15);
  --noti-bg: 48, 52, 70;
  --noti-bg-alpha: 0.8;
  --noti-bg-darker: rgb(41, 44, 60);
  --noti-bg-hover: rgb(65, 69, 89);
  --noti-bg-focus: rgba(81, 87, 109, 0.6);
  --noti-close-bg: rgb(81, 87, 109);
  --noti-close-bg-hover: rgb(98, 104, 128);
  --text-color: rgb(198, 208, 245);
  --text-color-disabled: rgb(115, 121, 148);
  --bg-selected: rgb(140, 170, 238);
  --notification-icon-size: 64px;
  --notification-app-icon-size: calc(var(--notification-icon-size) / 3);
  --notification-group-icon-size: 32px;
  --border: 1px solid var(--noti-border-color);
  --border-radius: 12px;
  --notification-shadow: 0 0 0 1px rgba(35, 38, 52, 0.3),
    0 1px 3px 1px rgba(35, 38, 52, 0.7), 0 2px 6px 2px rgba(35, 38, 52, 0.3);
  --font-size-body: 15px;
  --font-size-summary: 16px;
  /* Deprecated variables (because of their typos). Keeeping them around for backwards compatibility. */
  --hover-tranistion: background 0.15s ease-in-out;
  --group-collapse-tranistion: opacity 400ms ease-in-out;
  --hover-transition: var(--hover-tranistion);
  --group-collapse-transition: var(--group-collapse-tranistion);
}

/* Fallback for older CSS themes — Catppuccin Frappé */
@define-color cc-bg rgba(48, 52, 70, 0.7);
@define-color noti-border-color rgba(198, 208, 245, 0.15);
@define-color noti-bg rgba(48, 52, 70, 0.8);
@define-color noti-bg-opaque rgb(48, 52, 70);
@define-color noti-bg-darker rgb(41, 44, 60);
@define-color noti-bg-hover rgb(65, 69, 89);
@define-color noti-bg-hover-opaque rgb(65, 69, 89);
@define-color noti-bg-focus rgba(81, 87, 109, 0.6);
@define-color noti-close-bg rgba(198, 208, 245, 0.1);
@define-color noti-close-bg-hover rgba(198, 208, 245, 0.15);
@define-color text-color rgb(198, 208, 245);
@define-color text-color-disabled rgb(115, 121, 148);
@define-color bg-selected rgb(140, 170, 238);
notificationwindow, blankwindow {
  background: transparent;
}

.close-button {
  /* The notification Close Button */
  background: var(--noti-close-bg);
  color: var(--text-color);
  text-shadow: none;
  padding: 0;
  border-radius: 100%;
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
  border-radius: var(--border-radius);
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
  border-radius: var(--border-radius);
}

.notification-row .notification-background .notification .notification-default-action:hover {
  -gtk-icon-filter: none;
  background: var(--noti-bg-hover);
}

.notification-row .notification-background .notification .notification-default-action:not(:only-child) {
  /* When alternative actions are visible */
  border-bottom-left-radius: 0px;
  border-bottom-right-radius: 0px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content {
  background: transparent;
  border-radius: var(--border-radius);
  padding: 0;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .image {
  /* Notification Primary Image */
  -gtk-icon-filter: none;
  -gtk-icon-size: var(--notification-icon-size);
  border-radius: 100px;
  /* Size in px */
  margin: 4px;
}

.notification-row .notification-background .notification .notification-default-action .notification-content .app-icon {
  /* Notification app icon (only visible when the primary image is set) */
  -gtk-icon-filter: none;
  -gtk-icon-size: var(--notification-app-icon-size);
  -gtk-icon-shadow: 0 1px 4px rgba(35, 38, 52, 0.8);
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
  background-color: rgb(198, 208, 245);
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
  border-radius: var(--border-radius);
}

.notification-row .notification-background .notification .notification-default-action .notification-content .inline-reply .inline-reply-button {
  margin-left: 4px;
  background: rgba(var(--noti-bg), var(--noti-bg-alpha));
  border: var(--border);
  border-radius: var(--border-radius);
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
  border-bottom-left-radius: var(--border-radius);
  border-bottom-right-radius: var(--border-radius);
  padding: 4px;
}

.notification-row .notification-background .notification .notification-action {
  /* The alternative actions below the default action */
  margin: 4px;
  padding: 0;
}

.notification-row .notification-background .notification .notification-action > button {
  border-radius: var(--border-radius);
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
  border-radius: var(--border-radius);
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
  border-radius: var(--border-radius);
}

/* Title widget */
.widget-title > label {
  margin-right: 8px;
  font-size: 1.5rem;
}

.widget-title > button {
  margin-left: 8px;
  border-radius: var(--border-radius);
}

/* DND widget */
.widget-dnd label {
  color: var(--text-color);
  margin-right: 8px;
  font-size: 1.1rem;
}

.widget-dnd switch {
  border-radius: var(--border-radius);
  margin-left: 8px;
}

.widget-dnd switch slider {
  border-radius: var(--border-radius);
}

/* Label widget */
.widget-label > label {
  font-size: 1.1rem;
}

/* Mpris widget */
:root {
  --mpris-album-art-overlay: rgba(35, 38, 52, 0.55);
  --mpris-button-hover: rgba(35, 38, 52, 0.5);
  --mpris-album-art-icon-size: 96px;
  --mpris-album-art-shadow: 0px 0px 10px rgba(35, 38, 52, 0.75);
}

.widget-mpris {
  padding: 0;
  /* The parent to all players */
}

.widget-mpris .widget-mpris-player {
  margin: 16px 20px;
  border-radius: var(--border-radius);
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
  border-radius: var(--border-radius);
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
.widget-buttons-grid flowboxchild > button {
  border-radius: var(--border-radius);
}

.widget-buttons-grid flowboxchild > button.toggle:checked {
  /* style given to the active toggle button */
  background-color: rgb(140, 170, 238);
  color: rgb(35, 38, 52);
}

/* Menubar widget */
.widget-menubar {
  /* The revealer buttons */
  /* .AnyName { Name defined in config after #
    background-color: rgba(var(--noti-bg), 1.0);
    padding: 8px;
    margin: 8px;
    border-radius: 12px;
  }

  .AnyName>button {
    background: transparent;
    border: none;
  }

  .AnyName>button:hover {
    background-color: var(--noti-bg-hover);
  } */
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
  border-radius: var(--border-radius);
  margin: 0 4px;
}

.widget-menubar > revealer * {
  margin-top: 8px;
}

.widget-menubar > revealer * button {
  border-radius: var(--border-radius);
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
  background-color: rgb(65, 69, 89);
  margin: 8px;
  margin-bottom: 0;
  border-radius: var(--border-radius);
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
  border-radius: var(--border-radius);
}
'';
};
xdg.configFile."fastfetch/config.jsonc" = {
	force = true;
	text = ''
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "padding": {
            "top": 1,
            "right": 3
        }
    },
    "display": {
        "separator": " │ " // This creates the clean continuous vertical line for everything
    },
    "modules": [
    	{
    		"type": "custom",
    		"format": "╭───────────╮"
    		
    	},
        {
            "type": "user",
            "key": "│ user    ",
            "keyColor": "red"
        },
        {
            "type": "host",
            "key": "│󰋜 hname   ",
            "keyColor": "green"
        },
        {
            "type": "command",
            "key": "│󰋔 os age  ",
            "keyColor": "yellow",
            "text": "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days"
        },
        {
            "type": "uptime",
            "key": "│󱎫 uptime  ",
            "keyColor": "blue"
        },
        {
            "type": "os",
            "key": "│ distro  ",
            "keyColor": "cyan"
        },
        {
            "type": "kernel",
            "key": "│󰒋 kernel  ",
            "keyColor": "magenta"
        },
        {
            "type": "wm",
            "key": "│󱂬 wm      ",
            "keyColor": "green"
        },
        {
            "type": "lm",
            "key": "│󰧨 desktop ",
            "keyColor": "cyan"
        },
        {
            "type": "terminal",
            "key": "│ term    ",
            "keyColor": "red"
        },
        {
            "type": "shell",
            "key": "│󰞷 shell   ",
            "keyColor": "green"
        },
        {
            "type": "cpu",
            "key": "│󰻠 cpu     ",
            "keyColor": "yellow"
        },
        {
            "type": "gpu",
            "key": "│󰢮 gpu     ",
            "keyColor": "yellow"
        },
        {
            "type": "disk",
            "key": "│󰋊 disk    ",
            "keyColor": "blue"
        },
        {
            "type": "memory",
            "key": "│󰍛 memory  ",
            "keyColor": "cyan"
        },
        {
            "type": "localip",
            "key": "│ local ip",
            "keyColor": "blue"
        },
        {
            "type": "packages",
            "key": "│ packages",
            "keyColor": "green"
        },
        // --- This builds the tiny box ONLY around the colors label ---
        {
            "type": "custom",
            "format": "├───────────┤" // Connects cleanly into the separator line
        },
        {
            "type": "colors",
            "key": "│🎨 colors ", // Acts as the left wall of the tiny box
            "symbol": "circle"
        },
        {
            "type": "custom",
            "format": "╰───────────╯" // Closes the tiny box at the bottom
        }
    ]
}
'';
};
gtk = {
  enable = true;

  theme = {
    name = "catppuccin-frappe-blue-standard"; # whatever GTK theme you have installed
    package = pkgs.catppuccin-gtk.override {
      accents = [ "blue" ];
      size = "standard";
      variant = "frappe";
    };
  };

  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };


  font = {
    name = "Hanken Grotesk";
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
  name = "catppuccin-mocha-mauve-cursors";
  package = pkgs.catppuccin-cursors.mochaMauve;
  size = 24;
  gtk.enable = true;
  x11.enable = true;
};
programs.bash = {
  enable = true;
  shellAliases = {
    ll = "ls -la";
    gs = "git status";
    update = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch && cd";
    viconfig = "sudo fresh /etc/nixos/configuration.nix";
    rmold = "nh clean all";
    rmcache = "sudo nix-collect-garbage";
    sudo = "doas";
    home-update = "home-manager switch";
  };
  bashrcExtra = ''
    source -- ~/.local/share/blesh/ble.sh
    eval "$(starship init bash)"
    export PATH=~/bin:$PATH
    pfetch
  '';
};
}
