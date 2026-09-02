# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #./kernel.nix
    ];

  boot.blacklistedKernelModules = [ "acpi_pad" "nouveau" ];
  # Bootloader.
  #boot.loader.systemd-boot.enable = true;
boot.loader.grub = {
  enable = true;
  efiSupport = true;
  device = "nodev";
  useOSProber = true;

  theme = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "grub";
    rev = "main";              # or pin to a specific commit/tag for reproducibility
    sha256 = "jgM22pvCQvb0bjQQXoiqGMgScR9AgCK3OfDF5Ud+/mk=";                # leave blank first build — Nix will error with the correct hash, paste it back in
  } + "/src/catppuccin-frappe-grub-theme";
};

  boot.loader.efi.canTouchEfiVariables = true;
  # Use latest kernel. Baseline, cachy @ line 157
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  nix.settings.trusted-users = [ "root" "garinh" ];
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
  #nix helper
  programs.bash.blesh.enable = true;
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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
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

/*nixpkgs.overlays = [
  (final: prev: {
    hyprland = prev.hyprland.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or []) ++ [
        "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
        "-DFETCHCONTENT_SOURCE_DIR_GLAZE=${prev.fetchFromGitHub {
          owner = "stephenberry";
          repo = "glaze";
          rev = "v7.2.0";
          hash = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
        }}"
      ];
    });
  })
];*/
programs.hyprland.enable = true;
xdg.portal = {
  enable = true;
  extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
};
#kmscon tty
services.kmscon = {
  enable = true;
  hwRender = true;
  config = {
    font-name = "JetBrainsMono Nerd Font";
    font-size = 12;
    xkb-layout = "us";
  };
};

# Enable and configure LY
services.displayManager = {
  ly.enable = true;
  # Optional: Customize Ly visual elements
  ly.settings = {
    animation = "matrix"; # TUI matrix background effect
    bigclock = true;
  };
};

environment.sessionVariables = {
  # Tells GTK and XWayland apps what cursor theme to use
  # Forces Nvidia to render the mouse cursor manually
  WLR_NO_HARDWARE_CURSORS = "1";
  # Fixes standard electron/chromium apps on Wayland too
  NIXOS_OZONE_WL = "1"; 

};
# =========================================================================
# 2. SYSTEM-WIDE FONTS SETTINGS (Nerd Fonts, Ioskeley Mono, Hanken Grotesk)
# =========================================================================
fonts = {
  enableDefaultPackages = true;
  packages = with pkgs; [
    # Modern granular Nerd Font packages (instead of the huge legacy package)
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only       # Acts as a universal fallback for system icons

    # Ioskeley Mono - the exact Berkeley Mono mimic configuration built over Iosevka
    # Options include: .normal, .normal-NF (Nerd Font patched), .condensed, etc.
    ioskeley-mono.normal-NF       # Pre-patched with Nerd Font glyphs

    # Clean, modern sans-serif typeface
    noto-fonts
  ];


  # Inform your desktop environment how to prioritize these fonts
  fontconfig.defaultFonts = {
    monospace = [ "Ioskeley Mono" "JetBrainsMono Nerd Font" ];
    sansSerif = [ "Noto Sans" ];
  };
};
#zram and such (oh yes)
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 150;  # 1.5x RAM as compressed swap
};
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
services.xserver.videoDrivers = [ "nvidia" ];
#nvidia
hardware.nvidia = {
  package = config.boot.kernelPackages.nvidiaPackages.latest;
  open = true;
  modesetting.enable = true;
  powerManagement.enable = true;
};
#LE STEAM
programs.steam = {
  enable = true; # Master switch, already covered in installation
  remotePlay.openFirewall = true;  # Open ports in the firewall for Steam Remote Play
  dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
  # Other general flags if available can be set here.
};
# Improves Performance With games (temporary and in game, dont worry)
programs.gamemode.enable = true;
boot.extraModprobeConfig = ''
  options nvidia NVreg_PreserveVideoMemoryAllocations=1
  options nvidia NVreg_TemporaryFilePath=/var/tmp
'';

boot.kernelParams = [ "nvidia-drm.modeset=1" ];
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
  # services.xserver.libinput.enable = true;
  #helps bins work
programs.nix-ld.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."garinh" = {
    isNormalUser = true;
    description = "garinh";
    extraGroups = [ "networkmanager" "wheel" "input" ];
    packages = with pkgs; [
    #  thunderbird
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
services.udev.packages = with pkgs; [ oversteer ];
# make sure you're in the input group
  # 2. Tell NixOS to use the CachyOS kernel package
  # Options include: linuxPackages-cachyos-latest, linuxPackages-cachyos-lts, etc.
  # boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  services.flatpak.enable = true;
  # 3. (Optional) Enable Sched-ext (scx) framework support if you want to use its modern schedulers
  services.scx = {
  enable = true;
  scheduler = "scx_bpfland";  # or scx_rusty, scx_lavd, etc — pick per workload
  };
services.udisks2.enable = true;
  # Install firefox.
  programs.firefox.enable = true;
  #power prof daemon
  services.power-profiles-daemon.enable = true;
  #hehe wm
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
programs.starship.enable = true;
programs.git.enable = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
 	 catppuccin-gtk
 	 papirus-icon-theme
  # The Fresh Terminal Text Editor/IDE
 	 udisks2
 	 fresh-editor
     wget
     cpio
     cmake
     llvm
     clang
     protontricks
     winetricks
     wineWow64Packages.stable
     gpu-screen-recorder-gtk
     tty-clock
     stdenv.cc
     bison
     flex
     pkg-config
     elfutils          # Needed for kernel header unpacking
     openssl           # Needed for kernel signing checks
     bc                # Math tool used in the kernel Makefile
     gnumake
     lunar-client
     unzip
     yt-dlp
     pkgs.kdePackages.qtmultimedia
     pkgs.qt6.qtmultimedia
     swaynotificationcenter
     pkg-config
  	 nwg-look
     lavat
(pkgs.waybar.overrideAttrs (old: {
  buildInputs = (old.buildInputs or []) ++ [ pkgs.modemmanager ];
  mesonFlags = (old.mesonFlags or []) ++ [ 
      "-Dcava=disabled"
      "-Dsystemd=disabled"
  ];
  env.NIX_CFLAGS_COMPILE = "-march=native -O3";
  doInstallCheck = false;
}))
     ffmpeg
     micro
     hyprlock
     fastfetch
     psmisc
     kitty
     rofi
     btop
     kew
     go
     pavucontrol
     flatpak
     mdadm
     util-linux
     awww
     hyprshot
     gnome-themes-extra
     bibata-cursors
     catppuccin-cursors.mochaDark
     catppuccin-cursors.mochaGreen
     libsForQt5.qt5ct
     qt6Packages.qt6ct
     adwaita-qt
     adwaita-qt6
     pipes
     libreoffice
     kdePackages.qt6ct
     adwaita-icon-theme
     nautilus
     wl-clipboard
     playerctl
     telegram-desktop
     nodejs
  ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
  enable = true;
  ports = [ 22 ];
  settings = {
    PasswordAuthentication = true; # Set to false if using SSH keys exclusively
    PermitRootLogin = "no";        # "yes", "no", or "prohibit-password"
  };
};

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
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
