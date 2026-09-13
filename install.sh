#!/usr/bin/env bash

# 1. Require root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# 2. Prompt users for system username
read -p "Enter the new username for the system: " sys_user

# 3. Prompt users for display configuration
echo "Hyprland Display Configuration"
read -p "Enter your display output (e.g., eDP-1, DP-1, DP-3): " disp_out
read -p "Enter your display mode (e.g., 1920x1080@60, 2560x1440@144): " disp_mode

# 4. Prompt users for Kernel choice
echo "Select Kernel:"
echo "1) Base (latest)"
echo "2) CachyOS"
read -p "Which kernel do you want to use? (See configuration.nix comment for details) [1-2]: " kernel_choice

# 5. Prompt users for GPU choice
echo "Select GPU Driver:"
echo "1) Intel"
echo "2) Nvidia"
echo "3) AMD"
read -p "Which GPU driver do you want to use? [1-3]: " gpu_choice

# Update the username globally across all .nix files in the current directory
echo "Updating username across configuration files..."
sed -i "s/garinh/$sys_user/g" ./*.nix

# Update the Hyprland monitor output and mode inside home.nix
echo "Updating display configuration in home.nix..."
sed -i "s/output   = \"DP-3\"/output   = \"$disp_out\"/g" ./home.nix
sed -i "s/mode     = \"1920x1080@240\"/mode     = \"$disp_mode\"/g" ./home.nix

# Apply Kernel choice
if [ "$kernel_choice" = "1" ]; then
    echo "Setting kernel to linuxPackages_latest..."
    sed -i 's/boot.kernelPackages = pkgs.linuxPackages_cachyos;/boot.kernelPackages = pkgs.linuxPackages_latest;/g' ./configuration.nix
elif [ "$kernel_choice" = "2" ]; then
    echo "Keeping kernel as linuxPackages_cachyos..."
else
    echo "Invalid kernel choice, defaulting to Base (latest)..."
    sed -i 's/boot.kernelPackages = pkgs.linuxPackages_cachyos;/boot.kernelPackages = pkgs.linuxPackages_latest;/g' ./configuration.nix
fi

# Apply GPU choice based on official NixOS documentation
if [ "$gpu_choice" = "1" ]; then
    echo "Applying Intel GPU configuration..."
    sed -i 's/services.xserver.videoDrivers = \[ "nvidia" \];/services.xserver.videoDrivers = \[ "intel" \];/g' ./configuration.nix
    sed -i '/boot.blacklistedKernelModules = \[ "acpi_pad" "nouveau" \];/a \ \ boot.initrd.kernelModules = [ "i915" ];' ./configuration.nix
    
    # Disable Nvidia configurations in configuration.nix
    sed -i '/hardware.nvidia = {/,/};/s/^/#/' ./configuration.nix
    sed -i '/boot.extraModprobeConfig =/,/;/s/^/#/' ./configuration.nix
    sed -i '/boot.kernelParams = \[ "nvidia-drm.modeset=1" \];/s/^/#/' ./configuration.nix
    sed -i '/WLR_NO_HARDWARE_CURSORS = "1";/s/^/#/' ./configuration.nix
    
    # Disable Nvidia env vars in home.nix (Hyprland config)
    sed -i 's/hl.env("LIBVA_DRIVER_NAME", "nvidia")/-- hl.env("LIBVA_DRIVER_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("GBM_BACKEND", "nvidia-drm")/-- hl.env("GBM_BACKEND", "nvidia-drm")/g' ./home.nix

elif [ "$gpu_choice" = "3" ]; then
    echo "Applying AMD GPU configuration..."
    sed -i 's/services.xserver.videoDrivers = \[ "nvidia" \];/services.xserver.videoDrivers = \[ "amdgpu" \];/g' ./configuration.nix
    sed -i '/boot.blacklistedKernelModules = \[ "acpi_pad" "nouveau" \];/a \ \ boot.initrd.kernelModules = [ "amdgpu" ];' ./configuration.nix
    
    # Disable Nvidia configurations in configuration.nix
    sed -i '/hardware.nvidia = {/,/};/s/^/#/' ./configuration.nix
    sed -i '/boot.extraModprobeConfig =/,/;/s/^/#/' ./configuration.nix
    sed -i '/boot.kernelParams = \[ "nvidia-drm.modeset=1" \];/s/^/#/' ./configuration.nix
    sed -i '/WLR_NO_HARDWARE_CURSORS = "1";/s/^/#/' ./configuration.nix

    # Disable Nvidia env vars in home.nix (Hyprland config)
    sed -i 's/hl.env("LIBVA_DRIVER_NAME", "nvidia")/-- hl.env("LIBVA_DRIVER_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("GBM_BACKEND", "nvidia-drm")/-- hl.env("GBM_BACKEND", "nvidia-drm")/g' ./home.nix
    
elif [ "$gpu_choice" = "2" ]; then
    echo "Keeping standard Nvidia GPU configuration..."
else
    echo "Invalid GPU choice, keeping default (Nvidia)..."
fi

# Proceed with the original installation routine
echo "copying configuration files..."
cp ./*.nix /etc/nixos/

echo "installing the distro..."
cd /etc/nixos && nix flake update && nixos-rebuild switch --flake /etc/nixos#nixos --impure && cd && flatpak update -y

echo "Installation complete."
echo "OS installed!"
